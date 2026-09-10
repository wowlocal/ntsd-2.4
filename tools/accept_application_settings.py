#!/usr/bin/env python3
"""Publish own settings evidence only after isolated native raw acceptance.
17 actual own settings returns plus1 pre-fscanf missing-FILE stop are distinct.
No original stack import, Windows/device or whole World/dispatcher return claim.
"""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_settings import validate,digest

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-settings-work.json'))
 log=Path(a.acceptance_log);job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name)
 assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 9 tests, with 0 failures',text)
 for name in ['OriginalApplicationSettingsTests','OriginalSettingsLoadingTests','OriginalBitmapSurfaceLoadingTests','OriginalApplicationDispatchEntryTests']:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in ['Sources/NTSDCore/OriginalSettingsLoading.swift','Tests/NTSDCoreTests/OriginalBitmapSurfaceLoadingTests.swift','Tests/NTSDCoreTests/OriginalApplicationSettingsTests.swift']:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_settings.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-settings-prior-pins.json'));assert len(pins)==240
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-settings.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='17 whole own settings returns and1 missing-FILE stop, full immutable startup/loop/front parents. Native compares settings events and owned scratch only; original private stack remains evidence. Native own GameEntry supplies restored target. Whole pending loop rolls back at required screen/nullFile or late failures; no World/dispatcher/Windows return.',sourceCallbacks='Declared fopen/fclose/translated _read and existing single-thread services; no Windows file execution.')
 (ROOT/'docs/evidence/application-settings.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==241
 (ROOT/'build/research/application-settings-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes; all240 prior pins unchanged')
if __name__=='__main__':main()
