#!/usr/bin/env python3
"""Package immutable message-loop evidence after raw native comparison.
63 loop returns at declared OS/body boundaries and1 own required-dispatch stop
remain distinct. 131 actual controlled WndProc callbacks; not Windows, whole
dispatcher, full app or game completion. Compression is fixture transport only.
"""
import json,base64,zlib,hashlib
from verify_application_message_loop import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=ROOT/'build/research/application-message-loop-work.json';w=json.loads(p.read_bytes())
 assert w.get('rawAcceptancePassed') and w['nativeLoopReturns']==63 and w['nativeRequiredDispatchStops']==1
 assert all(j['status']=='terminal' for j in w['nativeJobs']+w['sourceJobs']) and w['nativeJobs'][-1]['exitCode']==0
 source=ROOT/'build/research/application-message-loop-candidate3.json';r=audit(source);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(9,wbits=-15);packed=z.compress(payload)+z.flush()
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-application-message-loop.json';assert not fixture.exists()
 data=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(packed).decode()),separators=(',',':'))+'\n').encode();fixture.write_bytes(data)
 r.update(nativeCompared=True,nativeLoopReturns=63,nativeRequiredDispatchStops=1,nativeCompletedIterations=215,nativeCallbacks=131,nativeEvents=896,fixture=fixture.name,fixtureBytes=len(data),fixtureSHA256=H(data),windowsVerified=False,fullGoalComplete=False,scope='Whole43d100..43d21f loop/ret16 decisions and selected actual WndProc callbacks from own startup.63 returns at declared OS/dispatcher/recovery boundaries,1 own stop at required43e9a0; earlier CRT/NLS/full dispatcher/application/device remain open.')
 (ROOT/'docs/evidence/application-message-loop.json').write_text(json.dumps(r,indent=2)+'\n')
 pins={f.name:H(f.read_bytes()) for f in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==236
 (ROOT/'build/research/application-message-loop-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w.update(fixturePublished=True,currentFixtures=len(pins),publication=dict(fixture=str(fixture.relative_to(ROOT)),sha256=H(data),bytes=len(data)));p.write_text(json.dumps(w,indent=2)+'\n');print(json.dumps(w['publication'],indent=2))
if __name__=='__main__':main()
