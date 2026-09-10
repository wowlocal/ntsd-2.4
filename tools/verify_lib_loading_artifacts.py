#!/usr/bin/env python3
"""Read-only raw/packed loading transport, blob, old-fixture and vendor checks.

Preserve complete original bytes including newline and masks. Compression here
only packages research evidence; it is not the game's replay codec or Windows
execution. Source-only observations remain separate from native comparisons.
"""
import base64,hashlib,json,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    bp=ROOT/'build/research';fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    prior=json.loads((bp/'lib-loading-prior-pins.json').read_bytes());current=json.loads((bp/'lib-loading-fixture-pins.json').read_bytes())
    actual={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    assert all(current[n]==h for n,h in prior.items()) and all(actual[n]==h for n,h in current.items())
    r=json.loads((ROOT/'docs/evidence/lib-loading.json').read_bytes());raw=(ROOT/'build/original/lib-loading.json').read_bytes()
    packed=(fixtures/r['fixture']).read_bytes();w=json.loads(packed);restored=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw)
    assert len(restored)==w['count'] and digest(restored)==w['sha256']
    assert len(raw)==r['bytes'] and digest(raw)==r['sha256'] and len(packed)==r['fixtureBytes'] and digest(packed)==r['fixtureSHA256']
    assert r['nativeCompared'] and not r['windowsVerified'];doc=json.loads(raw)
    for h,b in doc['blobs'].items():
        data=zlib.decompress(base64.b64decode(b['deflate']));assert len(data)==b['count'] and digest(data)==h
    vendor=ROOT/'native/Sources/NTSDReplayCodec';pins=json.loads((vendor/'upstream.json').read_bytes())['files'];assert len(pins)==10
    for n,p in pins.items():assert digest((vendor/'vendor'/n).read_bytes())==p['vendoredSHA256']
    result=dict(priorPinsUnchanged=len(prior),publishedPins=len(current),actualPins=len(actual),rawBytes=len(raw),rawSHA256=digest(raw),packedBytes=len(packed),packedSHA256=digest(packed),fullBytesAndJSONEqual=True,blobs=len(doc['blobs']),vendorHashesVerified=10,windowsVerified=False)
    (bp/'lib-loading-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
