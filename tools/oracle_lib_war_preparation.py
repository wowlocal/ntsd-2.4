#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""War43a21f first preparation through whole439ecd ret1c/422ab8 ret4.
Pinned NTSD EXE/lib/VC80, original DAT/BMP/DIB, controlled Unicorn2.1.4/CW023f,
C locale and declared normal allocator/GetLocalTime/COM/GDI/music responses.
Two11-call chains reproduce four accepted setup parent calls, use ordinary
settings/Random/Up/Start keys, then execute Actor/arena/music/input/recording.
Full instruction/read/store/mask/stack/FPU/helper/ownership traces recover
pending arguments, CPU/human destinations and intermediate numeric writes.
Synthetic arena wrappers/device identifiers have separate live ownership.
No unknown after-state import, damaged pointers/protection structures, source
fault continuation, Windows/device/played battle or Native-equivalence claim.
LIB_WAR_PREPARATION_PARENT_PLAN.md freezes this22-call preflight; preserve all
completed setup corpora and every new failure. Never restart for silence.
"""
import argparse,copy,datetime,hashlib,json,os,shutil,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_lib_war_setup import WarSetup,specifications as setup_specifications
from oracle_lib_war_setup import tournament_inputs,arena_inputs,catalog_input,CATALOG_FILE,CATALOG_SHA
from oracle_lib_war_setup import ROOT,EXE_SHA256,DLL_SHA256,WORLD,BM,TARGET,LIB,STACK,SP,TAIL_SP,REGISTERS,SPRINT
from oracle_lib_team_tournament_preparation import PreparationBitmaps,PREP_API,REPLAY,REPLAY_SIZE,WRAPPERS
from oracle_lib_character_roster import CATALOG
from oracle_lib_team_tournament_bracket import TeamTournamentBracket
from oracle_bitmap_surface_loading import BitmapSurface


def specifications():
 out=[];old=setup_specifications()
 for control in (False,True):
  parents=old[412:414] if control else old[:2];out.extend(copy.deepcopy(parents))
  suffix='-control' if control else ''
  def edge(label,button):
   for action,value in [('press',1),('release',0)]:
    out.append(dict(label='war-preparation-'+label+'-'+action+suffix,control=control,chain=True,buttons=[[0,button,value]]))
  edge('settings',0xd1);edge('random',0xd1)
  edge('start-up1',0xcd);edge('start-up0',0xcd)
  out.append(dict(label='war-preparation-start'+suffix,control=control,chain=True,buttons=[[0,0xd1,1]],
   localTime=[2026,9,5,11,12,34,56,789],expectedPreparation=True))
 assert len(out)==22
 return out


class WarArenaBitmaps(PreparationBitmaps):
 def __init__(self,owner):
  super().__init__(owner)
  # The original menu and War resources already own device identifiers.
  # Preserve that synthetic device's counters while allocating distinct arena
  # wrapper addresses; never overwrite either live War bitmap.
  previous=owner.war_graphics
  assert previous is not None and len(previous.allocations_resource)==2
  for key in ['counts','images','surfaces','dcs']:setattr(self,key,copy.deepcopy(getattr(previous,key)))
  self.loader_index=previous.loader_index
  self.rs=dict(kind='war-preparation')
 def code(self,u,pc,n,data):
  if pc==0x4450ac:
   self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP);i=len(self.allocations_resource)
   assert i<30 and self.u32(sp+4)==0x1f50 and self.u32(sp)==0x40c08a
   p=WRAPPERS+0x4000+i*0x2000;raw=b'\xa5'*0x1f50
   assert p not in self.owner.regions and p not in [a['address'] for a in self.owner.war_graphics.allocations_resource]
   self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+len(raw),b'\x69'*16)
   self.owner.add_region(p,raw,False);self.owner.live[p]=True
   self.allocations_resource.append(dict(address=p,backing=self.blob(raw)))
   self.append(dict(kind='allocate',index=i,address=p,count=len(raw),storeCount=len(self.writes)));self.ret(p);return
  if pc==0x43ee50:
   i=len(self.allocations_resource)-1;p=u.reg_read(UC_X86_REG_ECX);sp=u.reg_read(UC_X86_REG_ESP);path=self.cstr(self.u32(sp+8)).decode()
   assert p==self.allocations_resource[i]['address'] and self.u32(sp)==0x40c0a9
   self.append(dict(kind='construct',index=i,address=p,path=path,storeCount=len(self.writes)))
   return BitmapSurface.code(self,u,pc,n,data)
  return super().code(u,pc,n,data)


class WarPreparation(WarSetup):
 def __init__(self,*args):
  self.preparation_seen=False
  super().__init__(*args)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done and not self.constructing:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x43a21f:
    self.finish_war(pc)
    assert sp==self.war_sp and [h['entry'] for h in self.pending]==[0x429730,0x438b40]
    assert not self.war_graphics.helpers and not self.preparation_seen
    self.point('war-'+hex(pc));self.points[-1]['fpu']=self.fpu()
    self.preparing=True;self.preparation_seen=True;self.preparation_graphics=WarArenaBitmaps(self)
   if self.preparing:
    self.finish_war(pc);g=self.preparation_graphics;g.finish(pc)
    checkpoints={0x43a21f:0,0x43a2b6:0,0x43a305:0,0x43a3b1:0,0x43a42d:0,0x43a450:0,
      0x43a47b:0,0x43a5c1:0,0x43a70c:0,0x43a727:0,0x43a74d:0,0x43a766:12,0x43a769:0}
    if pc in checkpoints:
     assert sp==self.war_sp-checkpoints[pc],(hex(pc),hex(sp),hex(self.war_sp))
     self.point('war-preparation-'+hex(pc));self.points[-1].update(fpu=self.fpu(),
      locals={str(o):self.u32(self.war_sp+o) for o in (0x1c,0x28,0x2c,0x38,0x3c)},
      name=None if pc==0x43a21f else self.cstr(self.war_sp+0x84c).hex())
    if 0x43a21f<=pc<0x43a76e:
     self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex()
     if pc==0x43a769:
      assert not g.helpers and [h['entry'] for h in self.pending]==[0x429730,0x438b40]
      self.preparing=False
     return
    # Resume may construct the selected music graph, whose nested sprintf
    # belongs to the already recovered music observer and its CRT tracking.
    if self.current_graph or pc==SPRINT and self.music.music_pending:
     return TeamTournamentBracket.code(self,u,pc,n,data)
    if pc in (0x4061d0,0x40c030,0x40c0e0,0x43d280,0x43d2c0,SPRINT) or pc==0x417170 and self.u32(sp+4) in (0x123,0x125,0x127):
     h=dict(entry=pc,entrySP=sp,pop=4 if pc in (0x40c030,0x40c0e0) else 0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events))
     if pc==0x4061d0:self.event('reconstruct',[self.actors.index(u.reg_read(UC_X86_REG_ECX))])
     if pc in (0x40c030,0x40c0e0):
      assert u.reg_read(UC_X86_REG_ECX)==CATALOG;self.event('loadLayers' if pc==0x40c030 else 'releaseLayers',[self.u32(sp+4)])
     if pc==0x417170:
      tag,limit=self.u32(sp+4),self.u32(sp+8);assert self.u32(sp)=={0x123:0x43a2d9,0x125:0x43a52b,0x127:0x43a66f}[tag]
      h.update(stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34))
     if pc==0x43d2c0:
      assert self.u32(sp)==0x43a766 and [self.u32(sp+4),self.u32(sp+8),self.u32(sp+12)]==[4,WORLD+4,WORLD+0x194]
      self.event('replayEntry',[self.u32(sp+4)])
     if pc==SPRINT:
      fmt=self.cstr(self.u32(sp+8));assert fmt in (b'%4d%02d%02d_%02d%02d%02d_Battle',b'%s.lfr')
      h.update(destination=self.u32(sp+4),format=list(fmt))
     self.pending.append(h);self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
    if pc==0x4450c8:
     # A stage-track name may need more than the parent's reserved26 bytes.
     # Supply a fresh controlled allocation at a distinct address; retain the
     # inactive parent reservation and all live buffers, bytes and masks.
     count=self.u32(sp+4);assert self.u32(sp)==0x401e36 and not self.music.music_input['nullAllocation']
     entry=next(e for e in reversed(self.body_music_events) if e['kind']=='helper' and e['arguments']==[0x401da0])
     assert count==2*(len(entry['strings'][0])+1) and 0<count<0x1000
     p=self.music.music_arena+0x20020+len(self.music.music_allocations)*0x1000
     assert p not in self.regions
     raw=bytes(i%256 for i in range(count)) if self.control else b'\xa5'*count
     self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+count,b'\x69'*16)
     self.add_region(p,raw,False);self.live[p]=True
     self.music.music_allocations.append(dict(address=p,size=count,kind='music-wide',initial=raw))
     self.music.mevent('allocate',[count],pointer=p,raw=raw);self.ret(p);return
    if pc==PREP_API:
     assert self.u32(sp)==0x43a23c and self.u32(sp+4)==self.war_sp+0x40
     t=self.spec['localTime'];self.event('localTime',t);self.write(self.u32(sp+4),struct.pack('<8H',*t));self.ret(0,4);return
    if pc==PREP_API+16:
     assert self.u32(sp)==0x43d2de and [self.u32(sp+4),self.u32(sp+8)]==[1,REPLAY_SIZE] and REPLAY not in self.regions
     self.add_region(REPLAY,bytes(REPLAY_SIZE),True);self.live[REPLAY]=True
     self.event('calloc',[REPLAY,1,REPLAY_SIZE]);self.ret(REPLAY);return
    if pc in g.api or pc in (0x4450ac,0x43ee50,0x43ed10,0x4013d0,g.memset) or g.helpers and (0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or 0x78130000<=pc<0x78230000 or 0x4450b2<=pc<=0x4450ba or pc==0x4450a0):
     return g.code(u,pc,n,data)
    if any(a<=pc<=b for a,b in [(0x4061d0,0x4064cc),(0x40c030,0x40c15e),(0x417170,0x4171bc),(0x43d280,0x43d29c),(0x43d2c0,0x43db38)]):
     self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)
 def complete_case(self,c):
  c=WarSetup.complete_case(self,c)
  if self.preparation_seen:
   g=self.preparation_graphics
   c['preparationGraphics']=dict(events=g.events,allocations=g.allocations_resource,records=g.records(),helpers=g.returns_resource,
    images=g.images,surfaces=g.surfaces,dcs=g.dcs,wrapperLive={str(a['address']):self.live[a['address']] for a in g.allocations_resource})
   c['replayAddress']=self.u32(0x4588a8)
  return c


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
   vm=WarPreparation(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
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
  if number<10:
   first=json.loads((ROOT/'build/research/lib-war-preparation/war-preparation-parent-capture1.parts'/f'{number:04d}.json').read_bytes())
   assert canonical(c)==canonical(first['case']),(number,'preserved first-capture complete call')
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
