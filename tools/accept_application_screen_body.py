#!/usr/bin/env python3
"""Publish own installed-library screen-body evidence after isolated acceptance.
43 whole panel/body continuations compare owned strings/DC/resources and rollback.
No private stack import, worker execution, Windows/device or dispatcher return.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_screen_body import validate,digest

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-screen-body-work.json'))
 log=Path(a.acceptance_log);job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name)
 assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 13 tests, with 0 failures',text)
 for name in ['OriginalApplicationScreenBodyTests','OriginalApplicationFrontScreenTests','OriginalBitmapSurfaceLoadingTests','OriginalFrontScreenBodyTests','OriginalMenuPanelUpdateTests','OriginalLibSurfaceTextTests']:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in ['Sources/NTSDCore/OriginalFrontScreenBody.swift','Tests/NTSDCoreTests/OriginalBitmapSurfaceLoadingTests.swift','Tests/NTSDCoreTests/OriginalApplicationFrontScreenTests.swift','Tests/NTSDCoreTests/OriginalApplicationScreenBodyTests.swift']:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_screen_body.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-screen-body-prior-pins.json'));assert len(pins)==242
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-screen-body.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='43 own whole panel/body calls through4275cb/SP1000ea74; installed DLL text and own GameEntry target.4128 native local bytes compare;4128 private bytes remain unknown0/false.129 text and86 bitmap calls,1074 retained wrapper records and whole outer-loop rollback with7 late failures. No worker/World/dispatcher/Windows return',sourceCallbacks='Declared COM/GDI/critical-section results. Actual relocated DLL installer precedes independently entered own WinMain chain. Earlier CRT/NLS and real loader remain open; no worker delivery or Windows/device execution.')
 (ROOT/'docs/evidence/application-screen-body.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==243
 (ROOT/'build/research/application-screen-body-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes; all242 prior pins unchanged')
if __name__=='__main__':main()
