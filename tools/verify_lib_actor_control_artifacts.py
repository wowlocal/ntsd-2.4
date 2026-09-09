#!/usr/bin/env python3
"""Verify complete immutable raw/packed library-control evidence and prior pins.

This validates research transport bytes, not the game's replay compressor or
Windows behavior. No reference game file or expected state is rewritten.
"""
import base64
import hashlib
import json
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
digest = lambda value: hashlib.sha256(value).hexdigest()


def main():
    fixtures = ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    prior = json.loads((ROOT/'build/research/lib-actor-control-prior-pins.json').read_bytes())
    current = json.loads((ROOT/'build/research/lib-actor-control-fixture-pins.json').read_bytes())
    old = json.loads((ROOT/'build/research/lib-runtime-fixture-pins.json').read_bytes())
    actual = {p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    assert len(old) == 200 and all(prior[k] == v for k,v in old.items())
    assert all(current[k] == v for k,v in prior.items())
    assert all(actual[k] == v for k,v in current.items())
    raw = (ROOT/'build/original/lib-actor-control.json').read_bytes()
    report = json.loads((ROOT/'docs/evidence/lib-actor-control.json').read_bytes())
    packed = (fixtures/report['fixture']).read_bytes();wrapper = json.loads(packed)
    restored = zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
    assert restored+b'\n' == raw and json.loads(restored) == json.loads(raw)
    assert len(restored) == wrapper['count'] and digest(restored) == wrapper['sha256']
    assert len(raw) == report['bytes'] and digest(raw) == report['sha256']
    assert len(packed) == report['fixtureBytes'] and digest(packed) == report['fixtureSHA256']
    assert report['nativeCompared'] and report['bundledLibInstalled'] and not report['windowsVerified']
    vendor = ROOT/'native/Sources/NTSDReplayCodec'
    pins = json.loads((vendor/'upstream.json').read_bytes())['files'];assert len(pins) == 10
    for name,item in pins.items():assert digest((vendor/'vendor'/name).read_bytes()) == item['vendoredSHA256']
    result = dict(priorFixturePinsUnchanged=len(prior),publishedPins=len(current),actualPins=len(actual),
        fullRawBytesEqual=True,completeJSONEqual=True,rawBytes=len(raw),rawSHA256=digest(raw),
        packedBytes=len(packed),packedSHA256=digest(packed),vendorHashesVerified=10,windowsVerified=False)
    (ROOT/'build/research/lib-actor-control-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':main()
