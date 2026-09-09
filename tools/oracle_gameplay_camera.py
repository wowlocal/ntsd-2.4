#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continue own41f484 through the entire camera/background call to41f496.
Fresh original menu/loading/launch/control/physics/contacts/hits/cpoints on the
same CPU/stack with no gameplay stimuli. Actual bitmap/clip/fill children run;
COM Blt is an explicit output boundary. Source capture; native comparison open.
"""
import argparse,json,struct
from oracle_gameplay_cpoints import GameplayCPoints
from oracle_loaded_catalog import FRAME_KINDS
from oracle_gameplay_entry import ROOT,EXE_SHA256,DLL_SHA256,WORLD,REGISTERS,digest,capture_startup,transport
from oracle_front_screen_prelude import PAPI
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
HELPERS={0x41b5d0:(2,8),0x41a250:(1,4),0x41a050:(1,4),0x43f010:(6,24),0x43ef70:(6,0),0x415160:(5,0),0x4450d0:(0,0)}
def signed(v):return (v+0x80000000)%0x100000000-0x80000000
class GameplayCamera(GameplayCPoints):
 def camera_active(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='camera-background'
 def imported(self,uc,pc,size,data):
  if not self.camera_active():return super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not self.camera_active():return super().checkpoint(uc,pc,size,data)
 def camera_event(self,kind,args=(),**kw):self.camera_events.append(dict(kind=kind,arguments=list(args),strings=[],**kw))
 def camera_read(self,uc,access,p,size,value,data):
  if not self.camera_active() or self.camera_bitmap is None or not 0x43f010<=uc.reg_read(UC_X86_REG_EIP)<=0x43f2fe:return
  start=self.camera_bitmap
  if start<=p and p+size<=start+0x1f50:
   r=self.region(p,size);offset=p-start;assert size==4
   self.camera_event('read',read=dict(offset=offset,value=self.u32(p),defined=all(r['mask'][offset:offset+size])))
 def gameplay_code(self,uc,pc,size,data):
  if not self.camera_active():return super().gameplay_code(uc,pc,size,data)
  self.gameplay_instructions.add(pc);sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
  while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
   h=self.gameplay_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
   if h['entry']==0x43f010:self.camera_bitmap=None
  if self.camera_clip and pc==self.camera_clip['returnPC']:
   c=self.camera_clip;self.camera_clip=None;assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
   self.camera_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['src']],destination=[signed(self.u32(p)) for p in c['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
  if pc==self.gameplay_stop:
   assert not self.gameplay_pending and self.camera_clip is None;self.gameplay_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   count,pop=HELPERS[pc]
   self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),arguments=[arg(i) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x43f010:
   pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer in self.camera_bitmap_tokens
   self.camera_bitmap=pointer;self.camera_event('draw',[self.camera_bitmap_tokens[pointer],*[arg(i) for i in range(6)]])
  elif pc==0x43ef70:
   assert self.camera_clip is None
   src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   self.camera_clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  elif pc==0x415160:self.camera_fill_inputs.append(bytes(uc.mem_read(sp-0x64,100)).hex())
  elif pc==PAPI:
   if arg(4)==0x1000400:
    assert arg(0)==self.u32(0x455608) and arg(2)==arg(3)==0 and arg(5)!=0
    self.camera_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=list(uc.mem_read(arg(5),100)),defined=[i<4 or 0x50<=i<0x54 for i in range(100)]))
    result=0
   else:
    assert arg(0)==self.camera_target and arg(5)==0
    self.camera_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
    result=self.camera_blits%2;self.camera_blits+=1
   self.ret(result,24);return
  assert any(a<=pc<=b for a,b in [(0x41f484,0x41f496),(0x41b5d0,0x41bc87),(0x41a050,0x41a590),(0x43ef70,0x43f2fe),(0x415160,0x4151c2),(0x4450d0,0x44517a)]),hex(pc)
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'gameplay-cpoints{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
  print('Entire pinned GAMEPLAY_CPOINTS reproduced; continuing camera/background',flush=True)
  def heap():return [dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
  self.camera_events=[];self.camera_fill_inputs=[];self.camera_clip=None;self.camera_bitmap=None;self.camera_blits=0
  self.camera_bitmap_tokens={b['address']:i+1 for i,b in enumerate(self.bitmaps)}
  self.camera_target=self.u32(self.body_sp+0x68)
  drawing=dict(target=self.camera_target,mode=self.u32(0x451160),surfaces=[self.u32(b['address']) for b in self.bitmaps],drawResults=[0,1],fillResult=0)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.camera_read)
  before_heap=heap();section=self.gameplay_step('camera-background',0x41f484,0x41f496)
  section['before']['frameHeap']=before_heap;section['after']['frameHeap']=heap()
  drawing.update(events=self.camera_events,fillInputs=self.camera_fill_inputs);section['drawing']=drawing
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})
def main():
 p=argparse.ArgumentParser();p.add_argument('--control',action='store_true');a=p.parse_args()
 doc=capture_startup(a.control,vm_type=GameplayCamera,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'gameplay-camera{suffix}.json';path.write_bytes(raw)
 c=doc['cases'][0];report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],nativeCompared=False,end=c['end'],helpers=len(c['helpers']),instructions=len(c['instructions']),readsBeforeWrites=c['readsBeforeWrites'],events=len(c['drawing']['events']))
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
