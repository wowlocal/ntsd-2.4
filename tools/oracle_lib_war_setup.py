#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole War438b40 setup/4389a0/438ad0 through439ecd ret1c/422ab8 ret4.
Pinned NTSD EXE/lib/VC80/raw DAT/BMP/DIBs; controlled Unicorn2.1.4/CW023f,
ordinary allocator/COM/GDI/music responses. Actual World/400Actor constructors
establish parent provenance before declared ready menu200 entries. Actual
41bc90 prologue,4229cc tail and installed lib output execute on one CPU.
Full read/store/mask/stack/register/helper/REP/resource traces recover troop
presets, live Random lists and same-call output/input order. Start stops BEFORE
43a21f preparation. No Windows/device/full app/played battle claim, unknown
after-state import, damaged control/protection structures or fault continuation.
LIB_WAR_SETUP_PLAN.md freezes scope; preserve failures and completed calls.
"""
import argparse,base64,copy,datetime,hashlib,json,os,struct,traceback,zlib
from pathlib import Path
from unicorn.x86_const import *
from oracle_lib_team_tournament_preparation import TeamTournamentPreparation,PreparationBitmaps,catalog_input,CATALOG_FILE,CATALOG_SHA,WRAPPERS
from oracle_lib_team_tournament_setup import tournament_inputs
from oracle_lib_selection_stage import arena_inputs,sequence as selection_sequence
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,GLOBAL,REGISTERS,EXE_SHA256,DLL_SHA256,digest,STOP,SPRINT
from oracle_bitmap_surface_loading import BitmapSurface
from import_ntsd import ROOT

def specifications():
 out=[]
 for control in (False,True):
  first=copy.deepcopy(selection_sequence(control)[0]);suffix='-control' if control else ''
  first['label']='war-ready'+suffix;first['constructorParent']=True
  g=first['globals'];g.update({0x44d020:200,0x451160:4,0x4512c8:3,0x45116c:BM+0x4000,0x44d024:100,0x44d028:1,0x451b80:3 if control else 0})
  first['ready']=[]
  for seat in range(8):
   obj=0 if control or seat>=2 else [17,21][seat]
   status=3 if control or seat<2 else 13
   g.update({0x451248+seat*4:obj,0x451288+seat*4:status,0x451228+seat*4:int(obj==0)})
   first['ready'].append(dict(seat=seat,object=obj,team=1 if seat<4 else 2,status=status))
  first['buttons']=[]
  parent=copy.deepcopy(first);parent['label']='war-resource-parent'+suffix
  parent['globals'].update({0x44d020:3,0x4512c8:0});parent.pop('ready')
  for seat in range(8):
   for address in (0x451248,0x451288,0x451228):parent['globals'].pop(address+seat*4,None)
  out.append(parent)
  ready_globals={0x44d020:200,0x4512c8:3}
  for row in first['ready']:
   seat=row['seat'];ready_globals.update({0x451248+seat*4:row['object'],0x451288+seat*4:row['status'],0x451228+seat*4:int(row['object']==0)})
  out.append(dict(label=first['label'],control=control,chain=True,buttons=[],bridgeGlobals=ready_globals,bridgeReady=first['ready'],bridgeScope='Declared ready War participants after actual fresh resource/menu return; this does not claim earlier mode4 CPU selection reachability'))
  def frame(label,buttons=(),**kw):out.append(dict(label=label+suffix,control=control,chain=True,buttons=[list(x) for x in buttons],**kw))
  def edge(label,*buttons,held=False):
   frame(label+'-press',[(0,b,1) for b in buttons])
   if held:frame(label+'-held')
   frame(label+'-release',[(0,b,0) for b in buttons])
  for i in range(3):frame('initial-pulse-'+str(i))
  edge('section-down-wrap',0xce);edge('section-up-wrap',0xcd);edge('multiplier-row',0xce)
  for side in range(2):
   for i in range(5):edge('multiplier-'+str(side)+'-'+str(i),0xd1,held=i==0)
   edge('multiplier-down-wrap-'+str(side),0xd2)
   edge('multiplier-both-'+str(side),0xd1,0xd2)
   edge('multiplier-side-'+str(side),0xd0)
  for row in range(1,5):
   edge('troop-row-'+str(row),0xce)
   if not control:
    for i,buttons in enumerate([(0xd1,),(0xd3,),(0xd3,),(0xd3,),(0xd2,),(0xd1,),(0xd1,0xd2,0xd3)]):edge('count-boundary-'+str(row)+'-'+str(i),*buttons)
    if row in (2,4):
     for i in range(7):edge('reserve-capacity-'+str(row)+'-'+str(i),0xd3)
    for i in range(12 if row<=2 else 10):edge('troop-cell-'+str(row)+'-'+str(i),0xd0,0xd3)
   else:
    edge('count-control-'+str(row),0xd1,0xd2,0xd3)
    edge('cursor-control-left-'+str(row),0xcf)
  edge('preset-row',0xce)
  # Thirty controlled confirmations retain actual popup resource/backup history.
  # The UI selection/strength scalars are declared inputs, not source after-state.
  for side in range(2):
   edge('popup-open-table-'+str(side),0xd1)
   if not control:
    for preset in range(5):
     for strength in range(3):
      frame('preset-table-'+str(side)+'-'+str(preset)+'-'+str(strength),[(0,0xd1,1)],bridgeGlobals={0x44d020:210,0x451ba8:side,0x44d760:5+preset,0x451b98+side*4:strength},bridgeScope='Declared reachable popup selector and strength scalars; all produced arrays/resources/backup bytes retained')
      frame('preset-table-release-'+str(side)+'-'+str(preset)+'-'+str(strength),[(0,0xd1,0)])
   edge('popup-jump-restore-'+str(side),0xd2)
   edge('preset-side-'+str(side),0xd0)
  edge('popup-none-open',0xd1);edge('popup-none-position',0xce);edge('popup-none',0xd1)
  edge('popup-strength',0xce);edge('popup-strength-choose',0xd1)
  for i in range(3):edge('popup-special-position-'+str(i),0xce)
  edge('popup-special-all',0xd1)
  for i in range(5):edge('popup-apply-position-'+str(i),0xcd)
  edge('popup-apply',0xd1)
  edge('popup-cancel-open',0xd1);edge('popup-cancel-position',0xd0);edge('popup-cancel',0xd1)
  edge('continue-row',0xce);edge('settings',0xd1)
  edge('reroll',0xd1,held=True);edge('reroll-again',0xd1)
  edge('settings-arena',0xce)
  for i in range(20 if not control else 2):edge('arena-'+str(i),0xd1)
  edge('settings-difficulty',0xce)
  for i in range(3):edge('difficulty-'+str(i),0xd1)
  for name,button in [('off',0xcf),('random',0xd0),('main',0xd0)]:edge('music-'+name,button,held=True)
  edge('settings-back',0xd2);edge('settings-again',0xd1)
  if control:
   for i in range(3):edge('quit-position-'+str(i),0xce)
   frame('quit',[(0,0xd1,1)])
  else:
   edge('start-position-1',0xcd);edge('start-position-0',0xcd)
   frame('start',[(0,0xd1,1)],end='warMatchPreparation')
 return out

class WarBitmaps(PreparationBitmaps):
 def __init__(self,owner):
  super().__init__(owner);self.rs=dict(kind='war')
 def append(self,e):self.events.append(e);self.owner.event('warBitmap',startup=e)
 def code(self,u,pc,n,data):
  self.finish(pc);sp=u.reg_read(UC_X86_REG_ESP)
  if pc==0x4450ac:
   i=len(self.allocations_resource);assert i<2 and self.u32(sp+4)==0x1f50 and self.u32(sp)==[0x438c50,0x438c8e][i]
   p=WRAPPERS+(1-i if self.owner.control else i)*0x2000;raw=b'\xa5'*0x1f50 if not self.owner.control else bytes((j*37+11)&255 for j in range(0x1f50))
   assert p not in self.owner.regions
   self.uc.mem_write(p-16,b'\x96'*16);self.uc.mem_write(p+len(raw),b'\x69'*16)
   self.owner.add_region(p,raw,False);self.owner.live[p]=True
   self.allocations_resource.append(dict(address=p,backing=self.blob(raw)))
   self.append(dict(kind='allocate',index=i,address=p,count=len(raw),storeCount=len(self.writes)));self.ret(p);return
  if pc==0x43ee50:
   i=len(self.allocations_resource)-1;p=u.reg_read(UC_X86_REG_ECX);path=self.cstr(self.u32(sp+8)).decode()
   assert p==self.allocations_resource[i]['address'] and self.u32(sp)==[0x438c71,0x438cb3][i]
   assert path==['BATTLEMODE','BATTLETROOPS'][i] and [self.u32(sp+4),self.u32(sp+12)]==[0x40,0]
   self.append(dict(kind='construct',index=i,address=p,path=path,storeCount=len(self.writes)))
  return BitmapSurface.code(self,u,pc,n,data)

class WarSetup(TeamTournamentPreparation):
 def __init__(self,control,inputs,arenas,catalog):
  self.war_graphics=None;self.war_sp=None;self.rep=None;self.reps=[]
  super().__init__(control,inputs,arenas,catalog)
  for p,n in [(0x44d350,0x428),(0x451b38,0x7c)]:
   raw=bytes(self.uc.mem_read(p,n));self.write(p,raw)
   self.file_backed_inputs.append(dict(address=p,bytes=raw.hex(),origin='original PE initialized data/BSS'))
 def finish_war(self,pc):
  u=self.uc;sp=u.reg_read(UC_X86_REG_ESP)
  if self.war_graphics:self.war_graphics.finish(pc)
  if self.rep and pc!=self.rep['pc']:
   h=self.rep;self.rep=None
   assert u.reg_read(UC_X86_REG_ECX)==0 and u.reg_read(UC_X86_REG_EDI)==h['destination']+h['count']
   if h['source'] is not None:assert u.reg_read(UC_X86_REG_ESI)==h['source']+h['count']
   h.update(after=bytes(u.mem_read(h['destination'],h['count'])).hex(),lastStore=len(self.writes),returnPC=pc);self.reps.append(h)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
   if h['entry']==0x43f010:self.bitmap_active=None
   if h['entry']==0x422b00:self.event('keyName',[h['key'],self.u32(h['width'])],[self.cstr(h['string'])])
   if h['entry']==SPRINT:
    raw=self.cstr(h['destination']);assert len(raw)==h['result'];h['output']=raw.hex();self.event('format',[len(raw)],[bytes(h['format']),raw])
   if h['entry']==0x417170:self.event('random',[h['stream'],h['range'],h['result'],h['index'],h['counter'],self.u32(0x450bcc),self.u32(0x450c34)])
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done and not self.constructing:
   self.finish_war(pc);sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x438b40:
    self.war_sp=sp-0xa50
    assert u.reg_read(UC_X86_REG_ECX)==WORLD and self.u32(sp)==0x42a10f
    assert [self.u32(sp+4+i*4) for i in range(7)]==[TARGET,0x44d020,0x451160,0x4512c8,0x451288,0x451248,0x451228]
    self.pending.append(dict(entry=pc,entrySP=sp,pop=28,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
    if self.war_graphics is None:self.war_graphics=WarBitmaps(self)
   if pc in (0x4389a0,0x438ad0):
    args=[self.u32(sp+4+i*4) for i in range(5)]
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),arguments=args))
    self.event('warFrame',[pc,*args])
   if 0x4389a0<=pc<=0x43a850:
    if pc in (0x438bbb,0x438d2a,0x438da5,0x438e49,0x43986a,0x4399c3,0x439a67,0x439e76,0x439ea6,0x439f93,0x43a21f):
     assert sp==self.war_sp,(hex(pc),hex(sp),hex(self.war_sp))
     self.point('war-'+hex(pc));self.points[-1]['fpu']=self.fpu()
    if pc==0x43a21f:
     assert [h['entry'] for h in self.pending]==[0x429730,0x438b40] and not self.war_graphics.helpers
     self.end='warMatchPreparation';u.emu_stop();return
    assert not 0x43a21f<pc<0x43a76e,hex(pc)
    opcode=bytes(u.mem_read(pc,n))
    if opcode[:2] in (b'\xf3\xa5',b'\xf3\xab') and self.rep is None:
     count=u.reg_read(UC_X86_REG_ECX)*4;p=u.reg_read(UC_X86_REG_EDI);src=u.reg_read(UC_X86_REG_ESI) if opcode[:2]==b'\xf3\xa5' else None
     assert u.reg_read(UC_X86_REG_EFLAGS)&0x400==0
     self.rep=dict(pc=pc,count=count,source=src,destination=p,before=bytes(u.mem_read(p,count)).hex(),input=bytes(u.mem_read(src,count)).hex() if src is not None else struct.pack('<I',u.reg_read(UC_X86_REG_EAX)).hex(),firstStore=len(self.writes))
    self.pcs[hex(pc)]=opcode.hex();return
   if pc==0x417170 and self.u32(sp+4)==0x122:
    limit=self.u32(sp+8);seat=(u.reg_read(UC_X86_REG_EDI)-0x451248)//4
    assert self.u32(sp)==0x439971 and 0<limit<=137 and seat in range(8)
    self.event('candidates',[seat,*struct.unpack('<'+'I'*limit,u.mem_read(self.war_sp+0x50,limit*4))])
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),stream=0x122,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34)))
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==SPRINT:
    fmt=self.cstr(self.u32(sp+8))
    if fmt in (b'x %d.%d',b'--'):self.formats[self.u32(sp+8)]=fmt
   g=self.war_graphics
   if g and (pc in g.api or pc in (0x4450ac,0x43ee50,0x43ed10,0x4013d0,g.memset) or g.helpers and (0x43ed10<=pc<=0x43ef41 or 0x4013d0<=pc<=0x4014d1 or 0x78130000<=pc<0x78230000 or 0x4450b2<=pc<=0x4450ba or pc==0x4450a0)):
    return g.code(u,pc,n,data)
  return super().code(u,pc,n,data)
 def complete_case(self,c):
  g=self.war_graphics
  c['warGraphics']=None if g is None else dict(events=g.events,allocations=g.allocations_resource,records=g.records(),helpers=g.returns_resource,images=g.images,surfaces=g.surfaces,dcs=g.dcs)
  c.update(warSP=self.war_sp,reps=self.reps)
  return c
 def probe(self,spec):
  for row in spec.get('ready',[]):
   p=self.actors[row['seat']]
   self.write(p+0x364,struct.pack('<i',row['team']));self.write(p+0x368,struct.pack('<I',self.roster['entries'][row['object']]['address']))
  return self.complete_case(super().probe(spec))

 def next_step(self,spec):
  self.body_music_events=[];self.reps=[];self.rep=None
  if self.war_graphics:self.war_graphics.events=[];self.war_graphics.returns_resource=[];self.war_graphics.checkpoints=[]
  assert self.end=='returned' and not self.pending and not self.graphics.helpers and not self.music.music_pending
  self.running=False;self.spec=spec;stimulus=[];bridge=[]
  for p,v in spec.get('bridgeGlobals',{}).items():
   allowed={0x44d020,0x451ba8,0x44d760,0x451b98,0x451b9c}
   if 'bridgeReady' in spec:allowed|={0x4512c8,*range(0x451228,0x451248,4),*range(0x451248,0x451268,4),*range(0x451288,0x4512a8,4)}
   assert int(p) in allowed
   raw=struct.pack('<I',v&0xffffffff);self.write(int(p),raw);bridge.append(dict(address=int(p),bytes=raw.hex()))
  for row in spec.get('bridgeReady',[]):
   assert row['seat'] in range(8) and row['team'] in (1,2) and row['status'] in (3,13)
   for offset,value in [(0x364,row['team']),(0x368,self.roster['entries'][row['object']]['address'])]:
    p=self.actors[row['seat']]+offset;raw=struct.pack('<I',value);self.write(p,raw);bridge.append(dict(address=p,bytes=raw.hex()))
  for seat,off,value in spec['buttons']:
   assert seat in range(8) and off in (0xca,0xcd,0xce,0xcf,0xd0,0xd1,0xd2,0xd3) and value in (0,1)
   p=self.actors[seat]+off;self.write(p,bytes([value]));stimulus.append(dict(address=p,bytes=bytes([value]).hex()))
  # Only externally supplied ordinary call-frame words; retain all other stack
  # storage and masks from the previous real return. No full stack reset.
  abi=[]
  for p,v in ((SP,STOP),(SP+4,TARGET),(TAIL_SP+0x68,TARGET)):
   self.write(p,struct.pack('<I',v));abi.append(dict(address=p,bytes=struct.pack('<I',v).hex()))
  for r,v in zip(REGISTERS,self.saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_ESP,SP);assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f
  self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.helpers=[];self.pending=[];self.pcs={};self.clip=None;self.bitmap_active=None;self.fill_before=None;self.end=None;self.scans={};self.points=[];self.screenSP=None;self.character_sp=None
  self.startup_done=False;g=self.graphics;g.events=[];g.returns_resource=[];g.checkpoints=[];self.music.music_calls=[]
  before=self.snapshot();self.running=True;self.prologue=True
  try:
   self.uc.emu_start(0x41bc90,0,count=1000);self.prologue=False;assert self.uc.reg_read(UC_X86_REG_ESP)==TAIL_SP
   self.point('declaredTail');self.uc.reg_write(UC_X86_REG_EBX,WORLD)
   self.uc.emu_start(0x4229cc,0,count=2_000_000);assert self.end==spec.get('end','returned')
  except Exception as e:
   f=self.capture_path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),traceback=traceback.format_exc(),pc=hex(self.uc.reg_read(UC_X86_REG_EIP)),spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.running=False
  assert not g.helpers and not self.music.music_pending
  startup=dict(spec=dict(label=spec['label'],ramp=self.control,reverse=self.control,kind='retained'),before=dict(globals=next(x['storage']['bytes'] for x in before if x['address']==GLOBAL),cw=0x23f,sp=SP),after=self.startup_after,allocations=g.allocations_resource,checkpoints=g.checkpoints,records=g.records(),events=g.events,helpers=g.returns_resource,images=dict(g.images),surfaces=dict(g.surfaces),dcs=dict(g.dcs),end='ready',musicBoundary=self.music_boundary,musicAllocations=self.music_at_startup,musicInput=self.music.music_input,musicCalls=self.music.music_calls)
  result=dict(spec=spec,bridge=bridge,before=before,after=self.snapshot(),stimulus=stimulus,callerABI=abi,events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans,points=self.points,actorAddresses=self.actors,screenSP=self.screenSP,characterSP=self.character_sp,output=self.output,saved=self.saved,startup=startup,bodyMusic=self.body_music_events,musicAfter=self.music_records())

  return self.complete_case(result)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');p.add_argument('--limit',type=int);p.add_argument('--control-only',action='store_true');a=p.parse_args()
 assert not a.output.exists();specs=[s for s in specifications() if not a.control_only or s['control']]
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite calls',len(specs));return
 inputs=tournament_inputs();arenas=arena_inputs();catalog=catalog_input();parts=a.output.with_suffix('.parts');parts.mkdir();blobs={};installations=[];assets={};parents=[];case_paths=[]
 for number,s in enumerate(specs):
  if a.limit is not None and number>=a.limit:break
  if not s.get('chain'):
   vm=WarSetup(s['control'],inputs,arenas,catalog);vm.capture_path=a.output
   parents.append(dict(firstCase=number,constructors=vm.constructor_parent,fileBackedInputs=vm.file_backed_inputs))
  c=vm.next_step(s) if s.get('chain') else vm.probe(s)
  assert c['end']==s.get('end','returned')
  temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json')
  with temp.open('w') as f:json.dump(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets,parents=parents[-1:]),f,separators=(',',':'));f.write('\n')
  os.replace(temp,part);case_paths.append(part);installations.append(copy.deepcopy(vm.installation))
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
  print('completed',number,s['label'],c['end'],[vm.u32(p) for p in (0x44d020,0x44d770,0x44d76c,0x451ba8,0x44d760,0x451b84)],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,catalogDependency=dict(path=str(CATALOG_FILE.relative_to(ROOT)),sha256=CATALOG_SHA,bitmapAddresses=[b['address'] for b in catalog['bitmaps']],checksum=catalog['checksum']),parents=parents,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 temp=a.output.with_suffix('.tmp')
 with temp.open('w') as f:
  f.write('{"cases":[')
  for i,part in enumerate(case_paths):
   if i:f.write(',')
   with part.open() as src:part_doc=json.load(src)
   json.dump(part_doc['case'],f,separators=(',',':'));del part_doc
  f.write(']')
  for key,value in d.items():f.write(','+json.dumps(key)+':');json.dump(value,f,separators=(',',':'))
  f.write('}\n')
 os.replace(temp,a.output);h=hashlib.sha256()
 with a.output.open('rb') as f:
  for raw in iter(lambda:f.read(8*1024*1024),b''):h.update(raw)
 print(dict(cases=len(case_paths),bytes=a.output.stat().st_size,sha256=h.hexdigest()),flush=True)

if __name__=='__main__':main()
