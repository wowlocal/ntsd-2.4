#!/usr/bin/env python3
"""Publish immutable original input evidence only after terminal native acceptance.

Verify the original 4369 whole input callbacks plus three separate constructors,
full source reconstruction and isolated native export. No Windows/device or
remaining WndProc message equivalence is inferred. Deflation only transports
research data, never changes game output or introduces a runtime dependency.
"""
import base64,hashlib,json,re,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()

def main():
    b=ROOT/'build/research';wp=b/'window-input-work.json';w=json.loads(wp.read_bytes())
    assert w['sourceStatus']==w['rawStatus']=='terminal' and w['sourceExitCode']==w['rawExitCode']==0
    assert digest((ROOT/'tools/oracle_window_input.py').read_bytes())==w['sourceToolSHA256']
    pins=json.loads((b/'window-input-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
    for n,h in pins.items():assert digest((dest/n).read_bytes())==h,n
    for n in w['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==pins[n],n
    log=(b/'window-input-native-raw.log').read_text()
    assert 'Executed 3 tests, with 0 failures' in log
    assert 'WINDOW INPUT 4369 whole callbacks 3 constructors 385 own retained calls 5908 requests 23835 ordered stores' in log
    previous=(b/'window-input-native-attempt1.log').read_text()
    for name in ('OriginalMainMenuTests','OriginalMenuPresentationTests','OriginalMusicPlaybackTests','OriginalStartupStorageTests'):
        assert "Test Suite '"+name+"' passed" in previous
    v=json.loads((b/'window-input-source-verification.json').read_bytes())
    raw=(ROOT/'build/original/window-input.json').read_bytes()
    assert digest(raw)==w['sourceRawSHA256']==v['rawSHA256'] and len(raw)==w['sourceBytes']==v['rawBytes']
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((b/'window-input-prior-pins.json').read_bytes())
    for n,h in prior.items():assert digest((fixtures/n).read_bytes())==h,n
    assert raw.endswith(b'\n');payload=raw[:-1];c=zlib.compressobj(9,zlib.DEFLATED,-15)
    packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(c.compress(payload)+c.flush()).decode()),separators=(',',':'))+'\n').encode()
    fixture=fixtures/'original-window-input.json'
    if fixture.exists():assert fixture.read_bytes()==packed
    else:fixture.write_bytes(packed)
    w.update(status='raw-accepted-packaged-pending',nativeCompared=True,rawTests=3,
             rawTestSeconds=float(re.findall(r'Executed 3 tests, with 0 failures \(0 unexpected\) in ([0-9.]+)',log)[-1]),
             rawBuildSeconds=float(re.search(r'Build complete! \(([0-9.]+)s\)',log)[1]),rawLogSHA256=digest(log.encode()),
             retainedTestsPassedBeforeTransportCorrection=6,verifierSHA256=digest((ROOT/'tools/verify_window_input.py').read_bytes()))
    report=dict(v)
    report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
                  nativeRawTests=3,nativeRawTestSeconds=w['rawTestSeconds'],nativeRawBuildSeconds=w['rawBuildSeconds'],
                  fullCRTStartupCompared=False,nativeAppExercised=False,sourceTool='tools/oracle_window_input.py',
                  nativeImplementation='native/Sources/NTSDCore/OriginalWindowInput.swift',
                  transportCorrection=w['attempt1'],originalExpectedBytesChanged=False)
    (ROOT/'docs/evidence/window-input.json').write_text(json.dumps(report,indent=2)+'\n')
    current={p.name:digest(p.read_bytes()) for p in fixtures.glob('*.json')}
    assert set(current)==set(prior)|{fixture.name}
    (b/'window-input-fixture-pins.json').write_text(json.dumps(current,indent=2)+'\n')
    w.update(publishedFixtures=len(current),sourceVerification=v);wp.write_text(json.dumps(w,indent=2)+'\n')
    print(json.dumps(dict(rawBytes=len(raw),packedBytes=len(packed),rawSHA256=digest(raw),packedSHA256=digest(packed),
                         prior=len(prior),current=len(current),rawTestSeconds=w['rawTestSeconds'],rawBuildSeconds=w['rawBuildSeconds']),indent=2))
if __name__=='__main__':main()
