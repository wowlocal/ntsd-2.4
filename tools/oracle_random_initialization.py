#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute EXE startup seed/table calls with actual VC80 srand/rand, then match.

Same supplied CRT thread state throughout a chain. Timer values, intervening CRT
draw counts and menu inputs are explicit controls, not a complete startup trace.
No source replay supplies the table. Full loaded catalog/prelude/preparation and
recording are retained; Windows binding/output and other rand consumers are open.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib

from import_ntsd import EXE_SHA256, ROOT
from oracle_crt import DLL_SHA256, PACKAGE_SHA256, POLICY_SHA256
from oracle_match_prelude import MatchPrelude
from oracle_replay_initialization import POINTERS, SIZE
from oracle_match_preparation import digest, WORLD, GLOBAL, GLOBAL_SIZE
from oracle_loaded_catalog import CATALOG
from oracle_objects import DEVICE, STUB
from oracle_state import STACK
from unicorn.x86_const import UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_ESP


class RandomInitialization(MatchPrelude):
    def initialize_random_boundary(self):
        # Preserve real mapped PE/BSS, do not read replay_random at all.
        assert self.uc.mem_read(0x44FF90, 3001) == bytes(3001)
        assert self.u32(0x450BCC) == self.u32(0x450C34) == 0
        self.random_source = dict(kind='PE/BSS, then real CRT-generated table')

    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        assert self.crt.random_state == 1
        self.put(0x447198, STUB+0x390)
        self.put(0x4470EC, STUB+0x3A0)
        self.random_calls = None

    def allowed_code(self, uc, address, size, data):
        if address == getattr(self, 'execution_stop', None):
            uc.emu_stop()
            return
        if (0x43CF40 <= address < 0x43CF63 or 0x422AC0 <= address <= 0x422AF7
                or address in (0x427A2C, 0x427A71)):
            return
        super().allowed_code(uc, address, size, data)

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        caller = self.u32(sp)
        if address == STUB+0x390:
            assert caller == 0x422AD2 and self.random_calls is not None
            call = self.crt.random_call()
            self.random_calls.append(call)
            self.ret(call['result'])
        elif address == STUB+0x3A0:
            assert caller == 0x43CF60 and self.u32(sp+4) == self.milliseconds
            self.seed_call = self.crt.random_call(self.u32(sp+4))
            self.ret()  # srand is void; original caller does not read EAX
        elif self.lookup.get(address) == 'timeGetTime' and caller == 0x43CF57:
            self.timer_calls += 1
            self.ret(self.milliseconds)
        else:
            super().imported(uc, address, size, data)

    def before_prelude(self):
        index = len(self.replay_regions)
        # Inputs precede the tested instructions and are recorded, never derived
        # from their expected output. Distinguish preservation/reset from zeros.
        self.stimulus(0x458420, struct.pack('<I', 0x81230000+index))
        self.stimulus(0x450B48, bytes([0xA7+index]))
        before = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        state_before = self.crt.random_state
        self.seed_call, self.timer_calls = None, 0
        self.global_accesses = set()
        if self.milliseconds is not None:
            self.uc.reg_write(UC_X86_REG_ESP, STACK+0xF000)
            self.execute(0x43CF40, 0x43CF63)
            assert self.uc.reg_read(UC_X86_REG_ESP) == STACK+0xF000-0x34
            assert self.uc.reg_read(UC_X86_REG_ESI) == self.milliseconds
            assert self.timer_calls == 1 and self.seed_call is not None
        intervening = [self.crt.random_call() for _ in range(self.draws)]
        self.random_calls = []
        caller = (0x427A2C, 0x427A71)[index % 2]
        registers = [UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_EDI]
        values = [0x11111111, 0x22222222, 0x33333333, 0x44444444]
        for register, value in zip(registers, values):
            self.uc.reg_write(register, value)
        self.uc.reg_write(UC_X86_REG_ESP, STACK+0xF000)
        self.execute(caller, caller+5)  # actual CALL, entire 422ac0, actual RET
        assert self.uc.reg_read(UC_X86_REG_ESP) == STACK+0xF000
        assert [self.uc.reg_read(r) for r in registers] == values
        assert len(self.random_calls) == 3000
        after = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        writes = {(a, n, pc) for m, a, n, pc in self.global_accesses if m == 'write'}
        expected = {(0x44FF90+i, 1, 0x422AE6) for i in range(3000)} | {(0x450B48, 1, 0x422AEF)}
        if self.milliseconds is not None:
            expected.add((0x458420, 4, 0x43CF4B))
        assert writes == expected
        changed = set(range(0x44FF90-GLOBAL, 0x450B49-GLOBAL))
        if self.milliseconds is not None:
            changed.update(range(0x458420-GLOBAL, 0x458424-GLOBAL))
        assert all(a == b or i in changed for i, (a, b) in enumerate(zip(before, after)))
        self.random_initialization = dict(milliseconds=self.milliseconds, interveningDrawCount=self.draws,
            beforeState=state_before, afterState=self.crt.random_state, seed=self.seed_call,
            intervening=intervening, tableCalls=self.random_calls, caller=hex(caller),
            beforeGlobals=self.blob(before), afterGlobals=self.blob(after),
            preservedRegisters=values, stackAfter=STACK+0xF000, timerCalls=self.timer_calls,
            writes=[dict(address=a, size=n, instruction=hex(pc)) for a, n, pc in sorted(writes)])
        self.random_calls = None
        self.uc.reg_write(UC_X86_REG_EBX, 0)  # supplied common-preparation context

    def scenario(self, *args, **kwargs):
        result = super().scenario(*args, **kwargs)
        assert self.crt.random_state == self.random_initialization['afterState']
        result['randomInitialization'] = self.random_initialization
        return result


def accept():
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    paths, reports = [], []
    for suffix in ('', '-ramp'):
        raw = (ROOT/f'build/original/random-initialization{suffix}.json').read_bytes()
        report_path = ROOT/f'docs/evidence/random-initialization{suffix}.json'
        report = json.loads(report_path.read_text())
        assert digest(raw) == report['corpusSHA256']
        doc = json.loads(raw)
        for case in doc['cases']:
            for key in ('globalAccesses', 'replayGlobalAccesses', 'replayWrites'):
                case.pop(key)
            case['randomInitialization'].pop('writes')
        blobs = doc.pop('blobs')
        def keys(value):
            if isinstance(value, str):
                return {value} if value in blobs else set()
            if isinstance(value, list):
                return set().union(*(keys(x) for x in value))
            if isinstance(value, dict):
                return set().union(*(keys(x) for x in value.values()))
            return set()
        doc['blobs'] = {k: blobs[k] for k in sorted(keys(doc))}
        compact = json.dumps(doc, separators=(',', ':')).encode()
        packed = dict(count=len(compact), sha256=digest(compact),
                      deflate=base64.b64encode(zlib.compress(compact, level=9, wbits=-15)).decode())
        path = ROOT/f'build/original/random-initialization{suffix}-check.json'
        path.write_text(json.dumps(packed, separators=(',', ':'))+'\n')
        paths.append(path); reports.append((report_path, report))
    loaded = ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'
    result = subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'), '--random-initialization', str(loaded),
                             *map(str, paths)], capture_output=True, text=True)
    print(result.stdout, end='', flush=True)
    if result.returncode:
        print(result.stderr, end='', flush=True)
        result.check_returncode()
    for suffix, path, (report_path, report) in zip(('', '-ramp'), paths, reports):
        fixture = ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-random-initialization{suffix}.json'
        fixture.write_bytes(path.read_bytes())
        report.update(nativeComparison=result.stdout.strip(), fixture=fixture.name,
                      fixtureSHA256=digest(fixture.read_bytes()), fixtureBytes=fixture.stat().st_size)
        report_path.write_text(json.dumps(report, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ramp', action='store_true')
    parser.add_argument('--accept', action='store_true')
    parser.add_argument('--check-parent', action='store_true', help='reproduce the unchanged historical prelude corpus')
    args = parser.parse_args()
    if args.accept:
        assert not args.ramp and not args.check_parent
        accept(); return
    provenance = next(c for c in json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_text())['corpora']
                      if c['corpus'] == 'loaded-catalog.json')
    raw = (ROOT/'build/original'/provenance['corpus']).read_bytes()
    assert digest(raw) == provenance['corpusSHA256']
    if args.check_parent:
        suffix = '-ramp' if args.ramp else ''
        report = json.loads((ROOT/f'docs/evidence/match-prelude{suffix}.json').read_text())
        parent_raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(parent_raw) == report['corpusSHA256']
        parent = json.loads(parent_raw)
        vm = MatchPrelude(json.loads(raw), None if args.ramp else 0xA5)
        assert vm.blob(vm.global_initial) == parent['globalInitial']
        assert vm.bootstrap() == parent['staged']
        for case in parent['cases']:
            vm.stage = case['prelude']['stage']
            background = next(struct.unpack('<i', bytes.fromhex(w['bytes']))[0]
                              for w in case['stimulus'] if w['address'] == 0x44D024)
            actual = vm.scenario(case['label'], case['mode'], background, case['selections'])
            assert actual == case, (case['label'], [k for k in case if actual[k] != case[k]])
        assert vm.cleanup() == parent['cleanup']
        vm.verify_immutable()
        assert vm.blobs == parent['blobs']
        print(f"Historical prelude{suffix}: all {len(parent['cases'])} cases and blobs reproduced exactly", flush=True)
        return
    vm = RandomInitialization(json.loads(raw), None if args.ramp else 0xA5)
    del raw
    staged = vm.bootstrap()
    by_path = {o['path']: o['index'] for o in vm.object_inputs}
    two = [(1, by_path['chars\\naruto.dat'], 0), (11, by_path['chars\\sasuke.dat'], 0)]+[(0, 0, 0)]*6
    seeds = [None, 0, None, 1, None, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF, 0xFFFFFFFE,
             0xFFFF0000, 0x0000FFFF, 0x12345678, 0x87654321, 0x55555555, 0xAAAAAAAA,
             0, 1, 2, 32767, 32768, 65536, 214013, 2531011, None, None]
    cases = []
    for index, milliseconds in enumerate(seeds):
        vm.milliseconds = milliseconds
        vm.draws = [0, 0, 9, 0, 4096, 1, 2, 255][index % 8]
        vm.stage = (index % 6)*10
        label = f'{index}-'+('continue-crt-state' if milliseconds is None else f'timer-{milliseconds}')
        cases.append(vm.scenario(label, 0 if index < 5 else index % 2, index % 17, two,
                                  random_index=2999 if index == 24 else None,
                                  random_counter=1233 if index == 24 else None))
    cleanup = vm.cleanup()
    vm.verify_immutable()
    scope = ('Real _initptd/srand/rand; bounded startup43cf40..43cf63 and actual menu calls427a2c/427a71 '
             'through422ac0 return; generated table consumed by full catalog/prelude/preparation/recording; '
             'supplied thread/timer/intervening-draw/menu/metadata/device/allocator boundaries, no Windows output')
    doc = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, packageSHA256=PACKAGE_SHA256, policySHA256=POLICY_SHA256,
        scope=scope, loadedCatalog=provenance['corpus'], loadedCatalogSHA256=provenance['corpusSHA256'],
        loadedFixtureSHA256=provenance['fixtureSHA256'], catalogAddress=CATALOG, worldAddress=WORLD,
        actorAddresses=vm.actor_addresses, objects=vm.object_inputs, objectAddresses=vm.object_addresses,
        bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]], surfaceAddress=DEVICE,
        globalAddress=GLOBAL, globalInitial=vm.blob(vm.global_initial), randomSource=vm.random_source,
        crtInitialState=1, replayPointersAddress=POINTERS, replayPointersInitial=vm.pointer_initial.hex(), cleanup=cleanup,
        pattern='ramp' if args.ramp else 'a5', selector=2, staged=staged, cases=cases,
        assets=list(vm.asset_inputs.values()), readsBeforeWrites=sorted(vm.reads_before_writes), blobs=vm.blobs)
    suffix = '-ramp' if args.ramp else ''
    path = ROOT/f'build/original/random-initialization{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':'))+'\n')
    summaries = []
    for case in cases:
        rng = case['randomInitialization']
        summaries.append(dict(label=case['label'], **{k: v for k, v in rng.items() if k not in ('tableCalls', 'intervening', 'writes')},
            tableCalls=len(rng['tableCalls']), tableCallsSHA256=digest(json.dumps(rng['tableCalls'], sort_keys=True, separators=(',', ':')).encode()),
            interveningSHA256=digest(json.dumps(rng['intervening'], sort_keys=True, separators=(',', ':')).encode()),
            writeCount=len(rng['writes']), writeInventorySHA256=digest(json.dumps(rng['writes'], sort_keys=True, separators=(',', ':')).encode())))
    report = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, packageSHA256=PACKAGE_SHA256, policySHA256=POLICY_SHA256,
        scope=scope, corpus=path.name, corpusSHA256=digest(path.read_bytes()), nativeComparison='pending',
        loadedCatalogSHA256=provenance['corpusSHA256'], readsBeforeWrites=[], immutableCatalogObjectHeapBytesVerified=True,
        crtPTDBytesCheckedPerCall=512, crtInitialState=1, cases=len(cases), replayBytes=len(cases)*SIZE,
        tableCalls=len(cases)*3000, interveningCalls=sum(c['randomInitialization']['interveningDrawCount'] for c in cases),
        seedCalls=sum(c['randomInitialization']['milliseconds'] is not None for c in cases), casesSummary=summaries)
    (ROOT/f'docs/evidence/random-initialization{suffix}.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Captured {len(cases)} CRT-generated match/recording chains: {path}', flush=True)


if __name__ == '__main__':
    main()
