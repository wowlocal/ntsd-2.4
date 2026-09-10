#!/usr/bin/env python3
"""Check full raw/packed library-hit evidence, all blobs, prior pins and vendor.

Read-only research transport validation, separate from native game algorithms
and Windows behavior. The paired164-call artifact is source-only evidence.
"""
import base64,hashlib,json,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((ROOT/'build/research/lib-world-hits-prior-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research/lib-world-hits-fixture-pins.json').read_bytes());actual={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    assert all(current[n]==h for n,h in prior.items()) and all(actual[n]==h for n,h in current.items())
    results=[]
    for name in ('lib-world-hits','lib-hits-pristine-changes'):
        r=json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes());raw=(ROOT/'build/original'/(name+'.json')).read_bytes()
        packed=(fixtures/r['fixture']).read_bytes();w=json.loads(packed);restored=zlib.decompress(base64.b64decode(w['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw)
        assert len(restored)==w['count'] and digest(restored)==w['sha256']
        assert len(raw)==r['bytes'] and digest(raw)==r['sha256'] and len(packed)==r['fixtureBytes'] and digest(packed)==r['fixtureSHA256']
        assert r['nativeCompared']==(name=='lib-world-hits') and not r['windowsVerified']
        doc=json.loads(raw)
        for key,b in doc['blobs'].items():
            data=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(data)==b['count'] and digest(data)==key
        results.append(dict(name=name,rawBytes=len(raw),rawSHA256=digest(raw),packedBytes=len(packed),packedSHA256=digest(packed),blobs=len(doc['blobs']),fullBytesAndJSONEqual=True))
    vendor=ROOT/'native/Sources/NTSDReplayCodec';pins=json.loads((vendor/'upstream.json').read_bytes())['files'];assert len(pins)==10
    for n,p in pins.items():assert digest((vendor/'vendor'/n).read_bytes())==p['vendoredSHA256']
    result=dict(priorPinsUnchanged=len(prior),publishedPins=len(current),actualPins=len(actual),artifacts=results,vendorHashesVerified=10,windowsVerified=False)
    (ROOT/'build/research/lib-world-hits-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
