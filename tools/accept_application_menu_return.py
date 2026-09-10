#!/usr/bin/env python3
"""Publish own menu/World/dispatcher/first-iteration evidence after acceptance.
47 complete own iterations and1 pre-NULL cursor stop;9 late rollback checks.
No unknown private stack import, worker/Windows/device or full-match claim.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_menu_return import validate,digest
OWNED_NATIVE=['Sources/NTSDCore/OriginalApplicationDispatchEntry.swift','Sources/NTSDCore/OriginalMainMenu.swift','Sources/NTSDCore/OriginalMenuPresentation.swift','Tests/NTSDCoreTests/OriginalBitmapSurfaceLoadingTests.swift','Tests/NTSDCoreTests/OriginalApplicationSettingsTests.swift','Tests/NTSDCoreTests/OriginalApplicationFrontScreenTests.swift','Tests/NTSDCoreTests/OriginalApplicationScreenBodyTests.swift','Tests/NTSDCoreTests/OriginalApplicationMenuReturnTests.swift']
SUITES=['OriginalApplicationMenuReturnTests','OriginalApplicationScreenBodyTests','OriginalBitmapSurfaceLoadingTests','OriginalFrontMenuCompletionTests','OriginalFrontScreenAlternateTests','OriginalMenuPresentationTests','OriginalApplicationMessageLoopTests','OriginalApplicationDispatchEntryTests']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-menu-return-work.json'))
 log=Path(a.acceptance_log);job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name)
 assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 17 tests, with 0 failures',text)
 for name in SUITES:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in OWNED_NATIVE:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_menu_return.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-menu-return-prior-pins.json'));assert len(pins)==243
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-menu-return.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='47 own full early-menu/World/dispatcher/first due-loop iterations,1 pre-NULL cursor rejection with full rollback;9 late observer rollback cases. Own target/selector/RNG/DC/resources only;1199 retained bitmap records. Native discards World presentation HRESULT; dispatcher retained1 controls timer. No private cookie/SEH/register import or Windows/full-match claim.',sourceCallbacks='Actual relocated DLL installer precedes independently entered WinMain; declared image/COM/GDI/clock/thread boundaries. Ordinary original SEH/cookie epilogues execute; no memory corruption/bypass/fault continuation. Earlier CRT/NLS, worker delivery and real Windows/devices remain open.')
 (ROOT/'docs/evidence/application-menu-return.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==244
 (ROOT/'build/research/application-menu-return-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes; all243 prior pins unchanged')
if __name__=='__main__':main()
