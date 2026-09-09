#!/usr/bin/env python3
"""Accept the paused caller's whole HUD callee, with immutable older fixtures."""
import argparse
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest


def validate():
    report, raw, doc = capture('paused-hud')
    assert doc['calleeOnly'] is True and doc['entry'] == 0x41ae60 and doc['returnPC'] == 0x30000000
    assert doc['callerEDI'] == report['callerEDI'] == 1 and doc['fpcw'] == report['fpcw'] == 0x27f
    assert doc['callerESIEqualsArgument'] is True and report['callerESIEqualsArgument'] is True
    assert len(doc['cases']) == report['cases'] == 1789
    assert len({c['label'] for c in doc['cases']}) == 1789
    assert Counter(c['group'] for c in doc['cases']) == report['groups']
    kinds = Counter(e['kind'] for c in doc['cases'] for e in c['events'])
    assert sum(kinds.values()) == report['events'] == 283090
    assert sum(c['helpers'] for c in doc['cases']) == report['helpers'] == 61173
    assert sum(c['blits'] for c in doc['cases']) == report['blits'] == kinds['blit'] == 40542
    undefined = sum(e['kind'] == 'read' and not e['read']['defined'] for c in doc['cases'] for e in c['events'])
    assert undefined == 70
    _, _, old = capture('world-hud')
    assert len(old['cases']) == 1753
    for case in doc['cases']:
        assert case['endPC'] == 0x30000000 and case['argumentAccesses'] == []
        assert case['blits'] == sum(e['kind'] == 'blit' for e in case['events'])
        assert case['helpers'] == 1 + sum(e['kind'] in ('draw', 'rectangle', 'clip') for e in case['events'])
        # Independently reconstruct the complete declared entry globals. No
        # after-state or source stack value is used to drive native behavior.
        entry = bytearray(0xb440)
        entry[0x44ff90-0x44d000:0x44ff90-0x44d000+3000] = bytes(1+i%255 for i in range(3000))
        entry[0x34:0x38] = b'\1\0\0\0'
        for address, hexadecimal in case['globals']:
            value = bytes.fromhex(hexadecimal); offset = address-0x44d000
            entry[offset:offset+len(value)] = value
        assert digest(entry) == case['globalsSHA256']
    for previous, actual in zip(old['cases'], doc['cases']):
        assert {k:v for k,v in previous.items() if k not in ('endPC','argumentAccesses','globalsSHA256')} == {
            k:v for k,v in actual.items() if k not in ('endPC','argumentAccesses','globalsSHA256')}
    observed = set(doc['instructions'])
    caller = {0x421a15, 0x421a19, 0x421a1a, 0x421a1c, 0x421a22, 0x421a28}
    assert len(observed) == len(doc['instructions']) == report['instructions'] == 477
    assert observed == set(old['instructions']) - caller
    lines = (ROOT/'build/research/compact.asm').read_text().splitlines()
    coverage = {}
    for start, end, count, executed in [(0x41ae60,0x41b12d,223,223), (0x43ef70,0x43f000,57,45),
                                      (0x43f010,0x43f2fe,214,171), (0x43f310,0x43f37a,38,38)]:
        expected = {int(line[:6],16) for line in lines if len(line)>6 and line[6]==' '
                    and all(c in '0123456789abcdef' for c in line[:6]) and start<=int(line[:6],16)<=end}
        actual = {pc for pc in observed if start<=pc<=end}
        assert len(expected)==count and len(actual)==executed and actual<=expected
        coverage[hex(start)] = dict(instructions=count,executed=executed,missing=sorted(expected-actual))
    assert sum(v['executed'] for v in coverage.values()) == 477
    report.update(instructionCoverage=coverage, eventKinds=dict(kinds), undefinedBitmapReadEvents=undefined,
        poolBytesPerCase=0x7d8+400*0x420, globalsBytesPerCase=0xb440,
        retainedHUDCasesReproduced=1753, entryGlobalsUnchanged=True, commandFlagPairs=36,
        hudStackArgumentRead=False, callerResetsFlagsBeforeHUD=False,
        wholePausedCallerCompared=False, initializedOwnPauseCompared=False, pixelsCompared=False)
    return report, raw


def atomic(path, raw):
    temporary = path.with_suffix(path.suffix+'.paused-hud-tmp')
    temporary.write_bytes(raw)
    os.replace(temporary, path)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--verify-only',action='store_true')
    p.add_argument('--scratch-path',default='build/gameplay-body-swift')
    p.add_argument('--package-path',default='native')
    a = p.parse_args()
    report, raw = validate()
    print('PAUSED HUD source validation passed',report['cases'],report['events'],flush=True)
    if a.verify_only:return
    pins = {p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old = json.loads((ROOT/'build/research/gameplay-return-fixture-pins.json').read_bytes())
    assert len(old)==188 and all(pins[n]==sha for n,sha in old.items())
    subprocess.run(['swift','test','--package-path',str(ROOT/a.package_path),'-c','release','--scratch-path',
                    str(ROOT/a.scratch_path),'--filter','OriginalWorldHUDTests|OriginalGameplayBodyTests'],
        env=dict(os.environ,NTSD_PAUSED_HUD_CORPUS=str(ROOT/'build/original/paused-hud.json')),check=True)
    assert all(digest((FIXTURES/name).read_bytes())==sha for name,sha in pins.items())
    payload = raw[:-1]
    compressor = zlib.compressobj(level=9,wbits=-15)
    compressed = compressor.compress(payload)+compressor.flush()
    assert zlib.decompress(compressed,-15)==payload
    packed = (json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),
                         separators=(',',':'))+'\n').encode()
    fixture = FIXTURES/'original-paused-hud.json'
    if fixture.name in pins:assert digest(packed)==pins[fixture.name], 'Never rewrite accepted expectations'
    else:atomic(fixture,packed)
    report.update(nativeCompared=True,windowsVerified=False,fixture=fixture.name,
                  fixtureSHA256=digest(packed),fixtureBytes=len(packed))
    atomic(ROOT/'docs/evidence/paused-hud.json',(json.dumps(report,indent=2)+'\n').encode())
    pins.update({p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')})
    atomic(ROOT/'build/research/paused-hud-fixture-pins.json',(json.dumps(pins,indent=2)+'\n').encode())
    print('PAUSED HUD published',len(pins),'fixture pins',len(packed),'packed bytes',flush=True)


if __name__=='__main__':main()
