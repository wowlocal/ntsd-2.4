#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole retained VS reselect/reroll commands with installed library text.
Pinned NTSD EXE/lib/VC80/DAT/BMP/DIBs, controlled Unicorn2.1.4/CW023f, actual
41bc90 prologue and declared4229cc continuation through429730/422ab8ret4 or
BEFORE42cf8a. Retain complete World/400Actor/globals/resources/DC/source stack;
only ordinary buttons and declared ABI words change. Execute actual tagEA RNG,
recover live candidate/selection order and caller-local provenance. Research
only: no private expected input, pointer/protection corruption, fault continuation,
Windows/device/full-tick claim. See LIB_SELECTION_COMMANDS_PLAN.md.
"""
import argparse,json,os,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_lib_selection_stage import Selection,arena_inputs,sequence as stage_sequence
from oracle_lib_character_roster import roster_inputs
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,REGISTERS,EXE_SHA256,DLL_SHA256,digest


def sequence(control):
 parent=stage_sequence(control);suffix='-control' if control else ''
 last=next(i for i,s in enumerate(parent) if s['label']=='cpu2-ready-release'+suffix)
 out=parent[:last+1]
 def frame(label,seats=(),button=None,value=None,**kw):
  out.append(dict(label=label+suffix,control=control,chain=True,buttons=[[s,button,value] for s in seats],**kw))
 def edge(label,button,seats=(0,),held=False):
  frame(label+'-press',seats,button,1)
  if held:frame(label+'-held')
  frame(label+'-release',seats,button,0)
 edge('reroll-first',0xd1,held=True);edge('reroll-second',0xd1)
 edge('option-reselect',0xcd);edge('reselect',0xd1,held=True)
 edge('rejoin',0xd1,(0,1),True);edge('reconfirm-human',0xd1,(0,1),True);edge('reready-human',0xd1,(0,1),True)
 for i in range(5):edge('reaccelerate-'+str(i),0xd2)
 edge('recount-confirm',0xd1,held=True)
 for label in ('reCPU1-character','reCPU1-ready','reCPU2-character','reCPU2-ready'):edge(label,0xd1)
 edge('reroll-after-reselect',0xd1,held=True)
 # Reuse the previously declared ordinary arena/music/Start suffix verbatim.
 out.extend(parent[last+1:])
 return out


class Commands(Selection):
 def code(self,u,pc,n,data):
  if self.running and not self.prologue and self.startup_done and pc==0x417170:
   sp=u.reg_read(UC_X86_REG_ESP)
   if self.u32(sp+4)==0xea:
    limit=self.u32(sp+8);seat=self.u32(sp+0x40)//4
    assert self.u32(sp)==0x42e072 and 0<limit<=137 and 0<=seat<8
    self.event('candidates',[seat,*struct.unpack('<'+'I'*limit,u.mem_read(sp+0x50,limit*4))])
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events),stream=0xea,range=limit,index=self.u32(0x450bcc),counter=self.u32(0x450c34)))
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=roster_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=Commands(control,inputs,arenas);vm.capture_path=a.output
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
