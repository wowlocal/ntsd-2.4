#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole413080 on ALL42 original type0 Objects, frame0 and128 held-input sets.
Objects restored from the pinned complete original catalog capture, unmodified.
Actor/input/global probes are explicit synthetic callers, not a natural match.
Native rebuilds and verifies the full catalog before using its own loaded data.
"""
import argparse,base64,json,os,struct,subprocess,zlib
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from oracle_actor_control import ActorControl,held,d,digest,OBJECT
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EIP

class CatalogControl(ActorControl):
 def __init__(self,objects):
  self.objects=objects;self.current_mask=None
  super().__init__();self.uc.hook_add(UC_HOOK_MEM_READ,self.object_read,begin=OBJECT,end=OBJECT+0x3ffff)
 def object_bytes(self,item):
  assert not item.get('header') and not item.get('frames')
  raw,self.current_mask=self.objects[item['objectIndex']]
  return raw
 def object_read(self,uc,access,address,size,value,data):
  if not self.running:return
  offset=address-OBJECT
  assert offset>=0 and offset+size<=len(self.current_mask) and all(self.current_mask[offset:offset+size]),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(offset),size)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 path=ROOT/'build/original/actor-control-catalog.json';report_path=ROOT/'build/research/actor-control-catalog.json'
 parent=json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'][0]
 fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/parent['fixture'];assert digest(fixture.read_bytes())==parent['fixtureSHA256']
 if a.accept:
  report=json.loads(report_path.read_bytes());raw=path.read_bytes();assert len(raw)==report['bytes'] and digest(raw)==report['sha256']
 else:
  original=(ROOT/'build/original'/parent['corpus']).read_bytes();assert digest(original)==parent['corpusSHA256']
  catalog=json.loads(original)
  def blob(key):
   b=catalog['blobs'][key];v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(v)==b['count'] and digest(v)==key;return v
  objects={};bindings=[]
  for item in catalog['children']:
   if item['kind']!='object' or item['objectType']!=0:continue
   assert digest(read_bytes(DEFAULT_SOURCE/item['path'].replace('\\','/')))==item['source']
   raw=blob(item['storage']['bytes']);mask=blob(item['storage']['defined']);assert len(raw)==len(mask)==0x25360
   assert raw[0x7a4]!=0
   objects[item['index']]=(raw,mask);bindings.append({key:item[key] for key in ('index','id','path','source')})
  assert len(objects)==42;vm=CatalogControl(objects);cases=[]
  for index in objects:
   for mask in range(128):
    cases.append(vm.probe(dict(label=f'source-{index}-held-{mask}',objectIndex=index,group='source-frame0',actor=held(mask)),len(cases)))
   print('CATALOG CONTROL',index,'cases',len(cases),flush=True)
  doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,parent=dict(fixture=parent['fixture'],sha256=parent['fixtureSHA256']),
   bindings=bindings,header=[],states={},cases=cases,instructions=sorted(vm.instructions))
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
  report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),objects=len(objects),parent=doc['parent'],nativeCompared=False)
  report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  env=dict(os.environ,NTSD_ACTOR_CATALOG_CORPUS=str(path))
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalActorControlTests/testControlWithAllOriginalTypeZeroObjects'],env=env,check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  output=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-actor-control-catalog.json';output.write_bytes(packed)
  report.update(nativeCompared=True,fixture=output.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/actor-control-catalog.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
