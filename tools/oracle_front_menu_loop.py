#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Repeated actual4246b0 early-menu calls after the fresh first return.
Each phase resumes the same CPU/stack/registers at its actual predecessor's PC;
no later body/menu entry registers are supplied. Reuse the verified original
resource/prefix/update/body/alternate/completion observers and real children.
Mouse/worker/timer/device/FILE and scratch backing are declared inputs. Stop at
other selectors or first41bc90 entry; no Windows/device pixels/full-match claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_front_menu_completion import FrontMenuCompletion
from oracle_front_screen_body import HELPERS,LOCAL_SIZE
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,SOURCE,BODY_SP,ENTRY_SP,REGISTERS
from oracle_bitmap_drawing import digest,packed
from oracle_state import STOP
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_ESP,UC_X86_REG_EIP

class FrontMenuLoop(FrontMenuCompletion):
 def __init__(self,control=False):
  self.loading_probe=False;super().__init__(control)
  first=self.completion_step('first-natural-return')
  self.loop_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,parent=self.completion_parent,initialGlobals=self.completion_initial,initialCRT=1,initialPointers=[0]*8,cases=[first])
  self.loop_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.loop_crt=self.crt.random_state
  self.completion_config=(self.body_range,self.body_stops,self.body_helpers,self.body_sound_slots)
 def code(self,uc,pc,size,data):
  if self.loading_probe:
   if pc==0x41BC90:uc.emu_stop();return
   assert 0x4246B0<=pc<=0x424741,hex(pc);return
  super().code(uc,pc,size,data)
 def configure(self,kind):
  if kind=='body':self.body_range=(0x42712C,0x4275CB);self.body_stops={0x4275CB:'alternateDispatch'};self.body_helpers=HELPERS;self.body_sound_slots={0x455610}
  elif kind=='alternate':
   self.body_range=(0x4275CB,0x427915);self.body_stops={0x427915:'mainMenu',0x427CA7:'otherSelector',0x42873E:'presentation'}
   self.body_helpers=HELPERS|{0x423230:0,0x4237E0:0,0x43C450:0,0x415160:0};self.body_sound_slots={0x455610,0x455614}
  else:self.body_range,self.body_stops,self.body_helpers,self.body_sound_slots=self.completion_config
 def loop_step(self,label,writes=(),milliseconds=100,thread=0x12345678,available=True,capacity=64,action='full',fail_at=-1,close=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  phases=[]
  def phase(kind,value,**extra):phases.append(dict(kind=kind,value=value,**extra))
  world=self.u32(WORLD)
  if world==1:
   self.configure('completion');phase('completion',self.completion_step('world-one-loop',entry='worldOne'));end='returned'
  elif world==2:
   self.put(0,0x12345678);self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE);self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
   for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.uc.reg_write(r,v)
   self.loading_probe=True
   try:self.uc.emu_start(0x4246B0,0,count=10000)
   finally:self.loading_probe=False
   assert self.uc.reg_read(UC_X86_REG_EIP)==0x41BC90 and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP-8 and self.u32(BODY_SP-8)==0x424746 and self.u32(BODY_SP-4)==SOURCE
   end='loading'
  else:
   assert self.u32(0x44D068)==0 # Already initialized by the fresh parent.
   self.configure('body')
   value=self.step('actual-repeat-entry');assert value['continuation']=='ready' and not value['allocations'];phase('initialize',value)
   assert self.uc.reg_read(UC_X86_REG_EIP)==0x42709B
   value=self.prefix_step('first-screen-prefix',milliseconds=milliseconds,thread=thread);phase('prefix',value)
   if value['continuation'] not in ('critical','alternate'):end='prefixBoundary'
   else:
    self.old_world=self.world_record();self.old_records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions]
    if value['continuation']=='critical':
     assert self.uc.reg_read(UC_X86_REG_EIP)==0x427127
     value=self.update_step('first-natural-update');assert value['continuation']=='ready' and not value['children'];phase('update',value)
     assert self.uc.reg_read(UC_X86_REG_EIP)==0x42712C
     backing=self.blob(self.uc.mem_read(BODY_SP,LOCAL_SIZE));self.local_mask=bytearray(LOCAL_SIZE)
     value=self.body_step('first-screen-body');phase('body',value,backing=backing)
     assert value['continuation']=='alternateDispatch'
    assert self.uc.reg_read(UC_X86_REG_EIP)==0x4275CB
    self.configure('alternate')
    value=self.alternate_step('first-natural-dispatch',timers=(milliseconds,milliseconds,milliseconds),thread=thread,capacity=capacity,available=available,action=action,fail_at=fail_at,close=close)
    phase('alternate',value)
    if value['continuation']=='otherSelector':end='otherSelector'
    elif value['continuation'] not in ('mainMenu','presentation'):end='alternateBoundary'
    else:
     entry='main' if value['continuation']=='mainMenu' else 'tail'
     assert self.uc.reg_read(UC_X86_REG_EIP)==(0x427915 if entry=='main' else 0x42873E)
     self.configure('completion');phase('completion',self.completion_step('first-natural-return',entry=entry));end='returned'
  return dict(label=label,stimulus=stimulus,phases=phases,continuation=end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),after=self.snapshot())
 def capture_loop(self):
  def mouse(x,y,held):return [(0x4546F0,x),(0x453CDC,y),(0x457580,held)]
  cases=[self.loop_step('next-natural-frame')]
  for i in range(4):cases.append(self.loop_step(f'idle-{i}'))
  cases.append(self.loop_step('open-settings',mouse(725,17,1)))
  cases.append(self.loop_step('release-on-settings',mouse(725,17,0)))
  cases.append(self.loop_step('expand-description',mouse(203,337,1)))
  for i in range(32):cases.append(self.loop_step(f'animation-{i}',mouse(0,0,0) if i==0 else ()))
  cases.append(self.loop_step('disable-animated-panel',mouse(465,100,1)))
  cases.append(self.loop_step('redraw-main-after-disable',mouse(0,0,0)))
  cases.append(self.loop_step('open-again',mouse(725,17,1)))
  cases.append(self.loop_step('enable-panel',mouse(209,271,1)+[(0x44D788,-99)],thread=0))
  cases.append(self.loop_step('main-after-enable',mouse(0,0,0)))
  for i in range(4):cases.append(self.loop_step(f'busy-worker-{i}',mouse(725,17,1)+[(0x458424,1)] if i==0 else ()))
  cases.append(self.loop_step('worker-release',mouse(0,0,0)+[(0x458424,0)]))
  cases.append(self.loop_step('waiting-entry',mouse(0,0,0)+[(0x44D064,-1),(0x4511F0,0),(0x4511E8,0)],milliseconds=0xFFFFFF80))
  for i in range(30):cases.append(self.loop_step(f'waiting-{i}',milliseconds=(0xFFFFFF80+(i+1)*151)&0xFFFFFFFF))
  cases.append(self.loop_step('cancel-waiting',mouse(331,320,1),milliseconds=5000))
  cases.append(self.loop_step('main-after-cancel',mouse(0,0,0)))
  for i in range(4):cases.append(self.loop_step(f'network-hover-{i}',mouse(300,252,0) if i==0 else ()))
  for phase in (-2147483648,-1,0,1,2,2147483647):cases.append(self.loop_step(f'phase-word-{phase}',mouse(0,0,0)+[(0x4511F8,phase)]))
  cases.append(self.loop_step('new-background',[(0x4511AC,0)],milliseconds=12))
  for setting in (-1,0,1,2):cases.append(self.loop_step(f'initial-selector-{setting}',[(0x44D064,-2),(0x450BE8,setting)]))
  cases.append(self.loop_step('restore-main',[(0x44D064,0)]))
  for x,y in ((612,492),(693,492),(592,522)):
   cases.append(self.loop_step(f'link-{x}',mouse(x,y,1)));cases.append(self.loop_step(f'link-release-{x}',mouse(0,0,0)))
  for available,action in ((False,'full'),(True,'error')):
   cases.append(self.loop_step(f'open-write-{available}',mouse(725,17,1)))
   cases.append(self.loop_step(f'write-{available}',mouse(465,271,1),available=available,capacity=7,action=action,fail_at=1 if action=='error' else -1,close=-1))
   cases.append(self.loop_step(f'after-write-{available}',mouse(0,0,0)))
   if not available:
    cases.append(self.loop_step('retry-save',mouse(465,271,1)));cases.append(self.loop_step('after-retry',mouse(0,0,0)))
  for selector in (1,6,7):cases.append(self.loop_step(f'other-selector-{selector}',[(0x44D064,selector)]))
  cases.append(self.loop_step('choose-match',mouse(300,222,1)+[(0x44D064,0)]))
  cases.append(self.loop_step('world-one'))
  cases.append(self.loop_step('world-two-loading'))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.loop_parent,initialGlobals=self.loop_initial,initialCRT=self.loop_crt,
   sources=list(self.background_sources.values()),cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   candidate=ROOT/'build/research'/f'front-menu-loop{suffix}.json';report=json.loads(candidate.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-menu-loop{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-menu-loop',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((ROOT/'docs/evidence'/candidate.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=FrontMenuLoop(a.control).capture_loop();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-menu-loop{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  phases={k:sum(p['kind']==k for c in doc['cases'] for p in c['phases']) for k in sorted({p['kind'] for c in doc['cases'] for p in c['phases']})},
  continuations={k:sum(c['continuation']==k for c in doc['cases']) for k in sorted({c['continuation'] for c in doc['cases']})},nativeCompared=False)
 (ROOT/'build/research'/f'front-menu-loop{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
