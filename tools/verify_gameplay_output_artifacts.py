#!/usr/bin/env python3
"""Independently verify immutable raw/packed output corpus and previous pins."""
import base64
import hashlib
import json
import zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FIXTURES=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
def digest(value):return hashlib.sha256(value).hexdigest()

def main():
    report=json.loads((ROOT/'docs/evidence/gameplay-output-controlled.json').read_bytes())
    raw=(ROOT/'build/original'/report['corpus']).read_bytes();packed=(FIXTURES/report['fixture']).read_bytes()
    assert len(raw)==report['bytes'] and digest(raw)==report['sha256'] and raw.endswith(b'\n')
    assert len(packed)==report['fixtureBytes'] and digest(packed)==report['fixtureSHA256']
    envelope=json.loads(packed);payload=zlib.decompress(base64.b64decode(envelope['deflate']),-15)
    assert payload+b'\n'==raw and len(payload)==envelope['count'] and digest(payload)==envelope['sha256']
    doc=json.loads(raw);assert doc==json.loads(payload)
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key
    old=json.loads((ROOT/'build/research/result-layout-fixture-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research/gameplay-output-fixture-pins.json').read_bytes())
    assert len(old)==183 and current[report['fixture']]==report['fixtureSHA256']
    assert all(current[n]==sha and digest((FIXTURES/n).read_bytes())==sha for n,sha in old.items())
    assert all(digest((FIXTURES/n).read_bytes())==sha for n,sha in current.items())
    result=dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),fixtureSHA256=digest(packed),
        blobCount=len(doc['blobs']),caseCount=len(doc['cases']),oldUnchangedPins=len(old),pinsAtPublication=len(current),
        fullRawAndPackedBytesEqual=True,fullJSONEqual=True,allBlobSHA256Verified=True,oldFixturesUnchanged=True)
    (ROOT/'build/research/gameplay-output-artifact-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
