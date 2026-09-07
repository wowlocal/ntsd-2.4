#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original BG parse/load/release instruction paths, with explicit CRT/device IO.

Shares the Object harness's bytewise decoder and bitmap/stdio boundaries. No
baseline writes. Pixel output and actual MSVCR80/allocator behavior remain open.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from oracle_objects import Objects, DEVICE, STUB, HEAP
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

CATALOG, BG_BASE, BG_SIZE, CAPACITY = 0x26000000, 0x4D45DB0, 0x990, 101
PROBE = br'''name: ABCDEFGHIJKLMNOPQRSTUVWXYZ_123456789 name: X_Y
width: -2147483648 width: nope zboundary: -7 +19suffix
perspective: 123 nope perspective: -1 2147483647
shadow: sprite\sys\shadow.bmp ignored_label: -17 23
layer: bg\sys\District\s.bmp
transparency: -1 width: 900 x: -31 y: +42 height: 19 loop: -3
cc: 60 c1: 3 c2: 17 rect: 65535 rect: nope rect32: -2147483648
layer_end
layer: bg\sys\District\s.bmp rect: -1 rect32: 33 rect: nope layer_end
layer: bg\sys\District\s.bmp rect: 0 layer_end
ignored_\xff
'''.replace(b'\\xff', b'\xff').replace(b'\n', b'\r\n')
RELOAD = br'''name: Q width: 17
layer: bg\sys\District\s.bmp rect32: -1 layer_end
'''


class Backgrounds(Objects):
    def __init__(self, text_mode=True, pattern=0xA5):
        super().__init__(text_mode=text_mode, pattern=pattern)
        start = CATALOG + BG_BASE
        self.uc.mem_map(start & ~0xFFF, ((start % 0x1000 + CAPACITY*BG_SIZE + 16 + 4095)//4096)*4096)
        self.table = self.add_region(start, CAPACITY*BG_SIZE, 'background-table')
        self.active_index = None
        self.released = []
        for mode, callback in [(UC_HOOK_MEM_READ, self.track_read), (UC_HOOK_MEM_WRITE, self.track_write)]:
            self.uc.hook_add(mode, callback, begin=start - 16, end=start + CAPACITY*BG_SIZE + 15)
        self.put(DEVICE + 0x100 + 8, STUB + 0x320)  # surface Release
        self.put(0x44717C, STUB + 0x330)  # free
        for address in (0x40C219, 0x40C263, 0x40C890):
            self.uc.hook_add(UC_HOOK_CODE, self.bg_checkpoint, begin=address, end=address)
        self.uc.hook_add(UC_HOOK_CODE, self.allowed_code)

    def allowed_code(self, uc, address, size, data):
        assert (0x40C030 <= address <= 0x40C901 or 0x4148A0 <= address <= 0x414A30
                or 0x43EE50 <= address <= 0x43EF85 or 0x43ED10 == address
                or 0x4450AC <= address <= 0x4450BA or STUB <= address < STUB + 0x400), hex(address)

    def track_write(self, uc, access, address, size, value, data):
        super().track_write(uc, access, address, size, value, data)
        if CATALOG + BG_BASE <= address < CATALOG + BG_BASE + CAPACITY*BG_SIZE:
            index, offset = divmod(address - CATALOG - BG_BASE, BG_SIZE)
            assert index == self.active_index and offset + size <= BG_SIZE
            self.accesses.add(('write', 'background', offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def track_read(self, uc, access, address, size, value, data):
        super().track_read(uc, access, address, size, value, data)
        if CATALOG + BG_BASE <= address < CATALOG + BG_BASE + CAPACITY*BG_SIZE:
            index, offset = divmod(address - CATALOG - BG_BASE, BG_SIZE)
            assert index == self.active_index and offset + size <= BG_SIZE
            self.accesses.add(('read', 'background', offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def write_host(self, address, raw):
        if CATALOG + BG_BASE <= address < CATALOG + BG_BASE + CAPACITY*BG_SIZE:
            self.track_write(self.uc, 0, address, len(raw), 0, None)
            self.uc.mem_write(address, raw)
        else:
            super().write_host(address, raw)

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == STUB + 0x320:
            assert self.u32(sp + 4) == DEVICE and self.u32(sp) == 0x40C120
            target = uc.reg_read(UC_X86_REG_ECX)
            assert target in [b['address'] for b in self.bitmaps] and target not in self.released
            self.events.append(dict(kind='surface-release', address=target))
            self.ret(0, 4)
        elif address == STUB + 0x330:
            target = self.u32(sp + 4)
            assert self.u32(sp) == 0x40C125 and self.events[-1] == dict(kind='surface-release', address=target)
            self.released.append(target)
            self.events.append(dict(kind='free', address=target))
            # Retain dead bytes for research; no native allocator contents claim.
            self.ret()
        else:
            if self.lookup.get(address) == 'fscanf':
                fmt = self.cstr(self.u32(sp + 8))
                caller = self.u32(sp)
                limits = {0x40C263: [100], 0x40C2D8: [100], 0x40C417: [40, 100, None, None],
                          0x40C49C: [30], 0x40C578: [100], 0x40C875: [100]}
                # Assert actual string destinations' non-overlap domain before the shared CRT call.
                if caller in limits:
                    h = self.handles[self.u32(sp + 4)]
                    tokens = h['data'][h['pos']:].split()
                    for i, limit in enumerate(limits[caller]):
                        if limit is not None and i < len(tokens):
                            assert len(tokens[i]) < limit, (hex(caller), tokens[i])
            super().imported(uc, address, size, data)

    def bg_checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x40C219:
            self.decoded = next(h['data'] for h in list(self.handles.values())[::-1] if h['mode'] == b'r')
        elif address == 0x40C263:
            self.outer_tokens.append(self.cstr(sp + 0x30).hex())
        elif address == 0x40C890:
            count = self.u32(CATALOG + BG_BASE + self.active_index*BG_SIZE + 0x1C)
            assert count < 30, 'BG layer table overflow outside the declared corpus'

    def record(self):
        offset = self.active_index*BG_SIZE
        raw = bytes(self.uc.mem_read(self.table['address'] + offset, BG_SIZE))
        return dict(bytes=raw.hex(), defined=bytes(self.table['mask'][offset:offset + BG_SIZE]).hex())

    def run(self, kind, index, source_id=0, path=None, payload=None):
        assert 0 <= index < CAPACITY
        self.active_index = index
        before = self.record()
        initial_checksum = self.u32(0x44F620)
        start_b, start_e, start_s = len(self.bitmaps), len(self.events), len(self.scans)
        self.outer_tokens, self.decoded = [], None
        sp = STACK + 0xF000
        raw = None
        if kind == 'parse':
            raw = read_bytes(DEFAULT_SOURCE / path.replace('\\', '/')) if payload is None else payload
            self.files[path.encode('latin1')] = raw
            self.uc.mem_write(STACK + 0x100, path.encode('latin1') + b'\0')
            args, entry = [index, source_id & 0xFFFFFFFF, STACK + 0x100], 0x40C160
        else:
            args, entry = [index], {'load': 0x40C030, 'release': 0x40C0E0}[kind]
        self.uc.mem_write(sp, struct.pack('<' + 'I'*(len(args) + 1), STOP, *args))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, CATALOG)
        self.uc.emu_start(entry, STOP, timeout=20_000_000, count=5_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP, ('BG limit', hex(self.uc.reg_read(UC_X86_REG_EIP)))
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 4*(len(args) + 1)
        assert all(h['closed'] for h in self.handles.values())
        if kind == 'parse':
            assert self.files[b'data\\temporary.txt'] == b'Do not erase this file.'
        result = dict(kind=kind, index=index, id=source_id, path=path, initialChecksum=initial_checksum,
                      checksum=self.u32(0x44F620), before=before, after=self.record(),
                      bitmaps=self.bitmaps[start_b:], events=self.events[start_e:], scans=self.scans[start_s:], outerTokens=self.outer_tokens)
        if raw is not None:
            result.update(source=raw.hex(), sourceSHA256=hashlib.sha256(raw).hexdigest(), decoded=self.decoded.hex())
        return result


def capture(name, pattern=0xA5, text_mode=True):
    vm = Backgrounds(pattern=pattern, text_mode=text_mode)
    vm.put(0x44F620, 0xFFFFF123 if name.startswith('probe') else 0)
    cases = []
    if name.startswith('baseline'):
        raw_registry = read_bytes(DEFAULT_SOURCE / 'data/data.txt')
        section = raw_registry.decode('latin1').split('<background>')[1].split('<background_end>')[0]
        entries = re.findall(r'id:\s*(-?\d+)\s+file:\s*(\S+)', section)
        for index, (sid, path) in enumerate(entries):
            cases.append(vm.run('parse', index, int(sid), path))
        # These are explicitly exercised lifecycle calls, not a recorded menu selection sequence.
        for index in range(len(entries)):
            cases.append(vm.run('load', index))
            cases.append(vm.run('release', index))
            cases.append(vm.run('release', index))  # first pointer is the sole sentinel
        cases.append(vm.run('load', 0))  # selected-arena reload gets fresh wrappers
    else:
        raw_registry = None
        cases.append(vm.run('parse', 98, -2147483648, 'bg\\probe.txt', PROBE))
        cases.append(vm.run('load', 98))
        cases.append(vm.run('release', 98))
        cases.append(vm.run('parse', 98, 2147483647, 'bg\\reload.txt', RELOAD))
        cases.append(vm.run('load', 98))
        cases.append(vm.run('release', 98))
        # No layers: reload preserves the prior first pointer's defined zero.
        cases.append(vm.run('parse', 98, 42, 'bg\\empty.txt', b'width: 5'))
        cases.append(vm.run('load', 98))
        cases.append(vm.run('release', 98))
        cases.append(vm.run('parse', 98, 0, 'bg\\missing-number.txt', b'width: '))
        cases.append(vm.run('parse', 98, 0, 'bg\\partial-pair.txt', b'zboundary: 123 '))
    doc = dict(exeSHA256=EXE_SHA256, name=name, translation='text' if vm.text_mode else 'raw',
               bitmapFill=vm.pattern, surfaceAddress=DEVICE, initialChecksum=cases[0]['initialChecksum'],
               registrySHA256=hashlib.sha256(raw_registry).hexdigest() if raw_registry else None,
               scope='40c160/4148a0/40c030/40c0e0/43ee50; supplied C-locale stdio, successful allocation and opaque device dimensions/Release/free; no pixel rendering or Windows capture',
               cases=cases, bitmaps=[{**b, 'storage': vm.snapshot_region(vm.region(b['address'], 0x1F50))} for b in vm.bitmaps],
               assetInputs=list(vm.asset_inputs.values()), regions=[vm.snapshot_region(r) for r in vm.regions],
               allocations=vm.allocations, released=vm.released,
               readsBeforeWrites=[dict(region=r, offset=o, size=n, instruction=hex(pc)) for r, o, n, pc in sorted(vm.reads_before_writes)],
               accesses=[dict(mode=m, region=r, offset=o, size=n, instruction=hex(pc)) for m, r, o, n, pc in sorted(vm.accesses)])
    assert not doc['readsBeforeWrites'], doc['readsBeforeWrites']
    path = ROOT / 'build/original' / ('backgrounds-' + name + '.json')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    print(f"{name}: {len(cases)} calls, {len(vm.bitmaps)} bitmaps, {len(vm.released)} releases; unaccepted corpus {path}", flush=True)
    return doc, path


def compact(doc):
    result = {k: v for k, v in doc.items() if k not in ('regions', 'allocations', 'accesses', 'readsBeforeWrites')}
    result['bitmaps'] = []
    # Lossless codec, not a comparison omission: prove the other 8004 bytes AND
    # flags are uniform before reconstructing them in the Swift reference adapter.
    for bitmap in doc['bitmaps']:
        raw = bytes.fromhex(bitmap['storage']['bytes'])
        mask = bytes.fromhex(bitmap['storage']['defined'])
        initial = bytes.fromhex(bitmap['storage']['initial'])
        assert initial == bytes([doc['bitmapFill']])*0x1F50
        assert raw[12:] == initial[12:] and mask[12:] == bytes(0x1F50 - 12)
        result['bitmaps'].append({k: v for k, v in bitmap.items() if k != 'storage'} | {
            'storage': dict(prefix=raw[:12].hex(), definedPrefix=mask[:12].hex())})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='store_true')
    args = parser.parse_args()
    specs = [('baseline', 0xA5, True), ('baseline-raw-zero', 0, False), ('probe', 0xA5, True)] if args.suite else [('baseline', 0xA5, True)]
    captured = [capture(*s) for s in specs]
    if not args.suite:
        return
    subprocess.run(['swift', 'build', '--package-path', str(ROOT / 'native'), '-c', 'release', '--product', 'NTSDBGCheck'], check=True)
    checks, summaries = [], []
    for doc, path in captured:
        check = compact(doc)
        target = path.with_stem(path.stem + '-check')
        target.write_text(json.dumps(check, separators=(',', ':')) + '\n')
        subprocess.run([str(ROOT / 'native/.build/release/NTSDBGCheck'), str(target)], check=True)
        checks.append(check)
        summaries.append(dict(name=doc['name'], corpus=path.name, corpusSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),
                              comparisonSHA256=hashlib.sha256(target.read_bytes()).hexdigest(), translation=doc['translation'], bitmapFill=doc['bitmapFill'],
                              calls=len(doc['cases']), parses=sum(c['kind'] == 'parse' for c in doc['cases']), bitmaps=len(doc['bitmaps']), releases=len(doc['released']),
                              recordsBytes=len(doc['cases'])*BG_SIZE, bitmapBytes=len(doc['bitmaps'])*0x1F50,
                              readsBeforeWrites=doc['readsBeforeWrites'], finalChecksum=doc['cases'][-1]['checksum'],
                              inputs=[dict(path=c['path'], sourceSHA256=c['sourceSHA256'], decodedSHA256=hashlib.sha256(bytes.fromhex(c['decoded'])).hexdigest(),
                                           layers=struct.unpack_from('<i', bytes.fromhex(c['after']['bytes']), 0x1C)[0], checksum=c['checksum']) for c in doc['cases'] if c['kind'] == 'parse']))
    fixture = ROOT / 'native/Tests/NTSDCoreTests/Fixtures/original-backgrounds.json'
    fixture.write_text(json.dumps(dict(corpora=checks), separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=captured[0][0]['scope'],
                  nativeScope='Every BG byte/mask before and after every call; entire bitmap wrapper bytes/masks; decoded input, outer-token checksum, allocation and ordered surface release/free requests. Dead bytes retained with explicit allocator boundary.',
                  fixtureSHA256=hashlib.sha256(fixture.read_bytes()).hexdigest(), registrySHA256=captured[0][0]['registrySHA256'],
                  corpora=summaries, accesses=captured[0][0]['accesses'])
    (ROOT / 'docs/evidence/background-loader.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
