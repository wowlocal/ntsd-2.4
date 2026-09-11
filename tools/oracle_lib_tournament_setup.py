#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Retained mode2 Tournament menu20..25 with installed original library text.
Pinned NTSD EXE/lib/VC80/raw DAT/head/small BMP/DIBs; controlled Unicorn2.1.4,
CW023f, declared API/COM/GDI responses and atlas geometry, not Windows pixels.
Actual41bc90 prologue/declared4229cc/432ab0/422ab8ret4; Start stops BEFORE4338c3.
Full reads/stores/helper/stack traces recover roster/controller/shuffle/f9/
settings/output order. Retain all prior storage; only buttons and3 ABI words
change. Object+728 operands derive from raw small BMP resources; label NUL
from file-backed EXE. No expected private inputs, pointer/protection damage,
fault continuation or full match/Windows/device claim. Finite acceptance in
LIB_TOURNAMENT_SETUP_PLAN.md; bracket/match and modes3/4 stay open.
"""
import argparse,json,os,re,struct
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_lib_selection_stage import Selection,arena_inputs,sequence as old_sequence
from oracle_lib_character_roster import roster_inputs
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,REGISTERS,EXE_SHA256,DLL_SHA256,digest
from import_ntsd import DEFAULT_SOURCE
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
 first=old_sequence(control)[0];suffix='-control' if control else ''
 first['label']='tournament-initial'+suffix
 first['globals'].update({0x44d020:20,0x451160:2,0x45116c:BM+0x4000,0x4513e0:29 if control else 0,0x44d024:0,0x44d028:0,0x458428:int(control)})
 out=[first]
 def frame(label,button=None,value=None,**kw):out.append(dict(label=label+suffix,control=control,chain=True,buttons=[] if button is None else [[0,button,value]],**kw))
 def edge(label,button,held=False):
  frame(label+'-press',button,1)
  if held:frame(label+'-held')
  frame(label+'-release',button,0)
 if not control:
  for label,b in [('first',0xd0),('random',0xcd),('last',0xcf),('last-random',0xd0),('naruto',0xd0)]:edge(label,b,held=label=='first')
 edge('first-character',0xd1,True)
 edge('controller-left',0xcf);edge('controller-right',0xd0)
 if not control:edge('controller-human',0xcf)
 edge('controller-back-character',0xd2);edge('character-reconfirm',0xd1)
 edge('first-ready',0xd1,True)
 edge('next-back-previous',0xd2);edge('previous-ready',0xd1)
 for seat in range(1,8):
  if seat==1 and not control:
   for i in range(5):edge('sasuke-'+str(i),0xd0)
  edge('fighter-'+str(seat),0xd1,held=seat==7)
  if seat==1 and not control:edge('sasuke-human',0xcf)
  edge('controller-'+str(seat),0xd1)
 edge('dialog-back',0xd2);edge('last-controller-again',0xd1)
 edge('shuffle',0xd1,True)
 for i in range(8):frame('shuffle-wait-'+str(i))
 edge('dialog-continue',0xd0);edge('randomize',0xd1,True)
 edge('reroll',0xd1,True)
 edge('settings-back',0xd2);edge('dialog-continue-again',0xcf);edge('randomize-again',0xd1)
 edge('option-reselect',0xcd);edge('reselect',0xd1,True)
 for seat in range(8):
  if not control and seat<2:
   for i in range(1 if seat==0 else 5):edge('re-roster-'+str(seat)+'-'+str(i),0xd0)
  edge('re-fighter-'+str(seat),0xd1)
  if not control and seat<2:edge('re-human-'+str(seat),0xcf)
  edge('re-controller-'+str(seat),0xd1)
 edge('re-dialog-continue',0xd0);edge('re-randomize',0xd1)
 edge('option-arena',0xce)
 for i in range(2 if control else 21):edge('arena-next-'+str(i),0xd1)
 edge('option-difficulty',0xce)
 for i in range(3):edge('difficulty-'+str(i),0xd1)
 for label,b in [('music-off',0xcf),('music-random',0xd0),('music-main',0xd0)]:edge(label,b,True)
 edge('option-quit',0xce)
 if control:frame('quit',0xd1,1)
 else:
  edge('option-down-wrap',0xce);edge('option-up-wrap',0xcd);edge('option-start',0xce)
  frame('start',0xd1,1,end='tournamentPrelude')
 return out

class Tournament(Selection):
 def __init__(self,control,inputs,arenas):
  super().__init__(control,inputs,arenas);self.tournament_sp=None
  p=SMALL&~0xffff;n=0x60000
  assert all(p+n<=a or p>b for a,b,_ in self.uc.mem_regions());self.uc.mem_map(p,n);self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=p,end=p+n-1)
  for item in inputs['entries']:
   if item['small']:
    pic=item['small'];self.add_region(item['address']+0x728,struct.pack('<I',pic['address']),True)
    self.add_region(pic['address'],b'\xa5'*0x1f50,False);self.write(pic['address'],struct.pack('<Iii',pic['surface'],pic['width'],pic['height']))
  # Exact declared file-backed original short string, not previous after-state.
  raw=bytes(self.uc.mem_read(0x44d31c,2));assert raw==b'x\0';self.write(0x44d31c,raw)
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done:
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x432ab0:
    self.tournament_sp=sp-0xa04
    self.pending.append(dict(entry=pc,entrySP=sp,pop=12,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
   if 0x432ab0<=pc<=0x434aaa:
    self.graphics.finish(pc);self.music.finish(pc)
    while self.pending and pc==self.pending[-1]['returnPC']:
     h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
     h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
     if h['entry']==0x43f010:self.bitmap_active=None
     if h['entry']==0x417170:self.event('random',[h['stream'],h['range'],h['result'],h['index'],h['counter'],self.u32(0x450bcc),self.u32(0x450c34)])
    if pc in (0x432af2,0x432be2,0x432c76,0x433311,0x433497,0x433550,0x433660,0x4338c3,0x433ae7,0x434a92):
     assert sp==self.tournament_sp;self.point('tournament-'+hex(pc))
     if pc not in (0x432af2,0x432be2):self.points[-1]['locals']={str(o):self.u32(sp+o) for o in (0x20,0x24)}
    if pc==0x4338c3:
     assert self.u32(0x44d020)==25 and not self.graphics.helpers and not self.music.music_pending
     assert [h['entry'] for h in self.pending]==[0x429730,0x432ab0]
     self.end='tournamentPrelude';u.emu_stop();return
    if pc==0x433ae7:assert self.u32(0x44d020)<26
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==0x417170 and self.u32(sp+4) in (0xf7,0xf8,0xf9):
    tag=self.u32(sp+4);limit=self.u32(sp+8);assert self.u32(sp)=={0xf7:0x4334bc,0xf8:0x4334ca,0xf9:0x433626}[tag]
    if tag==0xf9:
     seat=u.reg_read(UC_X86_REG_EBP)//4;assert 0<limit<=137 and seat<8
     self.event('candidates',[seat,*struct.unpack('<'+'I'*limit,u.mem_read(sp+0x48,limit*4))])
    else:assert limit==8
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34)))
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=tournament_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=Tournament(control,inputs,arenas);vm.capture_path=a.output
  for index,spec in enumerate(sequence(control)):
   if a.limit is not None and len(cases)>=a.limit:break
   c=vm.probe(spec) if index==0 else vm.next_step(spec)
   # Freeze metadata values too: subsequent calls retain emulator storage,
   # never mutate the already completed atomic cases in this document.
   c=json.loads(json.dumps(c));number=len(cases);temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part);cases.append(c);installations.append(vm.installation)
   for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
   for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
   print('completed',number,spec['label'],[vm.u32(a) for a in (0x44d020,0x4513e8,0x4513e4,0x4513dc)], [vm.u32(0x44d0c0+i*4) for i in range(2)],len(c['events']),flush=True)
  if a.limit is not None and len(cases)>=a.limit:break
  assert vm.u32(0x451340)==(0 if control else 2)
  assert vm.end==('returned' if control else 'tournamentPrelude') and vm.u32(0x44d020)==(10 if control else 25)
  if not control:assert [vm.u32(0x44d0c0+i*4) for i in range(2)]==[17,21]

 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
