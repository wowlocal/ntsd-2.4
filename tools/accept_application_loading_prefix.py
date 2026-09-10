#!/usr/bin/env python3
"""Publish verified own loading prologue/common-sound evidence after isolated
raw native acceptance.9 prefixes reach the catalog allocation request;3 failed
CreateSoundBuffer cases are explicit rejections. Preserve245 accepted fixtures,
full raw/packed bytes and parents; no Windows/device or whole-loading claim."""
import argparse,base64,json,os,re,zlib
from pathlib import Path
from import_ntsd import ROOT,EXE_SHA256
from verify_application_loading_prefix import validate,digest
OWNED_NATIVE=['Sources/NTSDCore/OriginalWaveLoader.swift','Sources/NTSDCore/OriginalInitialSoundLoading.swift','Sources/NTSDCore/OriginalInitialLoading.swift','Sources/NTSDCore/OriginalInitialLoadingCommon.swift','Tests/NTSDCoreTests/OriginalApplicationMenuInputTests.swift','Tests/NTSDCoreTests/OriginalApplicationLoadingPrefixTests.swift']
SUITES=['OriginalApplicationLoadingPrefixTests','OriginalApplicationMenuInputTests','OriginalInitialLoadingTests','OriginalWaveLoaderTests']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--package-path',required=True);p.add_argument('--acceptance-log',required=True);a=p.parse_args()
 path=Path(a.raw);raw=path.read_bytes();report=validate(path);work=json.load(open(ROOT/'build/research/application-loading-prefix-work.json'));log=Path(a.acceptance_log)
 job=next(j for j in work['nativeJobs'] if j['name']+'.log'==log.name);assert job['status']=='terminal' and job['exitCode']==0
 text=log.read_text();assert re.search(r'Executed 7 tests, with 0 failures',text)
 for name in SUITES:assert f"Test Suite '{name}' passed" in text
 package=Path(a.package_path)
 for f in OWNED_NATIVE:assert (ROOT/'native'/f).read_bytes()==(package/f).read_bytes()
 assert (ROOT/'tools/oracle_application_loading_prefix.py').read_bytes()==path.with_name(path.stem+'-source.py').read_bytes()
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-loading-prefix-prior-pins.json'));assert len(pins)==245
 for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
 payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);compressed=z.compress(payload)+z.flush();assert zlib.decompress(compressed,-15)+b'\n'==raw
 packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode();fixture=fixtures/'original-application-loading-prefix.json'
 if fixture.exists():assert fixture.read_bytes()==packed
 else:tmp=fixture.with_suffix('.tmp');tmp.write_bytes(packed);os.replace(tmp,fixture)
 report.update(exeSHA256=EXE_SHA256,nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=digest(packed),rawCorpus=str(path.relative_to(ROOT)) if path.is_absolute() else str(path),acceptanceLog=str(log),nativeScope='12 own loading prefixes:9 complete to actual catalog allocation request,3 rejected CreateSoundBuffer boundaries.187 whole WAV returns,3 short-read temporaries retained; own target/device/resources/RNG/MSG.5 late rollback cases. No whole loading return, Windows/device or full-match claim.',sourceCallbacks='Declared MMIO/COM/allocator/copy responses on the preserved own CPU/stack, actual original prologue/bitmap/clip/WAV/presentation instructions and normal SEH/cookie code. No private native backing, control/protective corruption, bypass, external IO or continuation beyond rejected40187a.')
 (ROOT/'docs/evidence/application-loading-prefix.json').write_text(json.dumps(report,indent=2)+'\n')
 current={f.name:digest(f.read_bytes()) for f in sorted(fixtures.glob('*.json'))};assert len(current)==246
 (ROOT/'build/research/application-loading-prefix-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n');print('Published',fixture.name,len(packed),'bytes;245prior unchanged')
if __name__=='__main__':main()
