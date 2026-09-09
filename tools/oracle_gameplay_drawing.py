#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue own41f496 through entire World/Actor drawing to41f4ac.
Fresh original menu/loading/launch/control/physics/contacts/hits/cpoints on the
same CPU/stack with no gameplay stimuli. Actual Object sheet/width and bitmap/clip/rectangle children run;
COM Blt is an explicit output boundary. Source capture; native comparison open.
"""
import argparse,json,struct
from oracle_gameplay_camera import GameplayCamera
from oracle_loaded_catalog import FRAME_KINDS
from oracle_gameplay_entry import ROOT,EXE_SHA256,DLL_SHA256,WORLD,REGISTERS,digest,capture_startup,transport
from oracle_front_screen_prelude import PAPI
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
HELPERS={0x41a5a0:(3,12),0x40de30:(3,12),0x40be70:(7,28),0x40bf30:(1,4),0x43f010:(6,24),0x43ef70:(6,0),0x43f310:(7,28),0x4450b2:(0,0)}
def signed(v):return (v+0x80000000)%0x100000000-0x80000000
class GameplayDrawing(GameplayCamera):
 def drawing_active(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='world-drawing'
 def imported(self,uc,pc,size,data):
  if not self.drawing_active():return super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not self.drawing_active():return super().checkpoint(uc,pc,size,data)
 def drawing_event(self,kind,args=(),**kw):self.drawing_events.append(dict(kind=kind,arguments=list(args),strings=[],**kw))
 def drawing_read(self,uc,access,p,size,value,data):
  if not self.drawing_active():return
  pc=uc.reg_read(UC_X86_REG_EIP)
  if pc==0x40bf9d:
   start=uc.reg_read(UC_X86_REG_ECX);assert start in self.drawing_bitmap_tokens
   self.drawing_event('width',[self.drawing_bitmap_tokens[start],p-start])
  elif self.drawing_bitmap is not None and (0x43f010<=pc<=0x43f2fe or pc==0x43f31b):start=self.drawing_bitmap
  else:return
  if start<=p and p+size<=start+0x1f50:
   r=self.drawing_regions[start];offset=p-start;assert size==4
   self.drawing_event('read',read=dict(offset=offset,value=self.u32(p),defined=all(r['mask'][offset:offset+size])))
 def gameplay_code(self,uc,pc,size,data):
  if not self.drawing_active():return super().gameplay_code(uc,pc,size,data)
  self.gameplay_instructions.add(pc);sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
   if h['entry'] in (0x43f010,0x43f310):self.drawing_bitmap=None
  if self.drawing_clip and pc==self.drawing_clip['returnPC']:
   c=self.drawing_clip;self.drawing_clip=None;assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
   self.drawing_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['src']],destination=[signed(self.u32(p)) for p in c['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending and self.drawing_clip is None;self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),arguments=[arg(i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc in (0x43f010,0x43f310):
   pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer in self.drawing_bitmap_tokens
   self.drawing_bitmap=pointer;self.drawing_event('draw' if pc==0x43f010 else 'rectangle',[self.drawing_bitmap_tokens[pointer],*[arg(i) for i in range(6 if pc==0x43f010 else 7)]])
  elif pc==0x43ef70:
   assert self.drawing_clip is None
   src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   self.drawing_clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  elif pc==PAPI:
   assert arg(0) in (self.drawing_target,self.u32(0x455608)) and arg(5)==0
   self.drawing_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
   result=self.drawing_blits%2;self.drawing_blits+=1;self.ret(result,24);return
  assert any(a<=pc<=b for a,b in [(0x41f496,0x41f4ac),(0x41a5a0,0x41ae50),(0x40de30,0x40e160),(0x40be70,0x40bfa8),(0x43ef70,0x43f37a),(0x4450b2,0x4450ba)]),hex(pc)
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'gameplay-camera{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
  print('Entire pinned GAMEPLAY_CAMERA reproduced; continuing World/Actor drawing',flush=True)
  def heap():return [dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
  self.drawing_events=[];self.drawing_fill_inputs=[];self.drawing_clip=None;self.drawing_bitmap=None;self.drawing_blits=0
  self.drawing_bitmap_tokens={b['address']:i+1 for i,b in enumerate(self.bitmaps)}
  self.drawing_regions={b['address']:self.region(b['address'],1) for b in self.bitmaps}
  for r in self.early.regions:
   self.drawing_regions[r['address']]=r;self.drawing_bitmap_tokens[r['address']]=r['address']
  for r in self.menu_bitmaps:
   self.drawing_regions[r['address']]=r;self.drawing_bitmap_tokens[r['address']]=r['address']
  self.drawing_target=self.u32(self.body_sp+0x68)
  drawing=dict(target=self.drawing_target,phase=self.u32(0x450bd8),resourceSurfaces={self.u32(g):self.u32(self.u32(g)) for g in (0x44faf4,0x44f888,0x44fcbc,0x44fb68,0x44faf8,0x44fd80,0x44f8fc,0x44fd7c)},mode=self.u32(0x451160),surfaces=[self.u32(b['address']) for b in self.bitmaps],drawResults=[0,1],fillResult=0)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.drawing_read)
  def menu():return [dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
  before_heap=heap();before_menu=menu();section=self.gameplay_step('world-drawing',0x41f496,0x41f4ac)
  section['before']['frameHeap']=before_heap;section['after']['frameHeap']=heap()
  section['before']['menuBitmaps']=before_menu;section['after']['menuBitmaps']=menu()
  drawing.update(events=self.drawing_events,fillInputs=self.drawing_fill_inputs);section['drawing']=drawing
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})
def main():
 p=argparse.ArgumentParser();p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayDrawing,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'gameplay-drawing{suffix}.json';path.write_bytes(raw)
 c=doc['cases'][0];report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],nativeCompared=False,end=c['end'],helpers=len(c['helpers']),instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'],events=len(c['drawing']['events']))
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
