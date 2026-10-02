#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.3"]
# ///
"""Recursive-descent instruction universe of a pristine PE image's .text.

Seeds: the PE entry point, every direct call target reached, jump-table
targets of `jmp [reg*4+table]`, and code pointers found as aligned dwords in
the data sections (accepted only when their decode stays on instruction
boundaries of the code already found or adds a self-consistent region).
Output JSON: functions (entry -> instruction starts), every instruction start
with its size, unreached .text byte ranges and the seed provenance. Static
reading only; nothing is executed.
"""
import json
import struct
import sys
from collections import defaultdict
from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_GRP_JUMP, CS_GRP_CALL, CS_GRP_RET, CS_GRP_INT
from capstone.x86 import X86_OP_IMM, X86_OP_MEM, X86_REG_INVALID


def sections(image):
    pe = struct.unpack_from('<I', image, 0x3c)[0]
    count = struct.unpack_from('<H', image, pe + 6)[0]
    optional = struct.unpack_from('<H', image, pe + 20)[0]
    base = struct.unpack_from('<I', image, pe + 52)[0]
    entry = base + struct.unpack_from('<I', image, pe + 40)[0]
    out = []
    for i in range(count):
        o = pe + 24 + optional + i * 40
        name = image[o:o + 8].rstrip(b'\0').decode()
        va = base + struct.unpack_from('<I', image, o + 12)[0]
        vsize, rsize, raw = (struct.unpack_from('<I', image, o + x)[0] for x in (8, 16, 20))
        out.append(dict(name=name, va=va, size=vsize, raw=raw, rawSize=rsize))
    return base, entry, out


def build(path):
    image = open(path, 'rb').read()
    base, entry, secs = sections(image)
    text = next(s for s in secs if s['name'] == '.text')
    lo, hi = text['va'], text['va'] + text['size']
    code = image[text['raw']:text['raw'] + min(text['size'], text['rawSize'])]

    def read(address, count):
        for s in secs:
            if s['va'] <= address < s['va'] + max(s['size'], s['rawSize']):
                off = s['raw'] + address - s['va']
                return image[off:off + count]
        return b''

    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.detail = True
    starts = {}            # address -> size
    owner = {}             # address -> function entry
    functions = defaultdict(set)
    provenance = {}

    def decode(address):
        if not lo <= address < hi:
            return None
        chunk = code[address - lo:address - lo + 16]
        for ins in md.disasm(chunk, address, count=1):
            return ins
        return None

    def explore(entry_address, why):
        if entry_address in functions or not lo <= entry_address < hi:
            return []
        stack, calls, local = [entry_address], [], []
        while stack:
            a = stack.pop()
            if a in starts and owner.get(a) is not None:
                if owner[a] != entry_address:
                    continue  # shared tail; counted once
                continue
            ins = decode(a)
            if ins is None:
                continue
            starts[a] = ins.size
            owner[a] = entry_address
            local.append(a)
            groups = set(ins.groups)
            nxt = a + ins.size
            mnemonic = ins.mnemonic
            if CS_GRP_RET in groups or mnemonic in ('hlt', 'int3', 'ud2'):
                continue
            if CS_GRP_INT in groups and mnemonic == 'int3':
                continue
            if CS_GRP_CALL in groups:
                op = ins.operands[0]
                if op.type == X86_OP_IMM:
                    calls.append(op.imm)
                stack.append(nxt)
                continue
            if CS_GRP_JUMP in groups:
                op = ins.operands[0]
                if op.type == X86_OP_IMM:
                    stack.append(op.imm)
                elif op.type == X86_OP_MEM and op.mem.index != X86_REG_INVALID and op.mem.scale == 4 and op.mem.base == X86_REG_INVALID:
                    table = op.mem.disp & 0xffffffff
                    for k in range(1024):
                        word = read(table + 4 * k, 4)
                        if len(word) < 4:
                            break
                        target = struct.unpack('<I', word)[0]
                        if not lo <= target < hi:
                            break
                        stack.append(target)
                if mnemonic != 'jmp':
                    stack.append(nxt)
                continue
            stack.append(nxt)
        functions[entry_address].update(local)
        provenance[entry_address] = why
        return calls

    pending = [(entry, 'entry')]
    while pending:
        a, why = pending.pop()
        for target in explore(a, why):
            pending.append((target, 'call'))

    # Code pointers in the data sections (vtables, callbacks, SEH/handler
    # tables, WndProc, jump tables outside .text).
    candidates = []
    for s in secs:
        if s['name'] in ('.text', '.rsrc'):
            continue
        blob = image[s['raw']:s['raw'] + s['rawSize']]
        for off in range(0, len(blob) - 3, 4):
            v = struct.unpack_from('<I', blob, off)[0]
            if lo <= v < hi and v not in starts:
                candidates.append(v)
    accepted = 0
    for v in sorted(set(candidates)):
        if v in starts or v in functions:
            continue
        # Reject pointers into the middle of known instructions.
        inside = any(s < v < s + starts[s] for s in range(v - 15, v) if s in starts)
        if inside:
            continue
        before = len(starts)
        pending = [(v, 'data-pointer')]
        while pending:
            a, why = pending.pop()
            for target in explore(a, why):
                pending.append((target, 'call'))
        if len(starts) > before:
            accepted += 1

    covered = bytearray(hi - lo)
    for a, n in starts.items():
        for i in range(n):
            if a + i < hi:
                covered[a + i - lo] = 1
    gaps, i = [], 0
    while i < len(covered):
        if not covered[i]:
            j = i
            while j < len(covered) and not covered[j]:
                j += 1
            gaps.append([lo + i, lo + j])
            i = j
        else:
            i += 1
    return dict(image=path, base=base, entry=entry, text=[lo, hi],
                instructionStarts=len(starts), instructionBytes=sum(starts.values()),
                functions={hex(f): sorted(v) for f, v in functions.items()},
                provenance={hex(f): w for f, w in provenance.items()},
                sizes={str(a): n for a, n in starts.items()},
                dataPointerSeedsAccepted=accepted, unreached=gaps)


if __name__ == '__main__':
    result = build(sys.argv[1])
    json.dump(result, open(sys.argv[2], 'w'))
    print(json.dumps({k: result[k] for k in ('text', 'instructionStarts', 'instructionBytes', 'dataPointerSeedsAccepted')}),
          'functions', len(result['functions']), 'unreached bytes', sum(b - a for a, b in result['unreached']))
