#!/usr/bin/env python3
"""Publish library-contact evidence after the verified isolated raw release run.

This reuses only a terminal successful six-test run whose log, every exported
source file and all three current owned native files retain the tested hashes.
Source results and prior fixtures are immutable. It does not execute a DLL in
Native, infer Windows compatibility or accept a source fault as a match.
"""
import base64,hashlib,json,re,subprocess,zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    workpath=ROOT/'build/research/lib-world-contacts-work.json';work=json.loads(workpath.read_bytes())
    assert work['sourceTerminal'] and work['sourceExitCode']==0
    assert work['nativeRawStatus']=='terminal' and work['nativeRawExitCode']==0
    log=(ROOT/'build/research/lib-world-contacts-native-raw.log').read_bytes()
    assert digest(log)==work['nativeRawLogSHA256']
    assert b'Executed 6 tests, with 0 failures' in log and b'LIB WORLD CONTACTS 10661 whole pools compared' in log
    assert b'WORLD CONTACTS 7925 whole pools compared' in log
    seconds=float(re.findall(rb'Executed 6 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1])
    build_seconds=float(re.search(rb'Build complete! \(([0-9.]+)s\)',log)[1])
    package=Path(work['isolatedPackage']).parent
    pins=json.loads((ROOT/'build/research/lib-world-contacts-source-pins.json').read_bytes())
    assert len(pins)==work['isolatedFiles']==525
    for name,sha in pins.items():assert digest((package/name).read_bytes())==sha,name
    for name in work['ownedNativeFiles']:assert digest((ROOT/name).read_bytes())==pins[name],name
    for name,sha in work['sourceHashes'].items():assert digest((ROOT/'tools'/name).read_bytes())==sha,name
    subprocess.run(['python3',str(ROOT/'tools/verify_lib_world_contacts.py')],check=True)
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    prior=json.loads((ROOT/'build/research/lib-world-contacts-prior-pins.json').read_bytes())
    for name,sha in prior.items():assert digest((fixtures/name).read_bytes())==sha,name
    raw=(ROOT/'build/original/lib-world-contacts.json').read_bytes();payload=raw[:-1]
    assert raw.endswith(b'\n');compressor=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressor.compress(payload)+compressor.flush()).decode()),separators=(',',':'))+'\n').encode()
    fixture=fixtures/'original-lib-world-contacts.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    report=json.loads((ROOT/'build/research/lib-world-contacts.json').read_bytes())
    verified=json.loads((ROOT/'build/research/lib-world-contacts-source-verification.json').read_bytes())
    report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
        nativeRawTests=6,nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build_seconds,sourceVerification=verified,
        limitations=['Controlled storage; no initialized library-enabled gameplay join','No damage or full-match evidence',
            'Windows loader and constructor memset remain declared source adapters','No app window/device/Windows run',
            'All142 static hook starts execute; not every branch outcome','Extended kinds and state20 absent from original loaded catalog; runtime mutation remains separate'])
    (ROOT/'docs/evidence/lib-world-contacts.json').write_text(json.dumps(report,indent=2)+'\n')
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    (ROOT/'build/research/lib-world-contacts-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    work.update(status='raw-accepted-packaged-pending',nativeCompared=True,priorPins=len(prior),currentPinsAtPublication=len(current),
        acceptanceReusedVerifiedRawRun=True,nativeRawTests=6,nativeRawTestSeconds=seconds,nativeRawBuildSeconds=build_seconds,
        fixtureBytes=len(packed),fixtureSHA256=digest(packed))
    workpath.write_text(json.dumps(work,indent=2)+'\n')
    print(json.dumps(dict(priorPins=len(prior),publishedPins=len(current),fixtureBytes=len(packed),fixtureSHA256=digest(packed))))
if __name__=='__main__':main()
