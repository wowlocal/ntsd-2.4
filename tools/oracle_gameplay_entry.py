#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue the own MATCH_LAUNCH state through complete control and physics
callers on the same CPU/stack/World/catalog/resources/replay. No gameplay
stimuli or synthetic calls. Research capture; native comparison is still open.
This is the beginning of the first tick, not a complete tick or match.
"""
import argparse,json
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_match_launch import MatchLaunch
from oracle_menu_startup import capture as capture_startup
from oracle_front_menu_resources import WORLD,REGISTERS
from oracle_initial_loading import transport
from oracle_bitmap_drawing import digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP

# Actual helper ABIs, not replacements. Calls outside these ranges fail closed.
HELPERS={0x413080:(2,8),0x412800:(0,0),0x4128F0:(0,0),0x4129E0:(0,0),
 0x412AC0:(0,0),0x412BA0:(0,0),0x412C90:(0,0),0x412D80:(0,0),
 0x412E60:(0,0),0x412F40:(1,4),0x40E170:(2,8),0x40E2D0:(1,4),
 0x40E450:(1,4),0x417170:(2,0),0x40E490:(0,0),0x403270:(2,8),0x4034E0:(1,0)}
CHECKPOINTS={0x413208:'buffers',0x41324C:'combos',0x4132EF:'frame-input',
 0x414247:'movement',0x41E364:'control-return',0x41E657:'physics-return'}

class GameplayEntry(MatchLaunch):
 def gameplay_code(self,uc,pc,size,data):
  if not self.gameplay_running:return
  self.gameplay_instructions.add(pc)
  sp=uc.reg_read(UC_X86_REG_ESP)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop()
   assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending
   self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,
    this=uc.reg_read(UC_X86_REG_ECX),arguments=[self.u32(sp+4+4*i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc in CHECKPOINTS:
   # The owning outer call keeps its current slot in these original locals.
   slot=self.u32(self.body_sp+0x3c) if self.gameplay_label=='control' else uc.reg_read(REGISTERS[3])
   assert 0<=slot<400,(hex(pc),slot)
   self.gameplay_checkpoints.append(dict(label=CHECKPOINTS[pc],pc=pc,slot=slot,actor=self.record(self.pool[slot])))
  assert any(a<=pc<=b for a,b in [(0x41E339,0x41EED1),(0x412800,0x4143CB),
   (0x40E170,0x40EF6A),(0x417170,0x4171BC),(0x403270,0x4034F0),
   (0x4450D0,0x44518F)]),hex(pc)
 def gameplay_step(self,label,start,stop):
  self.position(start);before=self.launch_state();self.gameplay_label=label
  self.gameplay_stop=stop;self.gameplay_finished=False;self.gameplay_pending=[]
  self.gameplay_helpers=[];self.gameplay_checkpoints=[];self.gameplay_instructions=set()
  previous_reads=self.reads_before_writes;assert not previous_reads;self.reads_before_writes=set()
  self.phase='gameplay-'+label;self.gameplay_running=True
  try:
   self.uc.emu_start(start,0,count=2_000_000)
   assert self.gameplay_finished and self.uc.reg_read(UC_X86_REG_ESP)==self.body_sp
   assert self.uc.reg_read(UC_X86_REG_EBX)==WORLD
  except Exception:
   print('GAMEPLAY FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.gameplay_pending,flush=True);raise
  finally:
   reads=sorted(self.reads_before_writes);self.reads_before_writes=previous_reads;self.gameplay_running=False
  result=dict(label=label,before=before,after=self.launch_state(),helpers=self.gameplay_helpers,
   checkpoints=self.gameplay_checkpoints,instructions=sorted(self.gameplay_instructions),readsBeforeWrites=reads,end=self.position(stop))
  print('GAMEPLAY',label,'helpers',len(self.gameplay_helpers),'checkpoints',len(self.gameplay_checkpoints),'end',hex(stop),flush=True)
  return result
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'match-launch{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  print('Entire pinned MATCH_LAUNCH reproduced; continuing own first gameplay passes',flush=True)
  self.gameplay_running=False;self.uc.hook_add(UC_HOOK_CODE,self.gameplay_code)
  cases=[]
  def document():return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,
   actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=cases),{**self.early.blobs,**self.blobs})
  for label,start,stop in [('control',0x41E339,0x41E634),('physics',0x41E634,0x41EED1)]:
   cases.append(self.gameplay_step(label,start,stop))
   (ROOT/'build/research'/f'gameplay-entry-partial{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  return document()

def summarize(doc,raw,path):
 return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,
  sha256=digest(raw),bytes=len(raw),parent=doc['parent'],cases=len(doc['cases']),nativeCompared=False,
  sections=[dict(label=c['label'],end=c['end'],helpers=len(c['helpers']),checkpoints=len(c['checkpoints']),
   instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'],
   actorCalls=[dict(entry=h['entry'],this=h['this'],arguments=h['arguments']) for h in c['helpers'] if h['entry'] in (0x413080,0x40E490)]) for c in doc['cases']])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayEntry,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
 path=ROOT/'build/original'/f'gameplay-entry{suffix}.json';path.write_bytes(raw)
 report=summarize(doc,raw,path)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
