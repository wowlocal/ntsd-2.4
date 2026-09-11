#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Ordinary retained VS count/computer/team/arena selection with installed lib.
Pinned NTSD EXE/lib/VC80/DAT/BMP/DIBs in controlled Unicorn2.1.4/CW023f. Actual
41bc90 prologue and declared4229cc continuation retain all prior resources,
World/400Actor/globals/DC/stack; end at422ab8ret4 or BEFORE42cf8a match prelude.
Raw resources independently supply catalog/arena operand views; RNG table and
configuration are declared controlled initial inputs, not own startup state.
Read/write/helper/stack traces recover selection order and string provenance.
No private expected inputs, damaged pointers/protection structures, fault
continuation, Windows/device or full-tick claim. LIB_SELECTION_STAGE_PLAN.md.
"""
import argparse,datetime,json,os,re,struct,traceback
from pathlib import Path
from unicorn.x86_const import *
from oracle_lib_character_roster import Roster,roster_inputs,sequence as parent_sequence,CATALOG
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,GLOBAL,REGISTERS,EXE_SHA256,DLL_SHA256,digest,STOP,SPRINT
from oracle_crt import PTD
from oracle_fresh_library_menu import MUSIC_ARENA,MUSIC_API
from import_ntsd import ROOT,DEFAULT_SOURCE
from verify_character_roster_inputs import decode,text_read

def arena_inputs():
 files={str(p.relative_to(DEFAULT_SOURCE)).replace('/','\\').lower():p for p in DEFAULT_SOURCE.rglob('*') if p.is_file()};pins={}
 def raw(name):
  p=files[name.lower()];value=p.read_bytes();pins[str(p.relative_to(DEFAULT_SOURCE))]=dict(bytes=len(value),sha256=digest(value));return value
 section=text_read(raw('data\\data.txt')).split(b'<background>',1)[1].split(b'<background_end>',1)[0]
 entries=re.findall(rb'id:\s*([+-]?\d+)\s+file:\s*([^\s]+)',section)
 assert 0<len(entries)<99
 out=[]
 for i,(_,path) in enumerate(entries):
  path=path.decode('latin1');data=decode(raw(path),path);tokens=re.findall(rb'[^ \t\r\n\v\f]+',data)
  names=[tokens[j+1] for j,t in enumerate(tokens[:-1]) if t==b'name:'];assert len(names)==1 and len(names[0])<100
  name=names[0][:29].replace(b'_',b' ')+b'\0';out.append(dict(ordinal=i,path=path,name=name.hex(),producer='40c160 name token'))
 #41233b..41251c sparse built-in catalog construction; literal names are inputs
 #from original source/accepted constructor, never expected post-menu storage.
 out.extend([dict(ordinal=99,name=(b'Lee On Road\0').hex(),producer='41233b..41251c built-in'),dict(ordinal=100,name=(b'Random\0').hex(),producer='41233b..41251c Random')])
 return dict(entries=out,count=len(entries),sourceFiles=pins,backgroundBase=0x4d45db0,recordSize=0x990,nameOffset=0x3cc)

def sequence(control):
 out=parent_sequence(control)
 #The control keeps all ready humans on team1, so the last CPU must exclude it.
 if control:
  for s in out:
   if s['label']=='teams-press-control':s['buttons']=[[0,0xd0,1],[1,0xd0,1]]
   if s['label']=='teams-release-control':s['buttons']=[[0,0xd0,0],[1,0xd0,0]]
 out[0]['globals'].update({0x44d070:-100,0x4511fc:0,0x44d024:100,0x44d028:1,0x44f18c:0,0x450bcc:0,0x450c34:0,0x450c30:0,0x450b98:0,**{0x451200+i*4:0 for i in range(8)}})
 def frame(label,changes=(),**kw):out.append(dict(label=label+('-control' if control else ''),control=control,chain=True,buttons=[list(x) for x in changes],**kw))
 def edge(label,button,held=False):
  frame(label+'-press',[(0,button,1)])
  if held:frame(label+'-held')
  frame(label+'-release',[(0,button,0)])
 for i in range(4):edge('accelerate-'+str(i),0xd2)
 edge('count-left-wrap',0xcf);edge('count-right-wrap',0xd0)
 for i in range(1 if control else 2):edge('count-right-'+str(i),0xd0)
 edge('count-confirm',0xd1,True);edge('cpu-first-cancel-count',0xd2);edge('count-reconfirm',0xd1)
 for label,button in [('cpu1-right',0xd0),('cpu1-random',0xcd),('cpu1-left-last',0xcf),('cpu1-last-random',0xd0),('cpu1-random-first',0xd0),('cpu1-character',0xd1),('cpu1-team-right',0xd0),('cpu1-team-left',0xcf),('cpu1-team-cancel',0xd2),('cpu1-reconfirm-character',0xd1),('cpu1-ready',0xd1),('cpu2-back-previous',0xd2),('cpu1-ready-again',0xd1),('cpu2-random',0xcd),('cpu2-left-last',0xcf),('cpu2-last-random',0xd0),('cpu2-character',0xd1),('cpu2-team-left',0xcf),('cpu2-ready',0xd1)]:edge(label,button,held=label in ('cpu1-right','cpu2-character'))
 for label,button in [('option-arena',0xce),('arena-none',0xd1),('arena-District',0xd1),('option-difficulty',0xce),('difficulty-next',0xd1),('option-music',0xce),('music-off',0xcf),('music-random',0xd0),('music-main',0xd0)]:edge(label,button)
 for i in range(5):edge('option-up-'+str(i),0xcd)
 frame('start',[(0,0xd1,1)],end='matchPrelude')
 return out

class Selection(Roster):
 def __init__(self,control,inputs,arenas):
  super().__init__(control,inputs);self.arenas=arenas;self.selection_random=None
  for a in arenas['entries']:
   self.add_region(CATALOG+0x4d45db0+a['ordinal']*0x990+0x3cc,bytes.fromhex(a['name']),True)
  self.add_region(CATALOG+0x4d82384,struct.pack('<I',arenas['count']),True)
  #Declared table from the independently recovered VC80 recurrence and422ac0.
  #This does not execute or claim an own startup. Include the original NUL tail.
  seed=0xffffffff if control else 17;table=bytearray()
  for _ in range(3000):
   seed=(seed*0x343fd+0x269ec3)&0xffffffff;table.append(((seed>>16)&0x7fff)%255+1)
  assert len(table)==3000 and 0 not in table
  self.write(0x44ff90,bytes(table)+b'\0')
  self.put(MUSIC_ARENA+0x2100+0x40+0x24,MUSIC_API+0x900)
  self.put(MUSIC_ARENA+0x2300+0x40+0x20,MUSIC_API+0x910)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done:
   sp=u.reg_read(UC_X86_REG_ESP)
   self.graphics.finish(pc);self.music.finish(pc)
   while self.pending and pc==self.pending[-1]['returnPC']:
    h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
    h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
    if h['entry']==0x43f010:self.bitmap_active=None
    if h['entry']==SPRINT:
     raw=self.cstr(h['destination']);assert len(raw)==h['result'];h['output']=raw.hex();self.event('format',[len(raw)],[bytes(h['format']),raw])
    if h['entry']==0x417170:
     self.event('random',[h['stream'],h['range'],h['result'],h['index'],h['counter'],self.u32(0x450bcc),self.u32(0x450c34)])
   if pc in (0x42b296,0x42b964,0x42cb86,0x42cf6c,0x42cf8a,0x42d706,0x42d789):
    assert sp==self.character_sp;self.point('character-'+hex(pc));self.points[-1].update(seat=0xffffffff,locals={str(o):self.u32(sp+o) for o in (0x20,0x28,0x34,0x38,0x3c)})
   if pc==0x42cf8a:
    assert not self.graphics.helpers and not self.music.music_pending
    assert len(self.pending)==1 and self.pending[0]['entry']==0x429730
    self.end='matchPrelude';u.emu_stop();return
   if pc in (0x402130,0x417170):
    h=dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events))
    if pc==0x402130:self.event('musicConfiguration',[self.u32(sp+4+i*4) for i in range(4)])
    else:
     tag,limit=self.u32(sp+4),self.u32(sp+8)
     assert (tag,h['returnPC']) in ((0xd7,0x42b704),(0xd9,0x42caf6),(1,0x40232d))
     h.update(stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34))
     if tag!=1:
      assert 0<limit<=137;self.event('candidates',[u.reg_read(UC_X86_REG_EBP)//4,*struct.unpack('<'+'I'*limit,u.mem_read(sp+0x50,limit*4))])
    self.pending.append(h)
   if pc==SPRINT:
    fmt=self.cstr(self.u32(sp+8))
    if fmt in (b'%d',b'Music: %s'):self.formats[self.u32(sp+8)]=fmt
   if pc==0x78132db2:self.ret(PTD);return
   if pc in (MUSIC_API+0x900,MUSIC_API+0x910):
    count,offset,token=(1,0x24,MUSIC_ARENA+0x2100) if pc==MUSIC_API+0x900 else (3,0x20,MUSIC_ARENA+0x2300)
    assert self.u32(sp+4)==token
    self.event('musicMethod',[token,offset,*[self.u32(sp+4+i*4) for i in range(1,count)]])
    self.ret(-2147467259,count*4);return
   if pc==0x402100:
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
    self.event('stopMusic')
   if any(a<=pc<=b for a,b in ((0x42b296,0x42cf89),(0x42d706,0x42e0b5),(0x402100,0x4025a5),(0x417170,0x4171bc))):
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)
 def next_step(self,spec):
  assert self.end=='returned' and not self.pending and not self.graphics.helpers and not self.music.music_pending
  self.running=False;self.spec=spec;stimulus=[]
  for seat,off,value in spec['buttons']:
   assert seat in (0,1) and off in (0xcd,0xce,0xcf,0xd0,0xd1,0xd2) and value in (0,1)
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
  startup=dict(spec=dict(label=spec['label'],ramp=self.control,reverse=self.control,kind='retained'),before=dict(globals=next(x['storage']['bytes'] for x in before if x['address']==GLOBAL),cw=0x23f,sp=SP),after=self.startup_after,allocations=g.allocations_resource,checkpoints=g.checkpoints,records=g.records(),events=g.events,helpers=g.returns_resource,images=dict(g.images),surfaces=dict(g.surfaces),dcs=dict(g.dcs),end='ready',musicBoundary=self.music_boundary,musicAllocations=self.music_records(),musicInput=self.music.music_input,musicCalls=self.music.music_calls)
  return dict(spec=spec,before=before,after=self.snapshot(),stimulus=stimulus,callerABI=abi,events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans,points=self.points,actorAddresses=self.actors,screenSP=self.screenSP,characterSP=self.character_sp,output=self.output,saved=self.saved,startup=startup)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=roster_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=Selection(control,inputs,arenas);vm.capture_path=a.output
  for index,spec in enumerate(sequence(control)):
   if a.limit is not None and len(cases)>=a.limit:break
   c=vm.probe(spec) if index==0 else vm.next_step(spec)
   # Freeze metadata values too: subsequent calls retain emulator storage,
   # never mutate the already completed atomic cases in this document.
   c=json.loads(json.dumps(c));number=len(cases);temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part);cases.append(c);installations.append(vm.installation)
   for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
   for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
   print('completed',number,spec['label'],[vm.u32(0x451248+i*4) for i in range(2)],[vm.u32(0x451288+i*4) for i in range(2)],len(c['events']),flush=True)
  if a.limit is not None and len(cases)>=a.limit:break
  assert [vm.u32(0x451248+i*4) for i in range(2)]==[17,21] and [vm.u32(0x451288+i*4) for i in range(4)]==[3,3,13,13]
  assert vm.end=='matchPrelude' and vm.u32(0x44d024)==0 and vm.u32(0x44d028)==0 and vm.u32(0x4512c8)==3
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
