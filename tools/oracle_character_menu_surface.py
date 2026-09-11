#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Controlled character-menu resources4297ae..429e5a with whole bitmap helpers.
Pinned NTSD EXE/VC80/eleven embedded DIBs, Unicorn2.1.4; execute43ee50,
43ed10,4013d0 and CRT memset with the retained image/GDI/COM adapters. Declared
outer frame, globals, allocation backing and ordinary API results are inputs.
Trace instructions, all writes, stack/bitmap reads, masks, helper returns and
lifetimes to recover native resource composition and retained-field provenance.
Normal cookie checks execute unchanged. NULL-SPARK stops BEFORE429b21's null
write; unknown private operands stay unknown. Unexpected faults stop and retain
the error and observations without automatic retries or fault continuation.
No control/protection corruption, exploit, bypass, unrelated target, native
expected-state import, whole own menu return or Windows/device claim. Reference
execution is research-only. See CHARACTER_MENU_SURFACE_PLAN.md.
"""
import argparse, datetime, json, os, struct, traceback
from collections import Counter
from pathlib import Path
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_bitmap_surface_loading import BitmapSurface, BASE, FULL_SIZE, TRACE_STACK, TRACE_SIZE, REGS, DEVICE, STOP, STACK
from oracle_menu_resources import PATHS, SLOTS, STORES, RETURNS
from oracle_bitmap_drawing import digest
from oracle_crt import DLL_SHA256
from import_ntsd import EXE_SHA256

WRAPPERS, WORLD, MENU_SP = 0x50000020, 0x3200f000, 0x1000f000
REGISTER_NAMES = [('eax', UC_X86_REG_EAX), ('ebx', UC_X86_REG_EBX), ('ecx', UC_X86_REG_ECX),
                  ('edx', UC_X86_REG_EDX), ('ebp', UC_X86_REG_EBP), ('esi', UC_X86_REG_ESI), ('edi', UC_X86_REG_EDI)]

class CharacterMenuSurface(BitmapSurface):
 def __init__(self):
  self.menu_active = False
  super().__init__()
  assert all(0x50020000 <= lo or 0x50000000 > hi for lo, hi, _ in self.uc.mem_regions())
  self.uc.mem_map(0x50000000, 0x20000)
  for lo, hi in [(STACK, STACK+0xffff), (0x50000000, 0x5001ffff), (WORLD, WORLD+0x7d7)]:
   self.uc.hook_add(UC_HOOK_MEM_READ, self.read_controlled, begin=lo, end=hi)
 def read_controlled(self, u, access, p, n, v, data):
  if not self.menu_active: return
  known = None; region = 'stack'
  if STACK <= p < p+n <= STACK+0x10000: known = list(self.stack_known[p-STACK:p-STACK+n])
  else:
   for r in self.regions:
    if r['address'] <= p < p+n <= r['address']+r['count']:
     known = list(r['mask'][p-r['address']:p-r['address']+n]); region = r['kind']; break
  row = dict(pc=u.reg_read(UC_X86_REG_EIP), address=p, count=n, bytes=bytes(u.mem_read(p,n)).hex(),
             known=known, region=region if known is not None else 'undeclared', storeCount=len(self.writes), eventIndex=len(self.events))
  self.reads.append(row)
  assert known is not None, ('Undeclared memory read', row)
 def allocate_record(self, address):
  raw = bytes(i%256 for i in range(0x1f50)) if self.rs.get('ramp') else b'\xa5'*0x1f50
  self.uc.mem_write(address-16, b'\x96'*16+raw+b'\x69'*16)
  r = dict(address=address, count=len(raw), kind='bitmap', initial=self.blob(raw), mask=bytearray(len(raw)))
  self.regions.append(r); return r
 def records(self, check_guards=True):
  result = []
  for r in self.regions:
   p, n = r['address'], r['count']
   guards = [bytes(self.uc.mem_read(p-16,16)).hex(), bytes(self.uc.mem_read(p+n,16)).hex()]
   if check_guards: assert guards == ['96'*16,'69'*16], (hex(p), guards)
   result.append(dict(address=p,count=n,kind=r['kind'],initial=r['initial'],bytes=self.blob(self.uc.mem_read(p,n)),mask=self.blob(r['mask']),guards=guards))
  return result
 def snapshot_menu(self):
  result = self.snapshot_resource()
  result['registers'] = {name:self.uc.reg_read(reg) for name,reg in REGISTER_NAMES}
  return result
 def finish_helpers(self, pc):
  sp = self.uc.reg_read(UC_X86_REG_ESP)
  if self.helpers and pc == self.helpers[-1]['returnPC'] and sp == self.helpers[-1]['sp']+4+self.helpers[-1]['pop']:
   h = self.helpers.pop(); assert [self.uc.reg_read(r) for r in REGS] == h['saved']
   h.update(result=self.uc.reg_read(UC_X86_REG_EAX),returnSP=sp,eventEnd=len(self.events),lastStore=len(self.writes))
   if h['kind'] == 'constructor': assert h['result'] == h['wrapper']
   self.returns_resource.append(h)
 def checkpoint_menu(self, kind, index=-1):
  self.checkpoints.append(dict(kind=kind,index=index,snapshot=self.snapshot_menu(),records=self.records(),
                               storeCount=len(self.writes),readCount=len(self.reads),eventCount=len(self.events)))
 def code(self, u, pc, n, data):
  if not self.menu_active: return super().code(u,pc,n,data)
  self.finish_helpers(pc); sp = u.reg_read(UC_X86_REG_ESP)
  if pc == 0x4297e1: self.checkpoint_menu('prefix')
  if pc in STORES:
   index = STORES.index(pc)
   assert self.u32(SLOTS[index]) == self.allocations_resource[index]['address']
   self.checkpoint_menu('bitmap',index)
  if pc == 0x429b21:
   self.checkpoint_menu('seats')
   if u.reg_read(UC_X86_REG_EAX) == 0:
    assert self.u32(0x44f8fc) == 0
    self.end = 'nullSpark'; u.emu_stop(); return
  if pc == 0x429c56: self.checkpoint_menu('flag')
  if pc == 0x429e5a:
   self.checkpoint_menu('complete'); self.end = 'ready'; u.emu_stop(); return
  if pc == 0x4450ac:
   index = len(self.allocations_resource); assert index < 11 and self.u32(sp+4) == 0x1f50
   address = 0 if index in self.rs.get('nulls',[]) else WRAPPERS+(10-index if self.rs.get('reverse') else index)*0x2000
   backing = self.allocate_record(address)['initial'] if address else None
   self.allocations_resource.append(dict(address=address,backing=backing))
   self.events.append(dict(kind='allocate',index=index,address=address,count=0x1f50,caller=self.u32(sp),storeCount=len(self.writes)))
   self.ret(address); return
  if pc == 0x43ee50:
   index = len(self.allocations_resource)-1; address = self.allocations_resource[index]['address']
   path = self.cstr(self.u32(sp+8)).decode()
   assert address != 0 and address == u.reg_read(UC_X86_REG_ECX) and self.u32(sp) == RETURNS[index]
   assert path == PATHS[index] and self.u32(sp+4) == 0x40 and self.u32(sp+12) == 0
   self.events.append(dict(kind='construct',index=index,address=address,path=path,storeCount=len(self.writes)))
  if 0x4297ae <= pc < 0x429e5a: self.original(u,pc,n); return
  return BitmapSurface.code(self,u,pc,n,data)
 def run_menu(self, spec):
  self.rs=spec; self.bind(); self.stores=[]; self.events=[]; self.writes=[]; self.stack_stores=[]; self.global_stores=[]
  self.global_mask=bytearray(0xb440); self.call_pcs={}; self.regions=[]; self.counts=Counter(); self.helpers=[]
  self.returns_resource=[]; self.allocations_resource=[]; self.images={}; self.surfaces={}; self.dcs={}
  self.loader_index=-1; self.end=None; self.reads=[]; self.checkpoints=[]; self.phase='controlledCharacterMenu'
  self.reserved=None; self.provenance=[]; self.stack_known=bytearray(0x10000)
  self.uc.mem_write(TRACE_STACK,b'\xa5'*TRACE_SIZE)
  self.frame_inputs = [(0x14,WORLD),(0x1c,0x451160),(0x24,0x12345678),(0x40,0x44d020),
                       (0x20,0x11223344),(0x28,0x11223344),(0x34,0x11223344),(0x38,0x11223344),(0x3c,0x11223344)]
  for offset,value in self.frame_inputs:
   self.put(MENU_SP+offset,value); self.stack_known[MENU_SP+offset-STACK:MENU_SP+offset-STACK+4]=b'\1'*4
  self.global_inputs = [(0x44d07c,spec.get('loadFlag',1)),(0x44d020,spec.get('menu',10)),
                        (0x4512c8,spec.get('selection',0)),(0x4512cc,0x12345678),(0x457578,DEVICE)]
  for p,v in self.global_inputs: self.put(p,v)
  for slot in SLOTS: self.put(slot,0x87654321)
  self.uc.mem_write(0x451248,bytes((i*7+3)&255 for i in range(96)))
  for name,reg in REGISTER_NAMES: self.uc.reg_write(reg,{'ebp':0x44d020,'edi':WORLD}.get(name,0x12345678))
  self.uc.reg_write(UC_X86_REG_ESP,MENU_SP); self.uc.reg_write(UC_X86_REG_EIP,0x4297ae)
  before=self.snapshot_menu(); crt_before=self.snapshot(); self.active=self.resource_active=self.menu_active=True
  try:
   self.uc.emu_start(0x4297ae,0,count=2_000_000)
   assert self.end in ('ready','nullSpark') and not self.helpers, ('Unreturned controlled caller', self.end, hex(self.uc.reg_read(UC_X86_REG_EIP)))
   assert self.uc.reg_read(UC_X86_REG_ESP) == MENU_SP
   assert [self.u32(MENU_SP+i) for i in (0x20,0x28,0x34,0x38)] == [0]*4
   assert [self.uc.reg_read(r) for r in REGS] == [0xffffffff,0x44d020,0,WORLD]
   return dict(spec=spec,before=before,after=self.snapshot_menu(),frameInputs=self.frame_inputs,globalInputs=self.global_inputs,
               allocations=self.allocations_resource,checkpoints=self.checkpoints,records=self.records(),events=self.events,writes=self.writes,
               reads=self.reads,helpers=self.returns_resource,images=self.images,surfaces=self.surfaces,dcs=self.dcs,
               crtBefore=crt_before,crtAfter=self.snapshot(),instructions=self.call_pcs,end=self.end,mappings=[list(x) for x in self.uc.mem_regions()])
  except Exception as e:
   failure=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),
                traceback=traceback.format_exc(),spec=spec,before=before,after=self.snapshot_menu(),events=self.events,writes=self.writes,
                reads=self.reads,helpers=self.returns_resource,pendingHelpers=self.helpers,records=self.records(False),checkpoints=self.checkpoints,
                instructions=self.call_pcs,blobs=self.blobs,assets=self.assets)
   path=self.capture_path.with_suffix('.failure.json'); assert not path.exists()
   path.write_text(json.dumps(failure,separators=(',',':'))+'\n'); raise
  finally: self.active=self.resource_active=self.menu_active=False

def specs():
 yield dict(kind='controlledMenu',label='nominal-a5')
 yield dict(kind='controlledMenu',label='nominal-ramp-reverse',ramp=True,reverse=True)
 yield dict(kind='controlledMenu',label='disabled-min-max',loadFlag=0,menu=-2147483648,selection=2147483647)
 yield dict(kind='controlledMenu',label='disabled-max-min',loadFlag=0,menu=2147483647,selection=-2147483648)
 yield dict(kind='controlledMenu',label='negative-load-flag',loadFlag=-2147483648)
 for label,indices in [('first',[0]),('last',[10]),('all',list(range(11))),('alternating',list(range(0,10,2)))]:
  yield dict(kind='controlledMenu',label='null-'+label,nulls=indices)
 for label,indices in [('first',[0]),('last',[10]),('all',list(range(11)))]:
  yield dict(kind='controlledMenu',label='missing-'+label,missing=indices)
 for label,key,value in [('surface-first-negative','createSurface#1',-1),('surface-last-positive','createSurface#11',1),
                         ('key-first-negative','colorKey#1',-1),('key-last-negative','colorKey#11',-1),
                         ('dc-last-negative','getDC#11',-1),('stretch-last-zero','stretch#11',0),
                         ('description-last-negative','description#11',-1),('object-first-zero','getObject#1',0)]:
  yield dict(kind='controlledMenu',label=label,results={key:value})

if __name__ == '__main__':
 parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,required=True); parser.add_argument('--limit',type=int)
 args=parser.parse_args(); assert not args.output.exists(); parts=args.output.with_suffix('.parts'); parts.mkdir()
 cases=[]; blobs={}; assets={}
 for index,spec in enumerate(specs()):
  if args.limit is not None and index>=args.limit: break
  vm=CharacterMenuSurface(); vm.capture_path=args.output; case=vm.run_menu(spec)
  part=parts/f'{index:04d}.json'; temp=part.with_suffix('.tmp')
  temp.write_text(json.dumps(dict(case=case,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n'); os.replace(temp,part)
  cases.append(case); blobs.update(vm.blobs); assets.update(vm.assets)
  print('completed',index,spec['label'],case['end'],len(case['events']),len(case['writes']),len(case['reads']),flush=True)
 doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,
          stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,worldToken=WORLD,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode(); temp=args.output.with_suffix('.tmp'); temp.write_bytes(raw); os.replace(temp,args.output)
 print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
