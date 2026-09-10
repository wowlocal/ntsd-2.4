#!/usr/bin/env python3
"""Pack immutable original graph-event evidence after terminal native acceptance.

Require full source reconstruction, own graph producer, aligned local/read/seek
checks and source/export/prior pins. Controlled COM/Win32/stack evidence is not
actual Windows/audio or callback reentrancy. Deflation only transports fixtures.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
h=lambda b:hashlib.sha256(b).hexdigest()

def main():
    b=ROOT/'build/research';wp=b/'graph-events-work.json';w=json.loads(wp.read_bytes());v=json.loads((b/'graph-events-source-verification.json').read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    assert h((ROOT/'tools/oracle_graph_events.py').read_bytes())==w['sourceToolSHA256']
    pins=json.loads((b/'graph-events-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,digest in pins.items():assert h((dest/n).read_bytes())==digest,n
    for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==pins[n],n
    log=(b/'graph-events-native-raw.log').read_text();assert 'Executed 5 tests, with 0 failures' in log and 'GRAPH EVENTS 371 whole callbacks 4 graph initializations 5 own retained calls 2358 requests 1588 ordered stores' in log
    initial=(b/'graph-events-native-initial12.log').read_text();assert 'Executed 12 tests, with 0 failures' in initial
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((b/'graph-events-prior-pins.json').read_bytes())
    for n,digest in prior.items():assert h((fixtures/n).read_bytes())==digest,n
    raw=(ROOT/'build/original/graph-events.json').read_bytes();assert h(raw)==v['rawSHA256']==w['sourceRawSHA256'] and len(raw)==v['rawBytes']==w['sourceBytes']
    assert raw.endswith(b'\n');payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=h(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-graph-events.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,rawSession=30018,rawTests=5,rawTestSeconds=float(re.findall(r'Executed 5 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=h(log.encode()),sourceVerification=v,verifierSHA256=h((ROOT/'tools/verify_graph_events.py').read_bytes()),sourceVerifierExitCode=0)
    r=dict(v);r.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=h(packed),fixtureBytes=len(packed),nativeRawTests=5,nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],initialRaw12=w['initial12'],testExtension=w['testExtension'],nativeAppExercised=False,actualAudibleLoopingCompared=False,fullCRTStartupCompared=False,actualCallbackReentrancyCompared=False,fullWndProcCompared=False,sourceTool='tools/oracle_graph_events.py',nativeImplementation='native/Sources/NTSDCore/OriginalGraphEvents.swift')
    (ROOT/'docs/evidence/graph-events.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:h(p.read_bytes()) for p in fixtures.glob('*.json')};assert set(current)==set(prior)|{fixture.name}
    (b/'graph-events-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');w['publishedFixtures']=len(current);wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=h(raw),packedSHA256=h(packed),prior=len(prior),current=len(current),rawTests=5,rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
