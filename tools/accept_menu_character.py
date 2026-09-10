#!/usr/bin/env python3
"""Publish immutable NTSD menu-character evidence after native acceptance.

Only controlled source/key-state adapter results are packed; no actual keyboard,
network or Windows claim. Require terminal jobs, original/source/export
pins and independent full storage/read/request verification before preparing the
packaged-test export. Deflation transports fixtures only.
"""
import base64,hashlib,json,re,shutil,subprocess,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
h=lambda b:hashlib.sha256(b).hexdigest()

def main():
    b=ROOT/'build/research';wp=b/'menu-character-work.json';w=json.loads(wp.read_bytes());v=json.loads((b/'menu-character-source-verification.json').read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    for key in ('sourcePID','rawPID'):assert subprocess.run(['ps','-p',str(w[key])],capture_output=True).returncode==1,key
    assert h((ROOT/'tools/oracle_menu_character.py').read_bytes())==w['sourceToolSHA256']
    pins=json.loads((b/'menu-character-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,digest in pins.items():assert h((dest/n).read_bytes())==digest,n
    for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==pins[n],n
    log=(b/'menu-character-native-raw.log').read_text();assert 'Executed 17 tests, with 0 failures' in log and 'MENU CHARACTER 10492 whole calls 2890 keyboard requests 11048 Shift reads' in log
    assert 'NETWORK PEERS 2 original/native calls 4 own packet deliveries 3169 bytes' in log
    assert v['wholeCalls']==10492 and v['declaredBeforeReconstructed'] and v['fullSourceEAXVerified'] and v['nativeALOnly']
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((b/'menu-character-prior-pins.json').read_bytes())
    for n,digest in prior.items():assert h((fixtures/n).read_bytes())==digest,n
    raw=(ROOT/'build/original/menu-character.json').read_bytes();assert h(raw)==v['rawSHA256']==w['sourceRawSHA256'] and len(raw)==v['rawBytes']==w['sourceBytes']
    assert raw.endswith(b'\n');payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=h(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-menu-character.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    # Prepare the dependent export only after terminal acceptance. The next test
    # cannot be launched against a missing fixture by this publication sequence.
    name=str(fixture.relative_to(ROOT));target=dest/name;assert not target.is_symlink()
    if target.exists():assert target.read_bytes()==packed
    else:shutil.copyfile(fixture,target)
    pins[name]=h(packed);assert len(pins)==561
    (b/'menu-character-final-export-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    w.update(status='raw-accepted-packaged-ready',nativeCompared=True,rawSession=66987,rawTests=17,rawTestSeconds=float(re.findall(r'Executed 17 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=h(log.encode()),sourceVerification=v,verifierSHA256=h((ROOT/'tools/verify_menu_character.py').read_bytes()),sourceVerifierExitCode=0,isolatedFinalFiles=561,packagedStatus='ready')
    r=dict(v);r.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=h(packed),fixtureBytes=len(packed),nativeRawTests=17,nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],nativeAppExercised=False,actualNetworkSessionCompared=False,fullCRTStartupCompared=False,actualCallbackReentrancyCompared=False,fullMenuReturnCompared=False,nativeALOnly=True,interveningClientUIExecuted=False,sourceTool='tools/oracle_menu_character.py',nativeImplementation='native/Sources/NTSDCore/OriginalMenuCharacter.swift')
    (ROOT/'docs/evidence/menu-character.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:h(p.read_bytes()) for p in fixtures.glob('*.json')};assert set(current)==set(prior)|{fixture.name}
    (b/'menu-character-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');w['publishedFixtures']=len(current);wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=h(raw),packedSHA256=h(packed),prior=len(prior),current=len(current),rawTests=17,rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
