#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continuous original startup/message-loop compatibility study.
Pinned NTSD EXE/VC80/resources on Unicorn2.1.4. Recover43d100..43d21f queue,
MSG lifetime, timer/counter/return order with actual selected43b3d0 callbacks.
Win32 queue/clock/callback delivery is controlled, not actual Windows. Separate
controlled timer cases declare dispatcher/recovery results; own due dispatch
stops at actual43e9a0 without injecting success. No original-file/network,
protection/control corruption or fault-continuation operations. Research only;
see APPLICATION_MESSAGE_LOOP_PLAN.md. Native/app/full game remain separate.
"""
import argparse,copy,json,os,struct
from pathlib import Path
from collections import Counter
from oracle_winmain_startup import WinMainStartup,specifications,FINISH,BASE,SIZE,ENTRYSP
from oracle_calendar_time import REGS,SAVED
from oracle_crt import STOP,STACK
from oracle_bitmap_drawing import digest
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from unicorn.x86_const import *
API,MSG,OUTER,OUTER_SIZE=0x30009000,0x1000f01c,0x458440,0x854
LOOP_NAMES=['peek','get','translate','dispatchMessage','sleep','windowDefault','invalidate','setCursor']
CALLBACK_RETURN=API+0x100
CALLBACK_MESSAGES={0x100,0x101,0x200,0x201,0x202,0x203,0x204,0x205,0x3a0,0x3a1,0x3b5,0x3b6,0x3b7,0x3b8,5,0x1c,0x20,0x112,0x777}

def message(code=0x777,w=0,l=0,window=0x73000001):return [window,code,w&0xffffffff,l&0xffffffff,1234,0xfffffff0,17]
def retrieval(result,values=None):return dict(result=result,writes=[] if values is None else [dict(offset=0,bytes=list(struct.pack('<7I',*values)))])
def queued(values,get=1,bridge=True,peek=1,getValues=True):return dict(peek=retrieval(peek,values),get=retrieval(get,values if getValues else None),bridge=bridge)
def quit_step(value):return queued(message(0x12,value),get=0,bridge=False)
def timer(times,dispatch=1,**kwargs):return dict(peek=retrieval(0),times=times,dispatch=dispatch,**kwargs)

class MessageLoop(WinMainStartup):
 def __init__(self):
  self.loop_active=False;super().__init__(copy.deepcopy(next(specifications())))
  self.loop_imports={API+i*16:name for i,name in enumerate(LOOP_NAMES)}
  for iat,name in [(0x447204,'peek'),(0x447208,'get'),(0x4471c0,'translate'),(0x447210,'dispatchMessage'),(0x447098,'sleep')]:self.put(iat,API+16*LOOP_NAMES.index(name))
  names={'DefWindowProcA':'windowDefault','InvalidateRect':'invalidate','SetCursor':'setCursor'}
  for item in self.pe.imports():
   if item['name'] in names:self.put(int(item['iatVA'],16),API+16*LOOP_NAMES.index(names[item['name']]))
  # Preserve the original startup cursor adapter; only switch this import once
  # the parent has returned, outside any original call. This is API binding.
  self.put(0x4471f8,0x30004510)
 def boundary(self,u,pc,n,data):
  if self.loop_active and pc<0x78000000:return
  super().boundary(u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if self.loop_active:
   b=(v&((1<<(n*8))-1)).to_bytes(n,'little')
   if OUTER<=p<p+n<=OUTER+OUTER_SIZE:self.outer_stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,bytes=b.hex(),eventIndex=len(self.events)));self.outer_mask[p-OUTER:p-OUTER+n]=b'\1'*n
   if MSG<=p<p+n<=MSG+28:self.msg_mask[p-MSG:p-MSG+n]=b'\1'*n
 def request(self,kind,args=(),msg=False,response=None):
  r=dict(kind=kind,arguments=list(args),message=list(self.uc.mem_read(MSG,28)) if msg else None,defined=[bool(x) for x in self.msg_mask] if msg else None)
  e=dict(request=r,response=response or dict(result=0,writes=[]),globals=self.blob(self.uc.mem_read(BASE,SIZE)),outer=self.blob(self.uc.mem_read(OUTER,OUTER_SIZE)),baseline=self.uc.reg_read(UC_X86_REG_ESI),msgStoreCount=len(self.stack_stores))
  self.events.append(e);return e
 def output(self,response):
  for w in response['writes']:
   assert 0<=w['offset']<=w['offset']+len(w['bytes'])<=28
   self.write_host(MSG+w['offset'],bytes(w['bytes']));self.msg_mask[w['offset']:w['offset']+len(w['bytes'])]=b'\1'*len(w['bytes'])
 def snapshot_loop(self):
  return dict(globals=self.blob(self.uc.mem_read(BASE,SIZE)),outer=self.blob(self.uc.mem_read(OUTER,OUTER_SIZE)),message=self.blob(self.uc.mem_read(MSG,28)),messageMask=self.blob(self.msg_mask),baseline=self.uc.reg_read(UC_X86_REG_ESI),counter=self.u32(0x458580),eax=self.uc.reg_read(UC_X86_REG_EAX),sp=self.uc.reg_read(UC_X86_REG_ESP),registers=[self.uc.reg_read(r) for r in REGS],events=len(self.events),globalStores=len(self.global_stores),outerStores=len(self.outer_stores),pc=self.uc.reg_read(UC_X86_REG_EIP))
 def finish_iteration(self,end):
  self.iterations.append(dict(spec=self.step,before=self.loop_before,after=self.snapshot_loop(),end=end));self.step=None
 def code(self,u,pc,n,data):
  if not self.loop_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if pc==0x43d110:
   if self.step is not None:self.finish_iteration('continued')
   if len(self.iterations)==len(self.loop_spec['steps']):self.loop_end='boundedIterations';u.emu_stop();return
   self.step=self.loop_spec['steps'][len(self.iterations)];self.time_index=0;self.loop_before=self.snapshot_loop()
  if pc==STOP:
   self.finish_iteration('quit');self.loop_end='returned';u.emu_stop();return
  if pc==CALLBACK_RETURN:
   assert self.callback is not None and sp==self.callback['dispatchSP']
   self.callback.update(result=u.reg_read(UC_X86_REG_EAX),returnSP=sp,globals=self.blob(u.mem_read(BASE,SIZE)),outer=self.blob(u.mem_read(OUTER,OUTER_SIZE)),registers=[u.reg_read(r) for r in REGS])
   self.dispatch_event['response']['result']=(u.reg_read(UC_X86_REG_EAX)+2**31)%2**32-2**31
   self.ret(u.reg_read(UC_X86_REG_EAX),4);self.callback=None;return
  if pc in self.loop_imports:
   name=self.loop_imports[pc]
   if name in ('peek','get'):
    args=[arg(i) for i in range(1,5 if name=='peek' else 4)];assert arg(0)==MSG and args==([0]*len(args))
    response=copy.deepcopy(self.step[name]);self.request(name,args,True,response);self.output(response);self.ret(response['result'],20 if name=='peek' else 16);return
   if name in ('translate','dispatchMessage'):
    assert arg(0)==MSG;e=self.request(name,(),True,dict(result=self.step.get(name,0),writes=[]))
    if name=='dispatchMessage' and self.step.get('bridge',False):
     values=list(struct.unpack('<4I',u.mem_read(MSG,16)));assert values[1] in CALLBACK_MESSAGES and all(self.msg_mask[:16])
     self.callback=dict(input=dict(zip(('window','message','wParam','lParam'),values)),dispatchSP=sp,entrySP=sp-20,beforeGlobals=self.blob(u.mem_read(BASE,SIZE)),beforeOuter=self.blob(u.mem_read(OUTER,OUTER_SIZE)),eventStart=len(self.events),saved=[u.reg_read(r) for r in REGS]);self.callbacks.append(self.callback);self.dispatch_event=e
     self.write_host(sp-20,struct.pack('<5I',CALLBACK_RETURN,*values));u.reg_write(UC_X86_REG_ESP,sp-20);u.reg_write(UC_X86_REG_EIP,0x43b3d0);return
    self.ret(e['response']['result'],4);return
   if name=='sleep':args=[arg(0)];pop=4
   elif name=='windowDefault':args=[arg(i) for i in range(4)];pop=16
   elif name=='invalidate':args=[arg(i) for i in range(3)];pop=12
   else:args=[arg(0)];pop=4
   result=self.step.get(name,-123 if name=='windowDefault' else 0);self.request(name,args,response=dict(result=result,writes=[]));self.ret(result,pop);return
  if pc==0x30007500:
   value=self.step['times'][self.time_index];self.time_index+=1;self.request('time',response=dict(result=(value+2**31)%2**32-2**31,writes=[]));self.ret(value);return
  if pc==0x43e9a0:
   e=self.request('gameDispatch',[arg(0)],response=dict(result=self.step.get('dispatch',1),writes=[]))
   if self.loop_spec.get('requireDispatcher'):
    e['response']=None;self.loop_end='requiredDispatcher';self.finish_iteration('requiredDispatcher');u.emu_stop();return
   self.ret(e['response']['result']);return
  if pc==0x43e890:self.request('recoverSurface');self.ret(0);return
  # Activation logging is the existing declared debug API, not host output.
  if pc==0x30000130:
   assert self.cstr(arg(0))==b'Active App!\n ';self.request('debug',list(self.cstr(arg(0))));self.ret(0,4);return
  allowed=0x43d100<=pc<=0x43d21f or self.callback is not None and (0x43b3d0<=pc<=0x43bc40 or 0x4031b0<=pc<=0x40325e)
  assert allowed,('unrecovered loop child',hex(pc))
  self.original(u,pc,n)
 def run(self,spec):
  parent=super().run_whole();assert parent['end']=='startupBoundary'
  self.loop_spec=spec;self.loop_initial_outer=self.blob(self.uc.mem_read(OUTER,OUTER_SIZE));self.put(0x4471f8,API+16*LOOP_NAMES.index('setCursor'))
  self.events=[];self.global_stores=[];self.global_mask=bytearray(SIZE);self.stack_stores=[];self.call_pcs={};self.outer_stores=[];self.outer_mask=bytearray(OUTER_SIZE);self.msg_mask=bytearray(28);self.iterations=[];self.callbacks=[];self.step=None;self.callback=None;self.loop_end=None
  stimulus=[]
  for address,value in spec.get('writes',[]):
   raw=struct.pack('<I',value&0xffffffff);self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
  before=self.snapshot_loop();self.loop_active=self.active=True
  try:self.uc.emu_start(FINISH,0,count=1_000_000)
  except Exception as error:
   failure=dict(error=repr(error),snapshot=self.snapshot_loop(),events=self.events,iterations=self.iterations,globalStores=self.global_stores,outerStores=self.outer_stores,stackStores=self.stack_stores,instructions=self.call_pcs,blobs=self.blobs);self.capture_path.with_suffix('.failure.json').write_text(json.dumps(failure,separators=(',',':'))+'\n');raise
  finally:self.loop_active=self.active=False
  assert self.loop_end is not None
  return parent,dict(spec=spec,initialOuter=self.loop_initial_outer,stimulus=stimulus,before=before,after=self.snapshot_loop(),iterations=self.iterations,events=self.events,callbacks=self.callbacks,globalStores=self.global_stores,globalMask=self.blob(self.global_mask),outerStores=self.outer_stores,outerMask=self.blob(self.outer_mask),stackStores=self.stack_stores,instructions=self.call_pcs,end=self.loop_end,controlWord=self.uc.reg_read(UC_X86_REG_FPCW))

def cases():
 seed=123456789
 yield dict(label='own-quit',steps=[quit_step(0)])
 yield dict(label='own-input-and-quit',steps=[queued(message(0x100,65)),queued(message(0x101,65)),queued(message(0x200,0,0xffff0001)),queued(message(0x201)),queued(message(0x202)),queued(message(5,1)),queued(message(5,0)),queued(message(0x3a0,0,0x00300020)),quit_step(37)])
 yield dict(label='own-no-message-yet',steps=[timer([seed+3,seed+3]),timer([seed+33,seed+33]),quit_step(0)])
 yield dict(label='own-required-dispatch',requireDispatcher=True,steps=[queued(message(5,0)),timer([seed+34,seed+34])])
 yield dict(label='own-get-error-retains-peek',steps=[queued(message(0x100,66),get=-1,getValues=False),queued(message(0x101,66)),quit_step(0xffffffff)])
 for counter in [0,59,60,61,0x7ffffffe,0x7fffffff,0x80000000,0xfffffffe,0xffffffff]:
  for get in [1,-1,0]:yield dict(label=f'counter-{counter}-{get}',writes=[(0x458580,counter)],steps=[queued(message(0x777,0x12345678),get=get,getValues=get!=-1),quit_step(0)] if get else [quit_step(0x12345678)])
 for code,w,l in [(0x100,66,0),(0x101,66,0),(0x200,0,0xffffffff),(0x201,0,0),(0x202,0,0),(0x203,0,0),(0x204,0,0),(0x205,0,0),(5,1,0),(5,2,0),(0x20,0,0),(0x112,0xf100,0),(0x112,0xf101,0),(0x777,0,0),(0x3a0,0,0x12345678),(0x3a1,0,0xffff0000),(0x3b5,0xf,0),(0x3b6,0x5,0),(0x3b7,0,0),(0x3b8,0,0)]:
  yield dict(label=f'message-{code}-{w}',steps=[queued(message(code,w,l)),quit_step(13)])
 for speed in [0,1,-1]:
  for result in [-1,0,1]:
   yield dict(label=f'controlled-timer-{speed}-{result}',writes=[(0x44d02c,speed)],steps=[timer([seed+34,seed+150,seed+200,seed+200],result),queued(message(5,1)),timer([seed+240,seed+240,seed+240,seed+240],result),queued(message(5,0)),quit_step(0)])
 yield dict(label='controlled-sleep-four',steps=[timer([seed+33,seed+29]),quit_step(0)])
 yield dict(label='controlled-callback-signed-returns',steps=[{**queued(message(0x777)), 'windowDefault':-2147483648,'translate':-1},quit_step(0x80000000)])
 yield dict(label='own-sixty-three-messages',steps=[queued(message(0x777,n)) for n in range(63)]+[quit_step(63)])

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();parents={};blobs={};items=[];pcs={}
 for i,s in enumerate(cases()):
  if a.limit is not None and i>=a.limit:break
  vm=MessageLoop();vm.capture_path=a.output;parent,c=vm.run(s);key=digest(json.dumps(parent,separators=(',',':'),sort_keys=True).encode());parents[key]=parent;c['parent']=key;items.append(c);blobs.update(vm.blobs);pcs.update(c['instructions'])
  part=dict(case=c,parent=parent,blobs=vm.blobs);raw=(json.dumps(part,separators=(',',':'))+'\n').encode();target=parts/f'{i+1:04d}.json';temp=target.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,target);print('Completed',i+1,s['label'],c['end'],flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,producerSHA256=digest(Path(__file__).read_bytes()),parentProducerSHA256=digest((ROOT/'tools/oracle_winmain_startup.py').read_bytes()),parents=parents,cases=items,blobs=blobs,instructions=pcs)
 a.output.write_text(json.dumps(d,separators=(',',':'))+'\n');print('Complete',len(items),'cases',len(parents),'parents',len(blobs),'blobs',flush=True)
