#!/usr/bin/env python3
"""Publish lossless adinfo research transport only after recorded raw acceptance.
The game EXE/CRT expected bytes remain immutable. Transport compression is not
native game behavior. Read-only independent audit runs before each publication.
"""
import argparse,base64,json,zlib,hashlib
from pathlib import Path
from verify_menu_info_reading import audit,ROOT
H=lambda b:hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.parse_args();work=ROOT/'build/research/menu-info-reading-work.json';w=json.loads(work.read_bytes())
 assert w.get('rawAcceptancePassed') is True and w['nativeJobs'][-1]['status']=='terminal' and w['nativeJobs'][-1]['exitCode']==0
 pending=[]
 for name,roundtrip in [('menu-info-reading',False),('menu-info-roundtrip',True)]:
  source=ROOT/f'build/research/{name}-candidate1.json';r=audit(source,roundtrip=roundtrip);raw=source.read_bytes();payload=raw[:-1];z=zlib.compressobj(level=9,wbits=-15);compressed=z.compress(payload)+z.flush()
  packed=(json.dumps(dict(count=len(payload),sha256=H(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-{name}.json';assert not fixture.exists()
  report=dict(r,nativeCompared=True,fixture=fixture.name,fixtureSHA256=H(packed),fixtureBytes=len(packed),fullGoalComplete=False,windowsVerified=False,scope='Controlled whole reader and declared own reader/cache-writer/reader ABI; two unknown-local rejections remain separate from194 whole main calls.')
  pending.append((name,fixture,packed,report))
 for name,fixture,packed,report in pending:
  fixture.write_bytes(packed);(ROOT/f'docs/evidence/{name}.json').write_text(json.dumps(report,indent=2)+'\n')
 pins={p.name:H(p.read_bytes()) for p in sorted((ROOT/'native/Tests/NTSDCoreTests/Fixtures').glob('*.json'))};assert len(pins)==230
 (ROOT/'build/research/menu-info-reading-fixture-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
 w['fixturePublished']=True;w['currentFixtures']=230;w['publications']=[dict(fixture=str(f.relative_to(ROOT)),sha256=H(p),bytes=len(p)) for _,f,p,_ in pending];work.write_text(json.dumps(w,indent=2)+'\n')
 print(json.dumps(w['publications'],indent=2))
if __name__=='__main__':main()
