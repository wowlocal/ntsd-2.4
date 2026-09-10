#!/usr/bin/env python3
"""Publish immutable full loading evidence after exact terminal raw comparison.

Verify source modules, all exported native files, current owned files and
terminal logs before packing original bytes unchanged. Native implements
loading data operations, not the DLL installer or Windows API behavior.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    bp=ROOT/'build/research';wp=bp/'lib-loading-work.json';w=json.loads(wp.read_bytes())
    assert w['sourceStatus']==w['nativeRawStatus']=='terminal' and w['sourceExitCode']==w['nativeRawExitCode']==w['sourceVerifierExitCode']==0
    for n,h in w['sourceHashes'].items():assert digest((ROOT/'tools'/n).read_bytes())==h,n
    pins=json.loads((bp/'lib-loading-source-pins.json').read_bytes());assert len(pins)==w['isolatedFiles']==532
    for n,h in pins.items():assert digest((Path(w['isolatedPackage']).parent/n).read_bytes())==h,n
    for n in w['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==pins[n],n
    for name,key in [('source','source'),('native-raw','nativeRaw'),('source-verification','sourceVerifier')]:
        log=(bp/f'lib-loading-{name}.log').read_bytes();assert digest(log)==w[key+'LogSHA256']
        if name=='native-raw':assert b'Executed 4 tests, with 0 failures' in log and b'LIB LOADING 318 whole calls 20727 events 2 rollback trials' in log
    raw_log=(bp/'lib-loading-native-raw.log').read_text()
    seconds=float(re.findall(r'Executed 4 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',raw_log)[-1])
    build=float(re.search(r'Build complete! \(([0-9.]+)s\)',raw_log)[1])
    assert digest((ROOT/'tools/verify_lib_loading.py').read_bytes())==w['sourceVerifierSHA256']
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((bp/'lib-loading-prior-pins.json').read_bytes())
    for n,h in prior.items():assert digest((fixtures/n).read_bytes())==h,n
    raw=(ROOT/'build/original/lib-loading.json').read_bytes();r=json.loads((bp/'lib-loading.json').read_bytes());v=json.loads((bp/'lib-loading-source-verification.json').read_bytes())
    assert digest(raw)==r['sha256']==v['rawSHA256'] and len(raw)==r['bytes']==v['rawBytes'] and raw.endswith(b'\n')
    payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode()
    p=fixtures/'original-lib-loading.json'
    if p.exists():assert p.read_bytes()==packed
    else:p.write_bytes(packed)
    r.update(nativeCompared=True,fixture=p.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),nativeRawTests=4,nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build,sourceVerification=v)
    (ROOT/'docs/evidence/lib-loading.json').write_text(json.dumps(r,indent=2)+'\n')
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')};(bp/'lib-loading-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,nativeRawTests=4,nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build,currentPinsAtPublication=len(current),fixtureSHA256=digest(packed))
    wp.write_text(json.dumps(w,indent=2)+'\n');print('Published',len(raw),len(packed),len(prior),len(current),digest(packed))
if __name__=='__main__':main()
