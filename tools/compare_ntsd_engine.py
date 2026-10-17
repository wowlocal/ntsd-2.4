#!/usr/bin/env python3
"""Bounded static compatibility comparison against an existing game dump.

Reads standard MDMP mappings and recorded main-module code. Uses the existing
PE reader; never runs code, rebuilds an EXE, reads bundled resources, or supplies
missing memory as zero. All results are static observations, not native parity.
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--anchors', type=Path)
    parser.add_argument('--ranges', type=Path)
    args = parser.parse_args()
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
