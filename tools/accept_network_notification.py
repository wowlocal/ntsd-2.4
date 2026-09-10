#!/usr/bin/env python3
"""Publish immutable NTSD network-notification evidence after native acceptance.

Only controlled source/socket-adapter results are packed; no actual network,
Windows or peer-session claim. Require terminal jobs, original/source/export
pins and independent full storage/packet verification before preparing the
packaged-test export. Deflation transports fixtures only.
"""
import base64,hashlib,json,re,shutil,subprocess,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
h=lambda b:hashlib.sha256(b).hexdigest()

def main():
    b=ROOT/'build/research';wp=b/'network-notification-work.json';w=json.loads(wp.read_bytes());v=json.loads((b/'network-notification-source-verification.json').read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    for key in ('sourcePID','rawPID'):assert subprocess.run(['ps','-p',str(w[key])],capture_output=True).returncode==1,key
    assert h((ROOT/'tools/oracle_network_notification.py').read_bytes())==w['sourceToolSHA256']
    pins=json.loads((b/'network-notification-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,digest in pins.items():assert h((dest/n).read_bytes())==digest,n
    for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==pins[n],n
    log=(b/'network-notification-native-raw.log').read_text();assert 'Executed 10 tests, with 0 failures' in log and 'NETWORK NOTIFICATION 415 whole callbacks 4 retained calls 3692 requests 33377 ordered semantic stores' in log
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((b/'network-notification-prior-pins.json').read_bytes())
    for n,digest in prior.items():assert h((fixtures/n).read_bytes())==digest,n
    raw=(ROOT/'build/original/network-notification.json').read_bytes();assert h(raw)==v['rawSHA256']==w['sourceRawSHA256'] and len(raw)==v['rawBytes']==w['sourceBytes']
    assert raw.endswith(b'\n');payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=h(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-network-notification.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    # Prepare the dependent export only after terminal acceptance. The next test
    # cannot be launched against a missing fixture by this publication sequence.
    name=str(fixture.relative_to(ROOT));target=dest/name;assert not target.is_symlink()
    if target.exists():assert target.read_bytes()==packed
    else:shutil.copyfile(fixture,target)
    pins[name]=h(packed);assert len(pins)==552
    (b/'network-notification-final-export-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
    w.update(status='raw-accepted-packaged-ready',nativeCompared=True,rawSession=1393,rawTests=10,rawTestSeconds=float(re.findall(r'Executed 10 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=h(log.encode()),sourceVerification=v,verifierSHA256=h((ROOT/'tools/verify_network_notification.py').read_bytes()),sourceVerifierExitCode=0,isolatedFinalFiles=552,packagedStatus='ready')
    r=dict(v);r.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=h(packed),fixtureBytes=len(packed),nativeRawTests=10,nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],nativeAppExercised=False,actualNetworkSessionCompared=False,fullCRTStartupCompared=False,actualCallbackReentrancyCompared=False,fullWndProcCompared=False,sourceTool='tools/oracle_network_notification.py',nativeImplementation='native/Sources/NTSDCore/OriginalNetworkNotification.swift')
    (ROOT/'docs/evidence/network-notification.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:h(p.read_bytes()) for p in fixtures.glob('*.json')};assert set(current)==set(prior)|{fixture.name}
    (b/'network-notification-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');w['publishedFixtures']=len(current);wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=h(raw),packedSHA256=h(packed),prior=len(prior),current=len(current),rawTests=10,rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
