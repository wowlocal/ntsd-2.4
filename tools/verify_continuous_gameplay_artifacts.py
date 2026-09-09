#!/usr/bin/env python3
"""Independently verify complete successive-call raw/packed bytes and pins.

Fixture transport is research packaging, not the game's replay compressor.
This checks immutable evidence; it does not run Windows or a device.
"""
import base64
import hashlib
import json
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FIXTURES=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
def digest(value):return hashlib.sha256(value).hexdigest()


def main():
    old=json.loads((ROOT/'build/research/gameplay-return-fixture-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research/continuous-gameplay-fixture-pins.json').read_bytes())
    actual={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    assert len(old)==188 and all(current[k]==v and actual[k]==v for k,v in old.items())
    assert all(actual[k]==v for k,v in current.items())
    checks=[]
    for suffix in ('','-control'):
        name='continuous-gameplay'+suffix
        raw=(ROOT/'build/original'/f'{name}.json').read_bytes();source=json.loads(raw)
        report=json.loads((ROOT/'docs/evidence'/f'{name}.json').read_bytes())
        assert report['nativeCompared'] and not report['windowsVerified']
        packed=(FIXTURES/report['fixture']).read_bytes();wrapper=json.loads(packed)
        restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==source
        assert wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
        assert report['sha256']==digest(raw) and report['bytes']==len(raw)
        assert report['fixtureBytes']==len(packed) and report['fixtureSHA256']==digest(packed)==actual[report['fixture']]
        for key,b in source['blobs'].items():
            value=zlib.decompress(base64.b64decode(b['deflate']),-15)
            assert len(value)==b['count'] and digest(value)==key
        for key,value in source['components'].items():
            canonical=json.dumps(value,separators=(',',':'),sort_keys=True).encode()
            assert digest(canonical)==key
        checks.append(dict(name=name,rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),
            fullRawBytesEqual=True,completeJSONEqual=True,blobs=len(source['blobs']),components=len(source['components']),everyBlobLengthAndSHAVerified=True,everyComponentHashVerified=True))
        print('VERIFIED',name,len(raw),'raw',len(packed),'packed',len(source['blobs']),'blobs',flush=True)
    vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
    assert len(upstream['files'])==10
    for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
    result=dict(acceptedOldPinsUnchanged=len(old),currentMilestonePins=len(current),actualPins=len(actual),vendorHashesVerified=10,
        completeArtifactChecks=checks,windowsVerified=False)
    (ROOT/'build/research/continuous-gameplay-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
