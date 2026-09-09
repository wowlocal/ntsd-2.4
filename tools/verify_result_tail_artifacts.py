#!/usr/bin/env python3
"""Independently verify complete published result/tail fixture transports and pins.

Transport deflation packages research bytes; it is separate from the native
1.1.4 game replay compressor. This does not execute Windows or an audio device.
"""
import base64
import hashlib
import json
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FIXTURES=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
NAMES=('result-recording','gameplay-result-recording','gameplay-result-recording-control',
       'bitmap-font','mode-label','playback-information','queued-sound')


def digest(value):return hashlib.sha256(value).hexdigest()


def main():
    old=json.loads((ROOT/'build/research/replay-writer-fixture-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research/queued-sound-fixture-pins.json').read_bytes())
    actual={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    assert len(old)==175 and len(current)==182 and current==actual
    assert all(actual[name]==sha for name,sha in old.items())
    checks=[]
    for name in NAMES:
        raw=(ROOT/'build/original'/f'{name}.json').read_bytes();source=json.loads(raw)
        report=json.loads((ROOT/'docs/evidence'/f'{name}.json').read_bytes());assert report['nativeCompared'] and not report['windowsVerified']
        packed=(FIXTURES/report['fixture']).read_bytes();wrapper=json.loads(packed)
        restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert raw.endswith(b'\n') and restored+b'\n'==raw and json.loads(restored)==source
        assert wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
        assert report['sha256']==digest(raw) and report['bytes']==len(raw)
        assert report['fixtureBytes']==len(packed) and report['fixtureSHA256']==digest(packed)==actual[report['fixture']]
        encoding=source.get('blobEncoding');assert encoding in (None,'zlib')
        assert (encoding is None)==name.startswith('gameplay-')
        for key,blob in source['blobs'].items():
            data=zlib.decompress(base64.b64decode(blob['deflate']),15 if encoding=='zlib' else -15)
            assert len(data)==blob['count'] and digest(data)==key
        checks.append(dict(name=name,rawBytes=len(raw),rawSHA256=digest(raw),packedBytes=len(packed),packedSHA256=digest(packed),
            fullRawBytesEqual=True,completeJSONEqual=True,blobs=len(source['blobs']),everyBlobLengthAndSHAVerified=True))
        print('VERIFIED',name,len(raw),'raw',len(packed),'packed',len(source['blobs']),'blobs',flush=True)
    vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
    assert len(upstream['files'])==10
    for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
    stages={'result-recording':176,'gameplay-result-recording':178,'bitmap-font':179,'mode-label':180,'playback-information':181,'queued-sound':182}
    for name,count in stages.items():
        pins=json.loads((ROOT/'build/research'/f'{name}-fixture-pins.json').read_bytes())
        assert len(pins)==count and all(actual[key]==sha for key,sha in pins.items())
    report=dict(acceptedOldPinsUnchanged=len(old),currentPins=len(current),vendorHashesVerified=10,
        fullRawPackedArtifactChecks=checks,allSourceAndNativeComparisonsRequiredSeparately=True,windowsVerified=False)
    (ROOT/'build/research/result-tail-artifact-verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print('All175 old fixtures and10 vendor hashes unchanged;182 current pins verified',flush=True)


if __name__=='__main__':main()
