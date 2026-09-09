#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own41f4ac..41f550, mode0: actual VC80 sprintf,401290 and4196f0.
Fresh pinned gameplay-drawing parent on the same CPU/stack, without gameplay
stimuli. GDI/COM/thread responses are explicit boundaries. Mode1/4 children,
remaining post-draw loop, full tick and Windows are open. Source capture;
native comparison open.
"""
import argparse,json
from oracle_gameplay_drawing import GameplayDrawing
from oracle_gameplay_entry import ROOT,EXE_SHA256,DLL_SHA256,WORLD,REGISTERS,digest,capture_startup,transport
from oracle_loaded_catalog import FRAME_KINDS
from oracle_front_screen_body import BAPI
from oracle_crt import PTD,STOP
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW

HELPERS={0x7817775d:(8,0),0x401290:(6,0),0x4196f0:(0,0)}
FORMAT=b'u%d d%d l%d r%d a%d d%d '

class GameplayImpulses(GameplayDrawing):
 def impulses_active(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='post-draw-impulses'
 def imported(self,uc,pc,size,data):
  if not self.impulses_active():return super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not self.impulses_active():return super().checkpoint(uc,pc,size,data)
 def gameplay_code(self,uc,pc,size,data):
  if not self.impulses_active():return super().gameplay_code(uc,pc,size,data)
  self.gameplay_instructions.add(pc);sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
   if h['entry']==0x7817775d:
    raw=self.cstr(h['arguments'][0]);assert len(raw)==h['result']
    self.impulses_events.append(dict(kind='format',arguments=[len(raw)],strings=[list(FORMAT),list(raw)]))
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending and uc.reg_read(UC_X86_REG_EDI)==0
   self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),arguments=[arg(i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
   if pc==0x7817775d:assert self.cstr(arg(1))==FORMAT and arg(0)==self.body_sp+0x48c
  if pc==0x78132db2:self.ret(PTD);return
  gdi=self.early.gdi
  if pc in gdi.presentation_imports:gdi.presentation_imported(uc,pc,size,data);return
  if pc in (BAPI+0x100,BAPI+0x110):gdi.com('getDC' if pc==BAPI+0x100 else 'releaseDC');return
  assert any(a<=pc<=b for a,b in [(0x41f4ac,0x41f550),(0x401290,0x4012fe),(0x4196f0,0x419798),(0x78130000,0x7822ffff),(STOP+0x6000,STOP+0x7fff)]),hex(pc)
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'gameplay-drawing{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
  print('Entire pinned GAMEPLAY_DRAWING reproduced; continuing post-draw text/impulses',flush=True)
  def heap():return [dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
  def menu():return [dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
  assert self.u32(0x451160)==0 and self.u32(0x447174)==0x7817775d
  self.impulses_events=[]
  boundary=dict(mode=self.u32(0x451160),target=self.u32(0x455608),dcResult=0,dc=0x12345678,methodResult=0)
  self.early.gdi.presentation_input=boundary;self.early.gdi.presentation_events=self.impulses_events
  fpcw=self.uc.reg_read(UC_X86_REG_FPCW);fpsw=self.uc.reg_read(UC_X86_REG_FPSW)
  before_heap=heap();before_menu=menu();section=self.gameplay_step('post-draw-impulses',0x41f4ac,0x41f550)
  section['before']['frameHeap']=before_heap;section['after']['frameHeap']=heap()
  section['before']['menuBitmaps']=before_menu;section['after']['menuBitmaps']=menu()
  boundary.update(events=self.impulses_events,fpcw=fpcw,fpswBefore=fpsw,fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW))
  assert self.uc.reg_read(UC_X86_REG_FPCW)==fpcw and (boundary['fpswAfter']>>11)&7==0
  # Preserve the inherited VM control word. This own pass has no division;
  # only the standalone controlled corpus establishes CW037f arithmetic.
  assert fpcw==getattr(self.early,'expected_fpcw',0) and not any(0x41971b<=pc<=0x419770 for pc in section['instructions'])
  section['impulses']=boundary
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})

def main():
 p=argparse.ArgumentParser();p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayImpulses,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'gameplay-impulses{suffix}.json';path.write_bytes(raw)
 c=doc['cases'][0];report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],nativeCompared=False,end=c['end'],helpers=len(c['helpers']),instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'],events=len(c['impulses']['events']))
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
