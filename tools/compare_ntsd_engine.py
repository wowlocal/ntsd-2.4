#!/usr/bin/env python3
"""Bounded static compatibility comparison against an existing game dump.

Default modes read MDMP mappings and recorded main-module code with the existing
PE reader. The separately planned RNG, ordinary-buffer and Object-body pilots
execute x86 routines in Unicorn on declared inputs. File inputs are only pinned
ordinary files or synthetic buffers. No mode rebuilds an EXE, reads opaque
embedded content, or supplies missing memory as known zero. Source-only results
do not establish Native or whole-game parity.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import struct
import sys

from inspect_original import PE


class RecordedMemory:
    def __init__(self, path):
        self.path = Path(path)
        self.file = self.path.open('rb')
        self.size = self.path.stat().st_size
        signature, version, count, directory, _, _, self.flags = self.unpack('<4sIIIIIQ', 0)
        if signature != b'MDMP' or count > 128:
            raise ValueError('Unsupported MDMP directory')
        self.directory_entries = count
        self.streams = {}
        for i in range(count):
            kind, size, rva = self.unpack('<III', directory + i*12)
            if kind == 0:
                if size != 0 or rva != 0:
                    raise ValueError('Nonempty unused stream directory entry')
                continue
            self.read(rva, size)
            if kind in self.streams:
                raise ValueError('Duplicate stream kind')
            self.streams[kind] = (size, rva)
        self.regions = []
        if 9 in self.streams:
            size, rva = self.streams[9]
            n, offset = self.unpack('<QQ', rva)
            if n > 100000 or 16+n*16 > size:
                raise ValueError('Memory64 directory extent')
            for i in range(n):
                address, length = self.unpack('<QQ', rva + 16+i*16)
                if offset+length > self.size:
                    raise ValueError('Memory64 payload outside file')
                self.regions.append((address, address+length, offset))
                offset += length
        else:
            raise ValueError('This pass requires the validated Memory64 stream')
        self.regions.sort()
        if any(a[1] > b[0] for a, b in zip(self.regions, self.regions[1:])):
            raise ValueError('Overlapping memory regions')
        self.starts = [r[0] for r in self.regions]
        self.payload_bytes_read = 0

    def read(self, offset, count):
        if offset < 0 or count < 0 or offset+count > self.size:
            raise ValueError('File read outside dump')
        self.file.seek(offset)
        data = self.file.read(count)
        if len(data) != count:
            raise ValueError('Short dump read')
        return data

    def unpack(self, fmt, offset):
        return struct.unpack(fmt, self.read(offset, struct.calcsize(fmt)))

    def virtual(self, address, count):
        if self.payload_bytes_read + count > 8*1024*1024:
            raise ValueError('Declared module-read budget exceeded')
        out = []
        while count:
            i = bisect_right(self.starts, address)-1
            if i < 0 or not self.regions[i][0] <= address < self.regions[i][1]:
                raise ValueError(f'Unrecorded memory at {address:#x}')
            begin, end, offset = self.regions[i]
            n = min(count, end-address)
            out.append(self.read(offset+address-begin, n))
            self.payload_bytes_read += n
            address += n
            count -= n
        return b''.join(out)

    def modules(self):
        size, rva = self.streams[4]
        count, = self.unpack('<I', rva)
        if count > 1024 or 4+count*108 > size:
            raise ValueError('Module directory extent')
        out = []
        for i in range(count):
            p = rva+4+i*108
            base, extent, checksum, timestamp, name_rva = self.unpack('<QIIII', p)
            length, = self.unpack('<I', name_rva)
            if length > 65536 or length % 2:
                raise ValueError('Module name extent')
            name = self.read(name_rva+4, length).decode('utf-16le')
            out.append(dict(name=name.replace('\\', '/').split('/')[-1],
                            base=hex(base), size=extent, checksum=hex(checksum),
                            timeDateStamp=timestamp))
        return out


def section_metadata(pe):
    offset = pe.pe+24+pe.u16(pe.pe+20)
    return [dict(s, characteristics=hex(pe.u32(offset+i*40+36)),
                 executable=bool(pe.u32(offset+i*40+36) & 0x20000000))
            for i, s in enumerate(pe.sections)]


def instruction_shape(ins):
    from capstone.x86 import X86_OP_IMM, X86_OP_MEM, X86_OP_REG
    if ins.id == 0:
        return ('data', bytes(ins.bytes).hex())
    operands = []
    for operand in ins.operands:
        if operand.type == X86_OP_REG:
            value = ('reg', operand.reg)
        elif operand.type == X86_OP_IMM:
            value = ('imm',)
        elif operand.type == X86_OP_MEM:
            m = operand.mem
            value = ('mem', m.segment, m.base, m.index, m.scale)
        else:
            value = ('other', operand.type)
        operands.append((operand.size, value))
    return (ins.mnemonic, tuple(operands))


def compare_anchors(baseline, pe, code, base, anchors):
    import capstone
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    md.skipdata = True

    def record(ins):
        return dict(address=hex(ins.address), bytes=ins.bytes.hex(), mnemonic=ins.mnemonic,
                    operands=ins.op_str)

    def prefix(data, address):
        out = []
        for ins in md.disasm(data[:256], address, count=20):
            if ins.mnemonic == 'int3':
                break
            out.append(ins)
            if ins.mnemonic == 'ret':
                break
        return out

    decoded = list(md.disasm(code, base))
    shapes = [instruction_shape(i) for i in decoded]
    windows = {}
    for i in range(max(0, len(shapes)-11)):
        key = tuple(shapes[i:i+12])
        if key not in windows:
            windows[key] = []
        windows[key].append(decoded[i].address)
    results = []
    for anchor in anchors:
        address = int(anchor['baselineVA'], 16)
        offset = pe.offset(address-pe.base)
        original = prefix(baseline[offset:offset+256], address)
        later = prefix(code[address-base:address-base+256], address)
        raw = b''.join(bytes(i.bytes) for i in original)
        raw_target = code[address-base:address-base+len(raw)]
        same_shape = ([instruction_shape(i) for i in original] ==
                      [instruction_shape(i) for i in later])
        if raw == raw_target:
            status = 'byte-identical sampled prefix at same VA'
        elif same_shape:
            status = 'same instruction/operand shape; numeric operands differ'
        else:
            status = 'different sampled instruction sequence; identity unresolved'
        changed = []
        if same_shape:
            for a, b in zip(original, later):
                if bytes(a.bytes) != bytes(b.bytes):
                    changed.append(dict(baseline=record(a), target=record(b)))
        candidates = windows.get(tuple(instruction_shape(i) for i in original[:12]), []) if len(original) >= 12 else []
        row = dict(anchor, status=status, sampledBaselineBytes=len(raw),
                   baselineInstructions=[record(i) for i in original],
                   targetSameVAInstructions=[record(i) for i in later], numericChanges=changed,
                   twelveInstructionShapeCandidateCount=len(candidates),
                   twelveInstructionShapeCandidates=[hex(v) for v in candidates[:8]])
        if 'baselineEndExclusive' in anchor:
            length = int(anchor['baselineEndExclusive'], 16)-address
            row['declaredWholeBaselineRange'] = dict(bytes=length,
                baselineHex=baseline[offset:offset+length].hex(),
                targetSameVAHex=code[address-base:address-base+length].hex())
        results.append(row)
    return dict(capstoneVersion=capstone.__version__,
                method='Purpose-selected same-VA prefixes, plus 12-instruction shape search ignoring numeric operands. Every numeric difference retained. Search candidates are not proven functions or behavioral matches.',
                limitation='Linear decoding can miss instruction starts or include data. Prefix agreement is not whole-function/caller equivalence. No global reuse percentage.',
                targetLinearInstructions=len(decoded), anchors=results)


def compare_ranges(baseline, pe, code, base, cases):
    import capstone
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    rows = []
    for case in cases:
        a, b = int(case['baselineVA'], 16), int(case['targetVA'], 16)
        n, m = case['baselineBytes'], case['targetBytes']
        if not 0 < n <= 16384 or not 0 < m <= 16384:
            raise ValueError('Declared range size exceeds bound')
        offset = pe.offset(a-pe.base)
        x, y = baseline[offset:offset+n], code[b-base:b-base+m]
        first, second = list(md.disasm(x, a)), list(md.disasm(y, b))
        if sum(i.size for i in first) != n or sum(i.size for i in second) != m:
            raise ValueError('Range is not fully decoded; boundary requires diagnosis')
        matcher = difflib.SequenceMatcher(a=[instruction_shape(i) for i in first],
            b=[instruction_shape(i) for i in second], autojunk=False)
        numeric, sequence = [], []
        for tag, i, j, k, l in matcher.get_opcodes():
            if tag == 'equal':
                for before, after in zip(first[i:j], second[k:l]):
                    if bytes(before.bytes) != bytes(after.bytes):
                        numeric.append(dict(baselineVA=hex(before.address), targetVA=hex(after.address),
                            mnemonic=before.mnemonic, baselineOperands=before.op_str, targetOperands=after.op_str,
                            baselineHex=before.bytes.hex(), targetHex=after.bytes.hex()))
            else:
                sequence.append(dict(kind=tag,
                    baseline=[dict(va=hex(q.address), mnemonic=q.mnemonic, operands=q.op_str) for q in first[i:j]],
                    target=[dict(va=hex(q.address), mnemonic=q.mnemonic, operands=q.op_str) for q in second[k:l]]))
        rows.append(dict(case, baselineInstructions=len(first), targetInstructions=len(second),
            baselineSHA256=hashlib.sha256(x).hexdigest(), targetSHA256=hashlib.sha256(y).hexdigest(),
            baselineHex=x.hex(), targetHex=y.hex(), numericChanges=numeric, sequenceChanges=sequence))
    return dict(method='Full declared static ranges aligned by instruction/operand shape; all numeric and sequence differences retained, no behavioral equivalence inferred.', cases=rows)


def rng_pilot(parent_path, pilot_path):
    """Case adapter for the existing configured Unicorn x86 reference environment.

    Existing frame/movement harnesses initialize 2.4-specific state; they cannot
    admit the captured target routine and relocated inputs without those effects.
    This adapter reuses their stack/return convention, with explicit leaf inputs.
    """
    import unicorn
    from unicorn import x86_const as registers
    from oracle_frames import STACK, STOP

    class Boundary(RuntimeError):
        pass

    parent = json.loads(parent_path.read_text())
    plan = json.loads(pilot_path.read_text())
    if hashlib.sha256(parent_path.read_bytes()).hexdigest() != plan['parentPlanSHA256']:
        raise ValueError('Pilot parent-plan pin mismatch')
    if unicorn.__version__ != plan['environment']['unicorn']:
        raise ValueError('Pilot Unicorn version mismatch')
    reference = parent['reference']
    original = Path(reference['baseline']).read_bytes()
    if hashlib.sha256(original).hexdigest() != reference['baselineSHA256']:
        raise ValueError('Pilot baseline identity mismatch')
    pe = PE(original)
    entry, end = int(plan['entry'], 16), int(plan['endExclusive'], 16)
    n = end-entry
    offset = pe.offset(entry-pe.base)
    source_bytes = original[offset:offset+n]
    target_bytes = RecordedMemory(reference['dump']).virtual(entry, n)
    if (hashlib.sha256(source_bytes).hexdigest() != plan['baselineCodeSHA256'] or
            hashlib.sha256(target_bytes).hexdigest() != plan['targetCodeSHA256']):
        raise ValueError('Pilot routine-byte identity mismatch')
    tables = {
        'ascending1to255': bytes(1+i % 255 for i in range(3000)),
        'all1': bytes([1])*3000,
        'alternating1and255': bytes(1 if i % 2 == 0 else 255 for i in range(3000)),
        'affine73plus19mod255plus1': bytes(1+(i*73+19) % 255 for i in range(3000)),
    }
    seeds = dict(EAX=0xf0e0d0c0, EBX=0x13579bdf, ECX=0x10a0b0c0,
                 EDX=0x11223344, ESI=0x55667788, EDI=0x99aabbcc,
                 EBP=0x2468ace0, EFLAGS=0x202)
    names = list(seeds)+['ESP', 'EIP']
    all_pcs = {key: set() for key in ('baseline', 'target')}

    def run(label, body, table, initial):
        fields = plan['stateIdentities'][label]
        uc = unicorn.Uc(unicorn.UC_ARCH_X86, unicorn.UC_MODE_32)
        for address, size in [(entry & ~0xfff, 0x1000), (fields['table'] & ~0xfff, 0x3000),
                              (STACK, 0x10000), (STOP & ~0xfff, 0x1000)]:
            uc.mem_map(address, size)
            uc.mem_write(address, b'\xa5'*size)
        uc.mem_write(entry, body)
        uc.mem_write(fields['table'], table)
        uc.mem_write(fields['index'], struct.pack('<I', initial['index']))
        uc.mem_write(fields['counter'], struct.pack('<I', initial['counter']))
        reads = [(fields['table'], fields['table']+3000),
                 (fields['index'], fields['index']+4), (fields['counter'], fields['counter']+4),
                 (STACK, STACK+0x10000)]
        writes = reads[1:]
        pending = []
        instruction_count = [0]

        def code_hook(machine, address, size, _):
            if not entry <= address < end or address+size > end:
                raise Boundary(f'Undeclared instruction at {address:#x}')
            instruction_count[0] += 1
            all_pcs[label].add(address)

        def memory_hook(machine, access, address, size, value, _):
            is_write = access == unicorn.UC_MEM_WRITE
            allowed = writes if is_write else reads
            if not any(a <= address and address+size <= b for a, b in allowed):
                raise Boundary(f'Undeclared {"write" if is_write else "read"} at {address:#x}+{size}')
            if is_write:
                identity = next((key for key in ('index', 'counter')
                                 if fields[key] <= address < fields[key]+4), 'stack')
                origin = STACK if identity == 'stack' else fields[identity]
                pending.append(dict(address=hex(address), identity=identity, offset=address-origin,
                    bytes=(value & ((1 << (size*8))-1)).to_bytes(size, 'little').hex()))

        uc.hook_add(unicorn.UC_HOOK_CODE, code_hook)
        uc.hook_add(unicorn.UC_HOOK_MEM_READ | unicorn.UC_HOOK_MEM_WRITE, memory_hook)
        calls = []
        for range_value in plan['rangeSequence']:
            pending.clear()
            instruction_count[0] = 0
            # Host setup is outside the source-write observer; it supplies the caller.
            sp = STACK+0xf000
            uc.mem_write(sp, struct.pack('<III', STOP, 0x2468ace0, range_value & 0xffffffff))
            pending.clear()
            for name, value in seeds.items():
                uc.reg_write(getattr(registers, 'UC_X86_REG_'+name), value)
            uc.reg_write(registers.UC_X86_REG_ESP, sp)
            try:
                uc.emu_start(entry, STOP, timeout=plan['bounds']['timeoutMicrosecondsPerCall'],
                             count=plan['bounds']['instructionsPerCall'])
            except Boundary as error:
                return dict(outcome='declared boundary', error=str(error), calls=calls)
            except unicorn.UcError as error:
                return dict(outcome='source fault', error=str(error), calls=calls,
                            eip=hex(uc.reg_read(registers.UC_X86_REG_EIP)))
            if uc.reg_read(registers.UC_X86_REG_EIP) != STOP:
                return dict(outcome='declared instruction/time boundary', calls=calls)
            final_registers = {name: uc.reg_read(getattr(registers, 'UC_X86_REG_'+name)) for name in names}
            if final_registers['ESP'] != sp+4:
                return dict(outcome='ABI mismatch', calls=calls, registers=final_registers)
            state = {key: struct.unpack('<I', uc.mem_read(fields[key], 4))[0] for key in ('index', 'counter')}
            unchanged = bytes(uc.mem_read(fields['table'], 3000)) == table
            raw_writes = [dict(x) for x in pending]
            calls.append(dict(range=range_value, registers=final_registers, state=state,
                tableUnchanged=unchanged, instructionCount=instruction_count[0], writes=raw_writes))
        return dict(outcome='returned', calls=calls)

    cases, mismatches = [], []
    for table_name in plan['tables']:
        table = tables[table_name]
        for initial in plan['initialStates']:
            a, b = run('baseline', source_bytes, table, initial), run('target', target_bytes, table, initial)
            # Addresses are different storage identities already established by
            # the five observed instruction operands. Raw addresses remain saved.
            def normalized(result):
                value = json.loads(json.dumps(result))
                for call in value['calls']:
                    for write in call['writes']:
                        del write['address']
                return value
            equal = normalized(a) == normalized(b)
            case = dict(id=len(cases), table=table_name, tableSHA256=hashlib.sha256(table).hexdigest(),
                        initial=initial, baseline=a, target=b, equal=equal)
            cases.append(case)
            if not equal or a['outcome'] != 'returned' or not all(c['tableUnchanged'] for c in a['calls']+b['calls']):
                mismatches.append(case['id'])
    if len(cases) != plan['cases']:
        raise ValueError('Pilot case accounting mismatch')
    return dict(schemaVersion=1, runID=plan['runID'], recordedUTC=datetime.now(timezone.utc).isoformat(),
        environment=dict(python=sys.version, executable=sys.executable, unicorn=unicorn.__version__, mode='synthetic x86_32, integer-only'),
        referenceBoundary=plan['referenceBoundary'], cases=cases,
        summary=dict(cases=len(cases), callsPerVersion=sum(len(c['baseline']['calls']) for c in cases),
                     mismatches=mismatches, pcs={key: [hex(a) for a in sorted(v)] for key, v in all_pcs.items()}),
        limitation='Controlled source/source RNG comparison only. No Native executable, Windows startup/seed, caller ordering or whole-game acceptance.')


def dat_buffer_pilot(parent_path, pilot_path):
    """Complete target in-place decoder on declared ordinary-file buffers.

    This reuses the configured Unicorn adapter's stack/return convention. No
    original file API, packed path, process or resource reader is executed.
    """
    import unicorn
    from unicorn import x86_const as registers
    from oracle_frames import STACK, STOP

    class Boundary(RuntimeError):
        pass

    parent = json.loads(parent_path.read_text())
    plan = json.loads(pilot_path.read_text())
    if hashlib.sha256(parent_path.read_bytes()).hexdigest() != plan['parentPlanSHA256']:
        raise ValueError('DAT buffer parent-plan pin mismatch')
    if unicorn.__version__ != plan['environment']['unicorn'] or len(plan['cases']) > 24:
        raise ValueError('DAT buffer environment/case bound differs')
    memory = RecordedMemory(parent['reference']['dump'])
    entry, end = int(plan['entry'], 16), int(plan['endExclusive'], 16)
    body = memory.virtual(entry, end-entry)
    key_address = int(plan['keyAddress'], 16)
    key = memory.virtual(key_address, plan['keyCount'])
    if (hashlib.sha256(body).hexdigest() != plan['codeSHA256'] or
            hashlib.sha256(key).hexdigest() != plan['keySHA256']):
        raise ValueError('DAT buffer code/key identity differs')
    results = []
    for case in plan['cases']:
        payload = (Path(case['inputPath']).read_bytes() if 'inputPath' in case
                   else bytes.fromhex(case['inputHex']))
        if len(payload) != case['count'] or hashlib.sha256(payload).hexdigest() != case['sha256']:
            raise ValueError('DAT buffer input differs: '+case['id'])
        if len(payload) > 1 << 20:
            raise ValueError('DAT buffer input budget exceeded')
        name = bytes.fromhex(case['fileNameHex'])
        if b'\0' in name:
            raise ValueError('Plan filename embeds NUL')
        data, filename, frame = 0x20010000, 0x20000080, STACK+0x8000
        uc = unicorn.Uc(unicorn.UC_ARCH_X86, unicorn.UC_MODE_32)
        for address, size in [(entry & ~0xfff, 0x1000), (key_address & ~0xfff, 0x1000),
                              (STACK, 0x10000), (0x20000000, 0x1000),
                              (data, (max(1, len(payload))+4095)//4096*4096), (STOP & ~0xfff, 0x1000)]:
            uc.mem_map(address, size)
            uc.mem_write(address, b'\xa5'*size)
        uc.mem_write(entry, body)
        uc.mem_write(key_address, key)
        uc.mem_write(filename, name+b'\0')
        if payload:
            uc.mem_write(data, payload)
        sp = STACK+0xf000
        uc.mem_write(sp, struct.pack('<III', STOP, data, len(payload)))
        uc.mem_write(frame+0x14, struct.pack('<I', filename))
        seeds = dict(EAX=0xf0e0d0c0, EBX=0x13579bdf, ECX=0x10a0b0c0,
                     EDX=0x11223344, ESI=0x55667788, EDI=0x99aabbcc, EBP=frame, EFLAGS=0x202)
        for register, value in seeds.items():
            uc.reg_write(getattr(registers, 'UC_X86_REG_'+register), value)
        uc.reg_write(registers.UC_X86_REG_ESP, sp)
        pcs, write_count, ordered, digest = set(), [0], [True], hashlib.sha256()
        reads = [(STACK, STACK+0x10000), (filename, filename+len(name)+1),
                 (data, data+len(payload)), (key_address, key_address+len(key))]
        writes = [(STACK, STACK+0x10000), (data, data+len(payload))]

        def instruction(machine, address, size, _):
            if not entry <= address < end or address+size > end:
                raise Boundary(f'Undeclared instruction {address:#x}+{size}')
            pcs.add(address)

        def access(machine, kind, address, size, value, _):
            is_write = kind == unicorn.UC_MEM_WRITE
            if not any(a <= address and address+size <= b for a, b in (writes if is_write else reads)):
                raise Boundary(f'Undeclared {"write" if is_write else "read"} at {address:#x}+{size}')
            if is_write and data <= address < data+len(payload):
                ordered[0] &= size == 1 and address-data == write_count[0]
                digest.update(struct.pack('<II', address-data, size))
                digest.update((value & ((1 << (8*size))-1)).to_bytes(size, 'little'))
                write_count[0] += 1

        uc.hook_add(unicorn.UC_HOOK_CODE, instruction)
        uc.hook_add(unicorn.UC_HOOK_MEM_READ | unicorn.UC_HOOK_MEM_WRITE, access)
        outcome, error = 'returned', None
        try:
            uc.emu_start(entry, STOP, timeout=plan['bounds']['timeoutMicrosecondsPerCall'],
                         count=plan['bounds']['instructionsPerCall'])
            if uc.reg_read(registers.UC_X86_REG_EIP) != STOP:
                outcome, error = 'execution-limit', 'Routine did not reach return sentinel'
        except Boundary as exc:
            outcome, error = 'unsupported-input-read', str(exc)
        except unicorn.UcError as exc:
            outcome, error = 'source-memory-fault', str(exc)
        after = bytes(uc.mem_read(data, len(payload))) if payload else b''
        values = {name: uc.reg_read(getattr(registers, 'UC_X86_REG_'+name))
                  for name in list(seeds)+['ESP', 'EIP']}
        results.append(dict(id=case['id'], input=case, outcome=outcome, error=error,
            decodedBufferHex=after.hex(), cursorOffset=values['ECX'], registers=values,
            returnedESP=values['ESP'], expectedReturnedESP=sp+12,
            preservedRegisters=all(values[r] == seeds[r] for r in ('EBX','ESI','EDI','EBP')),
            bufferWrites=write_count[0], ascendingSingleByteWrites=ordered[0], writeOrderSHA256=digest.hexdigest(),
            filenameUnchanged=bytes(uc.mem_read(filename, len(name)+1)) == name+b'\0',
            keyUnchanged=bytes(uc.mem_read(key_address, len(key))) == key,
            instructionAddresses=[hex(a) for a in sorted(pcs)]))
    return dict(schemaVersion=1, runID=plan['runID'], recordedUTC=datetime.now(timezone.utc).isoformat(),
        environment=dict(python=sys.version, executable=sys.executable, unicorn=unicorn.__version__),
        referenceBoundary=plan['referenceBoundary'], keyHex=key.hex(), cases=results,
        summary=dict(cases=len(results), outcomes={o:sum(c['outcome'] == o for c in results)
                     for o in sorted(set(c['outcome'] for c in results))}),
        limitation='Whole decoder routine only on declared disjoint ordinary buffers; no original file API, packed path, Windows, FileOpen/Object caller or Native acceptance.')


def object_body_pilot(parent_path, pilot_path):
    """Whole target Object body on declared Frame-free owned streams.

    Actual parser/scanner/EOF/close/tail/cookie instructions execute. FileOpen
    supplies a declared owned buffer and free is an allocator boundary. No
    Windows API, packed file, bitmap child or source after-state is supplied.
    """
    import base64
    import zlib
    import unicorn
    from unicorn import x86_const as registers
    from oracle_frames import STACK, STOP

    class Boundary(RuntimeError):
        pass

    plan = json.loads(pilot_path.read_text())
    parent = json.loads(parent_path.read_text())
    if hashlib.sha256(parent_path.read_bytes()).hexdigest() != plan['parentPlanSHA256']:
        raise ValueError('Object-body parent pin differs')
    if (unicorn.__version__ != plan['environment']['unicorn'] or
            len(plan['cases']) != plan['bounds']['cases'] or not 1 <= len(plan['cases']) <= 24):
        raise ValueError('Object-body environment/case bound differs')
    memory = RecordedMemory(parent['reference']['dump'])
    source_regions = []
    for pin in plan['sourceRegions']:
        address = int(pin['va'], 16)
        raw = memory.virtual(address, pin['count'])
        if hashlib.sha256(raw).hexdigest() != pin['sha256']:
            raise ValueError('Object-body source pin differs: '+pin['label'])
        source_regions.append((address, raw, pin['label'], pin['executable']))
    blobs, results = {}, []

    def blob(raw):
        raw = bytes(raw)
        key = hashlib.sha256(raw).hexdigest()
        if key not in blobs:
            blobs[key] = dict(count=len(raw), deflate=base64.b64encode(zlib.compress(raw, 9)).decode())
        return key

    obj, filename = 0x22000000, 0x23000000
    extent, sp = plan['allocationBytes'], STACK+0xf000
    for case in plan['cases']:
        uc = unicorn.Uc(unicorn.UC_ARCH_X86, unicorn.UC_MODE_32)
        mapped, regions, pcs = set(), [], set()
        events, groups, allocations, pending = [], [], [], {}
        state = dict(writes=0, ordered=hashlib.sha256())

        def region(address, raw, label, writable=False, known=True):
            for page in range(address & ~4095, (address+len(raw)+4095) & ~4095, 4096):
                if page not in mapped:
                    uc.mem_map(page, 4096)
                    uc.mem_write(page, b'\xa5'*4096)
                    mapped.add(page)
            uc.mem_write(address, bytes(raw))
            r = dict(address=address, count=len(raw), label=label, writable=writable,
                     mask=bytearray([int(known)])*len(raw), live=True)
            regions.append(r)
            return r

        for a, raw, label, _ in source_regions:
            region(a, raw, label)
        stack_region = region(STACK, b'\xa5'*0x10000, 'synthetic stack', True, False)
        object_region = region(obj, bytes([case['backingByte']])*extent, 'Object allocation', True, False)
        region(filename, bytes.fromhex(plan['filenameHex'])+b'\0', 'owned filename')
        region(0x49eea4, struct.pack('<I', plan['cookie']), 'declared process cookie')
        region(STOP, b'\xcc', 'return sentinel')

        def seed(address, raw, r):
            uc.mem_write(address, bytes(raw))
            offset = address-r['address']
            r['mask'][offset:offset+len(raw)] = b'\1'*len(raw)

        def patch(fields):
            for offset, value in fields:
                seed(obj+offset, struct.pack('<I', value & 0xffffffff), object_region)

        patch(case['initialFields'])
        patch([[0x7a8, filename]])
        initial_bytes = blob(uc.mem_read(obj, extent))
        initial_mask = blob(object_region['mask'])

        def register(name):
            return uc.reg_read(getattr(registers, 'UC_X86_REG_'+name))

        def put_register(name, value):
            uc.reg_write(getattr(registers, 'UC_X86_REG_'+name), value)

        def word(address):
            return struct.unpack('<I', uc.mem_read(address, 4))[0]

        def returned(pop=0, eax=None):
            at = register('ESP')
            target = word(at)
            if eax is not None:
                put_register('EAX', eax)
            put_register('ESP', at+4+pop)
            put_register('EIP', target)

        def cstring(address):
            out = bytearray()
            for offset in range(256):
                b = uc.mem_read(address+offset, 1)[0]
                if b == 0:
                    return out.hex()
                out.append(b)
            raise Boundary('Diagnostic token exceeds declared bound')

        def instruction(machine, pc, size, _):
            pcs.add(pc)
            if pc in pending:
                kind, data = pending.pop(pc)
                if kind == 'scan':
                    events.append(dict(kind='token', bytes=cstring(data['destination']),
                        before=data['before'], after=word(data['stream'])-data['buffer']))
                elif kind == 'eof':
                    events.append(dict(kind='eof', cursor=word(data['stream'])-data['buffer'],
                                       result=register('EAX')))
            if pc == 0x4143e0:
                at = register('ESP')
                if word(at+4) != filename:
                    raise Boundary('Open filename owner differs')
                call = state['call']
                data, stream = 0x31000000+call*0x10000, 0x30000000+call*0x1000
                raw = bytes.fromhex(state['input']['streamHex'])
                buffer_region = region(data, raw, 'owned stream buffer')
                stream_region = region(stream, struct.pack('<III', data, data+len(raw), data),
                                       'owned stream record', True)
                allocations.extend([buffer_region, stream_region])
                state.update(buffer=data, stream=stream)
                events.append(dict(kind='open', bytes=len(raw), cursor=0))
                returned(4, stream)
                return
            if pc == 0x4450a6:
                address = word(register('ESP')+4)
                matches = [r for r in allocations if r['address'] == address and r['live']]
                if len(matches) != 1:
                    raise Boundary('Unknown or repeated free')
                matches[0]['live'] = False
                events.append(dict(kind='free', owner=matches[0]['label']))
                # free has no game-level return contract; this is a declared
                # volatile-register response, not recovered CRT behavior.
                returned(eax=plan['freeVolatileEAX'])
                return
            if not any(executable and a <= pc and pc+size <= a+len(raw)
                       for a, raw, _, executable in source_regions):
                raise Boundary(f'Undeclared instruction {pc:#x}+{size}')
            if pc == 0x414490:
                at = register('ESP')
                if word(at+4) != state['stream'] or word(at+8) != 0x4977fc:
                    raise Boundary('Unexpected scanner owner or format')
                pending[word(at)] = ('scan', dict(destination=word(at+12),
                    before=word(state['stream'])-state['buffer'], stream=state['stream'], buffer=state['buffer']))
            elif pc == 0x414920:
                at = register('ESP')
                if word(at+4) != state['stream']:
                    raise Boundary('Unexpected EOF owner')
                pending[word(at)] = ('eof', dict(stream=state['stream'], buffer=state['buffer']))
            elif pc == 0x414950:
                events.append(dict(kind='close'))

        def access(machine, kind, address, size, value, _):
            writing = kind == unicorn.UC_MEM_WRITE
            hot = [object_region, stack_region]
            found = next((r for r in hot if r['address'] <= address
                          and address+size <= r['address']+r['count']), None)
            if found is None:
                found = next((r for r in regions if r['live'] and r['address'] <= address
                              and address+size <= r['address']+r['count']), None)
            if found is None:
                raise Boundary(f'Undeclared memory {"write" if writing else "read"} '
                               f'{address:#x}+{size} at {register("EIP"):#x}')
            offset = address-found['address']
            if writing:
                if not found['writable']:
                    raise Boundary('Write to immutable '+found['label'])
                found['mask'][offset:offset+size] = b'\1'*size
                if found is object_region:
                    raw = (value & ((1 << (size*8))-1)).to_bytes(size, 'little')
                    state['writes'] += 1
                    state['ordered'].update(struct.pack('<II', offset, size)+raw)
                    if groups and groups[-1]['offset']+groups[-1]['size']*groups[-1]['count'] == offset and groups[-1]['size'] == size and groups[-1]['value'] == raw.hex():
                        groups[-1]['count'] += 1
                    else:
                        groups.append(dict(offset=offset, size=size, count=1, value=raw.hex()))
            elif not all(found['mask'][offset:offset+size]):
                raise Boundary(f'Unknown {found["label"]} bytes at {address:#x}+{size}, PC {register("EIP"):#x}')

        uc.hook_add(unicorn.UC_HOOK_CODE, instruction)
        uc.hook_add(unicorn.UC_HOOK_MEM_READ | unicorn.UC_HOOK_MEM_WRITE, access)
        calls = []
        for call_index, call in enumerate(case['calls']):
            patch(call.get('patches', []))
            state.update(call=call_index, input=call, writes=0, ordered=hashlib.sha256())
            events.clear(); groups.clear(); pending.clear()
            stack_region['mask'][:] = b'\0'*stack_region['count']
            uc.mem_write(STACK, b'\xa5'*0x10000)
            seed(sp, struct.pack('<II', STOP, obj), stack_region)
            seeds = dict(EAX=0xf0e0d0c0, EBX=0x13579bdf, ECX=0x10a0b0c0,
                         EDX=0x11223344, ESI=0x55667788, EDI=0x99aabbcc, EBP=0x12345678, EFLAGS=0x202)
            for name, value in seeds.items():
                put_register(name, value)
            put_register('ESP', sp)
            outcome, error = 'returned', None
            try:
                uc.emu_start(0x40e540, STOP, timeout=plan['bounds']['timeoutMicrosecondsPerCall'],
                             count=plan['bounds']['instructionsPerCall'])
                if register('EIP') != STOP:
                    outcome, error = 'execution-limit', 'Whole caller did not return'
            except Boundary as exc:
                outcome, error = 'unsupported-boundary', str(exc)
            except unicorn.UcError as exc:
                outcome, error = 'synthetic-mapping-fault', str(exc)
            calls.append(dict(input=call, outcome=outcome, error=error,
                objectBytes=blob(uc.mem_read(obj, extent)), objectDefined=blob(object_region['mask']),
                events=list(events), writeGroups=[dict(x) for x in groups], objectWrites=state['writes'],
                orderedWriteSHA256=state['ordered'].hexdigest(), returnedESP=register('ESP'),
                expectedReturnedESP=sp+8, terminalPC=register('EIP'), preservedRegisters=all(register(r) == seeds[r] for r in ('EBX','ESI','EDI','EBP')),
                liveStreamOwners=sum(r['live'] for r in allocations), pendingCallbacks=len(pending)))
            if outcome != 'returned':
                break  # Never continue a faulted/unsupported machine.
        results.append(dict(id=case['id'], input=case, initialObjectBytes=initial_bytes,
                            initialObjectDefined=initial_mask, calls=calls,
                            instructionAddresses=[hex(a) for a in sorted(pcs)]))
    outcomes = [call['outcome'] for case in results for call in case['calls']]
    return dict(schemaVersion=1, runID=plan['runID'], recordedUTC=datetime.now(timezone.utc).isoformat(),
        environment=dict(python=sys.version, executable=sys.executable, unicorn=unicorn.__version__),
        referenceBoundary=plan['referenceBoundary'], objectAddress=obj, filenameAddress=filename,
        cases=results, blobs=blobs, summary=dict(cases=len(results), calls=len(outcomes),
        outcomes={kind:outcomes.count(kind) for kind in sorted(set(outcomes))}),
        limitation='Controlled whole Object body only; declared Open/free boundaries, actual custom scanner and close; no Windows, packed/PNG resources or target startup/game acceptance.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--anchors', type=Path)
    parser.add_argument('--ranges', type=Path)
    parser.add_argument('--rng-pilot', type=Path)
    parser.add_argument('--dat-buffer-pilot', type=Path)
    parser.add_argument('--object-body-pilot', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Refusing to overwrite an existing run result')
    if args.object_body_pilot:
        result = object_body_pilot(args.plan, args.object_body_pilot)
        args.output.write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps(result['summary'], sort_keys=True))
        return
    if args.dat_buffer_pilot:
        result = dat_buffer_pilot(args.plan, args.dat_buffer_pilot)
        args.output.write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps(result['summary'], indent=2))
        return
    if args.rng_pilot:
        result = rng_pilot(args.plan, args.rng_pilot)
        args.output.write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps(result['summary'], indent=2))
        return
    plan = json.loads(args.plan.read_text())
    reference = plan['reference']
    baseline = Path(reference['baseline']).read_bytes()
    digest = hashlib.sha256(baseline).hexdigest()
    if digest != reference['baselineSHA256']:
        raise ValueError('Baseline identity mismatch')
    validation = json.loads(Path(reference['dumpValidation']).read_text())
    if validation['sha256'] != reference['dumpSHA256']:
        raise ValueError('Wrong saved dump-validation identity')
    dump = RecordedMemory(reference['dump'])
    if dump.size != validation['bytes']:
        raise ValueError('Dump size changed since saved validation')
    modules = dump.modules()
    targets = [m for m in modules if m['name'].lower() == 'ntsd.exe']
    expected = validation['targetModule']
    targets = [m for m in targets if int(m['base'], 16) == int(expected['base'], 16)
               and m['size'] == expected['imageSize']]
    if not targets or any(m != targets[0] for m in targets):
        raise ValueError('Ambiguous or absent validated target-module identity')
    target = targets[0]
    base = int(target['base'], 16)
    header = dump.virtual(base, 4096)
    later = PE(header)
    earlier = PE(baseline)
    sections = section_metadata(later)
    code_sections = []
    anchor_result = None
    range_result = None
    for s in sections:
        if not s['executable']:
            continue
        # Only the lowest executable section, the declared main-code candidate.
        # No unpacking/virtualization engine or resource region is inspected.
        address, length = base+s['rva'], s['virtualSize']
        try:
            code = dump.virtual(address, length)
        except ValueError as error:
            code_sections.append(dict(rva=s['rva'], status='unsupported', error=str(error)))
        else:
            code_sections.append(dict(rva=s['rva'], bytes=len(code),
                                      sha256=hashlib.sha256(code).hexdigest(),
                                      prefix64=code[:64].hex(), status='recorded'))
            if args.anchors:
                anchor_plan = json.loads(args.anchors.read_text())
                if len(anchor_plan['anchors']) > plan['bounds']['maxAnchorFunctions']:
                    raise ValueError('Anchor-count budget exceeded')
                anchor_result = compare_anchors(baseline, earlier, code, address, anchor_plan['anchors'])
            if args.ranges:
                range_plan = json.loads(args.ranges.read_text())
                range_result = compare_ranges(baseline, earlier, code, address, range_plan['cases'])
        break
    result = dict(schemaVersion=1, runID='engine-diff1',
                  recordedUTC=datetime.now(timezone.utc).isoformat(),
                  scope='Static recorded main-code availability only; no execution or behavioral equivalence',
                  baseline=dict(sha256=digest, base=hex(earlier.base), entry=hex(earlier.entry),
                                sections=section_metadata(earlier)),
                  dump=dict(path=reference['dump'], sha256=validation['sha256'],
                            hashValidation='Reused saved full-byte validation; no repeated dump hash',
                            bytes=dump.size, flags=hex(dump.flags), modules=modules,
                            directoryEntries=dump.directory_entries, nonemptyStreams=len(dump.streams),
                            memoryRegions=len(dump.regions)),
                  target=dict(machine=hex(later.machine), base=hex(later.base), entry=hex(later.entry),
                              identicalModuleRecords=len(targets), sections=sections, codeSections=code_sections),
                  payloadBytesRead=dump.payload_bytes_read)
    if anchor_result is not None:
        result['comparison'] = anchor_result
    if range_result is not None:
        result['rangeComparison'] = range_result
    if args.output.exists():
        raise ValueError('Refusing to overwrite an existing run result')
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(dict(output=str(args.output), target=result['target'],
                          payloadBytesRead=result['payloadBytesRead']), indent=2))


if __name__ == '__main__':
    main()
