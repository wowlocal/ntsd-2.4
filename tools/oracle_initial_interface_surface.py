#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Controlled loading pool41c052..41c581 with whole UI bitmap construction.
Pinned original NTSD EXE/VC80 and its10 UI DIBs, Unicorn2.1.4. Execute the
World/400Actor constructors, UI caller,43ee50/43ed10/4013d0 and actual CRT memset
on one controlled CPU. Normal constructor cookie checks run unchanged. Declared
catalog[0]/Object+90, outer frame, allocation backing and image/GDI/COM responses
are inputs; they are not a loaded own catalog or Windows/device observations.
Trace all stores, helper returns, full records/masks and ordered platform requests
so Native can compose its own produced dimensions and resource lifetime. Ordinary
NULL bitmap allocations, missing images and numeric API failures are finite
controls. No control/protection corruption, exploit, bypass, unrelated targets,
expected native after-state import or source-fault continuation. Stop at41c581,
not a full41bc90 return. See INITIAL_INTERFACE_SURFACE_PLAN.md. Research only.
"""
import argparse,copy,json,os,struct,traceback
from pathlib import Path
from collections import Counter
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_bitmap_surface_loading import BitmapSurface,BASE,FULL_SIZE,TRACE_STACK,TRACE_SIZE,REGS,DEVICE,STOP,STACK
from oracle_initial_interface import STORES,SLOTS
from oracle_bitmap_drawing import digest
from oracle_crt import DLL_SHA256
from import_ntsd import EXE_SHA256

WORLD,CATALOG,OBJECT=0x74801020,0x74800020,0x74800100
ACTORS,WRAPPERS=0x75000020,0x50000020
PATHS=['PAUSE','DEMO','SCORE_BOARD1','SCORE_BOARD2','SCORE_BOARD3','SCORE_BOARD4','WIN_ALIVE','WIN_DEAD','LOSE_DEAD','BARS']

class InitialInterfaceSurface(BitmapSurface):
 def __init__(self):
  self.interface_active=False
  super().__init__()
  for address,count in [(0x74800000,0x10000),(ACTORS&~4095,0x80000),(WRAPPERS&~4095,0x20000)]:
   assert all(address+count<=lo or address>hi for lo,hi,_ in self.uc.mem_regions()),hex(address)
   self.uc.mem_map(address,count)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_controlled,begin=STACK,end=STACK+0xffff)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_controlled,begin=0x74800000,end=0x75080000)
 def read_controlled(self,u,access,p,n,v,data):
  if not self.interface_active:return
  known=None;region='stack'
  if STACK<=p<p+n<=STACK+0x10000:known=list(self.stack_known[p-STACK:p-STACK+n])
  else:
   for r in self.regions:
    if r['address']<=p<p+n<=r['address']+r['count']:
     known=list(r['mask'][p-r['address']:p-r['address']+n]);region=r['kind'];break
   if known is None and p==CATALOG and n==4:known=[1]*4;region='catalog-entry'
   if known is None and p==OBJECT+0x90 and n==4:known=[1]*4;region='object-word90'
  assert known is not None,(hex(p),n)
  self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),known=known,region=region,storeCount=len(self.writes),eventIndex=len(self.events)))
 def allocate_record(self,address,count,kind):
  raw=bytes(i%256 for i in range(count)) if self.rs.get('ramp') else b'\xa5'*count
  self.uc.mem_write(address-16,b'\x96'*16+raw+b'\x69'*16)
  r=dict(address=address,count=count,kind=kind,initial=self.blob(raw),mask=bytearray(count));self.regions.append(r);return r
 def records(self):
  result=[]
  for r in self.regions:
   p,n=r['address'],r['count'];raw=bytes(self.uc.mem_read(p,n))
   assert self.uc.mem_read(p-16,16)==b'\x96'*16 and self.uc.mem_read(p+n,16)==b'\x69'*16
   result.append(dict(address=p,count=n,kind=r['kind'],initial=r['initial'],bytes=self.blob(raw),mask=self.blob(r['mask'])))
  return result
 def finish_helpers(self,pc):
  sp=self.uc.reg_read(UC_X86_REG_ESP)
  if self.helpers and pc==self.helpers[-1]['returnPC'] and sp==self.helpers[-1]['sp']+4+self.helpers[-1]['pop']:
   h=self.helpers.pop();assert [self.uc.reg_read(r) for r in REGS]==h['saved']
   h.update(result=self.uc.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes))
   if h['kind']=='constructor':assert h['result']==h['wrapper']
   self.returns_resource.append(h)
 def code(self,u,pc,n,data):
  if not self.interface_active:return super().code(u,pc,n,data)
  self.finish_helpers(pc)
  sp=u.reg_read(UC_X86_REG_ESP)
  if pc==0x41c581:self.end='interfaceBoundary';u.emu_stop();return
  if pc in (0x419e40,0x4061d0):
   target=u.reg_read(UC_X86_REG_ECX);kind='world' if pc==0x419e40 else 'actor'
   if kind=='actor':self.actor_calls.append(self.actor_addresses.index(target))
   self.helpers.append(dict(entry=pc,kind=kind,sp=sp,returnPC=self.u32(sp),pop=0,firstStore=len(self.writes),eventStart=len(self.events),saved=[u.reg_read(r) for r in REGS],wrapper=target))
  if pc==0x41c2f5:
   assert len(self.actor_addresses)==400 and self.actor_calls==list(range(400))+list(range(8))
   self.pool_before_interface=self.records();self.before_interface=self.snapshot_resource()
  if pc==0x4450ac:
   count=self.u32(sp+4);caller=self.u32(sp)
   if caller==0x41c07a:
    assert count==0x420 and len(self.actor_addresses)<400
    index=len(self.actor_addresses);physical=399-index if self.rs.get('reverse') else index
    address=ACTORS+physical*0x500;self.allocate_record(address,count,'actor');self.actor_addresses.append(address)
    self.events.append(dict(kind='allocateActor',index=index,address=address,count=count,caller=caller,storeCount=len(self.writes)))
   else:
    index=len(self.allocations_resource);assert index<10 and count==0x1f50
    address=0 if index in self.rs.get('nulls',[]) else WRAPPERS+(9-index if self.rs.get('reverse') else index)*0x2000
    backing=None
    if address:backing=self.allocate_record(address,count,'bitmap')['initial']
    self.allocations_resource.append(dict(address=address,backing=backing))
    self.events.append(dict(kind='allocate',index=index,address=address,count=count,caller=caller,storeCount=len(self.writes)))
   self.ret(address);return
  if pc==0x43ee50:
   index=len(self.allocations_resource)-1;path=self.cstr(self.u32(sp+8)).decode()
   assert path==PATHS[index] and self.u32(sp+4)==0x40 and self.u32(sp+12)==0
   self.events.append(dict(kind='construct',index=index,address=u.reg_read(UC_X86_REG_ECX),path=path,storeCount=len(self.writes)))
  if pc in STORES:
   index=STORES.index(pc)
   self.checkpoints.append(dict(index=index,slot=SLOTS[index],value=self.u32(SLOTS[index]),globals=self.blob(u.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes),eventCount=len(self.events)))
  if 0x419e40<=pc<=0x419e5f or 0x4061d0<=pc<=0x4064cc or 0x41c052<=pc<0x41c581:
   self.original(u,pc,n);return
  return BitmapSurface.code(self,u,pc,n,data)
 def execute(self,start,stop):
  self.uc.emu_start(start,stop,count=2_000_000)
  assert self.uc.reg_read(UC_X86_REG_EIP)==stop,('instruction limit',hex(self.uc.reg_read(UC_X86_REG_EIP)))
  self.finish_helpers(stop)
 def run_interface(self,spec):
  self.rs=spec;self.bind();self.stores=[];self.events=[];self.writes=[];self.stack_stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440);self.call_pcs={};self.regions=[];self.counts=Counter();self.helpers=[];self.returns_resource=[];self.allocations_resource=[];self.images={};self.surfaces={};self.dcs={};self.loader_index=-1;self.end=None;self.reads=[];self.actor_calls=[];self.actor_addresses=[];self.checkpoints=[]
  self.phase='controlledInitialInterface';self.reserved=None;self.provenance=[]
  self.uc.mem_write(TRACE_STACK,b'\xa5'*TRACE_SIZE);self.stack_known=bytearray(0x10000)
  self.allocate_record(WORLD,0x7d8,'world')
  self.put(CATALOG,OBJECT);self.put(OBJECT+0x90,0x12345678)
  self.put(0x44d05c,1);self.put(0x457578,DEVICE)
  for slot in SLOTS:self.put(slot,0x87654321)
  self.put(0x1000f000,STOP);self.stack_known[0xf000:0xf004]=b'\1'*4
  self.uc.reg_write(UC_X86_REG_ESP,0x1000f000);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  self.initial=self.snapshot_resource();self.crt_before=self.snapshot()
  self.active=self.resource_active=self.interface_active=True
  try:
   self.execute(0x419e40,STOP)
   # Declared outer dispatcher selector and caller frame precede the studied
   # continuous pool/UI path. No state is replaced between pool and interface.
   self.events.append(dict(kind='declaredSelector',address=WORLD,value=2,storeCount=len(self.writes)))
   self.resource_output(WORLD,struct.pack('<I',2))
   self.resource_output(0x1000f038,struct.pack('<I',0x12345678))
   self.uc.reg_write(UC_X86_REG_ESP,0x1000f000);self.uc.reg_write(UC_X86_REG_EAX,CATALOG);self.uc.reg_write(UC_X86_REG_EBX,WORLD)
   self.before_pool=self.snapshot_resource()
   self.execute(0x41c052,0x41c581)
   assert self.end is None or self.end=='interfaceBoundary'
   self.end='interfaceBoundary'
   assert not self.helpers and len(self.checkpoints)==10 and self.u32(0x44d05c)==0
   assert self.uc.reg_read(UC_X86_REG_ESP)==0x1000f000 and self.uc.reg_read(UC_X86_REG_EDI)==0x12345678
   after=self.snapshot_resource();records=self.records()
   assert self.pool_before_interface==[r for r in records if r['kind']!='bitmap']
   assert all(all(q['known']) for q in self.reads if q['region']!='stack')
   return dict(spec=spec,initial=self.initial,beforePool=self.before_pool,beforeInterface=self.before_interface,after=after,worldAddress=WORLD,catalogAddress=CATALOG,objectAddress=OBJECT,firstObjectWord90=0x12345678,selector=2,actorAddresses=self.actor_addresses,constructorSlots=self.actor_calls,allocations=self.allocations_resource,checkpoints=self.checkpoints,records=records,events=self.events,writes=self.writes,reads=self.reads,helpers=self.returns_resource,images=self.images,surfaces=self.surfaces,dcs=self.dcs,crtBefore=self.crt_before,crtAfter=self.snapshot(),instructions=self.call_pcs,end=self.end,mappings=[list(x) for x in self.uc.mem_regions()])
  except Exception as e:
   failure=dict(scope=__doc__,error=repr(e),errorText=str(e),traceback=traceback.format_exc(),spec=spec,after=self.snapshot_resource(),events=self.events,writes=self.writes,reads=self.reads,helpers=self.returns_resource,pendingHelpers=self.helpers,records=self.records(),instructions=self.call_pcs,blobs=self.blobs)
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(failure,separators=(',',':'))+'\n');raise
  finally:self.active=self.resource_active=self.interface_active=False

def specs():
 yield dict(kind='controlledUI',label='nominal-a5')
 yield dict(kind='controlledUI',label='nominal-ramp-reverse',ramp=True,reverse=True)
 yield dict(kind='controlledUI',label='null-all',nulls=list(range(10)))
 yield dict(kind='controlledUI',label='null-alternating',nulls=list(range(0,10,2)))
 yield dict(kind='controlledUI',label='missing-first',missing=[0])
 yield dict(kind='controlledUI',label='missing-last',missing=[9])
 yield dict(kind='controlledUI',label='surface-first-negative',results={'createSurface#1':-1})
 yield dict(kind='controlledUI',label='surface-last-positive',results={'createSurface#10':1})
 yield dict(kind='controlledUI',label='key-last-negative',results={'colorKey#10':-1})
 yield dict(kind='controlledUI',label='dc-last-negative',results={'getDC#10':-1})

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--limit',type=int);args=parser.parse_args()
 assert not args.output.exists();parts=args.output.with_suffix('.parts');parts.mkdir()
 cases=[];blobs={};assets={}
 for index,spec in enumerate(specs()):
  if args.limit is not None and index>=args.limit:break
  vm=InitialInterfaceSurface();vm.capture_path=args.output;c=vm.run_interface(spec)
  part=parts/f'{index:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets);print('completed',index,spec['label'],len(c['events']),len(c['writes']),flush=True)
 doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=args.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,args.output)
 print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
