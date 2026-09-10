#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own first43e9a0/staticWorld entry after continuous NTSD WinMain/message loop.
Pinned EXE/VC80/resources, Unicorn2.1.4, same CPU/stack and own platform handles.
Execute ordinary SEH/cookie prologues, art/query/clear and selected4246b0 prefix
until required original front-resource allocation. No source control/protection
corruption, bypass, invented allocation/body return or Windows/device claim.
All opaque original stack bytes/provenance remain evidence; native compares only
owned platform fields and must not import private caller backing. Research only.
"""
import argparse,copy,json,os,struct
from pathlib import Path
from collections import Counter
from unicorn.x86_const import *
from oracle_application_message_loop import MessageLoop,queued,message,timer,BASE,SIZE,STACK,OUTER,OUTER_SIZE
from oracle_winmain_startup import Events
from oracle_window_initialization import FRAMES
from oracle_bitmap_drawing import digest
from import_ntsd import ROOT,EXE_SHA256
FULL_SIZE=0xc3a8
STACK_BASE,STACK_SIZE=0x1000e800,0x900

class DispatchEntry(MessageLoop):
 def __init__(self):
  self.dispatch_active=False;super().__init__();old=self.window.request
  def request(*args,**kwargs):
   response=old(*args,**kwargs)
   if self.dispatch_active:self.window.events[-1]['fullGlobals']=self.blob(self.uc.mem_read(BASE,FULL_SIZE))
   return response
  self.window.request=request
 def boundary(self,u,pc,n,data):
  if self.dispatch_active and pc<0x78000000:return
  super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if self.dispatch_active:
   b=(v&((1<<(8*n))-1)).to_bytes(n,'little')
   if BASE<=p<p+n<=BASE+FULL_SIZE:
    self.full_stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,bytes=b.hex(),eventIndex=len(self.events)));self.full_mask[p-BASE:p-BASE+n]=b'\1'*n
   if p==0:self.seh_stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,bytes=b.hex()))
   self.window.observe_write(u,access,p,n,v,data)
 def snapshot_dispatch(self):
  return dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),world=self.blob(self.uc.mem_read(0x458b00,0x7d8)),stack=self.blob(self.uc.mem_read(STACK_BASE,STACK_SIZE)),knownStack=self.blob(self.stack_known[STACK_BASE-STACK:STACK_BASE-STACK+STACK_SIZE]),seh=self.u32(0),registers={name:self.uc.reg_read(reg) for name,reg in [('eax',UC_X86_REG_EAX),('ecx',UC_X86_REG_ECX),('ebx',UC_X86_REG_EBX),('ebp',UC_X86_REG_EBP),('esi',UC_X86_REG_ESI),('edi',UC_X86_REG_EDI)]},cw=self.uc.reg_read(UC_X86_REG_FPCW))
 def code(self,u,pc,n,data):
  if not self.dispatch_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);w=self.window
  if pc==0x4450ac:
   self.required=dict(kind='frontBitmapAllocation',address=pc,returnPC=self.u32(sp),count=self.u32(sp+4),sp=sp,world=0x458b00,target=self.world_entry['target'])
   assert self.required['returnPC']==0x424784 and self.required['count']==0x1f50
   self.events.append(dict(kind='required',request=self.required,fullGlobals=self.blob(u.mem_read(BASE,FULL_SIZE))));u.emu_stop();return
  if pc==0x4246b0:
   self.world_entry=dict(address=pc,world=u.reg_read(UC_X86_REG_ECX),target=self.u32(sp+4),sp=sp,returnPC=self.u32(sp),bytes=self.blob(u.mem_read(u.reg_read(UC_X86_REG_ECX),0x7d8)))
   assert self.world_entry['world']==0x458b00
  allowed=0x43e9a0<=pc<=0x43ed01 or 0x43e8e0<=pc<=0x43e934 or 0x401250<=pc<=0x401281 or 0x4246b0<=pc<=0x42477f or pc in w.boundaries or pc in w.com_methods
  assert allowed,('Required unimplemented dispatcher child',hex(pc))
  if pc in FRAMES:
   kind,count=FRAMES[pc];address=sp-count
   self.frame_provenance.append(dict(kind=kind,entry=pc,address=address,count=count,bytes=self.blob(u.mem_read(address,count)),known=list(self.stack_known[address-STACK:address-STACK+count]),stageStackStoreCount=len(self.stack_stores)))
  for h in w.pending_helpers:
   if h['returnPC']==pc and sp==h['sp']+4:
    frame=next((f for f in w.frames if f['sp']==h['sp']),None)
    if frame:self.frame_returns.append(dict(entry=h['address'],address=frame['address'],bytes=self.blob(u.mem_read(frame['address'],frame['count'])),mask=self.blob(frame['mask'])))
  query=w.com_methods.get(pc,('','',0))[1]=='pixelFormat';address=self.u32(sp+8) if query else None
  w.code(u,pc,n,data)
  if query and 'bytes' in w.events[-1]['response']:
   raw=bytes(w.events[-1]['response']['bytes']);self.stack_stores.append(dict(pc=None,address=address,bytes=raw.hex()));self.stack_known[address-STACK:address-STACK+len(raw)]=b'\1'*len(raw)
  if pc not in w.boundaries and pc not in w.com_methods:self.original(u,pc,n)
 def run_entry(self,spec):
  loop_spec=dict(label='own-required-dispatch' if spec['windowParam']==0 else 'own-minimized-required-dispatch',requireDispatcher=True,steps=[queued(message(5,spec['windowParam'])),timer([123456823,123456823])])
  parent,loop=super().run(loop_spec);parent=json.loads(json.dumps(parent));loop=json.loads(json.dumps(loop))
  assert loop['end']=='requiredDispatcher' and self.uc.reg_read(UC_X86_REG_EIP)==0x43e9a0
  assert self.uc.reg_read(UC_X86_REG_ESP)==0x1000eff4
  before=self.snapshot_dispatch();self.parent_stack_history=parent['stackStores']+loop['stackStores']
  self.events=[];self.global_stores=[];self.global_mask=bytearray(SIZE);self.stack_stores=[];self.call_pcs={};self.full_stores=[];self.full_mask=bytearray(FULL_SIZE);self.seh_stores=[];self.frame_provenance=[];self.frame_returns=[];self.required=None;self.world_entry=None
  self.phase='dispatcher';w=self.window;w.spec=dict(results=spec['results']);w.events=Events(self,'surface');w.counts=Counter();w.frames=[];w.backings=[];w.pending_helpers=[];w.helper_returns=[];w.case_instructions={};w.mask=bytearray(SIZE);w.global_writes=[];w.capturing=True
  self.active=self.dispatch_active=True
  try:self.uc.emu_start(0x43e9a0,0,count=100000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=spec,snapshot=self.snapshot_dispatch(),events=self.events,stores=self.full_stores,stackStores=self.stack_stores,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.dispatch_active=False;w.capturing=False
  assert self.required is not None and not w.pending_helpers and not w.frames
  return parent,loop,dict(spec=spec,before=before,after=self.snapshot_dispatch(),events=self.events,stores=self.full_stores,mask=self.blob(self.full_mask),stackStores=self.stack_stores,sehStores=self.seh_stores,frames=self.frame_provenance,frameReturns=self.frame_returns,helperReturns=w.helper_returns,instructions=self.call_pcs,worldEntry=self.world_entry,required=self.required,crtAfter=self.snapshot())

def specs():
 for i,(wp,results) in enumerate([(0,{}),(1,{}),(0,{'pixelFormat#1':-1}),(0,{'blt#1':-1}),(0,{'blt#2':-1}),(0,{'pixelFormat#1':-2147483648,'blt#1':-2147483648,'blt#2':2147483647}),(0,{'pixelFormat#1':2147483647,'blt#1':2147483647,'blt#2':-2147483648}),(1,{'pixelFormat#1':-1,'blt#1':-1,'blt#2':-1})]):yield dict(index=i,windowParam=wp,results=results)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();parents={};loops={};blobs={};cases=[]
 for i,s in enumerate(specs()):
  if a.limit is not None and i>=a.limit:break
  vm=DispatchEntry();vm.capture_path=a.output;parent,loop,c=vm.run_entry(s)
  key=digest(json.dumps(parent,sort_keys=True,separators=(',',':')).encode());parents[key]=parent;loop['parent']=key
  lkey=digest(json.dumps(loop,sort_keys=True,separators=(',',':')).encode());loops[lkey]=loop;c.update(parent=key,loop=lkey);cases.append(c);blobs.update(vm.blobs)
  raw=(json.dumps(dict(case=c,parent=parent,loop=loop,blobs=vm.blobs),separators=(',',':'))+'\n').encode();out=parts/f'{i:04d}.json';tmp=out.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,out);print('completed',i,hex(c['required']['address']),hex(c['required']['sp']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,parents=parents,loops=loops,cases=cases,blobs=blobs,stackAddress=STACK_BASE,stackCount=STACK_SIZE,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),parents=len(parents),loops=len(loops),bytes=len(raw),sha256=digest(raw)))
