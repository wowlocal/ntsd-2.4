#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue real match preparation through recording initialization 43d2c0.

Uses the complete verified catalog and bootstrap. Replay metadata and selected
byte-pattern probes are explicit supplied inputs. calloc/free are boundaries;
all copy/reset instructions and the actual menu call execute. No playback/file
format/compression or complete Windows menu/first tick equivalence is claimed.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib

from import_ntsd import EXE_SHA256, ROOT
from oracle_match_preparation import MatchPreparation, run_scenarios, digest, WORLD, GLOBAL, GLOBAL_SIZE
from oracle_loaded_catalog import CATALOG
from oracle_objects import DEVICE, STUB
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ESP

ARENA, SIZE, POINTERS = 0x72000020, 0x630E18, 0x4588A8


class ReplayInitialization(MatchPreparation):
    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        self.uc.mem_map(ARENA & ~4095, 0xA000000)
        self.replay_regions, self.replay_events, self.replay_writes = [], [], set()
        self.current_replay = None
        self.pointer_initial = bytes(self.uc.mem_read(POINTERS, 8))
        assert self.pointer_initial == bytes(8), 'Unrecovered initial replay ownership'
        self.put(0x4471B0, STUB+0x340)  # calloc
        for hook, callback in [(UC_HOOK_MEM_READ, self.track_read), (UC_HOOK_MEM_WRITE, self.track_write)]:
            self.uc.hook_add(hook, callback, begin=ARENA, end=(ARENA & ~4095)+0xA000000-1)
        for hook, mode in [(UC_HOOK_MEM_READ, 'read'), (UC_HOOK_MEM_WRITE, 'write')]:
            self.uc.hook_add(hook, self.global_access, begin=POINTERS, end=POINTERS+7, user_data=mode)
        self.uc.hook_add(UC_HOOK_CODE, self.replay_entry, begin=0x43D2C0, end=0x43D2C0)

    def allowed_code(self, uc, address, size, data):
        # Switching stop points inside a cached Unicorn translation block must
        # not let the following menu instructions leak into a preparation call.
        if address == getattr(self, 'execution_stop', None):
            uc.emu_stop()
            return
        if 0x43D280 <= address <= 0x43D29C or 0x43D2C0 <= address <= 0x43DB38 or 0x42D6ED <= address < 0x42D704:
            return
        super().allowed_code(uc, address, size, data)

    def execute(self, start, stop):
        self.execution_stop = stop
        try:
            super().execute(start, stop)
        finally:
            self.execution_stop = None

    def track_write(self, uc, access, address, size, value, data):
        super().track_write(uc, access, address, size, value, data)
        if ARENA <= address < (ARENA & ~4095)+0xA000000:
            from unicorn.x86_const import UC_X86_REG_EIP
            assert self.current_replay is not None
            self.replay_writes.add((uc.reg_read(UC_X86_REG_EIP), address-self.current_replay['address'], size))

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == STUB+0x340:
            assert self.u32(sp) == 0x43D2DE and [self.u32(sp+4), self.u32(sp+8)] == [1, SIZE]
            assert self.current_replay is None and len(self.replay_regions) < 25
            target = ARENA+len(self.replay_regions)*0x640000
            region = self.add_region(target, SIZE, 'replay')
            self.uc.mem_write(target, bytes(SIZE))
            region['mask'][:] = b'\1'*SIZE  # calloc owns these initialized zeros
            self.replay_regions.append(region)
            self.current_replay = region
            self.replay_events.append(dict(kind='calloc', address=target, count=1, size=SIZE, caller='0x43d2de'))
            self.ret(target)
        elif address == STUB+0x330 and self.u32(sp) == 0x43D292:
            target = self.u32(sp+4)
            assert self.current_replay is not None and self.current_replay['address'] == target
            self.replay_events.append(dict(kind='free', address=target, caller='0x43d292'))
            self.current_replay = None
            self.ret()
        else:
            super().imported(uc, address, size, data)

    def replay_entry(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        assert self.u32(sp) == 0x42D701
        assert self.u32(sp+8) == WORLD+4 and self.u32(sp+12) == WORLD+0x194
        self.replay_events.append(dict(kind='entry', caller='0x42d701', mode=self.u32(sp+4),
                                       activity=self.u32(sp+8), actors=self.u32(sp+12)))

    def scenario(self, *args, **kwargs):
        item = super().scenario(*args, **kwargs)
        index = len(self.replay_regions)
        self.host_writes, self.replay_events, self.replay_writes, self.global_accesses = [], [], set(), set()
        word = lambda address, value: self.stimulus(address, struct.pack('<I', value & 0xFFFFFFFF))
        # Metadata provenance remains explicit. Source headers and RNG index /
        # counter are the actual result of the preceding original preparation.
        for offset, address in enumerate([0x450C30, 0x458428, 0x45842C, 0x450B94, 0x44D03C, 0x450B90,
                                          0x450B8C, 0x450B80, 0x450BD0, 0x450BD4, 0x450BD8]):
            word(address, (0x80000000 if index % 2 else 0x12340000)+index*257+offset)
        for address, count in [(0x44D5F8, 0x160), (0x44D324, 44)]:
            self.stimulus(address, bytes((index*19+i*23+7) & 255 for i in range(count)))
        names = b''.join((f'P{index}-{seat}'.encode()+b'\0').ljust(11, b'\xAD') for seat in range(8))
        if index == 20:
            names = bytearray(b'\xE9'*88)
            for end in (4, 27, 76, 87):
                names[end] = 0  # strcpy crosses the nominal 11-byte name slots
        self.stimulus(0x44FCC0, bytes(names))
        for address, byte in [(0x44FD18, 0xD1), (0x44F900, 0xE2), (0x44F890, 0xF3)]:
            count = [0, 1, 10, 99][index % 4]
            self.stimulus(address, bytes([byte])*count+b'\0')
        self.stimulus(0x44EED0, f'music\\track{index}_'.encode()+b'\xE9.wav\0')
        self.stimulus(0x44FF90+3000, bytes([0xA7 if index == 20 else 0]))
        if index == 20:
            fields = [0x364, 8, 0x10, 0x14, 0x18, 0x308, 0x354, 0x304, 0x33C, 0x344, 0x340]
            for slot in range(18):
                self.stimulus(WORLD+4+slot, bytes([[0, 1, 127, 128, 255][slot % 5]]))
                for field in fields:
                    word(self.actor_addresses[slot]+field, (0x80000000 if slot % 2 else 0x12340000)+slot*4096+field)
        before = self.snapshot()
        item['replayStimulus'] = self.host_writes
        item['replayBeforePointers'] = bytes(self.uc.mem_read(POINTERS, 8)).hex()
        self.execute(0x42D6ED, 0x42D704)  # actual call 42d6fc, real return and caller cleanup
        assert self.uc.reg_read(UC_X86_REG_ESP) == STACK+0xF000
        item['continued'] = self.snapshot()
        for field in ('world', 'actors', 'backgrounds', 'bitmapCount', 'released'):
            assert item['continued'][field] == before[field], ('Replay changed source state', field)
        assert self.u32(0x450C34) == 0 and self.u32(0x450BCC) == before['random']['index']
        region = self.current_replay
        item['replay'] = dict(address=region['address'], storage=self.record(region))
        item['replayAfterPointers'] = bytes(self.uc.mem_read(POINTERS, 8)).hex()
        assert self.u32(POINTERS) == region['address'] and self.u32(POINTERS+4) == 0
        item['replayEvents'] = self.replay_events
        item['replayWrites'] = [dict(instruction=hex(pc), offset=offset, size=size) for pc, offset, size in sorted(self.replay_writes)]
        item['replayGlobalAccesses'] = [dict(mode=m, address=a, size=n, instruction=hex(pc)) for m, a, n, pc in sorted(self.global_accesses)]
        print(f"  replay {index+1}: full {SIZE} bytes, RNG counter {before['random']['counter']} -> 0", flush=True)
        return item

    def cleanup(self):
        self.replay_events = []
        before = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        for _ in range(2):
            sp = STACK+0xF000
            self.uc.mem_write(sp, struct.pack('<II', STOP, POINTERS))
            self.uc.reg_write(UC_X86_REG_ESP, sp)
            self.execute(0x43D280, STOP)
            assert self.uc.reg_read(UC_X86_REG_ESP) == sp+4
        assert self.u32(POINTERS) == 0 and self.current_replay is None
        assert len(self.replay_events) == 1 and self.replay_events[0]['kind'] == 'free'
        assert bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE)) == before
        for region in self.replay_regions:
            self.record(region)  # retained dead bytes and guards remain intact
        return dict(events=self.replay_events, pointers=bytes(self.uc.mem_read(POINTERS, 8)).hex(), globals=self.blob(before))


def accept():
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    paths, reports = [], []
    for suffix in ('', '-ramp'):
        raw = (ROOT/f'build/original/replay-initialization{suffix}.json').read_bytes()
        path = ROOT/f'docs/evidence/replay-initialization{suffix}.json'
        report = json.loads(path.read_text())
        assert digest(raw) == report['corpusSHA256']
        doc = json.loads(raw)
        for case in doc['cases']:
            for key in ('globalAccesses', 'replayGlobalAccesses', 'replayWrites'):
                case.pop(key)
        # The read-only catalog is already pinned/compared separately. Omit only
        # unreferenced blobs, never bytes of a retained record or supplied input.
        blobs = doc.pop('blobs')
        def keys(value):
            if isinstance(value, str):
                return {value} if value in blobs else set()
            if isinstance(value, list):
                return set().union(*(keys(x) for x in value))
            if isinstance(value, dict):
                return set().union(*(keys(x) for x in value.values()))
            return set()
        doc['blobs'] = {key: blobs[key] for key in sorted(keys(doc))}
        compact = json.dumps(doc, separators=(',', ':')).encode()
        packed = dict(count=len(compact), sha256=digest(compact), deflate=base64.b64encode(zlib.compress(compact, level=9, wbits=-15)).decode())
        output = ROOT/f'build/original/replay-initialization{suffix}-check.json'
        output.write_text(json.dumps(packed, separators=(',', ':'))+'\n')
        paths.append(output); reports.append((path, report, suffix))
    result = subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'), '--replay-initialization',
                             str(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'), *map(str, paths)],
                            check=True, capture_output=True, text=True)
    print(result.stdout, end='', flush=True)
    for packed, (path, report, suffix) in zip(paths, reports):
        fixture = ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-replay-initialization{suffix}.json'
        fixture.write_bytes(packed.read_bytes())
        report.update(nativeComparison=result.stdout.strip(), fixture=fixture.name,
                      fixtureSHA256=digest(fixture.read_bytes()), fixtureBytes=fixture.stat().st_size)
        path.write_text(json.dumps(report, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ramp', action='store_true')
    parser.add_argument('--accept', action='store_true')
    args = parser.parse_args()
    if args.accept:
        assert not args.ramp
        accept(); return
    provenance = next(c for c in json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_text())['corpora'] if c['corpus']=='loaded-catalog.json')
    raw = (ROOT/'build/original'/provenance['corpus']).read_bytes()
    assert digest(raw) == provenance['corpusSHA256']
    capture = json.loads(raw)
    vm = ReplayInitialization(capture, None if args.ramp else 0xA5)
    del capture, raw
    staged = vm.bootstrap()
    cases = run_scenarios(vm)
    cleanup = vm.cleanup()
    vm.verify_immutable()
    scope = 'Full catalog/bootstrap and 25 chained common preparations, actual caller 42d6fc and recording init43d2c0..43db38; supplied menu/RNG/metadata, calloc/free/device boundaries; no full startup or replay playback'
    doc = dict(exeSHA256=EXE_SHA256, scope=scope, loadedCatalog=provenance['corpus'],
               loadedCatalogSHA256=provenance['corpusSHA256'], loadedFixtureSHA256=provenance['fixtureSHA256'],
               catalogAddress=CATALOG, worldAddress=WORLD, actorAddresses=vm.actor_addresses,
               objects=vm.object_inputs, objectAddresses=vm.object_addresses,
               bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]], surfaceAddress=DEVICE,
               globalAddress=GLOBAL, globalInitial=vm.blob(vm.global_initial), randomSource=vm.random_source,
               replayPointersAddress=POINTERS, replayPointersInitial=vm.pointer_initial.hex(), cleanup=cleanup,
               pattern='ramp' if args.ramp else 'a5', selector=2, staged=staged,
               cases=cases, assets=list(vm.asset_inputs.values()), readsBeforeWrites=sorted(vm.reads_before_writes), blobs=vm.blobs)
    suffix = '-ramp' if args.ramp else ''
    output = ROOT/f'build/original/replay-initialization{suffix}.json'
    output.write_text(json.dumps(doc, separators=(',', ':'))+'\n')
    summary = dict(exeSHA256=EXE_SHA256, scope=scope, corpus=output.name, corpusSHA256=digest(output.read_bytes()),
                   loadedCatalogSHA256=provenance['corpusSHA256'], cases=len(cases), bufferBytes=SIZE,
                   allocations=len(vm.replay_regions), frees=sum(e['kind']=='free' for c in cases for e in c['replayEvents'])+len(cleanup['events']),
                   nativeComparison='pending', readOnlySourcesPreserved=True, readsBeforeWrites=[],
                   writeSchema=write_schema(cases),
                   casesSummary=[dict(label=c['label'], mode=c['mode'], buffer=c['replay']['address'], storage=c['replay']['storage']['bytes'],
                                      beforeRandom=c['after']['random'], afterRandom=c['continued']['random'],
                                      lifecycle=c['replayEvents'], distinctWriteSites=len(c['replayWrites'])) for c in cases])
    (ROOT/f'docs/evidence/replay-initialization{suffix}.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(f'Captured {len(cases)} recording initializations; native comparison pending: {output}', flush=True)


def write_schema(cases):
    instructions = {}
    for case in cases:
        for write in case['replayWrites']:
            instructions.setdefault(write['instruction'], set()).add((write['offset'], write['offset']+write['size']))
    result = []
    for instruction, spans in sorted(instructions.items()):
        merged = []
        for start, end in sorted(spans):
            if merged and start <= merged[-1][1]:
                merged[-1][1] = max(merged[-1][1], end)
            else:
                merged.append([start, end])
        result.append(dict(instruction=instruction, ranges=merged))
    return result


if __name__ == '__main__':
    main()
