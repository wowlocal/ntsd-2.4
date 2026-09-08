#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Original common match preparation with the verified, complete loaded catalog.

Restores the pinned 4122f0 capture, executes World/bootstrap, then runs
42d1ff..42d6ed (including real RNG, BG lifecycle and input reset). Menu selection,
RNG starting state and disabled music are explicit supplied boundaries. This is
an instruction witness, NOT native equivalence, full menu/startup or replay init.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from oracle_loaded_catalog import LoadedCatalog, CATALOG, CATALOG_SIZE, BG_BASE, BG_SIZE, STAGE_SIZE
from oracle_objects import BITMAP_SIZE, DEVICE, HEAP, STUB
from oracle_state import ACTOR_SIZE, WORLD_PREFIX, STACK, STOP
from original_replay import replay_random
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

WORLD, POOL = 0x68000020, 0x70000020
GLOBAL, GLOBAL_SIZE = 0x44D000, 0x458440 - 0x44D000


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


class MatchPreparation(LoadedCatalog):
    def __init__(self, capture, pattern):
        super().__init__()
        self.pool_pattern = pattern
        self.actor_addresses, self.actor_constructors, self.calls, self.released = [], [], [], []
        self.global_accesses, self.host_writes = set(), []
        self.rng_pending = None
        self.active = False
        self.uc.mem_map(WORLD & ~4095, 0x1000)
        self.uc.mem_map(POOL & ~4095, 0x80000)
        self.world_record = self.add_region(WORLD, WORLD_PREFIX, 'world')
        if pattern is None:
            self.world_record['initial'] = bytes(i & 255 for i in range(WORLD_PREFIX))
        else:
            self.world_record['initial'] = bytes([pattern])*WORLD_PREFIX
        self.uc.mem_write(WORLD, self.world_record['initial'])
        for start, count in [(WORLD, WORLD_PREFIX), (POOL, 0x80000-0x20)]:
            for hook, callback in [(UC_HOOK_MEM_READ, self.track_read), (UC_HOOK_MEM_WRITE, self.track_write)]:
                self.uc.hook_add(hook, callback, begin=start, end=start+count-1)
        for hook in [UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE]:
            self.uc.hook_add(hook, self.global_access, begin=GLOBAL, end=GLOBAL+GLOBAL_SIZE-1,
                             user_data='read' if hook == UC_HOOK_MEM_READ else 'write')
        for address in [0x4061D0, 0x417170, 0x41717C, 0x4171BC, 0x40C030, 0x40C0E0, 0x431C70, 0x4025B0, 0x402020]:
            self.uc.hook_add(UC_HOOK_CODE, self.observe, begin=address, end=address)
        self.uc.hook_add(UC_HOOK_CODE, self.allowed_code)
        self.restore(capture)
        self.put(DEVICE+0x108, STUB+0x320)
        self.put(0x44717C, STUB+0x330)
        self.put(0x44D010, 0)  # explicit disabled DirectShow boundary
        self.uc.mem_write(0x44EED0, b'\0')  # no supplied current music path
        self.random_source = replay_random(DEFAULT_SOURCE, read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe'))
        self.uc.mem_write(0x44FF90, bytes(self.random_source['table']))
        self.put(0x450BCC, self.random_source['index'])
        self.put(0x450C34, self.random_source['counter'])
        self.global_initial = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        self.active = True

    def restore(self, capture):
        cache = {}

        def blob(key):
            if key not in cache:
                item = capture['blobs'][key]
                raw = zlib.decompress(base64.b64decode(item['deflate']), wbits=-15)
                assert len(raw) == item['count'] and digest(raw) == key
                cache[key] = raw
            return cache[key]

        def restore_record(region, item, offset=0):
            raw, mask, initial = [blob(item[k]) for k in ('bytes', 'defined', 'initial')]
            assert len(raw) == len(mask) == len(initial) and offset+len(raw) <= region['size']
            assert set(mask) <= {0, 1} and all(flag or raw[i] == initial[i] for i, flag in enumerate(mask))
            assert region['initial'][offset:offset+len(raw)] == initial
            self.uc.mem_write(region['address']+offset, raw)
            region['mask'][offset:offset+len(raw)] = mask

        assert capture['exeSHA256'] == EXE_SHA256 and capture['catalogAddress'] == CATALOG
        assert capture['translation'] == 'text' and capture['bitmapFill'] == 0xA5
        assert digest(read_bytes(DEFAULT_SOURCE/capture['fileName'].replace('\\', '/'))) == capture['source']
        for offset, item in capture['regions'].items():
            restore_record(self.catalog, item, int(offset))
        for i, item in enumerate(capture['stages']):
            restore_record(self.catalog, item, 0x7D0+i*STAGE_SIZE)
        self.object_addresses = capture['objectAddresses']
        self.object_inputs = []
        for child in capture['children']:
            assert digest(read_bytes(DEFAULT_SOURCE/child['path'].replace('\\', '/'))) == child['source']
            if child['kind'] == 'object':
                target = self.object_addresses[child['index']]
                restore_record(self.add_region(target, 0x25360, 'object'), child['storage'])
                self.object_inputs.append({k: child[k] for k in ('index', 'id', 'objectType', 'path')})
        for item in capture['allocations']:
            restore_record(self.add_region(item['address'], item['size'], item['kind']), item['storage'])
        self.allocations = [{k: v for k, v in a.items() if k != 'storage'} for a in capture['allocations']]
        self.bitmaps = [{k: v for k, v in b.items() if k != 'storage'} for b in capture['bitmaps']]
        self.initial_bitmap_count = len(self.bitmaps)
        last = self.allocations[-1]
        self.bump = last['address']+((last['size']+63) & ~15)
        assert HEAP < self.bump < HEAP+self.heap_size
        self.put(0x44F620, capture['checksum'])
        self.put(0x458438, capture['soundCount'])
        self.uc.mem_write(0x455638, blob(capture['soundBytes']))
        self.immutable = []
        # Verify every byte/mask of the restored read-only catalog portions,
        # Objects and pre-existing allocations after the complete scenario chain.
        for r in self.regions:
            if r['kind'] not in ('world', 'catalog'):
                self.immutable.append((r, digest(self.uc.mem_read(r['address'], r['size'])), digest(r['mask'])))
        self.catalog_immutable = [(o, n, digest(self.uc.mem_read(CATALOG+o, n)), digest(self.catalog['mask'][o:o+n]))
                                  for o, n in [(0, BG_BASE), (BG_BASE+101*BG_SIZE, 0x28)]]

    def global_access(self, uc, access, address, size, value, mode):
        if self.active:
            self.global_accesses.add((mode, address, size, uc.reg_read(UC_X86_REG_EIP)))

    def allowed_code(self, uc, address, size, data):
        if not self.active:
            return
        assert (0x419E40 <= address < 0x419E61 or 0x41C052 <= address < 0x41C2F5
                or 0x42D1FF <= address < 0x42D6ED or 0x4061D0 <= address < 0x4064CD
                or 0x417170 <= address <= 0x4171BC or 0x40C030 <= address < 0x40C15E
                or 0x431C70 <= address < 0x431D10 or 0x4025B0 <= address < 0x4025C5
                or 0x402020 <= address < 0x402030 or 0x4020F6 <= address < 0x402101
                or 0x43EE50 <= address <= 0x43EF85 or address == 0x43ED10
                or 0x4450A0 <= address <= 0x4450BA or STUB <= address < STUB+0x400), hex(address)

    def write_host(self, address, raw):
        if WORLD <= address < WORLD+WORLD_PREFIX or POOL <= address < POOL+0x80000:
            self.track_write(self.uc, 0, address, len(raw), 0, None)
            self.uc.mem_write(address, raw)
        else:
            super().write_host(address, raw)

    def memset(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        dst, value, count = [self.u32(sp+i) for i in (4, 8, 12)]
        assert (WORLD <= dst < dst+count <= WORLD+WORLD_PREFIX
                or POOL <= dst < dst+count <= POOL+0x80000
                or dst == 0x455378 and count == 0x12C
                or STACK <= dst < dst+count <= STACK+0x10000), (hex(dst), count)
        if GLOBAL <= dst < GLOBAL+GLOBAL_SIZE:
            self.global_access(uc, 0, dst, count, 0, 'write')
        self.write_host(dst, bytes([value & 255])*count)
        self.ret(dst)

    def checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x4450AC and self.u32(sp+4) == ACTOR_SIZE:
            assert self.u32(sp) == 0x41C07A
            slot = len(self.actor_addresses)
            assert slot < 400
            target = POOL+slot*0x500
            r = self.add_region(target, ACTOR_SIZE, 'actor')
            r['initial'] = bytes(i & 255 for i in range(ACTOR_SIZE)) if self.pool_pattern is None else bytes([self.pool_pattern])*ACTOR_SIZE
            self.uc.mem_write(target, r['initial'])
            self.actor_addresses.append(target)
            self.ret(target)
        else:
            super().checkpoint(uc, address, size, data)

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == STUB+0x320:
            target = uc.reg_read(UC_X86_REG_ECX)
            assert self.u32(sp+4) == DEVICE and self.u32(sp) == 0x40C120
            assert target in [b['address'] for b in self.bitmaps] and target not in self.released
            self.events.append(dict(kind='surface-release', address=target))
            self.ret(0, 4)
        elif address == STUB+0x330:
            target = self.u32(sp+4)
            assert self.u32(sp) == 0x40C125 and self.events[-1] == dict(kind='surface-release', address=target)
            self.released.append(target)
            self.events.append(dict(kind='free', address=target))
            self.ret()
        else:
            super().imported(uc, address, size, data)

    def observe(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x4061D0:
            self.actor_constructors.append(self.actor_addresses.index(uc.reg_read(UC_X86_REG_ECX)))
        elif address == 0x417170:
            assert self.rng_pending is None
            self.rng_pending = dict(kind='rng', caller=hex(self.u32(sp)), stream=self.u32(sp+4),
                                    range=struct.unpack('<i', uc.mem_read(sp+8, 4))[0], before=self.random_state())
        elif address in (0x41717C, 0x4171BC):
            assert self.rng_pending is not None
            self.calls.append(dict(self.rng_pending, result=uc.reg_read(UC_X86_REG_EAX), after=self.random_state()))
            self.rng_pending = None
        else:
            item = dict(kind={0x40C030: 'load-layers', 0x40C0E0: 'release-layers', 0x431C70: 'reset-input',
                              0x4025B0: 'resume-music', 0x402020: 'music-path'}[address], caller=hex(self.u32(sp)))
            if address in (0x40C030, 0x40C0E0):
                assert uc.reg_read(UC_X86_REG_ECX) == CATALOG
                item['index'] = self.u32(sp+4)
            self.calls.append(item)

    def random_state(self):
        return dict(index=self.u32(0x450BCC), counter=self.u32(0x450C34))

    def execute(self, start, stop):
        self.uc.emu_start(start, stop, count=2_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == stop, hex(self.uc.reg_read(UC_X86_REG_EIP))
        assert not self.reads_before_writes, sorted(self.reads_before_writes)[:12]
        assert self.rng_pending is None

    def bootstrap(self):
        sp = STACK+0xF000
        self.put(sp, STOP)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, WORLD)
        self.execute(0x419E40, STOP)
        self.put(WORLD, 2)  # dispatcher selector remains an external input
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_EAX, CATALOG)
        self.uc.reg_write(UC_X86_REG_EBX, WORLD)
        self.execute(0x41C052, 0x41C2F5)
        assert self.actor_constructors == list(range(400))+list(range(8))
        return self.snapshot()

    def snapshot(self):
        return dict(world=self.record(self.world_record),
                    actors=[self.record(self.region(a, ACTOR_SIZE)) for a in self.actor_addresses],
                    backgrounds=[self.slice_record(self.catalog, BG_BASE+i*BG_SIZE, BG_SIZE) for i in range(101)],
                    globals=self.blob(self.uc.mem_read(GLOBAL, GLOBAL_SIZE)), random=self.random_state(),
                    bitmapCount=len(self.bitmaps), released=self.released.copy())

    def stimulus(self, address, raw):
        self.host_writes.append(dict(address=address, bytes=raw.hex()))
        self.write_host(address, raw)

    def before_preparation(self, mode):
        """Optional real caller prelude; historical corpora start at 42d1ff."""
        return None

    def scenario(self, label, mode, background, selections, random_index=None, random_counter=None, extras=False):
        self.host_writes, self.calls, self.actor_constructors, self.events = [], [], [], []
        self.global_accesses = set()
        word = lambda address, value: self.stimulus(address, struct.pack('<I', value & 0xFFFFFFFF))
        word(0x44D024, background)
        word(0x44D028, int(random_index is not None))
        if random_index is not None:
            word(0x450BCC, random_index)
            word(0x450C34, random_counter or 0)
        for seat, (status, ordinal, team) in enumerate(selections):
            word(0x451288+seat*4, status)
            word(self.actor_addresses[seat]+0x368, self.object_addresses[ordinal])
            word(self.actor_addresses[seat]+0x364, team)
            self.stimulus(WORLD+4+seat, bytes([int(1 <= status <= 10)]))
        for slot in (8, 9, 20, 399):
            self.stimulus(WORLD+4+slot, bytes([int(extras)]))
        # Nonzero stimuli distinguish real resets/preservation from zero input.
        for address, count in [(0x450C04, 40), (0x451320, 32), (0x4513A4, 28), (0x455378, 300)]:
            self.stimulus(address, bytes((i*17+19) & 255 for i in range(count)))
        for slot in range(8):
            self.stimulus(self.actor_addresses[slot]+0xCD, bytes(range(1, 8)))
        if extras:
            word(self.actor_addresses[8]+0x368, self.object_addresses[-1])  # type != 0
            word(self.actor_addresses[9]+0x368, self.object_addresses[0])
            word(self.actor_addresses[9]+0x364, 0)
        sp = STACK+0xF000
        self.put(sp+0x14, WORLD)
        mode_address = getattr(self, 'mode_address', STACK+0x200)
        self.put(sp+0x1C, mode_address)
        self.put(mode_address, mode)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_EBX, 0)
        prelude = self.before_preparation(mode)
        before = self.snapshot()
        start_bitmap = len(self.bitmaps)
        self.execute(0x42D1FF, 0x42D6ED)
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp
        after = self.snapshot()
        bitmaps = [{**b, 'storage': self.record(self.region(b['address'], BITMAP_SIZE))} for b in self.bitmaps[start_bitmap:]]
        assert [c['index'] for c in self.calls if c['kind'] == 'release-layers'] == list(range(17))
        assert self.calls[-1]['kind'] == 'reset-input'
        print(f"{label}: BG {self.u32(0x44D024)}, {len(self.actor_constructors)} constructors, "
              f"{sum(c['kind']=='rng' for c in self.calls)} RNG calls, {len(bitmaps)} new layers", flush=True)
        item = dict(label=label, mode=mode, selections=selections, stimulus=self.host_writes,
                    before=before, after=after, constructors=self.actor_constructors,
                    calls=self.calls, bitmaps=bitmaps, events=self.events,
                    globalAccesses=[dict(mode=m, address=a, size=n, instruction=hex(pc)) for m, a, n, pc in sorted(self.global_accesses)])
        if prelude is not None:
            item['prelude'] = prelude
        return item

    def verify_immutable(self):
        for r, raw, mask in self.immutable:
            assert digest(self.uc.mem_read(r['address'], r['size'])) == raw and digest(r['mask']) == mask
            self.record(r)  # guards and untouched-byte provenance
        for offset, count, raw, mask in self.catalog_immutable:
            assert digest(self.uc.mem_read(CATALOG+offset, count)) == raw
            assert digest(self.catalog['mask'][offset:offset+count]) == mask
        assert self.uc.mem_read(CATALOG-16, 16) == b'\x96'*16
        assert self.uc.mem_read(CATALOG+CATALOG_SIZE, 16) == b'\x69'*16


def accept():
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    packed_paths, fixture_paths, reports = [], [], []
    for suffix in ('', '-ramp'):
        raw = (ROOT/f'build/original/match-preparation{suffix}.json').read_bytes()
        report_path = ROOT/f'docs/evidence/match-preparation{suffix}.json'
        report = json.loads(report_path.read_text())
        assert digest(raw) == report['corpusSHA256']
        doc = json.loads(raw)
        # Retain all state, stimuli, calls and assets; only the repeated global
        # instruction-access inventory is omitted from the offline comparison.
        for case in doc['cases']:
            case.pop('globalAccesses')
        compact = json.dumps(doc, separators=(',', ':')).encode()
        packed = dict(count=len(compact), sha256=digest(compact),
                      deflate=base64.b64encode(zlib.compress(compact, level=9, wbits=-15)).decode())
        path = ROOT/f'build/original/match-preparation{suffix}-check.json'
        path.write_text(json.dumps(packed, separators=(',', ':'))+'\n')
        packed_paths.append(path)
        fixture_paths.append(ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-match-preparation{suffix}.json')
        reports.append((report_path, report))
    loaded = ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'
    result = subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'), '--match-preparation', str(loaded),
                             *map(str, packed_paths)], check=True, capture_output=True, text=True)
    print(result.stdout, end='', flush=True)
    # No fixture/report is accepted until both complete native comparisons pass.
    for packed, fixture, (report_path, report) in zip(packed_paths, fixture_paths, reports):
        fixture.write_bytes(packed.read_bytes())
        report.update(nativeComparison=result.stdout.strip(), fixture=fixture.name,
                      fixtureSHA256=digest(fixture.read_bytes()), fixtureBytes=fixture.stat().st_size)
        report['scope'] = report['scope'].replace(', no native comparison', '')
        report['nativeScope'] = 'Full native catalog rebuild/comparison, then bootstrap and every preparation before/after World/Actor/BG/global record; new bitmap storage and constructor/RNG/resource/input call order'
        report_path.write_text(json.dumps(report, indent=2)+'\n')


def run_scenarios(vm):
    by_path = {o['path']: o['index'] for o in vm.object_inputs}
    naruto, sasuke = by_path['chars\\naruto.dat'], by_path['chars\\sasuke.dat']
    two = [(1, naruto, 0), (11, sasuke, 0)]+[(0, 0, 0)]*6
    cases = [vm.scenario('naruto-sasuke-district', 0, 0, two), vm.scenario('restart-district', 0, 0, two)]
    # These are controlled menu-boundary inputs, not a claim that non-character
    # objects can be selected through the original UI. All 137 loaded headers
    # exercise the same binding/copy mechanism, with real source arena geometry.
    for batch in range(18):
        seats = [(1 if i % 2 == 0 else 11, (batch*8+i) % 137, [0, 3, -1, 0][i % 4]) for i in range(8)]
        cases.append(vm.scenario(f'catalog-batch-{batch}', batch % 2, batch % 17, seats, extras=batch == 1))
    boundary = [(1, naruto, 0), (10, sasuke, 4), (11, naruto, 0), (2147483647, sasuke, -1),
                (0, naruto, 0), (-1, sasuke, 0), (-2147483648, naruto, 0), (2, sasuke, 0)]
    cases.append(vm.scenario('status-boundaries-stage', 1, 0, boundary, extras=True))
    table = vm.random_source['table']
    special = next(i for i in range(3000) if (table[(i+1) % 3000]+1) % 15 == 14)
    cases.append(vm.scenario('random-special-99', 0, 0, two, random_index=special))
    cases.append(vm.scenario('rng-index-counter-wrap', 1, 0, two, random_index=2999, random_counter=1233))
    cases.append(vm.scenario('direct-special-99', 2, 99, boundary))
    cases.append(vm.scenario('empty-selection', 0, 0, [(0, 0, 0)]*8))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ramp', action='store_true', help='ramp Actor/World backing; catalog remains the pinned text/a5 capture')
    parser.add_argument('--accept', action='store_true', help='compare both existing captures natively before accepting fixtures')
    args = parser.parse_args()
    if args.accept:
        assert not args.ramp
        accept()
        return
    report = json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_text())
    provenance = next(c for c in report['corpora'] if c['corpus'] == 'loaded-catalog.json')
    path = ROOT/'build/original'/provenance['corpus']
    raw = path.read_bytes()
    assert digest(raw) == provenance['corpusSHA256'], 'Regenerate/verify the full catalog before restoring it'
    capture = json.loads(raw)
    vm = MatchPreparation(capture, None if args.ramp else 0xA5)
    del raw, capture
    staged = vm.bootstrap()
    cases = run_scenarios(vm)
    vm.verify_immutable()
    scope = 'Original 42d1ff..42d6ed after full loaded-catalog restore and real World/bootstrap; supplied menu/RNG/music boundaries, no native comparison'
    doc = dict(exeSHA256=EXE_SHA256, scope=scope, loadedCatalog=provenance['corpus'],
               loadedCatalogSHA256=provenance['corpusSHA256'], loadedFixtureSHA256=provenance['fixtureSHA256'],
               catalogAddress=CATALOG, worldAddress=WORLD, actorAddresses=vm.actor_addresses,
               objects=vm.object_inputs, objectAddresses=vm.object_addresses,
               bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]], surfaceAddress=DEVICE,
               globalAddress=GLOBAL, globalInitial=vm.blob(vm.global_initial), randomSource=vm.random_source,
               pattern='ramp' if args.ramp else 'a5', selector=2, staged=staged,
               cases=cases, assets=list(vm.asset_inputs.values()), readsBeforeWrites=sorted(vm.reads_before_writes), blobs=vm.blobs)
    suffix = '-ramp' if args.ramp else ''
    output = ROOT/f'build/original/match-preparation{suffix}.json'
    output.write_text(json.dumps(doc, separators=(',', ':'))+'\n')
    summary = dict(exeSHA256=EXE_SHA256, scope=scope, corpus=output.name, corpusSHA256=digest(output.read_bytes()),
                   loadedCatalogSHA256=provenance['corpusSHA256'], cases=len(cases), pattern=doc['pattern'],
                   bootstrapConstructors=408, sourceObjectsBound=sorted({s[1] for c in cases for s in c['selections']}),
                   nativeComparison='pending', immutableCatalogObjectHeapBytesVerified=True, readsBeforeWrites=[],
                   casesSummary=[dict(label=c['label'], mode=c['mode'], constructors=len(c['constructors']),
                                      rngCalls=[x for x in c['calls'] if x['kind']=='rng'],
                                      arenaCalls=[x for x in c['calls'] if x['kind'] in ('load-layers', 'release-layers')],
                                      newLayers=len(c['bitmaps']), releasedTotal=len(c['after']['released'])) for c in cases])
    (ROOT/f'docs/evidence/match-preparation{suffix}.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(f'Captured {len(cases)} cases; native comparison pending: {output}', flush=True)


if __name__ == '__main__':
    main()
