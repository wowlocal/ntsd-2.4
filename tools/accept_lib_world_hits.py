#!/usr/bin/env python3
"""Publish complete library-hit source evidence after verified raw acceptance.

Reuse only terminal successful source/verifier/five-test jobs with exact log,
source-module, all528 exported-file and five current owned native hashes.
The second fixture is an explicitly source-only164-case pristine delta audit.
Original bytes and old fixture pins remain immutable; no source fault is
reclassified as a native match and no Windows or runtime-DLL claim is made.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    wp=ROOT/'build/research/lib-world-hits-work.json';w=json.loads(wp.read_bytes())
    assert w['sourceTerminal'] and w['sourceExitCode']==0 and w['pairedSourceTerminal'] and w['pairedSourceExitCode']==0
    assert w['nativeRawStatus']=='terminal' and w['nativeRawExitCode']==0 and w['sourceVerifierExitCode']==0
    log=(ROOT/'build/research/lib-world-hits-native-raw.log').read_bytes();assert digest(log)==w['nativeRawLogSHA256']
    assert b'Executed 5 tests, with 0 failures' in log and b'LIB WORLD HITS 18137 whole pools compared' in log
    assert log.count(b'WORLD HITS 7845 whole pools compared')==2
    seconds=float(re.findall(rb'Executed 5 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1])
    build=float(re.search(rb'Build complete! \(([0-9.]+)s\)',log)[1])
    pins=json.loads((ROOT/'build/research/lib-world-hits-source-pins.json').read_bytes());package=Path(w['isolatedPackage']).parent
    assert len(pins)==w['isolatedFiles']==528
    for n,h in pins.items():assert digest((package/n).read_bytes())==h,n
    for n in w['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==pins[n],n
    for n,h in w['sourceHashes'].items():assert digest((ROOT/'tools'/n).read_bytes())==h,n
    assert digest((ROOT/'tools/oracle_lib_hits_pristine_changes.py').read_bytes())==w['pairedSourceSHA256']
    assert digest((ROOT/'tools/verify_lib_world_hits.py').read_bytes())==w['sourceVerifierSHA256']
    assert digest((ROOT/'build/research/lib-world-hits-source-verification.log').read_bytes())==w['sourceVerifierLogSHA256']
    verified=json.loads((ROOT/'build/research/lib-world-hits-source-verification.json').read_bytes())
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((ROOT/'build/research/lib-world-hits-prior-pins.json').read_bytes())
    for n,h in prior.items():assert digest((fixtures/n).read_bytes())==h,n
    published=[]
    for name in ('lib-world-hits','lib-hits-pristine-changes'):
        raw=(ROOT/'build/original'/(name+'.json')).read_bytes();r=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes())
        assert len(raw)==r['bytes'] and digest(raw)==r['sha256'] and raw.endswith(b'\n')
        if name=='lib-world-hits':assert r['sha256']==verified['rawSHA256']
        payload=raw[:-1];compressor=zlib.compressobj(9,zlib.DEFLATED,-15)
        packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressor.compress(payload)+compressor.flush()).decode()),separators=(',',':'))+'\n').encode()
        path=fixtures/('original-'+name+'.json')
        if path.exists():assert path.read_bytes()==packed
        else:path.write_bytes(packed)
        r.update(fixture=path.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed))
        if name=='lib-world-hits':r.update(nativeCompared=True,nativeRawTests=5,nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build,sourceVerification=verified)
        else:r.update(nativeCompared=False,sourceOnlyPairedDeltaAudit=True)
        (ROOT/'docs/evidence'/(name+'.json')).write_text(json.dumps(r,indent=2)+'\n');published.append(dict(name=name,bytes=len(packed),sha256=digest(packed)))
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    (ROOT/'build/research/lib-world-hits-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,acceptanceReusedVerifiedRawRun=True,nativeRawTests=5,
        nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build,priorPins=len(prior),currentPinsAtPublication=len(current),published=published)
    wp.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(dict(priorPins=len(prior),publishedPins=len(current),fixtures=published),indent=2))
if __name__=='__main__':main()
