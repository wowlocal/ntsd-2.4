#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Controlled original4014e0 comparison of two safe WAV allocation layouts.

Pinned NTSD EXE and155 ordinary WAV inputs from the preserved catalog failure,
Unicorn2.1.4 and retained explicit MMIO/COM/CRT-copy adapters. Execute complete
helper calls with declared standalone stack/return inputs, never resume the
failed catalog or import its private state. Check actual guards, bytes/masks,
events and returns with disjoint versus corrected adjacent buffers. The old
overlapping geometry is not executed. No guards removed, fault continuation,
live-producer edits, Windows/device or whole-catalog match claim. See
build/research/application-catalog-wave-guard-probe-plan.md for finite acceptance.
"""
import argparse
import copy
import json
import os
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from oracle_wave_loader import (
    WaveLoader, FIRST, SECOND, GLOBAL, GLOBAL_SIZE, data_size, digest,
)
from oracle_menu_sound_startup import MenuSoundStartup
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256

FAILURE = ROOT / 'build/research/application-catalog-candidate1-nominal.failure.json'
FAILURE_SHA = '9d2c5f74539a728e2be70165f5dceacd107bec08b5cc193824b2c7f8d77e298b'
GUARDED = ROOT / 'tools/oracle_application_catalog_guarded.py'
GUARDED_SHA = '69b07f75bac554d13874d73767456f298d2940946be2207538da1934b49a9ce4'


class GuardedWave(WaveLoader):
    # Retained allocator/free/copy adapter already accepts explicit addresses.
    crt = MenuSoundStartup.crt

    def __init__(self):
        super().__init__()
        self.next_mapping = 0x80000000
        self.layouts = []

    def storage(self, kind, count):
        # Exact corrected expression, also checked against the pinned producer.
        n = count
        size = (max(n, 1) + 64 + 4095) & ~4095
        base = self.next_mapping
        self.uc.mem_map(base, size)
        self.next_mapping += size
        assert self.next_mapping < 0xc0000000
        self.layouts.append(dict(kind=kind, mapping=base, mappedBytes=size,
                                 address=base+32, count=count))
        assert base+32+count+32 <= base+size
        return base+32

    def region(self, name, address, count):
        # WaveLoader.run's standalone first-buffer token is parameterized here.
        if name == 'first':
            assert address == FIRST
            address = self.p['firstPointer']
        super().region(name, address, count)

    def run_guarded(self, label, path, raw, p):
        self.layouts = []
        self.allocation = self.storage('temporary', data_size(raw))
        p = copy.deepcopy(p)
        p['firstPointer'] = self.storage('first', p['firstCount'])
        if p['secondPointer']:
            p['secondPointer'] = self.storage('second', p['secondCount'])
        result = self.run(label, path, raw, p)
        guards = []
        for name, region in self.regions.items():
            a, count = region['address'], region['count']
            leading = bytes(self.uc.mem_read(a-32, 32))
            trailing = bytes(self.uc.mem_read(a+count, 32))
            assert leading == b'\x96'*32 and trailing == b'\x69'*32
            guards.append(dict(kind=name, address=a, count=count,
                               leading=leading.hex(), trailing=trailing.hex()))
        return result, self.layouts, guards


class ObservedWave(WaveLoader):
    def __init__(self):
        self.pcs = {}
        super().__init__()

    def allowed(self, uc, address, size, data):
        super().allowed(uc, address, size, data)
        if self.running and (0x4014e0 <= address <= 0x40195e or
                             0x4450b2 <= address <= 0x4450ba):
            self.pcs[hex(address)] = bytes(uc.mem_read(address, size)).hex()


class ObservedGuardedWave(GuardedWave, ObservedWave):
    pass


def normalized(case):
    result = copy.deepcopy(case)
    p = result['input']
    for event in result['events']:
        if event['kind'] == 'unlock':
            a = event['arguments']
            assert a == [p['buffer'], p['firstPointer'], p['firstCount'],
                         p['secondPointer'], p['secondCount']]
            a[1] = FIRST
            a[3] = SECOND if p['secondPointer'] else 0
    p['firstPointer'] = FIRST
    p['secondPointer'] = SECOND if p['secondPointer'] else 0
    return result


def atomic(path, raw):
    assert not path.exists()
    temp = path.with_suffix(path.suffix+'.tmp')
    with temp.open('xb') as f:
        f.write(raw)
    os.replace(temp, path)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    assert not args.output.exists()
    start = time.monotonic()
    raw_failure = FAILURE.read_bytes()
    assert digest(raw_failure) == FAILURE_SHA
    failure = json.loads(raw_failure)
    guarded_bytes = GUARDED.read_bytes()
    assert digest(guarded_bytes) == GUARDED_SHA
    assert 'size=(max(n,1)+64+4095)&~4095;' in guarded_bytes.decode()
    pin_paths = {Path(__file__).resolve(), GUARDED, FAILURE}
    pin_paths.update(Path(m.__file__).resolve() for m in list(sys.modules.values())
                     if getattr(m, '__file__', None) and
                     Path(m.__file__).resolve().is_relative_to(ROOT/'tools'))
    pins = {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in pin_paths}
    inputs = failure['registeredWaves']+[failure['pendingWave']]
    assert len(inputs) == 155
    baseline, guarded = ObservedWave(), ObservedGuardedWave()
    cases, comparisons, layouts, guards = [], [], [], []
    for index, item in enumerate(inputs):
        path = bytes(item['path'])
        file_path = DEFAULT_SOURCE/path.decode('latin1').replace('\\', '/')
        assert file_path.resolve().is_relative_to(DEFAULT_SOURCE.resolve())
        raw = file_path.read_bytes()
        assert digest(raw) == item['file']
        p = copy.deepcopy(item['input'])
        p['firstPointer'] = FIRST
        p['secondPointer'] = SECOND if p['secondPointer'] else 0
        label = f'guarded-catalog-input-{index:03d}-'+path.decode('latin1')
        a = baseline.run(label, path, raw, p)
        b, layout, observed_guards = guarded.run_guarded(label, path, raw, p)
        assert normalized(a) == normalized(b), (index, 'whole controlled result')
        assert baseline.pcs == guarded.pcs
        if index < 154:
            for key in ['temporary', 'first', 'second']:
                assert b[key] == item[key], (index, key, 'prior completed PCM/mask')
            assert b['temporaryLive'] == item['temporaryLive']
        cases.append(b)
        comparisons.append(dict(index=index, path=path.decode('latin1'),
                                fileSHA256=item['file'], dataCount=data_size(raw),
                                completeControlledPair=True, priorOwnPCMCompared=index<154))
        layouts.append(layout)
        guards.append(observed_guards)
        print(index+1, label, 'returned with intact guards', flush=True)
    for relative, sha in pins.items():
        assert digest((ROOT/relative).read_bytes()) == sha, relative
    result = dict(scope=__doc__, createdUTC=datetime.now(timezone.utc).isoformat(),
                  producerSHA256=digest(Path(__file__).read_bytes()), pins=pins,
                  exeSHA256=EXE_SHA256, cases=cases, blobs=guarded.blobs,
                  comparisons=comparisons, layouts=layouts, observedGuards=guards,
                  instructions=guarded.pcs, controlledPairs=155,
                  priorCompletedOwnPCMComparisons=154,
                  nativeCompared=False, elapsedSeconds=time.monotonic()-start)
    payload = (json.dumps(result, separators=(',', ':'))+'\n').encode()
    atomic(args.output, payload)
    print('completed', len(cases), len(payload), digest(payload), flush=True)


if __name__ == '__main__':
    main()
