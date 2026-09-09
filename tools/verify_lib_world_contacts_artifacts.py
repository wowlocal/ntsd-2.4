#!/usr/bin/env python3
"""Verify full raw/packed contact evidence, every source blob and retained pins.

Read-only research transport validation. Native game algorithms and original
EXE/DLL/DAT resources are not modified or executed by this verifier.
"""
import base64,hashlib,json,zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    prior=json.loads((ROOT/'build/research/lib-world-contacts-prior-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research/lib-world-contacts-fixture-pins.json').read_bytes())
    actual={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    assert all(current[k]==v for k,v in prior.items()) and all(actual[k]==v for k,v in current.items())
    raw=(ROOT/'build/original/lib-world-contacts.json').read_bytes()
    report=json.loads((ROOT/'docs/evidence/lib-world-contacts.json').read_bytes())
    packed=(fixtures/report['fixture']).read_bytes();w=json.loads(packed)
    restored=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw)
    assert len(restored)==w['count'] and digest(restored)==w['sha256']
    assert len(raw)==report['bytes'] and digest(raw)==report['sha256']
    assert len(packed)==report['fixtureBytes'] and digest(packed)==report['fixtureSHA256']
    assert report['nativeCompared'] and report['bundledLibInstalled'] and not report['windowsVerified']
    doc=json.loads(raw)
    for key,value in doc['blobs'].items():
        b=zlib.decompress(base64.b64decode(value['deflate']),-15)
        assert digest(b)==key and len(b)==value['count']
    vendor=ROOT/'native/Sources/NTSDReplayCodec';pins=json.loads((vendor/'upstream.json').read_bytes())['files'];assert len(pins)==10
    for name,item in pins.items():assert digest((vendor/'vendor'/name).read_bytes())==item['vendoredSHA256']
    result=dict(priorFixturePinsUnchanged=len(prior),publishedPins=len(current),actualPins=len(actual),
        fullRawBytesEqual=True,completeJSONEqual=True,rawBytes=len(raw),rawSHA256=digest(raw),
        packedBytes=len(packed),packedSHA256=digest(packed),blobsVerified=len(doc['blobs']),vendorHashesVerified=10,windowsVerified=False)
    (ROOT/'build/research/lib-world-contacts-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
