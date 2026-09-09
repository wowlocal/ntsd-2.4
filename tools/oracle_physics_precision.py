#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole40e490 under explicit CW027f, the precision selected by EXE startup.
Fresh declared controls or all original loaded Frames; no historical fixture
rewrites. This is53-bit arithmetic revalidation, not a complete initialized
Windows/thread/device or natural match capture.
"""
import argparse,json,struct,zlib,base64
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from oracle_actor_physics import ActorPhysics,probes,HEADER,EXTRA_HEADER,STATES,d,q,digest
from oracle_actor_physics_catalog import CatalogPhysics
from unicorn.x86_const import UC_X86_REG_FPCW,UC_X86_REG_FPSW

class Physics53(ActorPhysics):
 def execute(self,item):
  self.uc.reg_write(UC_X86_REG_FPCW,0x27f);self.uc.reg_write(UC_X86_REG_FPSW,0)
  self.uc.mem_write(0x45971c,struct.pack('<I',item.get('sse2',0)));self.call(0x40e490)
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x27f and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
class Catalog53(CatalogPhysics):
 execute=Physics53.execute

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--catalog',action='store_true');a=p.parse_args()
 kind='actor-physics-catalog' if a.catalog else 'actor-physics'
 old_report=json.loads((ROOT/'docs/evidence'/f'{kind}.json').read_bytes());old=(ROOT/'build/original'/old_report['corpus']).read_bytes()
 assert digest(old)==old_report['sha256'] and digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/old_report['fixture']).read_bytes())==old_report['fixtureSHA256']
 old_doc=json.loads(old);old_cases={c['label']:c for c in old_doc['cases']}
 parent=old_doc.get('parent');bindings=old_doc.get('bindings');objects={}
 if a.catalog:
  r=json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
  source=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(source)==r['corpusSHA256'];cat=json.loads(source)
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture']).read_bytes())==parent['sha256']
  def blob(key):
   b=cat['blobs'][key];raw=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(raw)==b['count'] and digest(raw)==key;return raw
  for item in cat['children']:
   if item['kind']=='object':
    assert digest(read_bytes(DEFAULT_SOURCE/item['path'].replace('\\','/')))==item['source']
    objects[item['index']]=(blob(item['storage']['bytes']),blob(item['storage']['defined']))
  assert len(objects)==137
  vm=Catalog53(objects)
  def inputs():
   for index,(raw,mask) in objects.items():
    for n in range(400):
     assert mask[0x7a4+n*0x178]
     if not raw[0x7a4+n*0x178]:continue
     for mode,(y,vy,vx) in enumerate(((0,.1,.1),(-100,-3.5,2.8),(-1,12,13.7))):
      yield dict(label=f'object-{index}-frame-{n}-motion-{mode}',group='source-frame',objectIndex=index,actor=[d(0x70,n),d(0x14,-1 if y<0 else 0),q(0x60,y),q(0x48,vy),q(0x40,vx)])
 else:vm=Physics53();inputs=probes
 cases=[];changed=[]
 for n,item in enumerate(inputs()):
  case=vm.probe(item,n);cases.append(case);old=old_cases[case['label']]
  # All scenario inputs must reproduce exactly. Only CPU precision differs.
  for key,value in old.items():
   if key not in ('after','defined','globalsSHA256','events'):assert case[key]==value,(case['label'],key)
  if any(case[key]!=old[key] for key in ('after','defined','globalsSHA256','events')):changed.append(case['label'])
  if (n+1)%2000==0:print('PHYSICS53',kind,n+1,'changed',len(changed),flush=True)
 assert len(cases)==len(old_cases)
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x27f,header=old_doc['header'],states=old_doc['states'],cases=cases,instructions=sorted(vm.instructions),
  historical=dict(fixture=old_report['fixture'],sha256=old_report['fixtureSHA256']),changedFrom64=changed)
 if parent:doc.update(parent=parent,bindings=bindings)
 name='actor-physics53-catalog' if a.catalog else 'actor-physics53';path=ROOT/'build/original'/f'{name}.json'
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),fpcw=0x27f,cases=len(cases),
  groups=dict(Counter(c['group'] for c in cases)),instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),changedFrom64=len(changed),
  historical=doc['historical'],nativeCompared=False)
 if parent:report['parent']=parent
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
