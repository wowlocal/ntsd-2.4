#!/usr/bin/env python3
"""Publish independently verified own queued input/repeated-menu evidence.
47 idle repeats plus3 delivered click/World1/loading-entry chains;62 completed
iterations,3 pending loading calls. No private native input, worker, Windows,
device or loading-success claim. Require isolated raw native acceptance first.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_menu_input import validate,digest
OWNED_NATIVE=['Sources/NTSDCore/OriginalCRTRandom.swift','Sources/NTSDCore/OriginalMainMenu.swift','Sources/NTSDCore/OriginalMenuPresentation.swift','Tests/NTSDCoreTests/OriginalApplicationMenuReturnTests.swift','Tests/NTSDCoreTests/OriginalApplicationMenuInputTests.swift']
SUITES=['OriginalApplicationMenuInputTests','OriginalApplicationMenuReturnTests','OriginalFrontMenuLoopTests','OriginalMainMenuTests','OriginalMenuPresentationTests']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-menu-input-work.json'));log=Path(a.acceptance_log)
 job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name);assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 8 tests, with 0 failures',text)
 for name in SUITES:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in OWNED_NATIVE:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_menu_input.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-menu-input-prior-pins.json'));assert len(pins)==244
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-menu-input.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='50 own continuations of47 full parents:47 idle repeats,3 actual queued move/down/up plus main World0->1/3000rand/sound and World1->2/background release.62 complete iterations,3 pending loading entries41bc90,8 late rollback cases. Own surfaces/RNG/MSG/library/allocator state; private source stack never imported. No full loading/worker/Windows/device claim.',sourceCallbacks='Declared Peek/Get/Translate/Dispatch WndProc frame delivery, clocks/COM/GDI/sound/free responses. Actual original World/dispatcher/rand/library code and normal SEH/cookie paths execute on preserved own CPU/stack. Sound methods are attached to the already owned buffers; free is a declared allocator boundary. No arbitrary corruption, bypass, real network or fault continuation.')
 (ROOT/'docs/evidence/application-menu-input.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==245
 (ROOT/'build/research/application-menu-input-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes;244prior unchanged')
if __name__=='__main__':main()
