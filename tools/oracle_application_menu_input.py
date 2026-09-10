#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own queued input after first due iteration -> repeated menus/loading entry.
Pinned NTSD/lib/VC80/DIB/WAV, Unicorn2.1.4; same own CPU/stack/resources.
Real WndProc/dispatcher/World/menu/rand/release instructions; declared queue,
callback-frame delivery, clock/COM/GDI/audio/free boundaries. No direct mouse,
World/held/worker/CRT state injection or private native stack imports. Normal
SEH/cookie code executes, without protective/control corruption/bypass or fault
continuation. Stop at actual loading41bc90 or missing-resource read; no loading
success, real Windows/device/network/URL or full-match claim. Research only;
APPLICATION_MENU_INPUT_PLAN.md. Retain every completed case atomically.
"""
import argparse,copy,json,os,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_application_menu_return import ApplicationMenuReturn,specs as parents,EXTRA_HELPERS
from oracle_application_screen_body import ApplicationScreenBody,HELPERS,BODY_API,LIB,FRONT_API
from oracle_application_message_loop import queued,message,timer,MSG,CALLBACK_RETURN,API,LOOP_NAMES
from oracle_application_settings import key,BODY_SP
from oracle_bitmap_surface_loading import TRACE_STACK,TRACE_SIZE,REGS,API as BITMAP_API
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_crt import PTD,STOP,DLL_SHA256
from oracle_wave_loader import VTABLE as AUDIO_VTABLE
from oracle_bitmap_drawing import digest,signed
from oracle_lib_initialization import LIB_SHA256
from import_ntsd import ROOT,EXE_SHA256
NEW_API={STOP+0xe000:(0x48,1),STOP+0xe010:(0x34,2),STOP+0xe020:(0x30,4),STOP+0xe030:('free',1)}
MORE_HELPERS=EXTRA_HELPERS|{0x401250:0,0x415160:0,0x401a30:4,0x422ac0:0,0x423910:0,0x43ef50:0,0x7816d5f0:0}
CHECKPOINTS={0x43e9a0:'dispatch',0x4246b0:'world',0x42709b:'prefix',0x427127:'panel',0x42712c:'body',0x4275cb:'alternate',0x427915:'main',0x42873e:'tail',0x43ecbf:'worldReturn',0x43d187:'dispatchReturn'}

class ApplicationMenuInput(ApplicationMenuReturn):
 def __init__(self):self.repeat_active=False;super().__init__()
 def boundary(self,u,pc,n,data):
  if self.repeat_active:
   if pc==0x78132e29:self.ret(PTD)
   return
  return super().boundary(u,pc,n,data)
 def body_read(self,u,access,p,n,v,data):
  if not self.repeat_active:return super().body_read(u,access,p,n,v,data)
  self.body_active=True
  try:return ApplicationScreenBody.body_read(self,u,access,p,n,v,data)
  finally:self.body_active=False
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.repeat_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:self.front_mask[p-BASE:p-BASE+n]=b'\1'*n;self.front_event('write',[p,n,v&((1<<(8*n))-1)])
  if BODY_SP<=p<p+n<=BODY_SP+0xc0:
   self.local_mask[p-BODY_SP:p-BODY_SP+n]=b'\1'*n
   if 0x42712c<=pc<0x4275cb:self.front_event('writeLocal',[p-BODY_SP,n,v&((1<<(8*n))-1)])
  if MSG<=p<p+n<=MSG+28:self.msg_mask[p-MSG:p-MSG+n]=b'\1'*n
 def state(self):
  s=self.menu_state();s.update(message=self.blob(self.uc.mem_read(MSG,28)),messageMask=self.blob(self.msg_mask),random=self.random_state,records=[dict(address=r['address'],live=r['address'] not in self.freed,bytes=self.blob(self.uc.mem_read(r['address'],r['count'])),mask=self.blob(r['mask'])) for r in self.regions]);return s
 def queue_event(self,name,args=(),response=None,msg=False):
  e=dict(kind='queue',request=dict(kind=name,arguments=list(args),message=list(self.uc.mem_read(MSG,28)) if msg else None,defined=[bool(v) for v in self.msg_mask] if msg else None),response=response,globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes));self.events.append(e);return e
 def output(self,response):
  if not self.repeat_active:return super().output(response)
  for w in response['writes']:
   at=MSG+w['offset'];raw=bytes(w['bytes']);assert MSG<=at<at+len(raw)<=MSG+28;self.resource_output(at,raw);self.msg_mask[at-MSG:at-MSG+len(raw)]=b'\1'*len(raw)
 def code(self,u,pc,n,data):
  if not self.repeat_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.body_helpers and pc==self.body_helpers[-1]['returnPC']:
   h=self.body_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'],h
   h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.body_returns.append(h)
   if h['entry']==0x43f010:self.current_bitmap=None
   if h['entry']==0x7816d5f0:self.random_calls.append(dict(before=h['random'],after=self.random_state,result=u.reg_read(UC_X86_REG_EAX)))
  if self.clip_pending and pc==self.clip_pending['returnPC']:
   c=self.clip_pending;self.clip_pending=None;self.front_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['sourcePointers']],destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=u.reg_read(UC_X86_REG_EAX)==1))
  if pc==0x43d110:
   if self.step is not None:
    assert not self.body_helpers and self.callback is None;self.iterations.append(dict(spec=self.step,before=self.step_before,after=self.state(),eventEnd=len(self.events),end='continued'))
   if len(self.iterations)==len(self.repeat_spec['steps']):self.repeat_end='iterations';u.emu_stop();return
   self.step=self.repeat_spec['steps'][len(self.iterations)];self.time_index=0;self.step_before=self.state()
  if pc in CHECKPOINTS:
   self.states.append(dict(kind=CHECKPOINTS[pc],state=self.state(),eventIndex=len(self.events)))
   if pc in (0x43e9a0,0x4246b0):self.repeat_abi[str(pc)]=dict(sp=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS],seh=self.u32(0),target=arg(0))
   if pc in (0x43ecbf,0x43d187):
    a=self.repeat_abi[str(0x4246b0 if pc==0x43ecbf else 0x43e9a0)];assert sp==a['sp']+(8 if pc==0x43ecbf else 4) and self.u32(0)==a['seh'] and [u.reg_read(r) for r in REGS]==a['saved'];self.abi_returns.append(dict(entry=a,after=self.state()))
  if pc==0x41bc90:
   assert self.u32(0x458b00)==2;self.repeat_end='loading';self.iterations.append(dict(spec=self.step,before=self.step_before,after=self.state(),eventEnd=len(self.events),end='loading'));u.emu_stop();return
  if pc in (LIB+0x129d,0x43f04b,0x43f12b,0x43f2e6):
   reg=UC_X86_REG_ESI if pc in (LIB+0x129d,0x43f04b) else UC_X86_REG_EAX
   if u.reg_read(reg)==0:self.repeat_end='nullResource';u.emu_stop();return
  if pc==CALLBACK_RETURN:
   c=self.callback;assert c is not None and sp==c['dispatchSP'] and [u.reg_read(r) for r in REGS]==c['saved'];c.update(after=self.state(),result=u.reg_read(UC_X86_REG_EAX));self.ret(u.reg_read(UC_X86_REG_EAX),4);self.callback=None;return
  if pc in self.loop_imports:
   name=self.loop_imports[pc]
   if name in ('peek','get'):
    args=[arg(i) for i in range(1,5 if name=='peek' else 4)];assert arg(0)==MSG and args==[0]*len(args);response=copy.deepcopy(self.step[name]);self.queue_event(name,args,response,True);self.output(response);self.ret(response['result'],20 if name=='peek' else 16);return
   if name in ('translate','dispatchMessage'):
    assert arg(0)==MSG;self.queue_event(name,msg=True)
    if name=='dispatchMessage':
     values=list(struct.unpack('<4I',u.mem_read(MSG,16)));assert values[1] in (0x200,0x201,0x202) and all(self.msg_mask[:16]);c=dict(input=dict(zip(('window','message','wParam','lParam'),values)),dispatchSP=sp,entrySP=sp-20,saved=[u.reg_read(r) for r in REGS],before=self.state());self.callbacks.append(c);self.callback=c
     self.resource_output(sp-20,struct.pack('<5I',CALLBACK_RETURN,*values));u.reg_write(UC_X86_REG_ESP,sp-20);u.reg_write(UC_X86_REG_EIP,0x43b3d0);return
    self.ret(0,4);return
   if name=='sleep':args=[arg(0)];pop=4;result=0
   else:assert name=='windowDefault';args=[arg(i) for i in range(4)];pop=16;result=-123
   self.queue_event(name,args,dict(result=result,writes=[]));self.ret(result,pop);return
  if pc==0x30007500:
   value=self.step['times'][self.time_index];self.time_index+=1;self.queue_event('time',response=dict(result=signed(value),writes=[]));self.ret(value);return
  if pc in NEW_API:
   kind,count=NEW_API[pc];args=[arg(i) for i in range(count)]
   if kind=='free':
    p=args[0];assert p in {r['address'] for r in self.regions} and p not in self.freed;self.front_event('free',args);self.freed.add(p);self.ret();return
   assert args[0] in self.own_sound_buffers;self.front_event('soundMethod',[args[0],kind,*args[1:]]);self.ret(self.repeat_spec['soundResult'],count*4);return
  if pc in MORE_HELPERS:
   h=dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=MORE_HELPERS[pc],saved=[u.reg_read(r) for r in REGS],eventStart=len(self.events),firstStore=len(self.writes))
   if pc==0x7816d5f0:h['random']=self.random_state
   self.body_helpers.append(h)
  if pc==0x422ac0:self.table_start=self.random_state;self.table_index=len(self.random_calls)
  if pc==0x422af7:assert len(self.random_calls)-self.table_index==3000;self.front_event('randomTable',[self.table_start,self.random_state])
  if pc==0x401a30:self.front_event('soundRequest',[arg(0)])
  if pc==0x423b00:assert self.u32(0x458420)==0;self.front_event('panel',[arg(0),arg(1)])
  if pc in (0x401250,0x415160):self.fill_address=sp-100;self.fill_start=len(self.writes)
  if self.window.com_methods.get(pc,('','',0))[1]=='blt':
   ret=self.u32(sp)
   if ret in (0x40127e,0x4151bf):
    effects=self.frame(arg(5),100,self.fill_start)
    if ret==0x40127e:assert arg(1)==arg(2)==arg(3)==0;self.front_event('clear',[arg(0),arg(4)],effects=[effects])
    else:self.front_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=effects['bytes'],defined=effects['defined']))
    self.ret(self.repeat_spec['drawResult'],24);return
   if ret==0x43e975:self.front_event('method',[arg(0),0x14,*[arg(i) for i in range(1,6)]],[bytes(u.mem_read(arg(1),16))]);self.ret(self.repeat_spec['presentResult'],24);return
  if pc in BITMAP_API and BITMAP_API[pc]=='release':
   assert arg(0) in self.surfaces;self.front_event('method',[arg(0),8]);self.surfaces[arg(0)]['released']=True;self.ret(self.repeat_spec['releaseResult'],4);return
  if pc==0x78132e29:return # Declared PTD lookup hook, excluded from original PCs.
  delegate=(0x427127<=pc<0x4275cb or pc in HELPERS or 0x4236d0<=pc<=0x4237d3 or pc in BODY_API or pc in self.library_api or LIB<=pc<LIB+0x5000 or 0x43ef70<=pc<=0x43f2fe or pc in FRONT_API or self.window.com_methods.get(pc,('','',0))[1]=='blt')
  if delegate:
   self.body_active=True
   try:return ApplicationScreenBody.code(self,u,pc,n,data)
   finally:self.body_active=False
  allowed=(0x43d110<=pc<=0x43d20f or 0x43e9a0<=pc<=0x43ed01 or 0x4246b0<=pc<=0x42477f or 0x42709b<=pc<0x427127 or 0x4275cb<=pc<=0x427ca6 or 0x42873e<=pc<=0x428805 or 0x423b00<=pc<=0x423b14 or 0x4242af<=pc<=0x4242b2 or 0x4028a0<=pc<=0x402a5f or 0x43e940<=pc<=0x43e99e or 0x4450b2<=pc<=0x4450ba or 0x401250<=pc<=0x401281 or 0x415160<=pc<=0x4151c2 or 0x401a30<=pc<=0x401a6f or 0x422ac0<=pc<=0x422af7 or 0x7816d5f0<=pc<=0x7816d611 or 0x43b3d0<=pc<=0x43bc40 or 0x4031b0<=pc<=0x40325e or 0x423910<=pc<=0x423938 or 0x43ef50<=pc<=0x43ef68 or pc==0x4450a0)
  assert allowed,('unrecovered repeat child',hex(pc));self.original(u,pc,n)
 def run_input(self,s):
  ps,values,alt=list(parents())[s['parentIndex']];bh,b,sh,sc,fh,fc,body,parent=super().run_menu(ps,values,alt);assert parent['end']=='iteration'
  parent=copy.deepcopy(parent)
  self.bindings=[]
  for pc,(kind,n) in NEW_API.items():
   at=0x44717c if kind=='free' else AUDIO_VTABLE+kind;before=self.u32(at);self.put(at,pc);self.bindings.append(dict(address=at,before=before,after=pc))
  self.bindings.append(dict(address=0x447198,before=self.u32(0x447198),after=0x7816d5f0));self.put(0x447198,0x7816d5f0)
  self.own_sound_buffers={self.u32(0x45560c+i*4) for i in range(5)}-{0}
  assert self.own_sound_buffers=={q['input']['buffer'] for q in self.input.loads}
  self.repeat_spec=s;self.bs=dict(dcResult=s['dcResult'],dc=0x12345678,methodResult=s['drawResult'],drawResults=[s['drawResult']],shellResult=33)
  self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.local_mask=bytearray(0xc0);self.local_reads=[];self.body_helpers=[];self.body_returns=[];self.current_bitmap=None;self.clip_pending=None;self.freed=set();self.step=None;self.iterations=[];self.callbacks=[];self.callback=None;self.states=[];self.repeat_end=None;self.repeat_abi={};self.abi_returns=[];self.random_calls=[];self.msg_mask=bytearray(self.msg_mask)
  before=self.state();crt_before=self.snapshot();self.active=self.repeat_active=True;self.phase='applicationMenuInput'
  try:self.uc.emu_start(0x43d110,0,count=5_000_000)
  except Exception as error:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(error),spec=s,state=self.state(),events=self.events,writes=self.writes,helpers=self.body_helpers,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.repeat_active=False
  assert self.repeat_end is not None
  c=dict(spec=s,parent=key(parent),before=before,after=self.state(),states=self.states,iterations=self.iterations,callbacks=self.callbacks,abiReturns=self.abi_returns,crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,writes=self.writes,stackStores=self.stack_stores,crtStores=self.stores,helpers=self.body_returns,pending=self.body_helpers,localReads=self.local_reads,randomCalls=self.random_calls,bindings=self.bindings,soundBuffers=sorted(self.own_sound_buffers),instructions=self.call_pcs,end=self.repeat_end)
  return bh,b,sh,sc,fh,fc,body,parent,c

def specs():
 def case(label,parent,steps,**kw):return dict(label=label,parentIndex=parent,steps=steps,drawResult=0,presentResult=0,soundResult=0,releaseResult=0,dcResult=0)|kw
 for i in range(48):
  if i!=6:yield case(f'idle-parent-{i}',i,[timer([123456910]*4)])
 for i in (0,1,46):
  steps=[queued(message(0x200,0,(230<<16)|350)),queued(message(0x201)),timer([123456910]*4),queued(message(0x202)),timer([123456950]*4),timer([123456990]*4)]
  yield case(f'activate-parent-{i}',i,steps,presentResult=-1 if i==46 else 0,soundResult=-1 if i==46 else 0,releaseResult=-1 if i==46 else 0)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();items=[];bitmapParents={};settingsParents={};frontParents={};bodyParents={};menuParents={};blobs={};assets={};installation=None
 for i,s in enumerate(list(specs())[a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationMenuInput();vm.capture_path=a.output;bh,b,sh,sc,fh,fc,body,parent,c=vm.run_input(s);bitmapParents[bh]=b;settingsParents[sh]=sc;frontParents[fh]=fc
  if body:bodyParents[key(body)]=body
  menuParents[key(parent)]=parent;items.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  if installation is None:installation=vm.installation
  else:assert installation==vm.installation
  out=parts/f'{i:04d}.json';tmp=out.with_suffix('.tmp');tmp.write_text(json.dumps(dict(case=c,menuParent=parent,bodyParent=body,frontParent=fc,settingsParent=sc,bitmapParent=b,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(tmp,out);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,installation=installation,libraryInitial=vm.lib_initial,libraryAllocations=vm.lib_allocations,cases=items,menuParents=menuParents,bodyParents=bodyParents,frontParents=frontParents,settingsParents=settingsParents,bitmapParents=bitmapParents,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(items),bytes=len(raw),sha256=digest(raw)),flush=True)
