#!/usr/bin/env python3
"""Publish lossless startup-panel fixture after raw native acceptance.
Immutable original EXE/CRT outputs and unknown-boundary contracts are retained;
transport deflation is only research storage, not a game runtime dependency.
"""
import argparse,base64,json,zlib,hashlib
from pathlib import Path
from verify_startup_panel import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.parse_args();work=ROOT/'build/research/startup-panel-work.json';w=json.loads(work.read_bytes())
 assert w.get('rawAcceptancePassed') and w['nativeJobs'][-1]['status']=='terminal' and w['nativeJobs'][-1]['exitCode']==0
 source=ROOT/'build/research/startup-panel-candidate1.json';report=audit(source);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(level=9,wbits=-15);compressed=z.compress(payload)+z.flush()
 packed=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-startup-panel.json';assert not fixture.exists()
 report.update(nativeCompared=True,fixture=fixture.name,fixtureBytes=len(packed),fixtureSHA256=H(packed),windowsVerified=False,fullGoalComplete=False,scope='212 complete controlled callers;8 unknown-local source returns rejected natively with rollback. Same original CPU/stack; native carries own reader locals; earlier WinMain/CRT/application remain open.')
 fixture.write_bytes(packed);(ROOT/'docs/evidence/startup-panel.json').write_text(json.dumps(report,indent=2)+'\n')
 pins={p.name:H(p.read_bytes()) for p in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==231
 (ROOT/'build/research/startup-panel-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w.update(fixturePublished=True,currentFixtures=231,publication=dict(fixture=str(fixture.relative_to(ROOT)),sha256=H(packed),bytes=len(packed)));work.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w['publication'],indent=2))
if __name__=='__main__':main()
