#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole40e490 on every present frame of all137 original Objects, three
declared motion conditions per frame. Pinned unmodified LOADED_CATALOG,
original DAT hashes/read masks, CW037f. Actor/global/caller inputs are synthetic;
this is data coverage, not continuous gameplay or the World lifecycle caller.
"""
import argparse,base64,json,os,subprocess,zlib
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from oracle_actor_physics import ActorPhysics,d,q,digest
from oracle_actor_input import OBJECT
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EIP
class CatalogPhysics(ActorPhysics):
 def __init__(self,objects):
  self.objects=objects;self.object_mask=None
  super().__init__();self.uc.hook_add(UC_HOOK_MEM_READ,self.object_read,begin=OBJECT,end=OBJECT+0x3ffff)
 def object_bytes(self,item):
  assert not item.get('header') and not item.get('frames')
  raw,self.object_mask=self.objects[item['objectIndex']];return raw
 def object_read(self,uc,access,address,size,value,data):
  if not self.running:return
  offset=address-OBJECT
  assert 0<=offset<offset+size<=len(self.object_mask) and all(self.object_mask[offset:offset+size]),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(offset),size)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 path=ROOT/'build/original/actor-physics-catalog.json';report_path=ROOT/'build/research/actor-physics-catalog.json'
 parent=json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
 assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture']).read_bytes())==parent['fixtureSHA256']
 if a.accept:
  raw=path.read_bytes();report=json.loads(report_path.read_bytes());assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
 else:
  source=(ROOT/'build/original'/parent['corpus']).read_bytes();assert digest(source)==parent['corpusSHA256'];catalog=json.loads(source)
  def blob(key):
   b=catalog['blobs'][key];v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(v)==b['count'] and digest(v)==key;return v
  objects={};bindings=[]
  for item in catalog['children']:
   if item['kind']!='object':continue
   assert digest(read_bytes(DEFAULT_SOURCE/item['path'].replace('\\','/')))==item['source']
   raw=blob(item['storage']['bytes']);mask=blob(item['storage']['defined']);assert len(raw)==len(mask)==0x25360
   objects[item['index']]=(raw,mask);bindings.append({key:item[key] for key in ('index','id','objectType','path','source')})
  assert len(objects)==137;vm=CatalogPhysics(objects);cases=[];present=0
  for index,(raw,mask) in objects.items():
   for n in range(400):
    assert mask[0x7a4+n*0x178]
    if raw[0x7a4+n*0x178]==0:continue
    present+=1
    for mode,(y,vy,vx) in enumerate(((0,.1,.1),(-100,-3.5,2.8),(-1,12,13.7))):
     cases.append(vm.probe(dict(label=f'object-{index}-frame-{n}-motion-{mode}',group='source-frame',objectIndex=index,actor=[d(0x70,n),d(0x14,-1 if y<0 else 0),q(0x60,y),q(0x48,vy),q(0x40,vx)]),len(cases)))
   print('CATALOG PHYSICS',index,'frames',present,'cases',len(cases),flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x37f,parent=dict(fixture=parent['fixture'],sha256=parent['fixtureSHA256']),bindings=bindings,header=[],states={},cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),objects=len(objects),frames=present,instructions=len(vm.instructions),events=sum(len(c['events']) for c in cases),parent=doc['parent'],nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalActorPhysicsTests/testPhysicsOnCompleteCatalog'],env=dict(os.environ,NTSD_PHYSICS_CATALOG_CORPUS=str(path)),check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-actor-physics-catalog.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/actor-physics-catalog.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
