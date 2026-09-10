#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Publish whole43e890 evidence after verified isolated native raw acceptance.
No whole dispatcher, initialized stack, Windows/device or app-runtime claim.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_recovery import validate,h as digest

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True)
    p.add_argument('--acceptance-log',required=True);a=p.parse_args();path=Path(a.raw);raw=path.read_bytes();result=validate(path)
    work=json.load(open(ROOT/'build/research/application-recovery-work.json'))
    log=Path(a.acceptance_log);job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name)
    assert job['status']=='terminal' and job['exitCode']==0
    text=log.read_text();assert re.search(r'Executed 13 tests, with 0 failures',text)
    assert "Test Suite 'OriginalApplicationRecoveryTests' passed" in text and "Test Suite 'OriginalWindowLifecycleTests' passed" in text
    # The just-tested isolated overlay and frozen original producer must match.
    package=Path(a.package_path)
    for f in ('Sources/NTSDCore/OriginalApplicationRecovery.swift','Tests/NTSDCoreTests/OriginalApplicationRecoveryTests.swift','Sources/NTSDCore/OriginalDisplayDestruction.swift','Sources/NTSDCore/OriginalWindowLifecycle.swift'):
        assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
    assert (ROOT/'tools/oracle_application_recovery.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-recovery-prior-pins.json'))
    assert len(pins)==237
    for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
    payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush()
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
    assert zlib.decompress(compressed,-15)+b'\n'==raw
    fixture=fixtures/'original-application-recovery.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:
        temp=fixture.with_suffix('.tmp');temp.write_bytes(packed);os.replace(temp,fixture)
    result.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),
        rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),producerSHA256=digest((ROOT/'tools/oracle_application_recovery.py').read_bytes()),
        nativeScope='318 whole recovery returns and3 own initializations; one ordinary null-back source fault explicitly rejected, not a match. Full globals/masks, requests, structures and owned resource lifetime; no full dispatcher/WinMain/Windows claim.',
        acceptanceLog=str(log),sourceCallbacks='Declared COM/Win32 callbacks; no synchronous reentrancy or Windows/device execution')
    (ROOT/'docs/evidence/application-recovery.json').write_text(json.dumps(result,indent=2)+'\n')
    current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==238
    (ROOT/'build/research/application-recovery-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    print('Published',fixture.name,len(packed),'bytes; all237 prior pins unchanged')
if __name__=='__main__':main()
