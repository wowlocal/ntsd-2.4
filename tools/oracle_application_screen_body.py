#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own427127/4236d0 and42712c..4275cb with actual installed lib.dll text.
Pinned NTSD EXE/lib/VC80/DIBs, Unicorn2.1.4. Execute relocated DLL attach before
independently entered WinMain, then fresh own startup/loop/resources/settings/
background and body on the same CPU/stack. Trace original bytes, local producer
reads, resource/library state, ordered COM/GDI/critical-section responses.
No expected stack injection, CRT reset between parents, worker execution,
control/protection corruption, bypass, external IO or Windows/device claim.
Research-only; APPLICATION_SCREEN_BODY_PLAN.md; whole dispatcher remains pending.
"""
import argparse,json,struct,os
from pathlib import Path
from collections import Counter
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_application_front_screen import ApplicationFrontScreen,specs as front_specs,FRONT_API
from oracle_application_settings import key,BODY_SP
from oracle_bitmap_surface_loading import TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_bitmap_drawing import digest,signed
from oracle_crt import STOP,DLL_SHA256
from lib_runtime_loader import install_library,BASE as LIB,API as LIB_API
from oracle_lib_initialization import LIB_SHA256
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
HELPERS={0x4236d0:0,0x401290:0,0x43f010:24,0x43ef70:0}
BODY_API={STOP+0xd000:'getDC',STOP+0xd010:'releaseDC'}
LOCAL_SIZE=0xc0

class ApplicationScreenBody(ApplicationFrontScreen):
 def __init__(self):
  self.body_active=False;super().__init__()
  self.installation=install_library(self.uc)
  self.lib_initial=self.blob(self.uc.mem_read(LIB,0x5000))
  self.lib_allocations=[self.blob(self.uc.mem_read(a['address'],a['count'])) for a in self.installation['allocations']]
  pe=PE((DEFAULT_SOURCE/'lib.dll').read_bytes());self.library_api={LIB_API+16*n:i['name'] for n,i in enumerate(pe.imports())}
  self.uc.hook_add(UC_HOOK_MEM_READ,self.body_read)
 def boundary(self,u,pc,n,data):
  if self.body_active:return
  return super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.body_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:
   self.front_mask[p-BASE:p-BASE+n]=b'\1'*n;self.front_event('write',[p,n,v&((1<<(8*n))-1)])
  if BODY_SP<=p<p+n<=BODY_SP+LOCAL_SIZE:
   self.local_mask[p-BODY_SP:p-BODY_SP+n]=b'\1'*n
   assert 0x42712c<=pc<0x4275cb,hex(pc)
   self.front_event('writeLocal',[p-BODY_SP,n,v&((1<<(8*n))-1)])
 def body_read(self,u,access,p,n,v,data):
  if not self.body_active:return
  pc=u.reg_read(UC_X86_REG_EIP)
  if BODY_SP<=p<p+n<=BODY_SP+LOCAL_SIZE:
   self.local_reads.append(dict(pc=pc,address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),written=list(self.local_mask[p-BODY_SP:p-BODY_SP+n]),known=list(self.stack_known[p-STACK:p-STACK+n]),storeCount=len(self.writes),eventIndex=len(self.events)))
  if self.current_bitmap is not None and 0x43f010<=pc<=0x43f2fe and self.current_bitmap<=p<p+n<=self.current_bitmap+0x1f50:
   assert n==4;r=next(r for r in self.regions if r['address']==self.current_bitmap);o=p-r['address']
   self.front_event('read',read=dict(offset=o,value=self.u32(p),defined=all(r['mask'][o:o+n])))
 def body_state(self):
  s=self.front_state();s.update(local=self.blob(self.uc.mem_read(BODY_SP,LOCAL_SIZE)),localMask=self.blob(self.local_mask),library=self.blob(self.uc.mem_read(LIB,0x5000)),retainedDC=self.u32(LIB+0x306e),storeCount=len(self.writes));return s
 def code(self,u,pc,n,data):
  if not self.body_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  while self.body_helpers and pc==self.body_helpers[-1]['returnPC']:
   h=self.body_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'],h
   h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.body_returns.append(h)
   if h['entry']==0x43f010:self.current_bitmap=None
  if self.clip_pending and pc==self.clip_pending['returnPC']:
   c=self.clip_pending;self.clip_pending=None;self.front_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['sourcePointers']],destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=u.reg_read(UC_X86_REG_EAX)==1))
  if pc==0x42712c:self.panel_return=self.body_state()
  if pc==0x4275cb:
   assert sp==BODY_SP and not self.body_helpers;self.body_end='alternateDispatch';u.emu_stop();return
  if pc in (LIB+0x129d,0x43f04b,0x43f12b,0x43f2e6):
   reg=UC_X86_REG_ESI if pc in (LIB+0x129d,0x43f04b) else UC_X86_REG_EAX
   if u.reg_read(reg)==0:self.body_end='nullRead';u.emu_stop();return
  if pc in HELPERS:self.body_helpers.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[u.reg_read(r) for r in REGS],eventStart=len(self.events),firstStore=len(self.writes)))
  if pc==0x401290:self.front_event('text',[arg(0),arg(2),arg(3),arg(4),arg(5)],[self.cstr(arg(1))])
  if pc==0x43f010:
   self.current_bitmap=u.reg_read(UC_X86_REG_ECX);assert arg(5)==self.draw_target;self.front_event('draw',[self.current_bitmap,*[arg(i) for i in range(6)]])
  if pc==0x43ef70:
   assert self.clip_pending is None;src=[arg(i) for i in range(4)];dst=[u.reg_read(UC_X86_REG_ECX),u.reg_read(UC_X86_REG_EDI),arg(4),arg(5)];self.clip_pending=dict(returnPC=self.u32(sp),sourcePointers=src,destinationPointers=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  if pc in FRONT_API:
   name=FRONT_API[pc];assert name in ('enter','leave') and arg(0)==0x4554a4;self.front_event(name,[arg(0)]);self.ret(0,4);return
  if pc in BODY_API:
   name=BODY_API[pc];assert arg(0)==self.draw_target
   if name=='getDC':
    self.front_event(name,[arg(0)]);self.resource_output(arg(1),struct.pack('<I',self.bs['dc']));self.ret(self.bs['dcResult'],8)
   else:self.front_event(name,[arg(0),arg(1)]);self.ret(self.bs['methodResult'],8)
   return
  if pc in self.library_api:
   name=self.library_api[pc]
   if name in ('SetBkMode','SetTextColor'):self.front_event('setBackgroundMode' if name=='SetBkMode' else 'setTextColor',[arg(0),arg(1)]);self.ret(self.bs['methodResult'],8)
   elif name=='lstrlenA':
    raw=self.cstr(arg(0));self.front_event('stringLength',strings=[raw]);self.ret(len(raw),4)
   elif name=='TextOutA':self.front_event('textOut',[arg(0),arg(1),arg(2),arg(4)],[bytes(u.mem_read(arg(3),arg(4)))]);self.ret(self.bs['methodResult'],20)
   else:raise AssertionError(name)
   return
  if self.window.com_methods.get(pc,('','',0))[1]=='blt':
   assert arg(0)==self.draw_target and arg(5)==0;self.front_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',u.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=None));self.ret(self.bs['drawResults'][0],24);return
  assert 0x427127<=pc<0x4275cb or 0x4236d0<=pc<=0x4237d3 or pc==0x401290 or LIB+0x1298<=pc<=LIB+0x1309 or pc in (LIB+0x1c7e,LIB+0x1c84,LIB+0x1c8a,LIB+0x1c90) or 0x43ef70<=pc<=0x43f2fe,hex(pc)
  self.original(u,pc,n)
 def run_body(self,s,fs,ss,data):
  bh,b,sh,sc,fc=super().run_front(fs,ss,data);assert fc['end']=='critical';fh=key(fc);fc=json.loads(json.dumps(fc))
  assert self.blob(self.uc.mem_read(LIB,0x5000))==self.lib_initial
  assert self.u32(0x458424)==0 and self.u32(BODY_SP+0x20)==self.draw_target
  # Add the newly used methods to the existing declared COM vtable. No surface,
  # game/global/caller storage or retained import/register is changed.
  table=self.u32(self.draw_target)
  for offset,name in [(0x44,'getDC'),(0x68,'releaseDC')]:self.uc.mem_write(table+offset,struct.pack('<I',next(p for p,n in BODY_API.items() if n==name)))
  self.bs=s;self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.local_mask=bytearray(LOCAL_SIZE);self.local_reads=[];self.body_helpers=[];self.body_returns=[];self.body_end=None;self.panel_return=None;self.current_bitmap=None;self.clip_pending=None
  before=self.body_state();crt_before=self.snapshot();self.active=self.body_active=True;self.phase='applicationBody'
  try:self.uc.emu_start(0x427127,0,count=500_000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,state=self.body_state(),events=self.events,writes=self.writes,helpers=self.body_helpers,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.body_active=False
  assert self.body_end=='alternateDispatch' and self.panel_return is not None and not self.body_helpers and self.clip_pending is None
  for r in fc['records']:assert self.blob(self.uc.mem_read(r['address'],0x1f50))==r['bytes']
  for a,h in zip(self.installation['allocations'],self.lib_allocations):assert self.blob(self.uc.mem_read(a['address'],a['count']))==h
  c=dict(spec=s,parent=fh,before=before,panelReturn=self.panel_return,after=self.body_state(),crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,writes=self.writes,stackStores=self.stack_stores,crtStores=self.stores,helpers=self.body_returns,localReads=self.local_reads,records=fc['records'],instructions=self.call_pcs,end=self.body_end)
  return bh,b,sh,sc,fh,fc,c

def specs():
 parent=list(front_specs());normal=parent[0]
 def case(label,**kw):return dict(label=label,dcResult=0,dc=0x12345678,methodResult=0,drawResults=[0],shellResult=33)|kw
 for i,values in enumerate(parent):
  if i not in (35,39):yield case('front-'+values[0]['label']),values
 for label,kw in [('dc-negative',dict(dcResult=-1)),('dc-positive',dict(dcResult=1)),('methods-fail',dict(methodResult=-1)),('draw-fail',dict(drawResults=[-1]))]:yield case(label,**kw),normal
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();bitmapParents={};settingsParents={};frontParents={};cases=[];blobs={};assets={};installation=None
 for i,(s,(fs,ss,data)) in enumerate(specs()):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationScreenBody();vm.capture_path=a.output;bh,b,sh,sc,fh,fc,c=vm.run_body(s,fs,ss,data)
  if installation is None:installation=vm.installation
  else:assert installation==vm.installation
  bitmapParents[bh]=b;settingsParents[sh]=sc;frontParents[fh]=fc;cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  out=parts/f'{i:04d}.json';temp=out.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,bitmapParent=b,settingsParent=sc,frontParent=fc,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,out);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,installation=installation,libraryInitial=vm.lib_initial,libraryAllocations=vm.lib_allocations,cases=cases,bitmapParents=bitmapParents,settingsParents=settingsParents,frontParents=frontParents,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,localAddress=BODY_SP,localCount=LOCAL_SIZE,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),parents=len(frontParents),bytes=len(raw),sha256=digest(raw)),flush=True)
