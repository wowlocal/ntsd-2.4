#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole War preparation256-call/56-preparation controlled success matrix.
Pinned NTSD EXE/lib/VC80/resources, Unicorn2.1.4/CW023f/C locale and normal APIs.
Twenty fresh original401-constructor chains reproduce forty resource/ready
parent calls, then actual live Random and Start. Declared ordinary settings,
participant/team/multiplier and RNG entry inputs vary fixed/random arenas and
sparse seats. Retain all memory/stack/FPU/store/read/helper evidence, bitmap
Release/free/reload and recording replacement through ret1c/ret4. Synthetic
mapping/allocator ownership is separate from real Windows/host/device behavior.
No control/protection corruption, unknown after-state import, source-fault
continuation or Native/full-game claim. Preserve completed22-call preflight and
all failures; never restart for silence. LIB_WAR_PREPARATION_MATRIX_PLAN.md and
LIB_WAR_PREPARATION_MATRIX_INPUTS.md freeze the finite boundary before capture.
LIB_WAR_PREPARATION_MATRIX_LIFETIMES.md corrects the synthetic arena reserve:
at most30 wrappers per load,60 retained allocations across load/99/reload.
"""
import argparse,copy,datetime,hashlib,json,os,shutil,struct
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_lib_war_preparation_bound import BoundWarPreparation,specifications as preflight_specs
from oracle_lib_war_preparation import WarArenaBitmaps,WarPreparation,tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_preparation import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP,REPLAY,REGISTERS
from oracle_lib_team_tournament_preparation import PREP_API,REPLAY_SIZE


def specifications():
 out=[];parents=preflight_specs()
 for j,arena in enumerate([*range(17),99,'random-ordinary','random-special']):
  control=j%2==1;chain=copy.deepcopy(parents[11:22] if control else parents[:11]);first=len(out)
  for i,s in enumerate(chain[2:],2):
   s['label']='war-matrix-'+str(arena)+'-'+str(i);s['generation']=0;s['matrixOrdinal']=j
  start=chain[-1];words={0x44d028:int(isinstance(arena,str))};inputs=dict(words=words)
  if isinstance(arena,int):
   words.update({0x44d024:arena,0x44d758:100+50*(j%5),0x44d75c:100+50*((j+2)%5)})
   seats=[dict(seat=0,status=3,team=1),dict(seat=1,status=13,team=2)]
   seats += [dict(seat=i,status=[0,3,13][(j+i)%3],team=1+(j+i)%2) for i in range(2,8)]
   inputs['seats']=seats;start['arenaExpectation']=arena
  else:
   # Same declared VC80 table producer as the accepted parents. Supply only
   # its ordinary index/counter inputs; the actual417170 return is observed.
   seed=0xffffffff if control else 17;table=[]
   for _ in range(3000):
    seed=(seed*0x343fd+0x269ec3)&0xffffffff;table.append(((seed>>16)&0x7fff)%255+1)
   desired=14 if arena=='random-special' else 0
   index=next(i for i in range(3000) if (table[(i+1)%3000]+1)%15==desired)
   words.update({0x450bcc:index,0x450c34:0});start['arenaExpectation']=99 if desired==14 else desired
   start['randomArenaInput']=dict(index=index,counter=0,range=15,result=desired)
  start['matrixInputs']=inputs;out+=chain
  if isinstance(arena,int):
   for generation,target in [(1,99),(2,arena)]:
    out.append(dict(label='war-matrix-'+str(arena)+('-release' if generation==1 else '-reload'),control=control,chain=True,
     buttons=[[0,0xd1,1]],localTime=[2026,9,5,11,12,34,56,789],expectedPreparation=True,generation=generation,matrixOrdinal=j,
     arenaExpectation=target,matrixInputs=dict(words={0x44d020:202,0x451b84:0,0x44d024:target,0x44d028:0})))
  assert len(out)-first==(13 if isinstance(arena,int) else 11)
 assert len(out)==256 and sum(s.get('expectedPreparation',False) for s in out)==56
 return out


class WarLifetimeBitmaps(WarArenaBitmaps):
 def __init__(self,owner,previous):
  super().__init__(owner);self.history=[]
  if previous:
   for key in ['counts','images','surfaces','dcs','allocations_resource']:setattr(self,key,copy.deepcopy(getattr(previous,key)))
   self.loader_index=previous.loader_index;self.history=copy.deepcopy(previous.history+previous.returns_resource)
  self.allocation_start=len(self.allocations_resource)
 def code(self,u,pc,n,data):
  if pc==0x4450ac:
   self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP);i=len(self.allocations_resource)
   assert i<60 and self.u32(sp+4)==0x1f50 and self.u32(sp)==0x40c08a
   p=0x76004020+i*0x2000;raw=b'\xa5'*0x1f50
   assert p not in self.owner.regions and p not in [a['address'] for a in self.owner.war_graphics.allocations_resource]
   self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+len(raw),b'\x69'*16)
   self.owner.add_region(p,raw,False);self.owner.live[p]=True
   self.allocations_resource.append(dict(address=p,backing=self.blob(raw)))
   self.append(dict(kind='allocate',index=i,address=p,count=len(raw),storeCount=len(self.writes)));self.ret(p);return
  return super().code(u,pc,n,data)


class WarPreparationMatrix(BoundWarPreparation):
 def __init__(self,*args):
  super().__init__(*args)
  # Distinct declared recording allocations for the two later generations.
  # Preserve the first6.5MB allocation and all freed bytes/masks as tombstones.
  # Extend the arena reserve without rewriting its old mapping or dead owners.
  for p,n in [(0x77000000,0xc80000),(0x76040000,0x40000)]:
   assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions()),hex(p)
   self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done and not self.constructing:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x43a21f:
    previous=self.preparation_graphics
    assert not self.preparing
    self.preparation_seen=False
    super().code(u,pc,n,data)
    self.preparation_graphics=WarLifetimeBitmaps(self,previous)
    return
   if self.preparing:
    if pc==self.u32(0x44717c) and self.u32(sp)==0x40c125:
     self.finish_war(pc);g=self.preparation_graphics;g.finish(pc)
     p=self.u32(sp+4);assert self.live[p] and p in [a['address'] for a in g.allocations_resource]
     surface=self.u32(p);assert g.surfaces[surface]['released']
     e=g.resource_request('free',[p]);self.live[p]=False;g.respond(e);return
    if pc==PREP_API+16:
     assert self.u32(sp)==0x43d2de and [self.u32(sp+4),self.u32(sp+8)]==[1,REPLAY_SIZE]
     generation=self.spec['generation'];assert generation in (0,1,2)
     p=REPLAY if generation==0 else 0x77000020+(generation-1)*0x640000
     assert p not in self.regions
     self.add_region(p,bytes(REPLAY_SIZE),True);self.live[p]=True;self.event('calloc',[p,1,REPLAY_SIZE]);self.ret(p);return
    if pc in (0x43a4a8,0x43a5f2,0x43a553,0x43a6a8):
     assert sp==self.war_sp
     self.point('war-preparation-numeric-'+hex(pc));self.points[-1].update(fpu=self.fpu(),seat=self.u32(self.war_sp+0x20))
  return super().code(u,pc,n,data)
 def next_step(self,spec):
  changes=[]
  if 'matrixInputs' in spec:
   assert self.end=='returned' and not self.running and not self.preparing
   inputs=spec['matrixInputs'];allowed={0x44d020,0x451b84,0x44d024,0x44d028,0x44d758,0x44d75c,0x450bcc,0x450c34}
   for p,value in inputs['words'].items():
    assert p in allowed
    raw=struct.pack('<I',value);self.write(p,raw);changes.append(dict(address=p,bytes=raw.hex()))
   if inputs.get('seats'):
    assert spec['generation']==0 and len(inputs['seats'])==8
    for row in inputs['seats']:
     seat=row['seat'];assert seat in range(8) and row['status'] in (0,3,13) and row['team'] in (1,2)
     ordinal=self.u32(0x451248+4*seat);assert ordinal in range(len(self.roster['entries']))
     assert self.u32(self.actors[seat]+0x368)==self.roster['entries'][ordinal]['address']
     for p,value in [(0x451288+seat*4,row['status']),(self.actors[seat]+0x364,row['team'])]:
      raw=struct.pack('<I',value);self.write(p,raw);changes.append(dict(address=p,bytes=raw.hex()))
  result=super().next_step(spec)
  if 'matrixInputs' in spec:result['matrixInputBridge']=changes
  return result
 def complete_case(self,c):
  c=super().complete_case(c)
  if self.preparation_seen:
   g=self.preparation_graphics
   c['preparationGraphics'].update(allocationStart=g.allocation_start,constructionHistory=g.history+g.returns_resource)
  return c


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');a=p.parse_args()
 assert not a.output.exists();specs=specifications()
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input()
 parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];paths=[];parent_index=0
 canonical=lambda x:json.dumps(x,separators=(',',':')).encode()
 counts=dict(calls=0,parentsReproduced=0,capture1CallsReproduced=0,preparations=0,participants=0,cpu=0,human=0)
 for number,s in enumerate(specs):
  assert shutil.disk_usage(parts).free>6*1024**3,'researchStorageLimit: preserve6GiB reserve'
  if not s.get('chain'):
   vm=WarPreparationMatrix(s['control'],inputs,arenas,catalog);vm.capture_path=a.output;parent_index=number
   parents.append(dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
  c=vm.next_step(s) if s.get('chain') else vm.probe(s)
  assert c['end']=='returned';counts['calls']+=1
  temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json')
  with temp.open('w') as f:json.dump(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents[-1:]),f,separators=(',',':'));f.write('\n')
  os.replace(temp,part);paths.append(part);installations.append(copy.deepcopy(vm.installation))
  if number<25:
   old=ROOT/'build/research/lib-war-preparation/war-preparation-matrix-capture1.parts'/f'{number:04d}.json'
   assert part.read_bytes()==old.read_bytes(),(number,'exact complete capture1 part')
   counts['capture1CallsReproduced']+=1
  if number-parent_index<2:
   old_number=(11 if s['control'] else 0)+number-parent_index
   old=json.loads((ROOT/'build/research/lib-war-preparation/war-preparation-bound-capture1.parts'/f'{old_number:04d}.json').read_bytes())
   assert canonical(c)==canonical(old['case']),(number,'exact accepted resource/ready parent')
   old_parent=copy.deepcopy(old['parents']);old_parent[0]['firstCase']=parent_index
   assert canonical(parents[-1:])==canonical(old_parent),(number,'exact401-constructor parent')
   counts['parentsReproduced']+=1
  if s.get('expectedPreparation'):
   assert vm.preparation_seen and not vm.preparing and vm.u32(0x44d024)==s['arenaExpectation']
   assert sum(h['entry']==0x43d2c0 for h in c['helpers'])==1
   active=[]
   for seat in range(8):
    status=vm.u32(0x451288+4*seat)
    if status:
     cpu=status>10;active.append(seat+10 if cpu else seat);counts['cpu' if cpu else 'human']+=1
   assert [i for i,v in enumerate(bytes(vm.uc.mem_read(WORLD+4,400))) if v]==sorted(active)
   if s.get('randomArenaInput'):
    actual=next(h for h in c['helpers'] if h.get('stream')==0x123)
    for key,value in s['randomArenaInput'].items():assert actual[key]==value,(number,key,actual[key],value)
   counts['preparations']+=1;counts['participants']+=len(active)
  for key,value in vm.blobs.items():assert key not in blobs or blobs[key]==value;blobs[key]=value
  for key,value in vm.graphics.assets.items():assert key not in assets or assets[key]==value;assets[key]=value
  print('completed',number,s['label'],'generation',s.get('generation'),hex(c['endPC']),vm.u32(0x44d024),len(c['events']),flush=True)
 assert counts==dict(calls=256,parentsReproduced=40,capture1CallsReproduced=25,preparations=56,participants=340,cpu=168,human=172)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,
  catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[v['address'] for v in catalog['bitmaps']],checksum=catalog['checksum']),
  parents=parents,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,counts=counts,nativeCompared=False,windowsVerified=False)
 temp=a.output.with_suffix('.tmp')
 with temp.open('w') as f:
  f.write('{"cases":[')
  for i,part in enumerate(paths):
   if i:f.write(',')
   item=json.loads(part.read_bytes());json.dump(item['case'],f,separators=(',',':'))
  f.write(']')
  for key,value in d.items():f.write(','+json.dumps(key)+':');json.dump(value,f,separators=(',',':'))
  f.write('}\n')
 os.replace(temp,a.output);h=hashlib.sha256()
 with a.output.open('rb') as f:
  for raw in iter(lambda:f.read(8*1024*1024),b''):h.update(raw)
 print(dict(counts=counts,bytes=a.output.stat().st_size,sha256=h.hexdigest()),flush=True)

if __name__=='__main__':main()
