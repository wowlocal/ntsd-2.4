#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own settings -> initial screen selection/fill/background/bitmap draw.
Pinned NTSD EXE/VC80/PE DIBs, Unicorn2.1.4, same CPU/stack/PTD/resources.
Execute original helpers including full image loading/copy and actual sprintf;
timer/thread/allocator/Win32/COM outputs remain declared. Trace full private
stack and own allocations; native unknown fill fields must not import source
bytes. Stop before NULL dereference or screen body. No control/protection
corruption, bypass, worker execution, original file writes or Windows claim.
Research only; APPLICATION_FRONT_SCREEN_PLAN.md. Dispatcher remains pending.
"""
import argparse,json,struct,os
from pathlib import Path
from collections import Counter
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_application_settings import ApplicationSettings,specs as settings_specs,key,BODY_SP
from oracle_bitmap_surface_loading import BitmapSurface,TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_bitmap_drawing import digest,signed
from oracle_crt import STOP,DLL_SHA256
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
FRONT_API={STOP+0xc000:'timer',STOP+0xc010:'enter',STOP+0xc020:'leave',STOP+0xc030:'createThread',STOP+0xc040:'lastError'}
HELPERS={0x4237e0:0,0x43c450:0,0x415160:0,0x423840:0,0x43f010:24,0x43ef70:0,0x7817775d:0}

class ApplicationFrontScreen(ApplicationSettings):
 def __init__(self):
  self.front_active=False;super().__init__();self.uc.hook_add(UC_HOOK_MEM_READ,self.front_read,begin=0x28000000,end=0x281fffff)
 def boundary(self,u,pc,n,data):
  if self.front_active:
   if pc<0x78000000:return
   return super().boundary(u,pc,n,data)
  return super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.front_active:return
  raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');pc=u.reg_read(UC_X86_REG_EIP);self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:
   self.front_mask[p-BASE:p-BASE+n]=b'\1'*n;self.front_event('write',[p,n,v&((1<<(8*n))-1)])
  if self.fill_effects is not None and self.fill_effects<=p<p+n<=self.fill_effects+100:
   self.fill_mask[p-self.fill_effects:p-self.fill_effects+n]=b'\1'*n
 def front_event(self,kind,arguments=(),strings=(),**extra):
  self.events.append(dict(kind='front',event=dict(kind=kind,arguments=list(arguments),strings=[list(s) for s in strings],**extra),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes)))
 def front_read(self,u,access,p,n,v,data):
  if not self.front_active or self.current_bitmap is None or not 0x43f010<=u.reg_read(UC_X86_REG_EIP)<=0x43f2fe:return
  if self.current_bitmap<=p<p+n<=self.current_bitmap+0x1f50:
   assert n==4;r=next(r for r in self.regions if r['address']==self.current_bitmap);o=p-r['address']
   self.front_event('read',read=dict(offset=o,value=self.u32(p),defined=all(r['mask'][o:o+n])))
 def front_state(self):
  return dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),mask=self.blob(self.front_mask),stack=self.blob(self.uc.mem_read(TRACE_STACK,TRACE_SIZE)),knownStack=self.blob(self.stack_known[TRACE_STACK-STACK:TRACE_STACK-STACK+TRACE_SIZE]),cw=self.uc.reg_read(UC_X86_REG_FPCW),seh=self.u32(0),registers=[self.uc.reg_read(r) for r in REGS])
 def code(self,u,pc,n,data):
  if not self.front_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.helpers and pc==self.helpers[-1]['returnPC'] and sp==self.helpers[-1]['sp']+4+self.helpers[-1]['pop']:
   h=self.helpers.pop();assert [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.returns_resource.append(h)
  while self.front_helpers and pc==self.front_helpers[-1]['returnPC']:
   h=self.front_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.front_returns.append(h)
  if self.format_pending and pc==0x4238b9:
   q=self.format_pending;assert sp==q['sp']+4;self.front_event('format',[q['number'],u.reg_read(UC_X86_REG_EAX)],[b'MENU_BACK%d',bytes(u.mem_read(q['address'],14))]);self.format_pending=None
  if self.clip_pending and pc==self.clip_pending['returnPC']:
   c=self.clip_pending;self.clip_pending=None;self.front_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['sourcePointers']],destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=u.reg_read(UC_X86_REG_EAX)==1))
  if pc in (0x427127,0x4275cb):
   assert sp==BODY_SP and not self.helpers and not self.front_helpers;self.front_end='critical' if pc==0x427127 else 'alternate';u.emu_stop();return
  if pc in (0x4151b6,0x43f04b,0x43f12b,0x43f2e6):
   pointer=u.reg_read(UC_X86_REG_ESI if pc==0x43f04b else UC_X86_REG_EAX)
   if pointer==0:
    self.front_end={0x4151b6:'nullFillTarget',0x43f04b:'nullBitmap',0x43f12b:'nullDrawTarget',0x43f2e6:'nullDrawTarget'}[pc];u.emu_stop();return
  if pc==0x43ee50:
   assert self.allocation['address']==u.reg_read(UC_X86_REG_ECX);self.front_event('construct',[u.reg_read(UC_X86_REG_ECX),arg(0),arg(2)],[self.cstr(arg(1))])
  if self.helpers or pc in (0x43ee50,0x43ed10,0x4013d0,self.memset) or pc in self.api:
   self.resource_active=True
   try:return BitmapSurface.code(self,u,pc,n,data)
   finally:self.resource_active=False
  if pc in HELPERS:
   self.front_helpers.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[u.reg_read(r) for r in REGS],eventStart=len(self.events),firstStore=len(self.writes)))
  if pc==0x415160:
   assert [arg(i) for i in range(5)]==[0,0,794,550,0x10206c];self.fill_effects=sp-100;self.fill_mask=bytearray(100);self.fill_frame=dict(address=sp-100,bytes=self.blob(u.mem_read(sp-100,100)),known=self.blob(self.stack_known[sp-100-STACK:sp-STACK]),firstStore=len(self.writes))
  if pc==0x7817775d:
   assert self.cstr(arg(1))==b'MENU_BACK%d' and self.u32(sp)==0x4238b9;self.format_pending=dict(sp=sp,address=arg(0),number=arg(2))
  if pc==0x43f010:
   self.current_bitmap=u.reg_read(UC_X86_REG_ECX);assert [arg(0),arg(2),arg(3),arg(4),arg(5)]==[0,0xffffffff,1,0,self.draw_target];self.front_event('draw',[self.current_bitmap,*[arg(i) for i in range(6)]])
  if pc==0x43ef70:
   assert self.clip_pending is None;src=[arg(i) for i in range(4)];dst=[u.reg_read(UC_X86_REG_ECX),u.reg_read(UC_X86_REG_EDI),arg(4),arg(5)];self.clip_pending=dict(returnPC=self.u32(sp),sourcePointers=src,destinationPointers=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  if self.window.com_methods.get(pc,('','',0))[1]=='blt':
   if self.u32(sp)==0x4151bf:
    assert arg(2)==arg(3)==0 and arg(4)==0x1000400 and arg(5)==self.fill_effects;self.front_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=list(u.mem_read(arg(5),100)),defined=[bool(v) for v in self.fill_mask]));self.ret(self.fs.get('fillResult',0),24)
   else:
    assert arg(0)==self.draw_target;self.front_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',u.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=list(u.mem_read(arg(5),100)) if arg(5) else None));self.ret(self.fs.get('drawResult',0),24)
   return
  if pc in FRONT_API:
   name=FRONT_API[pc]
   if name=='timer':value=self.fs.get('milliseconds',123456900);self.front_event(name,[value]);self.ret(value);return
   if name in ('enter','leave'):assert arg(0)==0x4554a4;self.front_event(name,[arg(0)]);self.ret(0,4);return
   if name=='createThread':
    assert [arg(i) for i in range(5)]==[0,0,0x43c240,0,0] and arg(5)==BODY_SP-8
    thread=self.fs.get('thread',0x50010000);self.front_event(name,[0,0,0x43c240,0,0,thread,0xabcd]);self.resource_output(arg(5),struct.pack('<I',0xabcd));self.ret(thread,24);return
   if name=='lastError':self.front_event(name,[5]);self.ret(5);return
  if pc==0x4450ac:
   assert arg(0)==0x1f50 and self.allocation is None;self.front_event('allocate',[0x1f50]);token=0 if self.fs.get('null') else self.next_wrapper
   if token:
    self.next_wrapper+=0x2000;raw=b'\xa5'*0x1f50;self.uc.mem_write(token,raw);self.regions.append(dict(address=token,count=len(raw),mask=bytearray(len(raw))))
   self.allocation=dict(address=token,backing=self.blob(raw) if token else None);self.ret(token);return
  if pc in self.boundaries:return
  assert 0x42709b<=pc<=0x427121 or 0x4237e0<=pc<=0x423909 or 0x43c450<=pc<=0x43c495 or 0x415160<=pc<=0x4151c2 or 0x43ef70<=pc<=0x43f2fe or 0x4450b2<=pc<=0x4450ba or 0x78130000<=pc<0x781c0000,hex(pc)
  self.original(u,pc,n)
 def run_front(self,s,settings,data):
  bh,b,sc=super().run_settings(settings,data);assert sc['end']=='ready';sh=key(sc);sc=json.loads(json.dumps(sc))
  for p,name in [(0x447250,'timer'),(0x4470a0,'enter'),(0x44709c,'leave'),(0x4470b0,'createThread'),(0x4470a8,'lastError')]:self.uc.mem_write(p,struct.pack('<I',next(a for a,n in FRONT_API.items() if n==name)))
  self.fs=s;self.rs=dict(kind='own',results=s.get('results',{}),missing=[0] if s.get('missing') else []);self.loader_index=-1;self.counts=Counter();self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.helpers=[];self.returns_resource=[];self.front_helpers=[];self.front_returns=[];self.front_end=None;self.allocation=None;self.fill_effects=None;self.fill_frame=None;self.fill_mask=bytearray(100);self.current_bitmap=None;self.clip_pending=None;self.format_pending=None
  self.draw_target=self.uc.reg_read(UC_X86_REG_EDI);assert self.draw_target==b['parents']['entry']['worldEntry']['target'] and self.uc.reg_read(UC_X86_REG_ESI)==0xffffffff
  before=self.front_state();crt_before=self.snapshot();self.active=self.front_active=True;self.phase='applicationFront'
  try:self.uc.emu_start(0x42709b,0,count=2_000_000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,state=self.front_state(),events=self.events,writes=self.writes,helpers=self.helpers,frontHelpers=self.front_helpers,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.front_active=self.resource_active=False
  assert self.front_end is not None and self.clip_pending is None and self.format_pending is None
  for r in b['records']:assert self.blob(self.uc.mem_read(r['address'],0x1f50))==r['bytes']
  c=dict(spec=s,parent=sh,before=before,after=self.front_state(),crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,writes=self.writes,stackStores=self.stack_stores,crtStores=self.stores,helpers=self.returns_resource,frontHelpers=self.front_returns,pending=self.front_helpers,allocation=self.allocation,fillFrame=self.fill_frame,records=[dict(address=r['address'],bytes=self.blob(self.uc.mem_read(r['address'],r['count'])),mask=self.blob(r['mask'])) for r in self.regions],images=self.images,surfaces=self.surfaces,dcs=self.dcs,instructions=self.call_pcs,end=self.front_end)
  return bh,b,sh,sc,c

def specs():
 settings=list(settings_specs());normal,data=settings[0]
 for i,(s,d) in enumerate(settings):
  if s.get('present',True):yield dict(label='settings-'+s['label']),s,d
 for n in range(13):yield dict(label=f'background-{n+1}',milliseconds=n),normal,data
 for label,change in [('missing',dict(missing=True)),('create-negative',dict(results={'createSurface#1':-1})),('create-positive',dict(results={'createSurface#1':1})),('copy-dc-failure',dict(results={'getDC#1':-1})),('color-key-failure',dict(results={'colorKey#1':-1})),('null-background',dict(null=True)),('fill-failure',dict(fillResult=-1)),('draw-failure',dict(drawResult=-1))]:yield dict(label=label,**change),normal,data
 for setting,thread in [(1,0x50010000),(-1,0x50010000),(1,0)]:
  changed=data.replace(b'1 2 3 4\n0\n1\n',b'1 2 3 4\n'+str(setting).encode()+b'\n1\n');assert changed!=data
  yield dict(label=f'setting-{setting}-thread-{thread}',thread=thread),dict(label=f'own-setting-{setting}',resource=dict(kind='own',windowParam=0)),changed
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();bitmapParents={};settingsParents={};cases=[];blobs={};assets={}
 for i,(s,settings,data) in enumerate(list(specs())[a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationFrontScreen();vm.capture_path=a.output;bh,b,sh,sc,c=vm.run_front(s,settings,data);bitmapParents[bh]=b;settingsParents[sh]=sc;cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  out=parts/f'{i:04d}.json';temp=out.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,bitmapParent=b,settingsParent=sc,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,out);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,bitmapParents=bitmapParents,settingsParents=settingsParents,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),parents=len(settingsParents),bytes=len(raw),sha256=digest(raw)),flush=True)
