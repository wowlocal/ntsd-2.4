#!/usr/bin/env python3
"""Verify complete result-layout fixture transports, immutable pins and vendor bytes."""
import argparse
import base64
import json
import zlib
from verify_result_tail_artifacts import ROOT, FIXTURES, digest


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--controlled-only',action='store_true');args=parser.parse_args()
    names=['result-layout'] if args.controlled_only else ['result-layout','gameplay-result-layout','gameplay-result-layout-control']
    old=json.loads((ROOT/'build/research/queued-sound-fixture-pins.json').read_bytes())
    current=json.loads((ROOT/'build/research'/('result-layout-fixture-pins.json' if args.controlled_only else 'gameplay-result-layout-fixture-pins.json')).read_bytes())
    actual={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    assert len(old)==182 and len(current)==182+len(names)
    assert all(actual[k]==v for k,v in current.items()) and all(actual[k]==v for k,v in old.items())
    checks=[]
    for name in names:
        raw=(ROOT/'build/original'/f'{name}.json').read_bytes();source=json.loads(raw)
        report=json.loads((ROOT/'docs/evidence'/f'{name}.json').read_bytes());assert report['nativeCompared'] and not report['windowsVerified']
        packed=(FIXTURES/report['fixture']).read_bytes();wrapper=json.loads(packed)
        restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==source
        assert wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
        assert report['sha256']==digest(raw) and report['bytes']==len(raw)
        assert report['fixtureBytes']==len(packed) and report['fixtureSHA256']==digest(packed)==actual[report['fixture']]
        for key,blob in source['blobs'].items():
            value=zlib.decompress(base64.b64decode(blob['deflate']),15 if source.get('blobEncoding')=='zlib' else -15)
            assert len(value)==blob['count'] and digest(value)==key
        checks.append(dict(name=name,rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),
            fullRawBytesEqual=True,completeJSONEqual=True,blobs=len(source['blobs']),everyBlobLengthAndSHAVerified=True))
        print('VERIFIED',name,len(raw),'raw',len(packed),'packed',len(source['blobs']),'blobs',flush=True)
    vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
    assert len(upstream['files'])==10
    for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
    report=dict(acceptedOldPinsUnchanged=len(old),currentMilestonePins=len(current),actualPins=len(actual),vendorHashesVerified=10,
        completeArtifactChecks=checks,windowsVerified=False)
    path=ROOT/'build/research'/('result-layout-controlled-artifact-verification.json' if args.controlled_only else 'result-layout-artifact-verification.json')
    path.write_text(json.dumps(report,indent=2)+'\n')
    print('All182 old and',len(current),'milestone pins verified;10 vendor hashes unchanged',flush=True)


if __name__=='__main__':main()
