#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Team Tournament126..129 pair bracket/CPU results/four seat assignment/winner.
Pinned NTSD EXE/lib/VC80 and raw DAT/BMP/DIBs in controlled Unicorn2.1.4/CW023f,
with declared API/COM responses. Original instructions, reads/stores, stack and
helper returns recover pair promotion, two HP draws, Actor result consumption,
input history and output order. Fresh menu120 setup returns through actual
436fb5ret12/422ab8ret4 or stops BEFORE436747, after CPU seat placement but before
GetLocalTime, actor/arena/replay preparation. No played fight, own full catalog,
Windows or device claim. ActorCA is declared419a60 previous-Attack output; controlled
positive HP/state/team results and immutable PE geometry have explicit provenance.
No unknown after-state inputs, control-pointer/protection damage or fault continuation.
Finite acceptance: LIB_TEAM_TOURNAMENT_BRACKET_PLAN.md. Full preparation remains open.
"""
import argparse,json,os,re,struct,copy
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_lib_selection_stage import Selection,arena_inputs,sequence as old_sequence
from oracle_lib_character_roster import roster_inputs
from oracle_lib_menu_continuation import SPRINT,GLOBAL,STOP,SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,REGISTERS,EXE_SHA256,DLL_SHA256,digest
from import_ntsd import DEFAULT_SOURCE
from oracle_fresh_library_menu import FreshMenu
import datetime,traceback
from verify_character_roster_inputs import decode

SMALL=0x74000020

def tournament_inputs():
 inputs=roster_inputs();files={str(p.relative_to(DEFAULT_SOURCE)).replace('/','\\').lower():p for p in DEFAULT_SOURCE.rglob('*') if p.is_file()};pins={}
 def raw(name):
  p=files[name.lower()];value=p.read_bytes();pins[str(p.relative_to(DEFAULT_SOURCE))]=dict(bytes=len(value),sha256=digest(value));return value
 for item in inputs['entries']:
  data=decode(raw(item['path']),item['path']);header=data.split(b'<bmp_begin>',1)[1].split(b'<bmp_end>',1)[0] if b'<bmp_begin>' in data else b''
  tokens=re.findall(rb'[^ \t\r\n\v\f]+',header);small=[tokens[i+1] for i,t in enumerate(tokens[:-1]) if t==b'small:'];item['small']=None
  if small:
   name=small[-1].decode('latin1');bmp=raw(name);assert bmp[:2]==b'BM';width,height=struct.unpack_from('<ii',bmp,18);assert width>0 and height>0
   item['small']=dict(path=name,width=width,height=height,address=SMALL+item['ordinal']*0x2000,surface=0x24000000)
  if item['type']==0:assert item['small'] is not None
 inputs['smallSourceFiles']=pins
 assert sum(i['small'] is not None for i in inputs['entries'])==42
 return inputs

def sequence(control):
 first=old_sequence(control)[0];suffix='-cpu' if control else '-human';first['label']='team-bracket-initial'+suffix
 first['globals'].update({0x44d020:120,0x451160:3,0x45116c:BM+0x4000,0x45140c:29 if control else 0,0x44d024:0,0x44d028:0,0x458428:0,0x44f18c:1})
 def chain(humans,suffix):
  initial=copy.deepcopy(first);initial['label']='team-bracket-initial'+suffix
  out=[initial];held=[0]*8
  def frame(label,changes=(),**kw):
   buttons=[[seat,0xca,value] for seat,value in enumerate(held)]+[list(v) for v in changes]
   for seat,off,value in changes:
    if off==0xd1:held[seat]=value
   out.append(dict(label=label+suffix,control=control,chain=True,buttons=buttons,**kw))
  def edge(label,b,seat=0):frame(label+'-press',[(seat,b,1)]);frame(label+'-release',[(seat,b,0)])
  for seat in range(8):
   edge('fighter-'+str(seat),0xd1)
   if seat<humans:edge('human-'+str(seat),0xcf)
   edge('ready-'+str(seat),0xd1)
  edge('no-shuffle',0xd0);edge('randomize',0xd1)
  edge('option-up1',0xcd);edge('option-start',0xcd);edge('start',0xd1)
  if humans==0:
   # First Start raises scan level0->2. Release advances timer25->26.
   for i in range(54):frame('natural-'+str(i))
   for i in range(9):edge('skip-'+str(i),0xd2)
   for i in range(50):frame('winner-wait-'+str(i))
   frame('winner-dismiss',[(0,0xd1,1)])
  else:
   edge('skip-first-wait',0xd2)
   for seat in range(min(humans,4)):
    edge('claim-'+str(seat),0xd1,seat)
    if seat==0:
     frame('busy-first-press',[(0,0xd1,1)]);frame('busy-first-held');frame('busy-first-release',[(0,0xd1,0)])
   for i in range(4-min(humans,4)):frame('cpu-position-'+str(i))
   # CPU skipping selects No; pure human assignment retains Yes.
   if humans>=4:edge('dialog-no',0xd0)
   edge('cancel-seats',0xd1)
   for seat in range(min(humans,4)):edge('reclaim-'+str(seat),0xd1,seat)
   for i in range(4-min(humans,4)):frame('cpu-reposition-'+str(i))
   edge('dialog-yes',0xcf)
   frame('prepare-match',[(0,0xd1,1)],end='teamTournamentMatchPreparation')
  return out
 out=chain(0 if control else 8,suffix)
 if not control:return out+chain(2,'-mixed')
 # Controlled legitimate pair layouts and ordinary difficulty0/1/2.
 for difficulty in range(3):
  for mask in range(16):
   item=copy.deepcopy(first);item['label']=f'controlled-cpu-mask{mask}-d{difficulty}';item['controlledBracket']=True
   g=item['globals'];g.update({0x44d020:126,0x451414:8,0x451410:0,0x451408:0,0x451404:79,0x4513fc:4,0x451400:0,0x451340:0,0x44d318:2,0x450c30:difficulty,0x458428:1})
   for i in range(8):g.update({0x44d0c0+i*4:0 if i<4 and mask&(1<<i) else 17+(i%2)*4,0x44d0e0+i*4:i,0x44d100+i*4:i//2+1,0x451364+i*4:0,0x451384+i*4:2 if i<4 else 3,0x44d080+i*4:500-i*41,0x44d0a0+i*4:-1,0x451344+i*4:0})
   for i in range(4):g[0x4513ec+i*4]=i
   for i in range(20):g[0x4512d0+i*4]=-1
   item['buttons']=[[seat,0xca,0] for seat in range(8)];out.append(item)
 for winner in (1,2,-1):
  item=copy.deepcopy(out[-1]);item['label']='controlled-result-'+str(winner);g=item['globals'];g.update({0x44d020:128,0x451404:0,0x44d318:4,0x450bf8:winner})
  for i in range(8):g[0x451384+i*4]=5 if i<4 else 3
  for i in range(20):g[0x4512d0+i*4]=i if i<4 else -1
  item['actorWords']=[[i,off,value] for i in range(4) for off,value in [(0x2fc,0 if i%2==0 else 125),(0x300,321-i*41),(0x33c,4+i),(0x364,1 if i<2 else 2)]];out.append(item)
 for timer in (19,20,49):
  item=copy.deepcopy(out[-1]);item['label']='controlled-winner-'+str(timer);item.pop('actorWords',None);g=item['globals'];g.update({0x44d020:129,0x451404:timer,0x451400:0})
  order=[4,5,0,1,6,7,2,3]
  for i in range(8):g.update({0x44d0e0+i*4:order[i],0x44d100+i*4:order[i]//2+1,0x451384+i*4:7 if i<2 else 3})
  for i in range(20):g[0x4512d0+i*4]=-1
  if timer==49:item['buttons'].append([0,0xd1,1])
  out.append(item)
 item=copy.deepcopy(out[0]);item['label']='controlled-held-attack';item['controlledBracket']=True;g=item['globals'];g.update({0x44d020:127,0x451414:8,0x451410:0,0x451408:0,0x451404:0,0x4513fc:4,0x44d318:2})
 for i in range(8):g.update({0x44d0e0+i*4:i,0x44d0c0+i*4:17,0x44d100+i*4:i//2+1,0x451364+i*4:i+1,0x451384+i*4:3,0x451344+i*4:0})
 for i in range(4):g[0x4513ec+i*4]=i
 for i in range(20):g[0x4512d0+i*4]=-1
 item['buttons']=[[seat,0xca,1 if seat==0 else 0] for seat in range(8)]+[[0,0xd1,1]];out.append(item)
 return out

class TeamTournamentBracket(Selection):
 def __init__(self,control,inputs,arenas):
  super().__init__(control,inputs,arenas);self.tournament_sp=None;self.body_music_events=[];self.music.music_match_caller=True
  self.music_at_startup=[]
  original_event=self.music.mevent
  def music_event(kind,args=(),strings=(),result=0,pointer=None,raw=None):
   if self.startup_done:self.body_music_events.append(dict(kind=kind,arguments=list(args),strings=[list(v) for v in strings],response=dict(result=result,pointer=pointer,bytes=None if raw is None else list(raw))))
   original_event(kind,args,strings,result,pointer,raw)
  self.music.mevent=music_event
  for p in self.actors[:8]:self.write(p+0xca,b"\0")
  # Immutable file-backed dimensions and coordinates, not prior after-state.
  geometry=bytes(self.uc.mem_read(0x44d120,0x1f8));self.write(0x44d120,geometry)
  p=SMALL&~0xffff;n=0x60000
  assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions());self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
  for item in inputs['entries']:
   if item['small']:
    pic=item['small'];self.add_region(item['address']+0x728,struct.pack('<I',pic['address']),True)
    self.add_region(pic['address'],b'\xa5'*0x1f50,False);self.write(pic['address'],struct.pack('<Iii',pic['surface'],pic['width'],pic['height']))
  # Exact declared file-backed original short string, not previous after-state.
  raw=bytes(self.uc.mem_read(0x44d320,2));assert raw==b'x\0';self.write(0x44d320,raw)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x434ab0:
    self.tournament_sp=sp-0xa08
    self.pending.append(dict(entry=pc,entrySP=sp,pop=12,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
   if 0x434ab0<=pc<=0x436fb7:
    self.graphics.finish(pc);self.music.finish(pc)
    while self.pending and pc==self.pending[-1]['returnPC']:
     h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
     h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
     if h['entry']==0x43f010:self.bitmap_active=None
     if h['entry']==0x417170:self.event('random',[h['stream'],h['range'],h['result'],h['index'],h['counter'],self.u32(0x450bcc),self.u32(0x450c34)])
    if pc in (0x434af2,0x434c1f,0x434cb6,0x434d56,0x43518f,0x435418,0x4355cb,0x4356d8,0x4357f0,0x435a58,0x435c7c,0x435d59,0x435dbc,0x4366c5,0x436747,0x436afd,0x436e5e,0x436f9d):
     assert sp==self.tournament_sp;self.point('team-tournament-'+hex(pc))
     if pc not in (0x434af2,0x434c1f):self.points[-1]['locals']={str(o):self.u32(sp+o) for o in (0x20,0x28)}
    if pc==0x436747:
     assert self.u32(0x44d020)==127 and not self.graphics.helpers and not self.music.music_pending
     assert [h['entry'] for h in self.pending]==[0x429730,0x434ab0]
     self.end='teamTournamentMatchPreparation';u.emu_stop();return
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==0x417170 and self.u32(sp+4) in (0x101,0x102,0x103,0x105,0x106,0x107,0x108,0x10c):
    tag=self.u32(sp+4);limit=self.u32(sp+8);assert self.u32(sp)=={0x101:0x4355ec,0x102:0x4355fa,0x103:0x4357b6,0x105:0x4362ce,0x106:0x4362ce,0x107:0x43636d,0x108:0x4363ac,0x10c:0x436d8f}[tag]
    if tag==0x103:
     seat=u.reg_read(UC_X86_REG_EBP)//4;assert 0<limit<=137 and seat<8
     self.event('candidates',[seat,*struct.unpack('<'+'I'*limit,u.mem_read(sp+0x4c,limit*4))])
    elif tag in (0x101,0x102):assert limit==4
    elif tag not in (0x107,0x108):assert limit==2
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34)))
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==0x401a30 and u.reg_read(UC_X86_REG_ECX)==0x455618:
    self.pending.append(dict(entry=pc,entrySP=sp,pop=4,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
    self.event('soundRequest',[self.u32(sp+4)]);self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==0x4025b0:
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
   if pc==SPRINT and self.music.music_pending:
    fmt=self.cstr(self.u32(sp+8));assert fmt==b'%s\\graph.log'
    self.current_graph=dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),destination=self.u32(sp+4));self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if self.current_graph:
    if pc!=self.current_graph['returnPC']:return FreshMenu.code(self,u,pc,n,data)
    h=self.current_graph;self.current_graph=None;assert sp==h['entrySP']+4
    raw=self.cstr(h['destination']);assert len(raw)==u.reg_read(UC_X86_REG_EAX)
    h.update(returnSP=sp,result=len(raw),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h);self.music.mevent('format',[len(raw)],[b'%s\\graph.log',raw])
   if pc==0x4450c8 or 0x401c90<=pc<=0x401e85 or 0x401f30<=pc<=0x4020f6 or 0x4025b0<=pc<=0x4025c4 or self.music.music_pending and 0x4450b2<=pc<=0x4450ba:return self.music.code(u,pc,n,data)
  if self.running and not self.prologue and pc==0x429e5a:self.music_at_startup=json.loads(json.dumps(self.music_records()))
  return super().code(u,pc,n,data)

 def next_step(self,spec):
  self.body_music_events=[]
  assert self.end=='returned' and not self.pending and not self.graphics.helpers and not self.music.music_pending
  self.running=False;self.spec=spec;stimulus=[]
  for seat,off,value in spec['buttons']:
   assert seat in range(8) and off in (0xca,0xcd,0xce,0xcf,0xd0,0xd1,0xd2) and value in (0,1)
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
  return dict(spec=spec,before=before,after=self.snapshot(),stimulus=stimulus,callerABI=abi,events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans,points=self.points,actorAddresses=self.actors,screenSP=self.screenSP,characterSP=self.character_sp,output=self.output,saved=self.saved,startup=startup,bodyMusic=self.body_music_events,musicAfter=self.music_records())

 def probe(self,spec):
  self.body_music_events=[]
  for seat,off,value in spec.get('actorWords',[]):self.write(self.actors[seat]+off,struct.pack('<i',value))
  c=super().probe(spec);c['startup']['musicAllocations']=self.music_at_startup;c.update(bodyMusic=self.body_music_events,musicAfter=self.music_records());return c

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=tournament_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=TeamTournamentBracket(control,inputs,arenas);vm.capture_path=a.output
  for index,spec in enumerate(sequence(control)):
   if a.limit is not None and len(cases)>=a.limit:break
   if index>0 and not spec.get('chain'):vm=TeamTournamentBracket(control,inputs,arenas);vm.capture_path=a.output
   c=vm.probe(spec) if not spec.get('chain') else vm.next_step(spec)
   # Freeze metadata values too: subsequent calls retain emulator storage,
   # never mutate the already completed atomic cases in this document.
   c=json.loads(json.dumps(c));number=len(cases);temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part);cases.append(c);installations.append(vm.installation)
   for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
   for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
   print('completed',number,spec['label'],[vm.u32(a) for a in (0x44d020,0x451414,0x451410,0x451408)], [vm.u32(0x44d0c0+i*4) for i in range(2)],len(c['events']),flush=True)
  if a.limit is not None and len(cases)>=a.limit:break
  assert vm.end==('returned' if control else 'teamTournamentMatchPreparation') and vm.u32(0x44d020)==127

 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
