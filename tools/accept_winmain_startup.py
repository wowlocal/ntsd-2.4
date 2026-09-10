#!/usr/bin/env python3
"""Package immutable continuous startup research bytes after native acceptance.
Keep23 whole native comparisons separate from5 original-stop and7 unknown-
provenance native rejections. Compression is fixture transport only; no Windows,
private ABI, device, full WinMain return or application-completion claim.
"""
import json,base64,zlib,hashlib
from verify_winmain_startup import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=ROOT/'build/research/winmain-startup-work.json';w=json.loads(p.read_bytes())
 assert w.get('rawAcceptancePassed') and (w['nativeWholeChains'],w['nativeSourceStopRejections'],w['nativeUnknownProvenanceRejections'])==(23,5,7)
 assert all(j['status']=='terminal' for j in w['nativeJobs']+w['sourceJobs']) and w['nativeJobs'][-1]['exitCode']==0
 source=ROOT/'build/research/winmain-startup-candidate2.json';r=audit(source);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);packed=z.compress(payload)+z.flush()
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-winmain-startup.json';assert not fixture.exists()
 data=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(packed).decode()),separators=(',',':'))+'\n').encode();fixture.write_bytes(data)
 r.update(nativeCompared=True,nativeWholeChains=23,nativeSourceStopRejections=5,nativeUnknownProvenanceRejections=7,nativeComparedEvents=6325,nativeComparedWholeWAVs=119,fixture=fixture.name,fixtureBytes=len(data),fixtureSHA256=H(data),windowsVerified=False,fullGoalComplete=False,scope='Continuous43cf40..43d100:23 whole native chains,5 original-stop and7 unknown-provenance native rejections with rollback. Own RNG, window/panel, calendar/music, input and WAV state; masked opaque platform fields. Earlier CRT/NLS, full WinMain/message-loop/application, actual window/device and private-stack provenance remain open.')
 (ROOT/'docs/evidence/winmain-startup.json').write_text(json.dumps(r,indent=2)+'\n')
 pins={p.name:H(p.read_bytes()) for p in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==235
 (ROOT/'build/research/winmain-startup-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w.update(fixturePublished=True,currentFixtures=len(pins),publication=dict(fixture=str(fixture.relative_to(ROOT)),sha256=H(data),bytes=len(data)));p.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w['publication'],indent=2))
if __name__=='__main__':main()
