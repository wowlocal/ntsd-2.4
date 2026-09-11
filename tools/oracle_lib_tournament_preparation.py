#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole Tournament434349 preparation through432ab0ret12/422ab8ret4.
Pinned NTSD EXE/lib/VC80/DAT/BMP/DIB, controlled Unicorn2.1.4/CW023f.
Actual constructors establish400 Actor/World provenance before fresh/controlled
menu calls; immutable accepted catalog producer supplies declared operand views.
Original CPU assignment, date sprintf, RNG, Actor/BG/input/recording and output
instructions execute with controlled allocator/GetLocalTime/COM/GDI responses.
Reads/stores/masks/FPU/helper/stack/ownership traces recover game compatibility.
No unknown after-state import, damaged control/protection structures, fault
continuation, Windows/device/own full-catalog or played-match claim. Finite
acceptance: LIB_TOURNAMENT_PREPARATION_PLAN.md. Preserve all original bytes and
failures; do not retry safety refusals or restart a live capture for silence.
"""
import argparse,base64,copy,datetime,json,os,struct,traceback,zlib
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_lib_tournament_bracket import TournamentBracket,tournament_inputs,sequence as bracket_sequence
from oracle_lib_selection_stage import arena_inputs
from oracle_lib_character_roster import CATALOG
from oracle_lib_menu_continuation import GLOBAL,GSIZE,SP,TAIL_SP,STACK,STOP,WORLD,LIB,BM,TARGET,REGISTERS,SPRINT,EXE_SHA256,DLL_SHA256,digest
from oracle_fresh_library_menu import BitmapAdapter
from oracle_bitmap_surface_loading import BitmapSurface,DEVICE
from import_ntsd import ROOT

BG_BASE,BG_SIZE=0x4d45db0,0x990
PREP_API,REPLAY,REPLAY_SIZE,WRAPPERS=0x33008000,0x75000020,0x630e18,0x76000020
CATALOG_FILE=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'
CATALOG_SHA='5fcd6e364a7761fcad4dc5af9792acf18e20b7bd9ff6ea89a66955c48a2af05e'

def catalog_input():
 raw=CATALOG_FILE.read_bytes();assert digest(raw)==CATALOG_SHA
 envelope=json.loads(raw);raw=zlib.decompress(base64.b64decode(envelope['deflate']),-15)
 assert len(raw)==envelope['count'] and digest(raw)==envelope['sha256']
 c=json.loads(raw);assert c['exeSHA256']==EXE_SHA256
 return c

def specifications():
 chain=bracket_sequence(False);chain[-1].pop('end');chain[0]['constructorParent']=True
 for s in chain:s['label']='preparation-'+s['label']
 # Actual declared user configuration and replay metadata, before any menu call.
 def metadata(s):
  s['globals'].update({0x450b90:1,0x450b94:0,0x45842c:0,0x450be4:0,0x44d03c:0})
  s['strings'].update({0x44fd18:'Tournament preservation',0x44f900:'Controlled reference',0x44f890:'NTSD 2.4'})
 metadata(chain[0]);out=chain
 for ordinal,arena in enumerate([*range(17),99,'random-ordinary','random-special']):
  s=copy.deepcopy(chain[0]);s['label']='controlled-preparation-'+str(arena);s['controlledPreparation']=True
  control=ordinal%2==1;s['control']=control
  human=7 if control else 0;cpu=ordinal%3 != 0
  g=s['globals'];g.update({0x44d020:27,0x4513e8:8,0x4513e4:0,0x4513dc:0,0x4513d8:3,0x4513d0:2,0x4513c8:0,0x4513cc:1,0x44d318:[0,2,4,6][ordinal%4],0x44d024:100 if isinstance(arena,str) else arena,0x44d028:int(isinstance(arena,str)),0x450be4:int(control),0x450b70:3 if control else 0})
  for i in range(8):g.update({0x44d0c0+i*4:17 if i==0 else 21,0x44d0e0+i*4:i,0x451364+i*4:0 if i==1 and cpu else i+1,0x451384+i*4:1 if i<2 else 0,0x44d080+i*4:500-i*41,0x44d0a0+i*4:-1 if i==0 else 4,0x451344+i*4:0})
  s['assigned']=[[human,0,17]]+([] if cpu else [[1,1,21]])
  for i in range(20):g[0x4512d0+i*4]=next((p for slot,p,_ in s['assigned'] if i==slot),-1)
  s['buttons']=[[i,0xca,0] for i in range(8)]
  s['localTime']=[2026,9,5,11,12,34,56,789] if not control else [7,1,0,2,3,4,5,0]
  if isinstance(arena,str):
   # A declared RNG cursor on the independently generated table chooses the
   # ordinary/special random-arena outcome; no result is installed after entry.
   seed=0xffffffff if control else 17;table=[]
   for _ in range(3000):seed=(seed*0x343fd+0x269ec3)&0xffffffff;table.append(((seed>>16)&0x7fff)%255+1)
   #417170 increments index/counter before loading the table byte.
   desired=14 if arena=='random-special' else 0
   g[0x450bcc]=next(i for i in range(3000) if (table[(i+1)%3000]+1)%15==desired);g[0x450c34]=0
   s['randomArenaExpectation']=99 if arena=='random-special' else 0
  out.append(s)
 return out

class PreparationBitmaps(BitmapAdapter):
 def __init__(self,owner):
  # Share the same controlled device state without creating/remapping it.
  self.__dict__=dict(owner.graphics.__dict__);self.owner=owner
  self.helpers=[];self.events=[];self.returns_resource=[];self.allocations_resource=[];self.checkpoints=[]
  self.rs=dict(kind='preparation');self.counts=copy.copy(owner.graphics.counts)
  self.images=copy.deepcopy(owner.graphics.images);self.surfaces=copy.deepcopy(owner.graphics.surfaces);self.dcs=copy.deepcopy(owner.graphics.dcs)
  self.loader_index=owner.graphics.loader_index;self.assets=owner.graphics.assets
 def append(self,e):self.events.append(e);self.owner.event('preparationBitmap',startup=e)
 def code(self,u,pc,n,data):
  self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP)
  if pc==0x4450ac:
   i=len(self.allocations_resource);assert i<30 and self.u32(sp+4)==0x1f50 and self.u32(sp)==0x40c08a
   p=WRAPPERS+i*0x2000;raw=b'\xa5'*0x1f50
   self.owner.uc.mem_write(p-16,b'\x96'*16);self.owner.uc.mem_write(p+len(raw),b'\x69'*16)
   self.owner.add_region(p,raw,False);self.owner.live[p]=True
   self.allocations_resource.append(dict(address=p,backing=self.blob(raw)))
   self.append(dict(kind='allocate',index=i,address=p,count=len(raw),storeCount=len(self.writes)));self.ret(p);return
  if pc==0x43ee50:
   i=len(self.allocations_resource)-1;p=u.reg_read(UC_X86_REG_ECX);path=self.cstr(self.u32(sp+8)).decode()
   assert p==self.allocations_resource[i]['address'] and self.u32(sp)==0x40c0a9
   self.append(dict(kind='construct',index=i,address=p,path=path,storeCount=len(self.writes)))
  BitmapSurface.code(self,u,pc,n,data)

class TournamentPreparation(TournamentBracket):
 def __init__(self,control,inputs,arenas,catalog):
  self.constructing=False;self.preparing=False;self.preparation_graphics=None
  super().__init__(control,inputs,arenas)
  self.catalog_dependency=catalog;self.preparation_points=[];self.bitmap_active=None
  for p,n in [(PREP_API,0x1000),(REPLAY&~0xffff,0x640000),(WRAPPERS&~0xffff,0x40000)]:
   assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions()),hex(p)
   self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
  self.put(0x4470a4,PREP_API);self.put(0x4471b0,PREP_API+16)
  def blob(k):
   b=catalog['blobs'][k];raw=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(raw)==b['count'] and digest(raw)==k;return raw
  for i in range(101):
   p=CATALOG+BG_BASE+i*BG_SIZE;r=catalog['regions'][str(BG_BASE+i*BG_SIZE)]
   for a in list(self.regions):
    if p<=a<p+BG_SIZE:del self.regions[a]
   self.add_region(p,blob(r['bytes']),False);self.regions[p]['mask']=bytearray(blob(r['defined']))
  objects=[c for c in catalog['children'] if c['kind']=='object'];assert len(objects)==137
  for item,c in zip(inputs['entries'],objects):
   b,m=blob(c['storage']['bytes']),blob(c['storage']['defined']);assert m[0x90:0x94]==b'\1'*4
   self.add_region(item['address']+0x90,b[0x90:0x94],True)
  # These spans remain exact PE initialized data/BSS. Make their provenance
  # explicit before executing constructors or menu, never at a consumer read.
  self.file_backed_inputs=[]
  for p,n in [(0x44d5f8,22*4*4),(0x44d324,11*4),(0x44eed0,52)]:
   raw=bytes(self.uc.mem_read(p,n));self.write(p,raw);self.file_backed_inputs.append(dict(address=p,bytes=raw.hex(),origin='original PE initialized data/BSS'))
  self.write(0x44f620,struct.pack('<I',catalog['checksum']))
  self.constructor_parent=self.construct_parent()
 def fpu(self):return dict(cw=self.uc.reg_read(UC_X86_REG_FPCW),sw=self.uc.reg_read(UC_X86_REG_FPSW),tag=self.uc.reg_read(UC_X86_REG_FPTAG))
 def construct_parent(self):
  self.constructing=True;self.running=True;self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.pcs={};out=[]
  self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
  for kind,p,entry in [('world',WORLD,0x419e40)]+[('actor',p,0x4061d0) for p in self.actors]:
   self.write(SP,struct.pack('<I',STOP));self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_ECX,p)
   saved=[self.uc.reg_read(r) for r in REGISTERS];first=len(self.writes);reads=len(self.reads);before=self.storage(p);fpu=self.fpu()
   self.uc.emu_start(entry,0,count=10000)
   assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and saved==[self.uc.reg_read(r) for r in REGISTERS]
   out.append(dict(kind=kind,address=p,entry=entry,before=before,after=self.storage(p),firstStore=first,lastStore=len(self.writes),firstRead=reads,lastRead=len(self.reads),fpuBefore=fpu,fpuAfter=self.fpu()))
  self.constructing=False;self.running=False
  return dict(calls=out,writes=self.writes,reads=self.reads,instructions=self.pcs)
 def code(self,u,pc,n,data):
  if self.constructing:
   if pc==STOP:u.emu_stop();return
   assert pc in self.crt.boundaries or 0x4061d0<=pc<=0x4064cc or 0x419e40<=pc<=0x419e5f or pc==0x4450a0 or 0x78130000<=pc<0x78230000,hex(pc)
   self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  if self.running and not self.prologue and self.startup_done:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x434349:
    assert sp==self.tournament_sp;self.point('tournament-'+hex(pc));self.points[-1]['locals']={str(o):self.u32(sp+o) for o in (0x20,0x24)}
    self.preparing=True;self.preparation_graphics=PreparationBitmaps(self)
   if self.preparing:
    g=self.preparation_graphics;g.finish(pc)
    while self.pending and pc==self.pending[-1]['returnPC']:
     h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
     h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
     if h['entry']==0x417170:self.event('random',[h['stream'],h['range'],h['result'],h['index'],h['counter'],self.u32(0x450bcc),self.u32(0x450c34)])
     if h['entry']==SPRINT:
      raw=self.cstr(h['destination']);assert len(raw)==h['result'];h['output']=raw.hex();self.event('format',[len(raw)],[bytes(h['format']),raw])
    if pc in (0x4343c3,0x43451d,0x434571,0x4346ec,0x434765,0x4347a6,0x4347ba):
     assert sp==self.tournament_sp-(12 if pc==0x4347ba else 0)
     self.point('preparation-'+hex(pc));self.points[-1].update(fpu=self.fpu(),name=None if pc==0x4343c3 else self.cstr(self.tournament_sp+0x80c).hex())
     if pc==0x4347ba:assert self.u32(sp+0x1c)==0x44d020
    if pc==0x4347c5:
     assert not g.helpers;self.preparing=False
     return super().code(u,pc,n,data)
    if 0x434349<=pc<0x4347c5:self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
    if pc in (0x4061d0,0x40c030,0x40c0e0,0x43d280,0x43d2c0,SPRINT) or pc==0x417170 and self.u32(sp+4) in (0xfd,0xfe,0xff):
     h=dict(entry=pc,entrySP=sp,pop=4 if pc in (0x40c030,0x40c0e0) else 0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events))
     if pc==0x4061d0:self.event('reconstruct',[self.actors.index(u.reg_read(UC_X86_REG_ECX))])
     if pc in (0x40c030,0x40c0e0):
      assert u.reg_read(UC_X86_REG_ECX)==CATALOG;self.event('loadLayers' if pc==0x40c030 else 'releaseLayers',[self.u32(sp+4)])
     if pc==0x417170:
      tag,limit=self.u32(sp+4),self.u32(sp+8);assert self.u32(sp)=={0xfd:0x43453f,0xfe:0x43465d,0xff:0x43469e}[tag]
      h.update(stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34))
     if pc==0x43d2c0:
      assert self.u32(sp)==0x4347ba and [self.u32(sp+8),self.u32(sp+12)]==[WORLD+4,WORLD+0x194];self.event('replayEntry',[self.u32(sp+4)])
     if pc==SPRINT:
      fmt=self.cstr(self.u32(sp+8));assert fmt in (b'%4d%02d%02d_%02d%02d%02d',b'%s.lfr');h.update(destination=self.u32(sp+4),format=list(fmt))
     self.pending.append(h);self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
    if pc==0x431c70:self.event('resetInput')
    if pc==PREP_API:
     assert self.u32(sp)==0x4343d8 and self.u32(sp+4)==self.tournament_sp+0x2c
     t=self.spec.get('localTime',[2026,9,5,11,12,34,56,789]);self.event('localTime',t);self.write(self.u32(sp+4),struct.pack('<8H',*t));self.ret(0,4);return
    if pc==PREP_API+16:
     assert self.u32(sp)==0x43d2de and [self.u32(sp+4),self.u32(sp+8)]==[1,REPLAY_SIZE] and REPLAY not in self.regions
     self.add_region(REPLAY,bytes(REPLAY_SIZE),True);self.live[REPLAY]=True;self.event('calloc',[REPLAY,1,REPLAY_SIZE]);self.ret(REPLAY);return
    if pc in g.api or pc in (0x4450ac,0x43ee50,0x43ed10,0x4013d0,g.memset) or g.helpers and (0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or 0x78130000<=pc<0x78230000 or 0x4450b2<=pc<=0x4450ba or pc==0x4450a0):return g.code(u,pc,n,data)
    if any(a<=pc<=b for a,b in [(0x4061d0,0x4064cc),(0x40c030,0x40c15e),(0x417170,0x4171bc),(0x43d280,0x43d29c),(0x43d2c0,0x43db38)]):self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)
 def complete_case(self,c):
  if self.preparation_graphics:
   g=self.preparation_graphics;c['preparationGraphics']=dict(events=g.events,allocations=g.allocations_resource,records=g.records(),helpers=g.returns_resource,images=g.images,surfaces=g.surfaces,dcs=g.dcs)
  else:c['preparationGraphics']=None
  return c
 def probe(self,spec):
  for slot,participant,object in spec.get('assigned',[]):
   self.write(WORLD+4+slot,b'\1');self.write(self.actors[slot]+0x368,struct.pack('<I',self.roster['entries'][object]['address']))
  return self.complete_case(super().probe(spec))
 def next_step(self,spec):return self.complete_case(super().next_step(spec))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');p.add_argument('--limit',type=int);p.add_argument('--controlled-only',action='store_true');a=p.parse_args()
 assert not a.output.exists();specs=[s for s in specifications() if not a.controlled_only or s.get('controlledPreparation')]
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={};parents=[]
 for number,s in enumerate(specs):
  if a.limit is not None and number>=a.limit:break
  if not s.get('chain'):
   vm=TournamentPreparation(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
   parents.append(dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
  c=vm.next_step(s) if s.get('chain') else vm.probe(s);c=json.loads(json.dumps(c))
  if 'randomArenaExpectation' in s:assert vm.u32(0x44d024)==s['randomArenaExpectation']
  temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents[-1:]),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);installations.append(vm.installation)
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
  print('completed',number,s['label'],c['end'],hex(c['endPC']),vm.u32(0x44d024),len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[b['address'] for b in catalog['bitmaps']],checksum=catalog['checksum']),parents=parents,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)

if __name__=='__main__':main()
