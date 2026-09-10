#!/usr/bin/env python3
"""Pack whole controlled window/display evidence after terminal native acceptance.

Verify complete raw source bytes, independent reconstruction, unchanged native
export and all previous fixtures. Preserve opaque helper-entry backing and the
separate CRT/NLS/Windows boundary. Transport deflation is not game replay code.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    bp=ROOT/'build/research';wp=bp/'window-initialization-work.json';w=json.loads(wp.read_bytes());r=json.loads((bp/'window-initialization.json').read_bytes());v=json.loads((bp/'window-initialization-source-verification.json').read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    for n,h in w['sourceHashes'].items():assert digest((ROOT/'tools'/n).read_bytes())==h,n
    pins=json.loads((bp/'window-initialization-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,h in pins.items():assert digest((dest/n).read_bytes())==h,n
    for n in w['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==pins[n],n
    log=(bp/'window-initialization-native-raw.log').read_text();assert 'Executed 5 tests, with 0 failures' in log and 'WINDOW INITIALIZATION 280 whole calls 4574 ordered events' in log
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((bp/'window-initialization-prior-pins.json').read_bytes())
    for n,h in prior.items():assert digest((fixtures/n).read_bytes())==h,n
    raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256']==v['rawSHA256'] and len(raw)==r['bytes']==v['rawBytes']
    payload=raw[:-1];assert raw.endswith(b'\n');c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-window-initialization.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,rawTests=5,rawTestSeconds=float(re.findall(r'Executed 5 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=digest(log.encode()),verifierSHA256=digest((ROOT/'tools/verify_window_initialization.py').read_bytes()),verifierLogSHA256=digest((bp/'window-initialization-verification.log').read_bytes()),verifierSession=95279,verifierExitCode=0)
    r.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),nativeRawTests=w['rawTests'],nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],sourceVerification=v,fullCRTStartupCompared=False)
    (ROOT/'docs/evidence/window-initialization.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')};w['publishedFixtures']=len(current)
    (bp/'window-initialization-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),prior=len(prior),current=len(current),rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
