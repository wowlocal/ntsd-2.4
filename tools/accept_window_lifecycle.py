#!/usr/bin/env python3
"""Pack immutable original window-lifecycle evidence after native acceptance.

Require terminal source/raw jobs, exact source/export/prior-fixture pins and
full independent reconstruction. Preserve controlled API/backing boundaries;
no actual Windows, reentrancy, native-device or full-app claim is introduced.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
h=lambda b:hashlib.sha256(b).hexdigest()

def main():
    b=ROOT/'build/research';wp=b/'window-lifecycle-work.json';w=json.loads(wp.read_bytes());v=json.loads((b/'window-lifecycle-source-verification.json').read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    assert h((ROOT/'tools/oracle_window_lifecycle.py').read_bytes())==w['sourceToolSHA256']
    pins=json.loads((b/'window-lifecycle-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,digest in pins.items():assert h((dest/n).read_bytes())==digest,n
    for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==pins[n],n
    log=(b/'window-lifecycle-native-raw.log').read_text();assert 'Executed 9 tests, with 0 failures' in log and 'WINDOW LIFECYCLE 318 whole callbacks 2 initializations 18 own retained calls 3624 requests 1757 ordered stores' in log
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((b/'window-lifecycle-prior-pins.json').read_bytes())
    for n,digest in prior.items():assert h((fixtures/n).read_bytes())==digest,n
    raw=(ROOT/'build/original/window-lifecycle.json').read_bytes();assert h(raw)==v['rawSHA256']==w['sourceRawSHA256'] and len(raw)==v['rawBytes']==w['sourceBytes']
    assert raw.endswith(b'\n');payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=h(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-window-lifecycle.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,rawSession=66332,rawTests=9,rawTestSeconds=float(re.findall(r'Executed 9 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=h(log.encode()),sourceVerification=v,verifierSHA256=h((ROOT/'tools/verify_window_lifecycle.py').read_bytes()),sourceVerifierExitCode=0)
    r=dict(v);r.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=h(packed),fixtureBytes=len(packed),nativeRawTests=9,nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],nativeAppExercised=False,fullCRTStartupCompared=False,actualCallbackReentrancyCompared=False,fullWndProcCompared=False,sourceTool='tools/oracle_window_lifecycle.py',nativeImplementation='native/Sources/NTSDCore/OriginalWindowLifecycle.swift')
    (ROOT/'docs/evidence/window-lifecycle.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:h(p.read_bytes()) for p in fixtures.glob('*.json')};assert set(current)==set(prior)|{fixture.name}
    (b/'window-lifecycle-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');w['publishedFixtures']=len(current);wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=h(raw),packedSHA256=h(packed),prior=len(prior),current=len(current),rawTests=9,rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
