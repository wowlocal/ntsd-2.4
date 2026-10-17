#!/usr/bin/env python3
"""Bounded static compatibility comparison against an existing game dump.

Default modes read MDMP mappings and recorded main-module code with the existing
PE reader. --rng-pilot executes only its separately planned leaf x86 routine in
Unicorn with declared synthetic inputs. No mode rebuilds an EXE, reads bundled
resources, or supplies missing memory as known zero. Neither mode proves native
or whole-game parity.
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--anchors', type=Path)
    parser.add_argument('--ranges', type=Path)
    parser.add_argument('--rng-pilot', type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Refusing to overwrite an existing run result')
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
