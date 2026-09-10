#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own41bc90 prologue/common WAVs -> actual catalog allocation request4450ac.
Pinned NTSD/lib/VC80/DIB/WAV, Unicorn2.1.4, same own CPU/stack/resources after
delivered menu input. Execute normal SEH/cookie, bitmap/clip,18 whole4014e0 and
presentation; declare disjoint MMIO/COM/allocator/copy responses. Missing/short
reads are ordinary failures; failed CreateSoundBuffer stops at retained40187a
before unsafe continuation, never a successful match. No source/private stack
import, protective/control corruption, bypass, fault continuation, actual device/
Windows/network/URL or full loading return. APPLICATION_LOADING_PREFIX_PLAN.md.
"""
import argparse,copy,json,os,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_application_menu_input import ApplicationMenuInput,specs as parents
from oracle_application_screen_body import ApplicationScreenBody,HELPERS,BODY_API,LIB
from oracle_application_settings import key
from oracle_bitmap_surface_loading import TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_menu_sound_startup import MenuSoundStartup
from oracle_wave_loader import WaveLoader,platform,data_size,VTABLE
from oracle_bitmap_drawing import digest
from oracle_crt import DLL_SHA256
from oracle_lib_initialization import LIB_SHA256
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
PATHS=['data\\'+p+'.wav' for p in ['001','002','006','010','011','004','016','017','020','021','025','032','033','039','065','066','068','085']]
MEMORY=[0x60000000,0x64000000,0x68000000]

class ApplicationLoadingPrefix(ApplicationMenuInput):
 def __init__(self):self.loading_active=False;super().__init__()
 def boundary(self,u,pc,n,data):
  if self.loading_active:return
  return super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.loading_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(8*n))-1)).to_bytes(n,'little');self.record(p,raw,pc)
  if BASE<=p<p+n<=BASE+FULL_SIZE:self.front_mask[p-BASE:p-BASE+n]=b'\1'*n;self.front_event('write',[p,n,v&((1<<(8*n))-1)])
  if STACK<=p<p+n<=STACK+0x10000:self.wave.stack_written(u,access,p,n,v,data)
 def body_read(self,u,access,p,n,v,data):
  if not self.loading_active:return super().body_read(u,access,p,n,v,data)
  if self.current_bitmap is not None:
   self.body_active=True
   try:ApplicationScreenBody.body_read(self,u,access,p,n,v,data)
   finally:self.body_active=False
  if TRACE_STACK<=p<p+n<=TRACE_STACK+TRACE_SIZE:
   self.loading_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),known=list(self.stack_known[p-STACK:p-STACK+n]),storeCount=len(self.writes)))
 def wave_event(self,kind,args=(),strings=()):
  e=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]);self.wave.events.append(e)
  self.events.append(dict(kind='wave',event=e,globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes)))
 def begin_wave(self,sp):
  w=self.wave;i=len(w.loads);assert i<18;w.wave_entry_sp=sp;w.path=self.cstr(self.u32(sp+4));dst=self.uc.reg_read(UC_X86_REG_ECX)
  assert w.path.decode()==PATHS[i] and dst==0x451db0+i*4
  w.raw=(DEFAULT_SOURCE/PATHS[i].replace('\\','/')).read_bytes();changes={}
  if i==self.loading_spec.get('waveIndex'):
   changes={'open':dict(stream=0),'short':dict(dataReadResult=data_size(w.raw)-1),'create':dict(createResult=-1)}[self.loading_spec['failure']]
  w.p=platform(w.raw,500+i,destination=dst,device=self.u32(0x44eecc),**changes)
  w.allocation=MEMORY[0]+32+i*0x200000;w.p['firstPointer']=MEMORY[1]+32+i*0x200000
  if w.p['secondPointer']:w.p['secondPointer']=MEMORY[2]+32+i*0x200000
  w.put(w.p['buffer'],VTABLE);w.current=dict(label=PATHS[i],path=list(w.path),file=self.blob(w.raw),input=w.p,entrySP=sp,returnPC=self.u32(sp),saved=[self.uc.reg_read(r) for r in REGS],outputBefore=self.u32(dst),beforeGlobals=w.state())
  w.regions={};w.events=[];w.device_format=w.descriptor=None;w.descents=w.reads=w.locks=0;w.stack_mask=bytearray(0x10000)
  w.region('first',w.p['firstPointer'],w.p['firstCount'])
  if w.p['secondPointer']:w.region('second',w.p['secondPointer'],w.p['secondCount'])
  self.wave_event('load',[dst],[w.path])
 def code(self,u,pc,n,data):
  if not self.loading_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i);w=self.wave
  if w.current is not None and pc==w.current['returnPC']:
   assert sp==w.current['entrySP']+8 and [u.reg_read(r) for r in REGS]==w.current['saved'];w.finish_wave('returned',u.reg_read(UC_X86_REG_EAX));self.states.append(dict(kind='wave',state=self.state(),eventIndex=len(self.events)))
  while self.body_helpers and pc==self.body_helpers[-1]['returnPC']:
   h=self.body_helpers.pop();assert sp==h['sp']+4+h['pop'] and [u.reg_read(r) for r in REGS]==h['saved'];h.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes));self.body_returns.append(h)
   if h['entry']==0x43f010:self.current_bitmap=None
  if pc==0x4450ac and w.current is None:
   assert self.u32(sp)==0x41bff5 and arg(0)==0x4d823a8;self.catalog_request=dict(count=arg(0),returnPC=self.u32(sp),sp=sp);self.loading_end='catalogAllocation';u.emu_stop();return
  if pc==0x40187a and w.p['createResult']!=0:
   w.finish_wave('invalidCreateContinuation',None);self.loading_end='invalidCreateContinuation';u.emu_stop();return
  if pc==0x41be98:
   self.body_sp=sp;self.paused=self.u32(sp+0x38);self.commands=[self.blob(u.mem_read(sp+offset,10)) for offset in (0x434,0x440)];self.states.append(dict(kind='prologue',state=self.state(),eventIndex=len(self.events)))
  if pc==0x4014e0:self.begin_wave(sp)
  if w.current is not None:
   if pc in w.imports:return WaveLoader.imported(w,u,pc,n,data)
   if pc in (0x4450ac,0x4450a6,0x4450c2):return w.crt(u,pc,n,data)
   assert 0x4014e0<=pc<=0x40195e or 0x4450b2<=pc<=0x4450ba or pc==0x43f384,hex(pc);self.original(u,pc,n);return
  if pc==0x43e940:self.body_helpers.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),pop=0,saved=[u.reg_read(r) for r in REGS],eventStart=len(self.events),firstStore=len(self.writes)))
  if self.window.com_methods.get(pc,('','',0))[1]=='blt' and self.u32(sp)==0x43e975:
   self.front_event('method',[arg(0),0x14,*[arg(i) for i in range(1,6)]],[bytes(u.mem_read(arg(1),16))]);self.ret(self.repeat_spec['presentResult'],24);return
  if pc in HELPERS or 0x43ef70<=pc<=0x43f2fe or self.window.com_methods.get(pc,('','',0))[1]=='blt':
   self.body_active=True
   try:return ApplicationScreenBody.code(self,u,pc,n,data)
   finally:self.body_active=False
  assert 0x41bc90<=pc<=0x41bff0 or 0x43e940<=pc<=0x43e99e or 0x4450b2<=pc<=0x4450ba,('unrecovered loading child',hex(pc));self.original(u,pc,n)
 def run_loading(self,s):
  parent_values=super().run_input(list(parents())[s['parentIndex']]);parent_values=copy.deepcopy(parent_values);parent=parent_values[-1]
  assert parent['end']=='loading' and self.uc.reg_read(UC_X86_REG_EIP)==0x41bc90
  self.loading_spec=s;self.loading_end=None;self.loading_reads=[];self.catalog_request=None
  # New disjoint response storage only; all previously live allocations survive.
  for p in MEMORY:self.uc.mem_map(p,0x2400000)
  w=self.wave=MenuSoundStartup.__new__(MenuSoundStartup);w.uc=self.uc;w.blobs=self.blobs;w.blob=self.blob;w.put=self.put;w.ret=self.ret;w.imports=self.input.imports.copy();w.imports[self.u32(0x4471c8)]='message';w.running=True;w.prefix=False;w.regions={};w.loads=[];w.current=None;w.stack_mask=bytearray(0x10000);w.event=self.wave_event
  def output(p,raw):WaveLoader.host_write(w,p,raw);self.resource_output(p,raw)
  w.host_write=output
  retained=[(r['address'],r['count'],self.blob(self.uc.mem_read(r['address'],r['count']))) for r in self.regions]
  for load in self.input.loads:
   for r in load['storage']:retained.append((r['address'],self.blobs[r['bytes']]['count'],r['bytes']))
  self.events=[];self.writes=[];self.stack_stores=[];self.stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.front_mask=bytearray(FULL_SIZE);self.call_pcs={};self.local_mask=bytearray(0xc0);self.local_reads=[];self.body_helpers=[];self.body_returns=[];self.current_bitmap=None;self.clip_pending=None;self.states=[]
  before=self.state();crt_before=self.snapshot();self.active=self.loading_active=True;self.phase='applicationLoadingPrefix'
  try:self.uc.emu_start(0x41bc90,0,count=3_000_000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,state=self.state(),events=self.events,writes=self.writes,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.loading_active=w.running=False
  assert self.loading_end is not None and w.current is None and not self.body_helpers
  for p,n,h in retained:assert self.blob(self.uc.mem_read(p,n))==h
  for load in w.loads:
   for r in load['storage']:assert self.blob(self.uc.mem_read(r['address'],self.blobs[r['bytes']]['count']))==r['bytes']
  c=dict(spec=s,parent=key(parent),before=before,after=self.state(),states=self.states,crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,writes=self.writes,helpers=self.body_returns,loads=w.loads,localReads=self.loading_reads,commands=self.commands,paused=self.paused,bodySP=self.body_sp,catalogRequest=self.catalog_request,retained=retained,instructions=self.call_pcs,end=self.loading_end)
  return parent_values,c

def specs():
 for p in (47,48,49):yield dict(label=f'own-parent-{p}',parentIndex=p)
 for i in (0,8,17):
  for f in ('open','short','create'):yield dict(label=f'{f}-{i}',parentIndex=47,waveIndex=i,failure=f)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];parents_out={};blobs={};assets={}
 for i,s in enumerate(list(specs())[a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationLoadingPrefix();vm.capture_path=a.output;parent_values,c=vm.run_loading(s);parents_out[key(parent_values[-1])]=parent_values[-1];cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  out=parts/f'{i:04d}.json';tmp=out.with_suffix('.tmp');tmp.write_text(json.dumps(dict(case=c,parents=parent_values,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(tmp,out);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,libSHA256=LIB_SHA256,cases=cases,parents=parents_out,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,nativeCompared=False,windowsVerified=False);raw=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(raw);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
