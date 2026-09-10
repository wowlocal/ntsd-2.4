#!/usr/bin/env python3
"""Publish lossless whole startup-output evidence after raw native acceptance.
The49 whole source/native callers and9 stopped/native-rejected cases remain
separate. Transport compression only packages original research bytes; no
Windows/CRT/device or full native application completion claim.
"""
import json,base64,zlib,hashlib
from verify_startup_output import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=ROOT/'build/research/startup-output-work.json';w=json.loads(p.read_bytes())
 assert w.get('rawAcceptancePassed') and w.get('globalOrderAcceptancePassed')
 assert all(j['status']=='terminal' for j in w['nativeJobs']+w['sourceJobs']) and w['nativeJobs'][-1]['exitCode']==0
 source=ROOT/'build/research/startup-output-candidate1.json';r=audit(source);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);packed=z.compress(payload)+z.flush()
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-startup-output.json';assert not fixture.exists()
 data=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(packed).decode()),separators=(',',':'))+'\n').encode();fixture.write_bytes(data)
 r.update(nativeCompared=True,fixture=fixture.name,fixtureBytes=len(data),fixtureSHA256=H(data),windowsVerified=False,fullGoalComplete=False,scope='49 whole43cfb4..43d078 callers;9 original stops are distinct native rejections with rollback. Own calendar/music state and ordered global writes. Earlier full CRT/panel/WinMain, following input, Windows/device/application join remain open.')
 (ROOT/'docs/evidence/startup-output.json').write_text(json.dumps(r,indent=2)+'\n')
 pins={p.name:H(p.read_bytes()) for p in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==234
 (ROOT/'build/research/startup-output-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w.update(fixturePublished=True,currentFixtures=len(pins),publication=dict(fixture=str(fixture.relative_to(ROOT)),sha256=H(data),bytes=len(data)));p.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w['publication'],indent=2))
if __name__=='__main__':main()
