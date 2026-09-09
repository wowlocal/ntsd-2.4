#!/usr/bin/env python3
"""Independently check complete paused-HUD packaging and unchanged prior pins.

Raw deflate here is fixture transport, unrelated to game replay compression.
No game execution, Windows or device comparison is performed by this tool.
"""
import base64
import hashlib
import json
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT/'native/Tests/NTSDCoreTests/Fixtures'
def digest(value):return hashlib.sha256(value).hexdigest()


def main():
    old = json.loads((ROOT/'build/research/gameplay-return-fixture-pins.json').read_bytes())
    current = json.loads((ROOT/'build/research/paused-hud-fixture-pins.json').read_bytes())
    actual = {p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    assert len(old)==188 and all(current[k]==v and actual[k]==v for k,v in old.items())
    preceding = json.loads((ROOT/'build/research/continuous-gameplay-fixture-pins.json').read_bytes())
    assert len(preceding)==190 and all(current[k]==v and actual[k]==v for k,v in preceding.items())
    assert all(actual[k]==v for k,v in current.items())
    raw = (ROOT/'build/original/paused-hud.json').read_bytes()
    report = json.loads((ROOT/'docs/evidence/paused-hud.json').read_bytes())
    assert report['nativeCompared'] is True and report['windowsVerified'] is False
    packed = (FIXTURES/report['fixture']).read_bytes(); wrapper = json.loads(packed)
    restored = zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
    assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw)
    assert wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
    assert report['sha256']==digest(raw) and report['bytes']==len(raw)
    assert report['fixtureBytes']==len(packed) and report['fixtureSHA256']==digest(packed)==actual[report['fixture']]
    vendor = ROOT/'native/Sources/NTSDReplayCodec'
    upstream = json.loads((vendor/'upstream.json').read_bytes())
    assert len(upstream['files'])==10
    for name,pin in upstream['files'].items():
        assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
    result = dict(acceptedOldPinsUnchanged=len(old),precedingMilestonePinsUnchanged=len(preceding),
        currentMilestonePins=len(current),actualPins=len(actual),
        vendorHashesVerified=10,rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),
        fullRawBytesEqual=True,completeJSONEqual=True,windowsVerified=False)
    (ROOT/'build/research/paused-hud-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
