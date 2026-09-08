#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute confirmed-menu prelude, common preparation and recording init.

Original EXE instructions include sound/fill helpers; sprintf executes the pinned
VC80 DLL. Local time, COM resources/results, menu/RNG inputs and replay metadata
remain explicit boundaries. No complete menu, pixels, sound output or Windows run.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib

from import_ntsd import EXE_SHA256, ROOT
from oracle_crt import DLL_SHA256
from oracle_replay_initialization import ReplayInitialization, POINTERS, SIZE
from oracle_match_preparation import digest, WORLD, GLOBAL, GLOBAL_SIZE
from oracle_loaded_catalog import CATALOG
from oracle_objects import DEVICE, STUB
from oracle_state import STACK
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_ESP, UC_X86_REG_ECX

SOUND = 0x25000020
TIME_FIELDS = ('year', 'month', 'dayOfWeek', 'day', 'hour', 'minute', 'second', 'milliseconds')


class MatchPrelude(ReplayInitialization):
    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        self.mode_address = 0x451160  # actual caller 4229d0
        self.uc.mem_map(SOUND & ~4095, 4096)
        self.put(SOUND, SOUND+0x100)
        for offset, stub in [(0x48, 0x360), (0x34, 0x370), (0x30, 0x380)]:
            self.put(SOUND+0x100+offset, STUB+stub)
        self.put(0x4470A4, STUB+0x350)  # GetLocalTime
        self.uc.hook_add(UC_HOOK_CODE, self.sound_entry, begin=0x401A30, end=0x401A30)

    def allowed_code(self, uc, address, size, data):
        if (0x42CF8A <= address < 0x42D1FF or 0x401A30 <= address <= 0x401A6F
                or 0x415160 <= address <= 0x4151C2):
            return
        super().allowed_code(uc, address, size, data)

    def sound_entry(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        assert self.u32(sp) == 0x42D1FF and uc.reg_read(UC_X86_REG_ECX) == 0x455610
        assert self.u32(sp+4) == 0
        self.prelude_events.append(dict(kind='sound-request', loop=False))

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        caller = self.u32(sp)
        if address == STUB+0x350:
            assert caller == 0x42D05C and self.u32(sp+4) == STACK+0xF814
            self.uc.mem_write(self.u32(sp+4), struct.pack('<8H', *self.local_time.values()))
            self.prelude_events.append(dict(kind='local-time'))
            self.ret(0, 4)
        elif self.lookup.get(address) == 'sprintf':
            fmt = self.cstr(self.u32(sp+8))
            count = 6 if fmt == b'%4d%02d%02d_%02d%02d%02d' else 1
            assert caller in (0x42D0A7, 0x42D0E6, 0x42D1B5)
            args = [self.u32(sp+12+i*4) for i in range(count)]
            if fmt == b'%s.lfr':
                args = [self.cstr(args[0])]
            formatted = self.crt.format(fmt, args)
            raw = bytes.fromhex(formatted['bytes'])
            target = self.u32(sp+4)
            assert target in (STACK+0xF8A0, STACK+0xF828, 0x44FD98)
            self.write_host(target, raw)
            if target == 0x44FD98:
                self.global_access(uc, 0, target, len(raw), 0, 'write')
            self.format_calls.append(dict(caller=hex(caller), format=fmt.decode(),
                                          arguments=[a.hex() if isinstance(a, bytes) else a for a in args], **formatted))
            self.ret(formatted['result'])
        elif address in (STUB+0x360, STUB+0x370, STUB+0x380):
            offset, count, expected_caller = {
                STUB+0x360: (0x48, 1, 0x401A4A), STUB+0x370: (0x34, 2, 0x401A56),
                STUB+0x380: (0x30, 4, 0x401A6E)}[address]
            assert caller == expected_caller and self.u32(sp+4) == SOUND
            args = [self.u32(sp+8+i*4) for i in range(count-1)]
            self.prelude_events.append(dict(kind='sound-method', resource=SOUND, vtableOffset=offset, arguments=args))
            self.ret(self.device_result, count*4)
        elif address == STUB+0x310 and caller == 0x4151BF:
            resource, rect, source, source_rect, flags, effects = [self.u32(sp+4+i*4) for i in range(6)]
            assert resource == DEVICE and source == source_rect == 0 and flags == 0x1000400
            assert self.u32(effects) == 100  # only size/fill color are defined and used
            left, top, right, bottom = struct.unpack('<4i', uc.mem_read(rect, 16))
            self.prelude_events.append(dict(kind='fill-rectangle', resource=resource, x=left, y=top,
                                            width=right-left, height=bottom-top, color=self.u32(effects+0x50)))
            self.ret(self.device_result, 24)
        else:
            super().imported(uc, address, size, data)

    def before_preparation(self, mode):
        index = len(self.replay_regions)
        self.prelude_events, self.format_calls = [], []
        self.local_time = dict(zip(TIME_FIELDS, [
            (2026, 9, 2, 8, 3, 4, 5, 999), (7, 1, 6, 2, 3, 4, 5, 1),
            (0, 0, 65535, 0, 0, 0, 0, 65535), (65535,)*8][index % 4]))
        self.device_result = 0 if index % 2 == 0 else 0x80004005
        word = lambda address, value: self.stimulus(address, struct.pack('<I', value & 0xFFFFFFFF))
        word(self.mode_address, mode)
        word(0x44D020, 9)  # actual second argument 4229d5
        word(0x450B94, self.stage)
        for i, address in enumerate([0x450BB0, 0x450BB4, 0x450B9C, 0x450BA8, 0x450BAC, 0x450BA4,
                                     0x44FB6C, 0x450BA0, 0x44F880, 0x450BC8, 0x450BC4, 0x450B6C, 0x450B70]):
            word(address, 0x81230000+index*256+i)
        word(0x450BE4, -1 if index % 2 else 0)
        word(0x450B98, (1 if index % 2 else -1) if index % 5 == 0 else 0)
        word(0x44EECC, 0 if index % 4 == 0 else -1)
        word(0x455610, SOUND if index % 3 else 0)
        word(0x455608, DEVICE)
        self.stimulus(0x44FD98, b'\xE9'*127+b'\0')
        before = self.snapshot()
        self.put(STACK+0xF040, 0x44D020)
        self.uc.reg_write(UC_X86_REG_EDI, 0)  # established at 42cf67
        self.uc.reg_write(UC_X86_REG_ESI, self.mode_address)
        self.execute(0x42CF8A, 0x42D1FF)
        assert self.uc.reg_read(UC_X86_REG_ESP) == STACK+0xF000
        after = self.snapshot()
        for field in ('world', 'actors', 'backgrounds', 'bitmapCount', 'released', 'random'):
            assert before[field] == after[field], ('Prelude changed source', field)
        return dict(localTime=self.local_time, deviceResult=self.device_result, stage=self.stage,
                    background=self.u32(0x44D024),
                    beforeGlobals=before['globals'], afterGlobals=after['globals'],
                    fileName=self.cstr(0x44FD98).decode('ascii'), events=self.prelude_events, formats=self.format_calls)


def accept():
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    paths, reports = [], []
    for suffix in ('', '-ramp'):
        raw = (ROOT/f'build/original/match-prelude{suffix}.json').read_bytes()
        path = ROOT/f'docs/evidence/match-prelude{suffix}.json'
        report = json.loads(path.read_text())
        assert digest(raw) == report['corpusSHA256']
        doc = json.loads(raw)
        for case in doc['cases']:
            for key in ('globalAccesses', 'replayGlobalAccesses', 'replayWrites'):
                case.pop(key)
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
        output = ROOT/f'build/original/match-prelude{suffix}-check.json'
        output.write_text(json.dumps(packed, separators=(',', ':'))+'\n')
        paths.append(output); reports.append((path, report, suffix))
    result = subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'), '--match-prelude',
                             str(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'), *map(str, paths)],
                            check=True, capture_output=True, text=True)
    print(result.stdout, end='', flush=True)
    for packed, (path, report, suffix) in zip(paths, reports):
        fixture = ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-match-prelude{suffix}.json'
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
    vm = MatchPrelude(capture, None if args.ramp else 0xA5)
    del capture, raw
    staged = vm.bootstrap()
    by_path = {o['path']: o['index'] for o in vm.object_inputs}
    two = [(1, by_path['chars\\naruto.dat'], 0), (11, by_path['chars\\sasuke.dat'], 0)]+[(0, 0, 0)]*6
    plans = [(0, 0), (0, 0)] + [(1, s) for s in (0, 10, 20, 30, 40, 50, -2147483648, -11, -10, -9, -1, 1, 9, 19, 49, 51, 2147483647)]
    plans += [(m, 10) for m in (2, -1, -2147483648, 2147483647, 0, 1)]
    assert len(plans) == 25
    cases = []
    for index, (mode, stage) in enumerate(plans):
        vm.stage = stage
        label = ['naruto-sasuke-district', 'restart-district'][index] if index < 2 else f'mode-{mode}-stage-{stage}'
        cases.append(vm.scenario(label, mode, 0 if index < 2 else index % 17, two))
    cleanup = vm.cleanup()
    vm.verify_immutable()
    scope = 'Full catalog/bootstrap; prelude42cf8a..42d1ff with real VC80 sprintf and sound/fill helpers; common preparation and replay init through42d704; supplied time/menu/RNG/metadata/device/allocator boundaries; no whole startup or Windows output'
    doc = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=scope, loadedCatalog=provenance['corpus'],
               loadedCatalogSHA256=provenance['corpusSHA256'], loadedFixtureSHA256=provenance['fixtureSHA256'],
               catalogAddress=CATALOG, worldAddress=WORLD, actorAddresses=vm.actor_addresses,
               objects=vm.object_inputs, objectAddresses=vm.object_addresses,
               bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]], surfaceAddress=DEVICE,
               globalAddress=GLOBAL, globalInitial=vm.blob(vm.global_initial), randomSource=vm.random_source,
               replayPointersAddress=POINTERS, replayPointersInitial=vm.pointer_initial.hex(), cleanup=cleanup,
               pattern='ramp' if args.ramp else 'a5', selector=2, staged=staged,
               cases=cases, assets=list(vm.asset_inputs.values()), readsBeforeWrites=sorted(vm.reads_before_writes), blobs=vm.blobs)
    suffix = '-ramp' if args.ramp else ''
    output = ROOT/f'build/original/match-prelude{suffix}.json'
    output.write_text(json.dumps(doc, separators=(',', ':'))+'\n')
    summary = dict(exeSHA256=EXE_SHA256, dllSHA256=DLL_SHA256, scope=scope, corpus=output.name,
                   corpusSHA256=digest(output.read_bytes()), cases=len(cases), nativeComparison='pending',
                   loadedCatalogSHA256=provenance['corpusSHA256'], readsBeforeWrites=[],
                   immutableCatalogObjectHeapBytesVerified=True, replayBytes=len(cases)*SIZE,
                   casesSummary=[dict(label=c['label'], mode=c['mode'],
                                      **c['prelude']) for c in cases])
    (ROOT/f'docs/evidence/match-prelude{suffix}.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(f'Captured {len(cases)} prelude/preparation/recording chains: {output}', flush=True)


if __name__ == '__main__':
    main()
