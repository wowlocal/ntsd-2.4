#!/usr/bin/env python3
"""Publish own settings evidence only after isolated native raw acceptance.
40 own screen prefixes plus1 pre-NULL bitmap stop are distinct.
No private fill import, worker body, Windows/device or whole dispatcher claim.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_front_screen import validate,digest

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-front-screen-work.json'))
 log=Path(a.acceptance_log);job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name)
 assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 9 tests, with 0 failures',text)
 for name in ['OriginalApplicationFrontScreenTests','OriginalApplicationSettingsTests','OriginalFrontScreenPreludeTests','OriginalBitmapSurfaceLoadingTests']:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in ['Sources/NTSDCore/OriginalMenuBackground.swift','Sources/NTSDCore/OriginalFrontScreenPrelude.swift','Tests/NTSDCoreTests/OriginalBitmapSurfaceLoadingTests.swift','Tests/NTSDCoreTests/OriginalApplicationSettingsTests.swift','Tests/NTSDCoreTests/OriginalApplicationFrontScreenTests.swift']:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_front_screen.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-front-screen-prior-pins.json'));assert len(pins)==241
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-front-screen.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='40 own screen prefixes through427127/4275cb plus1 pre-NULL bitmap stop. Whole background constructor/loader/copy, source-state-derived allocations, ordered bitmap reads/clips/Blt and own parent globals.328 owned fill bytes compare;3772 private fill bytes stay unknown0/false. Own settings target and typed cached Sleep survive staged continuation.41 outer-loop rollbacks plus late failures; no World/dispatcher/worker/Windows return',sourceCallbacks='Declared timer/thread/allocator/Win32/GDI/COM results; same CPU/stack/CRT and complete own settings parents. No worker delivery or Windows/device execution.')
 (ROOT/'docs/evidence/application-front-screen.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==242
 (ROOT/'build/research/application-front-screen-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes; all241 prior pins unchanged')
if __name__=='__main__':main()
