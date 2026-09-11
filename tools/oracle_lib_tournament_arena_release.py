#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Retained Tournament arenas through whole preparation and actual ret12/ret4.
Pinned NTSD EXE/lib/VC80 and original DAT/BMP/DIB, Unicorn2.1.4/CW023f.
Execute constructors, all302 live layer Release/free pairs, first-pointer clear,
fresh reloads and whole replay replacement with declared COM/time/allocator
responses. Trace reads/stores/masks/stack/ownership to recover compatibility.
Between calls only explicit menu/arena/button/ABI stimuli change. No played
intervening fight, Windows/device/heap claim, unknown after-state import,
damaged control/protection structures or fault continuation. Preserve failures;
never retry safety refusals or restart live jobs for silence. Finite scope:
LIB_TOURNAMENT_ARENA_RELEASE_PLAN.md. No reference binaries in shipping runtime.
"""
from oracle_lib_tournament_preparation import *
from oracle_lib_tournament_preparation import specifications as preparation_specs

def specifications():
 out=[]
 for ordinal,s in enumerate(s for s in preparation_specs() if s.get('controlledPreparation')):
  if ordinal==17:break
  s=copy.deepcopy(s);s['label']='arena-release-'+str(ordinal)+'-load';s['releaseResult']=[0,1,17,-1][ordinal%4];s['generation']=0
  out.append(s)
  for generation,arena in [(1,99),(2,ordinal)]:
   out.append(dict(label='arena-release-'+str(ordinal)+('-release' if generation==1 else '-reload'),control=s['control'],chain=True,
    generation=generation,buttons=[],localTime=s['localTime'],releaseResult=s['releaseResult'],
    bridgeGlobals={0x44d020:27,0x44d024:arena,0x44d028:0},bridgeScope='Declared next confirmation, with all produced resource/game state retained; no intervening fight claim'))
 assert len(out)==51
 return out

class LifetimeBitmaps(PreparationBitmaps):
 def __init__(self,owner,previous):
  super().__init__(owner)
  self.history=[]
  if previous:
   for key in ['counts','images','surfaces','dcs','allocations_resource']:setattr(self,key,copy.deepcopy(getattr(previous,key)))
   self.loader_index=previous.loader_index
   self.history=copy.deepcopy(previous.history+previous.returns_resource)
  self.allocation_start=len(self.allocations_resource)
 def resource_request(self,name,*args,**kwargs):
  e=super().resource_request(name,*args,**kwargs)
  if name=='release':e['response']['result']=self.owner.spec['releaseResult']
  return e
 def code(self,u,pc,n,data):
  if pc==0x4450ac:
   self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP);i=len(self.allocations_resource)
   assert i<60 and self.u32(sp+4)==0x1f50 and self.u32(sp)==0x40c08a
   p=WRAPPERS+i*0x2000;raw=b'\xa5'*0x1f50;assert p not in self.owner.regions
   self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+len(raw),b'\x69'*16)
   self.owner.add_region(p,raw,False);self.owner.live[p]=True
   self.allocations_resource.append(dict(address=p,backing=self.blob(raw)))
   self.append(dict(kind='allocate',index=i,address=p,count=len(raw),storeCount=len(self.writes)));self.ret(p);return
  return super().code(u,pc,n,data)

class TournamentArenaRelease(TournamentPreparation):
 def __init__(self,*args):
  super().__init__(*args)
  for p,n in [(0x76040000,0x40000),(0x77000000,0xc80000)]:
   assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions()),hex(p)
   self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done:
   if pc==0x434349:
    previous=self.preparation_graphics
    super().code(u,pc,n,data)
    self.preparation_graphics=LifetimeBitmaps(self,previous);return
   if self.preparing:
    sp=u.reg_read(UC_X86_REG_ESP)
    if pc==self.u32(0x44717c) and self.u32(sp)==0x40c125:
     p=self.u32(sp+4);g=self.preparation_graphics
     assert self.live[p] and p in [a['address'] for a in g.allocations_resource]
     surface=self.u32(p);assert g.surfaces[surface]['released']
     e=g.resource_request('free',[p]);self.live[p]=False;g.respond(e);return
    if pc==PREP_API+16:
     assert self.u32(sp)==0x43d2de and [self.u32(sp+4),self.u32(sp+8)]==[1,REPLAY_SIZE]
     generation=self.spec['generation'];p=REPLAY if generation==0 else 0x77000020+(generation-1)*0x640000
     assert p not in self.regions
     self.add_region(p,bytes(REPLAY_SIZE),True);self.live[p]=True;self.event('calloc',[p,1,REPLAY_SIZE]);self.ret(p);return
  return super().code(u,pc,n,data)
 def complete_case(self,c):
  c=super().complete_case(c)
  if self.preparation_graphics:
   g=self.preparation_graphics
   c['preparationGraphics'].update(allocationStart=g.allocation_start,constructionHistory=g.history+g.returns_resource,
    wrapperLive={str(a['address']):self.live[a['address']] for a in g.allocations_resource})
  c['replayAddress']=self.u32(0x4588a8)
  return c
 def next_step(self,spec):
  assert self.end=='returned';self.running=False;before=self.snapshot();changes=[]
  for p,v in spec['bridgeGlobals'].items():
   raw=struct.pack('<I',v);self.write(p,raw);changes.append(dict(address=p,bytes=raw.hex()))
  c=super().next_step(spec);c['bridge']=dict(before=before,writes=changes,scope=spec['bridgeScope']);return c

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args()
 assert not a.output.exists();specs=specifications()
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={};parents=[]
 for number,s in enumerate(specs):
  if a.limit is not None and number>=a.limit:break
  if not s.get('chain'):
   vm=TournamentArenaRelease(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
   parents.append(dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
  c=vm.next_step(s) if s.get('chain') else vm.probe(s);c=json.loads(json.dumps(c))
  temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents[-1:]),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);installations.append(vm.installation)
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
  print('completed',number,s['label'],c['end'],hex(c['endPC']),vm.u32(0x44d024),len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[b['address'] for b in catalog['bitmaps']],checksum=catalog['checksum']),parents=parents,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)

if __name__=='__main__':main()
