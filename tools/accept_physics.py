#!/usr/bin/env python3
"""Validate and compare all five physics captures before publishing fixtures.
Source production stays in oracle_actor_physics.py, oracle_actor_physics_catalog.py,
oracle_world_physics.py and oracle_gameplay_entry.py. Uses one sequential SwiftPM
invocation and writes resource fixtures only after that process has succeeded.
"""
import base64,json,os,subprocess,zlib
from accept_gameplay_physics import ROOT,digest,validated_captures,publish

def main():
 captures=[]
 for name,count in [('actor-physics',9344),('actor-physics-catalog',46089),('world-physics',515)]:
  report=json.loads((ROOT/'build/research'/f'{name}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
  doc=json.loads(raw)
  assert doc['exeSHA256']==report['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
  assert len(doc['cases'])==report['cases']==count
  if 'parent' in doc:
   assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/doc['parent']['fixture']).read_bytes())==doc['parent']['sha256']
  captures.append((name,report,raw))
 gameplay=validated_captures()
 directory=ROOT/'build/original'
 subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','Original(ActorPhysics|WorldPhysics|GameplayPhysics)Tests'],
  env=dict(os.environ,NTSD_ACTOR_PHYSICS_CORPUS=str(directory/'actor-physics.json'),
   NTSD_PHYSICS_CATALOG_CORPUS=str(directory/'actor-physics-catalog.json'),
   NTSD_WORLD_PHYSICS_CORPUS=str(directory/'world-physics.json'),NTSD_GAMEPLAY_PHYSICS_DIRECTORY=str(directory)),check=True)
 for name,report,raw in captures:
  assert raw.endswith(b'\n');payload=raw[:-1]
  compressor=zlib.compressobj(level=9,wbits=-15);compressed=compressor.compress(payload)+compressor.flush()
  packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(compressed).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/f'original-{name}.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence'/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n')
  print(json.dumps(report,indent=2),flush=True)
 publish(gameplay)
if __name__=='__main__':main()
