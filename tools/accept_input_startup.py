#!/usr/bin/env python3
"""Publish two lossless input-startup fixtures after completed raw comparison.

Keep56 native whole segments/1900 own callbacks separate from four source
returns rejected natively for unknown capabilities. Development evidence only;
no Windows/device/app-runtime completion claim or source result rewriting.
"""
import base64,json,zlib
from import_ntsd import ROOT
from verify_input_startup import audit,H

def once(path,payload):
    if path.exists():assert path.read_bytes()==payload,('Immutable artifact differs',str(path))
    else:path.write_bytes(payload)

def main():
    b=ROOT/'build/research';wp=b/'input-startup-work.json';w=json.loads(wp.read_bytes())
    j=next(j for j in w['nativeJobs'] if j['key']=='input-startup-final-raw-native')
    assert j['status']=='terminal' and j['exitCode']==0 and w['sourceStatus']==w['successSourceStatus']=='terminal'
    assert w['sourceExitCode']==w['successSourceExitCode']==0
    log=(b/'input-startup-final-raw-native.log').read_text()
    assert 'Executed 8 tests, with 0 failures' in log and '56 whole input/sound segments 4 explicit unknown-capability rejections 280 WAV loads 1900 own callbacks 4780 startup events 98 capability checkpoints' in log
    pins=json.loads((b/'input-startup-prior-pins.json').read_bytes());assert len(pins)==226
    publications=[];source_pins={}
    for suffix in ['','-success']:
        source=b/('input-startup'+suffix+'-candidate1.json');report=audit(source);raw=source.read_bytes();assert raw.endswith(b'\n')
        payload=raw[:-1];z=zlib.compressobj(9,zlib.DEFLATED,-15)
        packed=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(z.compress(payload)+z.flush()).decode()),separators=(',',':'))+'\n').encode()
        fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-input-startup'+suffix+'.json');once(fixture,packed)
        report=audit(source,fixture);report.update(nativeCompared=True,nativeRawTests=8,nativeRawTestSeconds=11.332,nativeRawBuildSeconds=51.48,
            packagedNativeCompared=False,sourceUnknownCapsBytesImported=False,nativeFullUnknownBackingMatchClaim=False,
            sourceControlWord=0x37f,nativeProcessFPUClaim=False,ownWindowMessageDeliveryClaim=False)
        evidence=ROOT/'docs/evidence'/('input-startup'+suffix+'.json');once(evidence,(json.dumps(report,indent=2)+'\n').encode())
        pins[fixture.name]=H(packed);source_pins[str(source.relative_to(ROOT))]=H(raw)
        publications.append(dict(source=str(source.relative_to(ROOT)),fixture=str(fixture.relative_to(ROOT)),evidence=str(evidence.relative_to(ROOT)),sourceSHA256=H(raw),fixtureSHA256=H(packed),rawBytes=len(raw),packedBytes=len(packed)))
        print(fixture.name,len(raw),len(packed),flush=True)
    assert len(pins)==228
    once(b/'input-startup-fixture-pins.json',(json.dumps(pins,indent=2)+'\n').encode())
    once(b/'input-startup-source-pins.json',(json.dumps(source_pins,indent=2)+'\n').encode())
    w.update(fixturePublished=True,currentFixtures=228,publications=publications,newFixtureFiles=[p['fixture'] for p in publications],nativeRawCompared=True)
    wp.write_text(json.dumps(w,indent=2)+'\n')
if __name__=='__main__':main()
