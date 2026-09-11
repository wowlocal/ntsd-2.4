#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Bound-input War preparation22-call controlled original continuation.
Same pinned NTSD EXE/lib/VC80/resources and Unicorn2.1.4/CW023f as the completed
unbound capture3. Reproduce four original resource/ready parents, then supply
explicit phase/input-control/recording-notice and metadata-string inputs before
each third call. Record these input writes separately from original stores.
Execute actual43a21f Actor/arena/music/input/recording through ret1c/ret4; full
read/store/mask/FPU/helper/ownership traces establish comparison provenance.
LIB_WAR_PREPARATION_INPUTS.md declares this correction. Preserve old unknown
masks, source/tool failures and completed captures; no source fault continuation,
control/protection corruption, Windows/device/own-startup or Native-match claim.
"""
import argparse,copy,datetime,hashlib,json,os,shutil,struct
from pathlib import Path
from oracle_lib_war_preparation import WarPreparation,specifications as parent_specifications
from oracle_lib_war_preparation import tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_preparation import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP,REPLAY


def specifications():
 out=copy.deepcopy(parent_specifications())
 for index in (2,13):
  out[index]['preparationInputs']=dict(words={0x450b90:1,0x450b94:0,0x45842c:0,0x450be4:int(out[index]['control'])},
   strings={0x44fd18:'War preservation',0x44f900:'Controlled reference',0x44f890:'NTSD 2.4'})
 return out


class BoundWarPreparation(WarPreparation):
 def next_step(self,spec):
  inputs=spec.get('preparationInputs');writes=[]
  if inputs:
   assert self.end=='returned' and not self.running and not self.preparation_seen
   assert set(inputs['words'])=={0x450b90,0x450b94,0x45842c,0x450be4}
   assert set(inputs['strings'])=={0x44fd18,0x44f900,0x44f890}
   for address,value in inputs['words'].items():
    raw=struct.pack('<I',value);self.write(address,raw);writes.append(dict(address=address,bytes=raw.hex()))
   for address,text in inputs['strings'].items():
    raw=text.encode('ascii')+b'\0';assert len(raw)<100
    self.write(address,raw);writes.append(dict(address=address,bytes=raw.hex()))
  result=super().next_step(spec)
  if inputs:result['preparationInputBridge']=writes
  return result


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
 assert not a.output.exists();specs=specifications()
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input()
 parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];case_paths=[]
 canonical=lambda x:json.dumps(x,separators=(',',':')).encode()
 for number,s in enumerate(specs):
  assert shutil.disk_usage(parts).free>6*1024**3,'researchStorageLimit: preserve6GiB reserve'
  if not s.get('chain'):
   vm=BoundWarPreparation(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
   parents.append(dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
  c=vm.next_step(s) if s.get('chain') else vm.probe(s)
  assert c['end']=='returned'
  temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json')
  with temp.open('w') as f:json.dump(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents[-1:]),f,separators=(',',':'));f.write('\n')
  os.replace(temp,part);case_paths.append(part);installations.append(copy.deepcopy(vm.installation))
  if number in (0,1,11,12):
   old_number={0:0,1:1,11:412,12:413}[number]
   old=json.loads((ROOT/'build/research/lib-war/lib-war-capture2.parts'/f'{old_number:04d}.json').read_bytes())
   assert canonical(c)==canonical(old['case']),(number,'exact source2 parent call reproduction')
   old_parent=copy.deepcopy(old['parents']);old_parent[0]['firstCase']=11 if s['control'] else 0
   assert canonical(parents[-1:])==canonical(old_parent),(number,'constructor parent reproduction')
  if s.get('expectedPreparation'):
   assert vm.preparation_seen and not vm.preparing and c['replayAddress']==REPLAY
   assert sum(h['entry']==0x43d2c0 for h in c['helpers'])==1
   assert bytes(vm.uc.mem_read(WORLD+4,400)).count(1)==8
  for key,value in vm.blobs.items():assert key not in blobs or blobs[key]==value;blobs[key]=value
  for key,value in vm.graphics.assets.items():assert key not in assets or assets[key]==value;assets[key]=value
  print('completed',number,s['label'],c['end'],hex(c['endPC']),vm.u32(0x44d024),len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,
  catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[b['address'] for b in catalog['bitmaps']],checksum=catalog['checksum']),
  parents=parents,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 temp=a.output.with_suffix('.tmp')
 with temp.open('w') as f:
  f.write('{"cases":[')
  for i,part in enumerate(case_paths):
   if i:f.write(',')
   document=json.loads(part.read_bytes());json.dump(document['case'],f,separators=(',',':'))
  f.write(']')
  for key,value in d.items():f.write(','+json.dumps(key)+':');json.dump(value,f,separators=(',',':'))
  f.write('}\n')
 os.replace(temp,a.output);h=hashlib.sha256()
 with a.output.open('rb') as f:
  for raw in iter(lambda:f.read(8*1024*1024),b''):h.update(raw)
 print(dict(cases=len(case_paths),bytes=a.output.stat().st_size,sha256=h.hexdigest()),flush=True)

if __name__=='__main__':main()
