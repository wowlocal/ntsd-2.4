#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own4275cb menus -> actual World/dispatcher returns and next loop43d110.
Pinned NTSD EXE/lib/VC80/DIBs on Unicorn2.1.4, same own CPU/stack/resources.
Execute alternate/main/optional panel/bitmap/overlay/present and ordinary SEH/
cookie epilogues, then timer/counter consumer. API responses are declared;
no actual device/network/URL/audio IO, worker delivery or full CRT/NLS claim.
Trace bytes/masks, helper/return ABI, local provenance and ownership. Stop before
NULL resource reads; no control/protection corruption, bypass or fault continuation.
Research only; APPLICATION_MENU_RETURN_PLAN.md; no shipping executable runtime.
"""
import argparse,json,struct,os
from pathlib import Path
from unicorn.x86_const import *
from oracle_application_screen_body import ApplicationScreenBody,specs as body_specs,LIB,BODY_API,HELPERS as BODY_HELPERS
from oracle_application_front_screen import ApplicationFrontScreen,specs as front_specs
from oracle_application_settings import key,BODY_SP
from oracle_bitmap_surface_loading import TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_bitmap_drawing import digest
from oracle_crt import DLL_SHA256
from oracle_lib_initialization import LIB_SHA256
from import_ntsd import ROOT,EXE_SHA256
EXTRA_HELPERS={0x423b00:0,0x4028a0:0,0x43e940:0,0x4450b2:0}

class ApplicationMenuReturn(ApplicationScreenBody):
 def __init__(self):self.menu_active=False;self.own_abi={};super().__init__()
 def boundary(self,u,pc,n,data):
  if self.menu_active:return
  return super().boundary(u,pc,n,data)
 def body_read(self,u,access,p,n,v,data):
  if not self.menu_active:return super().body_read(u,access,p,n,v,data)
  self.body_active=True
  try:return super().body_read(u,access,p,n,v,data)
  finally:self.body_active=False
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.menu_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:
   self.front_mask[p-BASE:p-BASE+n]=b'\1'*n;self.front_event('write',[p,n,v&((1<<(8*n))-1)])
  if BODY_SP<=p<p+n<=BODY_SP+0xc0:self.local_mask[p-BODY_SP:p-BODY_SP+n]=b'\1'*n
 def menu_state(self):
  s=self.body_state();s.update(eax=self.uc.reg_read(UC_X86_REG_EAX),baseline=self.uc.reg_read(UC_X86_REG_ESI),counter=self.u32(0x458580));return s
 def code(self,u,pc,n,data):
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if not self.menu_active:
   if self.active and pc in (0x43e9a0,0x4246b0):self.own_abi[str(pc)]=dict(sp=sp,returnPC=self.u32(sp),registers=[u.reg_read(r) for r in REGS],seh=self.u32(0),eax=u.reg_read(UC_X86_REG_EAX),argument=arg(0))
   return super().code(u,pc,n,data)
  while self.body_helpers and pc==self.body_helpers[-1]['returnPC']:
   h=self.body_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'],h
   h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.body_returns.append(h)
   if h['entry']==0x43f010:self.current_bitmap=None
  if pc==0x427915:self.main_entry=self.menu_state()
  if pc==0x42873e:self.tail_entry=self.menu_state()
  if pc==0x43ecbf:
   a=self.own_abi[str(0x4246b0)];assert sp==a['sp']+8 and self.u32(0)==a['seh'] and [u.reg_read(r) for r in REGS]==a['registers'];self.world_return=self.menu_state()
  if pc==self.own_abi[str(0x43e9a0)]['returnPC']:
   a=self.own_abi[str(0x43e9a0)];assert sp==a['sp']+4 and self.u32(0)==a['seh'] and [u.reg_read(r) for r in REGS]==a['registers'];self.dispatch_return=self.menu_state()
  if pc==0x43d110:
   assert self.world_return is not None and self.dispatch_return is not None and not self.body_helpers and self.clip_pending is None
   self.menu_end='iteration';u.emu_stop();return
  if pc in (0x43f04b,0x43f12b,0x43f2e6):
   reg=UC_X86_REG_ESI if pc==0x43f04b else UC_X86_REG_EAX
   if u.reg_read(reg)==0:self.menu_end='nullBitmap' if pc==0x43f04b else 'nullTarget';u.emu_stop();return
  if pc in EXTRA_HELPERS:self.body_helpers.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=EXTRA_HELPERS[pc],saved=[u.reg_read(r) for r in REGS],eventStart=len(self.events),firstStore=len(self.writes)))
  if pc==0x423b00:
   assert self.u32(0x458420)==0;self.front_event('panel',[arg(0),arg(1)])
  if self.window.com_methods.get(pc,('','',0))[1]=='blt' and self.u32(sp)==0x43e975:
   self.front_event('method',[arg(0),0x14,*[arg(i) for i in range(1,6)]],[bytes(u.mem_read(arg(1),16))]);self.ret(self.ns['presentResult'],24);return
  if pc==0x30007500:self.front_event('time',[self.ns['time']]);self.ret(self.ns['time']);return
  if pc==0x30009040:self.front_event('sleep',[arg(0)]);self.ret(0,4);return
  delegate=(pc in BODY_HELPERS or pc in BODY_API or pc in self.library_api or LIB<=pc<LIB+0x5000 or 0x43ef70<=pc<=0x43f2fe or self.window.com_methods.get(pc,('','',0))[1]=='blt')
  if delegate:
   self.body_active=True
   try:return ApplicationScreenBody.code(self,u,pc,n,data)
   finally:self.body_active=False
  assert 0x4275cb<=pc<=0x427ca6 or 0x42873e<=pc<=0x428805 or 0x423b00<=pc<=0x423b14 or 0x4242af<=pc<=0x4242b2 or 0x4028a0<=pc<=0x402a5f or 0x43e940<=pc<=0x43e99e or 0x4450b2<=pc<=0x4450ba or 0x43ecbf<=pc<=0x43ed01 or 0x43d187<=pc<=0x43d21f,hex(pc)
  self.original(u,pc,n)
 def run_menu(self,s,values,alternate=False):
  if alternate:
   fs,ss,data=values
   bh,b,sh,sc,fc=ApplicationFrontScreen.run_front(self,fs,ss,data);assert fc['end']=='alternate';fh=key(fc);body=None;parent=fh
  else:
   bs,(fs,ss,data)=values;bh,b,sh,sc,fh,fc,body=super().run_body(bs,fs,ss,data);parent=key(body)
  assert self.uc.reg_read(UC_X86_REG_EIP)==0x4275cb and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
  assert self.uc.reg_read(UC_X86_REG_EAX)==(0xfffffffd if alternate else 0)
  self.ns=s;self.bs=dict(dcResult=0,dc=0x12345678,methodResult=0,drawResults=[s['drawResult']],shellResult=33)
  self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.local_mask=bytearray(0xc0);self.local_reads=[];self.body_helpers=[];self.body_returns=[];self.current_bitmap=None;self.clip_pending=None;self.menu_end=None;self.main_entry=self.tail_entry=self.world_return=self.dispatch_return=None
  before=self.menu_state();crt_before=self.snapshot();self.active=self.menu_active=True;self.phase='applicationMenuReturn'
  try:self.uc.emu_start(0x4275cb,0,count=500_000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,state=self.menu_state(),events=self.events,writes=self.writes,helpers=self.body_helpers,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.menu_active=self.body_active=False
  assert self.menu_end is not None
  for r in fc['records']:assert self.blob(self.uc.mem_read(r['address'],0x1f50))==r['bytes']
  c=dict(spec=s,parent=parent,parentKind='front' if alternate else 'body',before=before,mainEntry=self.main_entry,tailEntry=self.tail_entry,worldReturn=self.world_return,dispatchReturn=self.dispatch_return,after=self.menu_state(),abi=self.own_abi,crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,writes=self.writes,stackStores=self.stack_stores,crtStores=self.stores,helpers=self.body_returns,pending=self.body_helpers,localReads=self.local_reads,records=fc['records'],instructions=self.call_pcs,end=self.menu_end)
  return bh,b,sh,sc,fh,fc,body,c

def specs():
 parents=list(body_specs())
 def case(label,**kw):return dict(label=label,drawResult=0,presentResult=0,time=123456901)|kw
 for values in parents:yield case('body-'+values[0]['label']),values,False
 yield case('own-setting-minus-one'),list(front_specs())[39],True
 for label,kw in [('draw-negative',dict(drawResult=-1)),('draw-positive',dict(drawResult=1)),('present-negative',dict(presentResult=-1)),('present-positive',dict(presentResult=1))]:yield case(label,**kw),parents[0],False
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();bitmapParents={};settingsParents={};frontParents={};bodyParents={};cases=[];blobs={};assets={};installation=None
 for i,(s,values,alternate) in enumerate(list(specs())[a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationMenuReturn();vm.capture_path=a.output;bh,b,sh,sc,fh,fc,body,c=vm.run_menu(s,values,alternate)
  if installation is None:installation=vm.installation
  else:assert installation==vm.installation
  bitmapParents[bh]=b;settingsParents[sh]=sc;frontParents[fh]=fc
  if body is not None:bodyParents[key(body)]=body
  cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  out=parts/f'{i:04d}.json';temp=out.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,bitmapParent=b,settingsParent=sc,frontParent=fc,bodyParent=body,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,out);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,installation=installation,libraryInitial=vm.lib_initial,libraryAllocations=vm.lib_allocations,cases=cases,bitmapParents=bitmapParents,settingsParents=settingsParents,frontParents=frontParents,bodyParents=bodyParents,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,localAddress=BODY_SP,localCount=0xc0,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),parents=len(bodyParents),bytes=len(raw),sha256=digest(raw)),flush=True)
