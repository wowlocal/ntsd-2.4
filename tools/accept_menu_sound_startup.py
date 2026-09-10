#!/usr/bin/env python3
"""Publish the immutable menu sound fixture only after raw native acceptance.

112 whole segment matches and10 stopped CreateSoundBuffer rejections are distinct.
This packages development evidence; it does not publish a game or claim devices.
"""
import base64,json,zlib
from import_ntsd import ROOT
from verify_menu_sound_startup import audit,H

def write_once(path,data):
    if path.exists():assert path.read_bytes()==data,('Immutable publication differs',str(path))
    else:path.write_bytes(data)

def main():
    b=ROOT/'build/research';wp=b/'menu-sound-startup-work.json';w=json.loads(wp.read_bytes())
    job=next(j for j in w['nativeJobs'] if j['key']=='menu-sound-startup-raw-native2')
    assert job['status']=='terminal' and job['exitCode']==0 and w['sourceStatus']=='terminal' and w['sourceExitCode']==0
    log=(b/'menu-sound-startup-raw-native2.log').read_text()
    assert 'Executed 5 tests, with 0 failures' in log
    assert '112 whole segments 10 explicit rejected create continuations 590 loads 8542 events 533552320 bytes 20 retained temporaries' in log
    source=b/'menu-sound-startup-candidate1.json';report=audit(source);raw=source.read_bytes();assert raw.endswith(b'\n')
    payload=raw[:-1];z=zlib.compressobj(9,zlib.DEFLATED,-15)
    transport=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(z.compress(payload)+z.flush()).decode()),separators=(',',':'))+'\n').encode()
    fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-menu-sound-startup.json';write_once(fixture,transport)
    report=audit(source,fixture);report.update(nativeCompared=True,nativeWholeSegmentMatches=112,nativeExplicitRejections=10,
        nativeMatchedWholeSegmentEvents=8066,nativeMatchedWholeSegmentLoads=560,nativePartialContractEvents=476,
        nativeRawTests=5,nativeRawTestSeconds=22.482,nativeRawBuildSeconds=186.04,packagedNativeCompared=False,
        initializedWinMainClaim=False,sourceControlWord=0x37f,nativeProcessFPUClaim=False)
    write_once(ROOT/'docs/evidence/menu-sound-startup.json',(json.dumps(report,indent=2)+'\n').encode())
    pins=json.loads((b/'menu-sound-startup-prior-pins.json').read_bytes());pins[fixture.name]=H(transport);assert len(pins)==226
    write_once(b/'menu-sound-startup-fixture-pins.json',(json.dumps(pins,indent=2)+'\n').encode())
    w.update(fixturePublished=True,currentFixtures=226,newFixtureFiles=[str(fixture.relative_to(ROOT))],nativeRawCompared=True,
        sourceSHA256=H(raw),fixtureSHA256=H(transport),rawBytes=len(raw),packedBytes=len(transport))
    wp.write_text(json.dumps(w,indent=2)+'\n')
    print(fixture.name,len(raw),len(transport),'112 matches / 10 explicit rejections')
if __name__=='__main__':main()
