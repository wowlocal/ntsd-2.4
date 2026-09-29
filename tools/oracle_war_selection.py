#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Retained War (mode4) character screen: humans, mode4 teams, computer count,
computer characters/teams and the settings skip through42e0b6.
Reuses the accepted retained selection harness (oracle_lib_selection_stage.Selection):
pinned NTSD EXE/lib/VC80/DAT/BMP/DIBs in controlled Unicorn2.1.4/CW023f, actual
41bc90 prologue and declared4229cc continuation per call, all World/400 Actor/
globals/DC/stack retained between calls. Starts from the fresh initialize-mode-4
parent. Ends at the call that sets4512c8=3 (mode4 leaves before the settings
screen); the following menu200 War setup is a separate accepted study.
APPLICATION_WAR_PLAN.md W1.
"""
import argparse,json,os
from pathlib import Path
from oracle_fresh_character_menu import specs as fresh_specs
from oracle_lib_selection_stage import Selection,arena_inputs
from oracle_lib_character_roster import roster_inputs
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,EXE_SHA256,DLL_SHA256,digest

def sequence(control):
 first=next(s for s in fresh_specs() if s['label']=='initialize-mode-4'+('-control' if control else ''))
 first['label']='initial'+('-control' if control else '');first['globals'][0x458428]=0
 first['globals'].update({0x44d070:-100,0x4511fc:0,0x44d024:100,0x44d028:1,0x44f18c:0,0x450bcc:0,0x450c34:0,0x450c30:0,0x450b98:0,**{0x451200+i*4:0 for i in range(8)}})
 out=[first]
 def frame(label,changes=(),**kw):out.append(dict(label=label+('-control' if control else ''),control=control,chain=True,buttons=[list(x) for x in changes],**kw))
 def edge(label,seats,button,held=False):
  frame(label+'-press',[(s,button,1) for s in seats])
  if held:frame(label+'-held')
  frame(label+'-release',[(s,button,0) for s in seats])
 frame('release-initial')
 edge('join',(0,1),0xd1,True);edge('first-eligible',(0,1),0xd0,True)
 for i in range(4):edge('sasuke-right-'+str(i),(1,),0xd0)
 edge('naruto-random',(0,),0xcd);edge('random-left-last',(0,),0xcf)
 edge('last-right-random',(0,),0xd0);edge('random-right-naruto',(0,),0xd0)
 edge('confirm-character',(0,1),0xd1,True)
 # Mode4 humans start on team1. Right 1->2; Left 1->0,4,3 forbidden ->2.
 edge('human0-team-right',(0,),0xd0);edge('human1-team-left',(1,),0xcf)
 if not control:edge('human1-team-left-again',(1,),0xcf)   # 2->1: two groups
 edge('human0-team-right-wrap',(0,),0xd0,True)             # 2->3,4,0 forbidden ->1
 edge('human0-team-left',(0,),0xcf)                        # 1->0,4,3 forbidden ->2
 edge('ready',(0,1),0xd1,True);edge('countdown-jump',(1,),0xd2)
 for i in range(4):edge('accelerate-'+str(i),(0,),0xd2)
 edge('count-left-wrap',(0,),0xcf);edge('count-right-wrap',(0,),0xd0)
 for i in range(3 if not control else 2):edge('count-right-'+str(i),(0,),0xd0)
 edge('count-confirm',(0,),0xd1,True)
 edge('cpu1-right',(0,),0xd0,True);edge('cpu1-random',(0,),0xcd);edge('cpu1-left-last',(0,),0xcf)
 edge('cpu1-character',(0,),0xd1)
 edge('cpu1-team-right',(0,),0xd0)                         # 1->2
 edge('cpu1-team-right-three',(0,),0xd0,True)              # 2->3 now, next frame 3->1
 edge('cpu1-team-left',(0,),0xcf)                          # 1->0,4,3 forbidden ->2
 edge('cpu1-team-cancel',(0,),0xd2);edge('cpu1-reconfirm-character',(0,),0xd1)
 if not control:edge('cpu1-team-left-one',(0,),0xcf)      # 2->1
 edge('cpu1-ready',(0,),0xd1)
 edge('cpu2-back-previous',(0,),0xd2);edge('cpu1-ready-again',(0,),0xd1)
 edge('cpu2-random',(0,),0xcd);edge('cpu2-left-last',(0,),0xcf);edge('cpu2-last-random',(0,),0xd0)
 edge('cpu2-character',(0,),0xd1,True)
 edge('cpu2-team-right',(0,),0xd0)                         # 1->2
 edge('cpu2-ready',(0,),0xd1)
 # The last computer excludes a team only when all others share it (control).
 edge('cpu3-character',(0,),0xd1,True)
 edge('cpu3-team-right',(0,),0xd0,True);edge('cpu3-team-left',(0,),0xcf)
 edge('cpu3-team-left-again',(0,),0xcf)
 frame('cpu3-ready',[(0,0xd1,1)])
 return out

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();manifest=[s for control in (False,True) for s in sequence(control)]
 if a.manifest_only:a.output.write_text(json.dumps(manifest,indent=2)+'\n');print('Finite calls',len(manifest));raise SystemExit(0)
 inputs=roster_inputs();arenas=arena_inputs();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for control in (False,True):
  vm=Selection(control,inputs,arenas);vm.capture_path=a.output
  for index,spec in enumerate(sequence(control)):
   if a.limit is not None and len(cases)>=a.limit:break
   c=vm.probe(spec) if index==0 else vm.next_step(spec)
   c=json.loads(json.dumps(c));number=len(cases);temp=parts/f'{number:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part);cases.append(c);installations.append(vm.installation)
   for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
   for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
   teams=[vm.u32(vm.actors[i]+0x364) for i in range(8)]
   print('completed',number,spec['label'],'sel',vm.u32(0x4512c8),'status',[vm.u32(0x451288+i*4) for i in range(8)],'selected',[vm.u32(0x451248+i*4)-(1<<32 if vm.u32(0x451248+i*4)>>31 else 0) for i in range(8)],'teams',teams,'count',vm.u32(0x44d070),'cursor',vm.u32(0x4511fc),'countdown',vm.u32(0x44d078),len(c['events']),flush=True)
  if a.limit is not None and len(cases)>=a.limit:break
  assert vm.end=='returned' and vm.u32(0x4512c8)==3 and vm.u32(0x451160)==4 and vm.u32(0x44d020)==1
  assert [vm.u32(0x451288+i*4) for i in range(5)]==[3,3,13,13,13]
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,roster=inputs,arenas=arenas,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
