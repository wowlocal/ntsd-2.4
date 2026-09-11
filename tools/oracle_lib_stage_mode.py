#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole retained Stage/mode1 selection with installed library text.
Pinned NTSD EXE/lib/VC80/DAT/BMP/DIBs, controlled Unicorn2.1.4/CW023f; actual
41bc90 prologue and declared4229cc continuation through429730/422ab8ret4 or
BEFORE42cf8a. Recover Stage readiness/count/CPU/backtracking/RNGd7,d8,EA,
stage-label local writes/music/output order using full memory/read/stack traces.
Retain previous World/400Actor/globals/resources/DC/stack; only buttons and
ordinary ABI words change. Initial stage7/59 are declared within ordinary
stage ranges, not own startup. No pointer/protection corruption, expected
private inputs, fault continuation, Windows/device/full-tick claim. Research
only; LIB_STAGE_MODE_PLAN.md defines finite acceptance and remaining modes.
"""
import argparse,json,os,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_lib_selection_stage import Selection,arena_inputs,sequence as stage_sequence
from oracle_lib_character_roster import roster_inputs
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,REGISTERS,EXE_SHA256,DLL_SHA256,digest


def sequence(control):
 parent=stage_sequence(control);suffix='-control' if control else ''
 last=next(i for i,s in enumerate(parent) if s['label']=='confirm-character-release'+suffix)
 out=parent[:last+1]
 out[0]['globals'].update({0x451160:1,0x450b94:59 if control else 7})
 def frame(label,seats=(),button=None,value=None,**kw):
  out.append(dict(label=label+suffix,control=control,chain=True,buttons=[[s,button,value] for s in seats],**kw))
 def edge(label,button,seats=(0,),held=False):
  frame(label+'-press',seats,button,1)
  if held:frame(label+'-held')
  frame(label+'-release',seats,button,0)
 for i in range(5):edge('accelerate-'+str(i),0xd2)
 edge('count-left-wrap',0xcf);edge('count-right-wrap',0xd0)
 if not control:
  for i in range(2):edge('count-right-'+str(i),0xd0)
 edge('count-confirm',0xd1,held=True)
 if not control:
  for label,button in [('cpu1-cancel-count',0xd2),('count-reconfirm',0xd1),('cpu1-first',0xd0),('cpu1-character',0xd1),('cpu2-back-previous',0xd2),('cpu1-reconfirm',0xd1),('cpu2-random',0xcd),('cpu2-left-last',0xcf),('cpu2-last-random',0xd0),('cpu2-character',0xd1)]:edge(label,button,held=label in ('cpu1-character','cpu2-character'))
 edge('reroll-first',0xd1,held=True)
 edge('option-stage',0xce)
 for i in range(6):edge('stage-next-'+str(i),0xd1,held=i==4)
 edge('option-difficulty',0xce)
 for i in range(4):edge('difficulty-next-'+str(i),0xd1)
 edge('option-music',0xce)
 for label,button in [('music-off-left',0xcf),('music-on-left',0xcf),('music-off-right',0xd0),('music-on-right',0xd0)]:edge(label,button,held=True)
 for i in range(4):edge('option-up-'+str(i),0xcd)
 edge('reselect',0xd1,held=True);edge('rejoin',0xd1,(0,1),True);edge('reconfirm-human',0xd1,(0,1),True)
 for i in range(5):edge('reaccelerate-'+str(i),0xd2)
 edge('recount-confirm',0xd1,held=True)
 if not control:
  edge('reCPU1-character',0xd1);edge('reCPU2-character',0xd1,held=True)
 edge('reroll-after-reselect',0xd1,held=True)
 for i in range(2):edge('start-option-up-'+str(i),0xcd)
 frame('start',(0,),0xd1,1,end='matchPrelude')
 return out


class StageMode(Selection):
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done and pc==0x417170:
   sp=u.reg_read(UC_X86_REG_ESP)
   if self.u32(sp+4) in (0xea,0xd8):
    tag=self.u32(sp+4);limit=self.u32(sp+8);seat=self.u32(sp+0x40)//4 if tag==0xea else u.reg_read(UC_X86_REG_EBP)//4
    assert self.u32(sp)==(0x42e072 if tag==0xea else 0x42c286) and 0<limit<=137 and 0<=seat<8
    self.event('candidates',[seat,*struct.unpack('<'+'I'*limit,u.mem_read(sp+0x50,limit*4))])
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),stream=tag,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34)))
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=roster_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=StageMode(control,inputs,arenas);vm.capture_path=a.output
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
  assert [vm.u32(0x451248+i*4) for i in range(2)]==[17,21] and [vm.u32(0x451288+i*4) for i in range(4)]==([3,3,0,0] if control else [3,3,13,13])
  assert vm.end=='matchPrelude' and vm.u32(0x450b94)==(50 if control else 0) and vm.u32(0x44d070)==(0 if control else 2) and vm.u32(0x4512c8)==3
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
