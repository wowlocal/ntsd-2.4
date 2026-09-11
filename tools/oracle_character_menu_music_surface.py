#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continuous controlled4229cc->429730 music and whole menu bitmap loading.
Pinned NTSD EXE/VC80/main-track name/11DIBs, Unicorn2.1.4, original prologue,
music helpers, sprintf, bitmap helpers and memset on one CPU. Declared caller,
PTD, allocator and COM/Win32 responses recover ordered ownership and shared
stack provenance. Full stack/SEH/globals/music/bitmap bytes and write/read masks
are observations, never native expected-state inputs. Ordinary failure controls
and unknown consumed operands remain distinct boundaries. Normal cookie/guard
checks execute unchanged; no control/protection corruption, bypass, source-fault
continuation, unrelated system or Windows/device claim. Research only; see
CHARACTER_MENU_MUSIC_SURFACE_PLAN.md. Stop at429e5a, not a whole menu return.
"""
import argparse,datetime,json,os,struct,traceback
from collections import Counter
from pathlib import Path
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
from oracle_character_menu_surface_stack import FullStackMenuSurface
from oracle_character_menu_surface import BASE,FULL_SIZE,TRACE_STACK,TRACE_SIZE,WORLD,STACK,DEVICE,SLOTS,REGISTER_NAMES,REGS,EXE_SHA256,DLL_SHA256,digest
from oracle_music_playback import platform,HELPERS as MUSIC_HELPERS
from oracle_startup_output import SPRINT
from oracle_crt import CRT

BODY_SP,ROOT_SP=0x1000e000,0x1000eab4

class CharacterMenuMusicSurface(FullStackMenuSurface):
 def __init__(self):
  self.join_active=False
  super().__init__()
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_controlled,begin=self.music.music_arena+0x10000,end=self.music.music_arena+0x3fffff)
 def boundary(self,u,pc,n,data):
  if self.join_active and pc in self.boundaries:
   name=self.boundaries[pc]
   self.crt_boundaries.append(dict(pc=pc,name=name,returnPC=self.u32(u.reg_read(UC_X86_REG_ESP)),storeCount=len(self.writes),eventIndex=len(self.events)))
   assert name in ('_getptd','_lock','_unlock'),('Undeclared CRT dependency',name,hex(pc))
   return CRT.boundary(self,u,pc,n,data)
  return super().boundary(u,pc,n,data)
 def read_controlled(self,u,access,p,n,v,data):
  if self.join_active:
   for r in self.music.music_allocations:
    if r['address']<=p<p+n<=r['address']+r['size']:
     off=p-r['address'];self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),known=list(r['mask'][off:off+n]),region='music-wide',storeCount=len(self.writes),eventIndex=len(self.events)));return
  return super().read_controlled(u,access,p,n,v,data)
 def add_backing(self,p,n,kind):
  raw=bytes(i%256 for i in range(n)) if self.spec.get('ramp') else b'\xa5'*n
  self.uc.mem_write(p-16,b'\x96'*16+raw+b'\x69'*16)
  return dict(address=p,size=n,kind=kind,initial=raw,mask=bytearray(n))
 def music_put(self,p,v):self.resource_output(p,struct.pack('<I',v&0xffffffff))
 def mevent(self,kind,args=(),strings=(),result=0,pointer=None,raw=None):
  if not self.join_active:return super().mevent(kind,args,strings,result,pointer,raw)
  e=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],response=dict(result=result,pointer=pointer,bytes=None if raw is None else list(raw)))
  self.music.music_events.append(e)
  self.events.append(dict(kind='music',music=e,globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),storeCount=len(self.writes)))
 def music_records(self,check=True):
  out=[]
  for r in self.music.music_allocations:
   p,n=r['address'],r['size'];guards=[bytes(self.uc.mem_read(p-16,16)).hex(),bytes(self.uc.mem_read(p+n,16)).hex()]
   if check:assert guards==['96'*16,'69'*16],(hex(p),guards)
   out.append(dict(address=p,count=n,kind='music-wide',initial=self.blob(r['initial']),bytes=self.blob(self.uc.mem_read(p,n)),mask=self.blob(r['mask']),guards=guards))
  return out
 def finish_music(self,pc):
  m=self.music;sp=self.uc.reg_read(UC_X86_REG_ESP)
  if m.music_pending and pc==m.music_pending[-1]['returnAddress']:
   c=m.music_pending.pop();assert sp==c['entrySP']+4 and c['saved']==[self.uc.reg_read(r) for r in REGS]
   c.update(returnSP=sp,returned=self.uc.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));m.music_calls.append(c)
 def code(self,u,pc,n,data):
  if not self.join_active:return super().code(u,pc,n,data)
  if pc in self.boundaries:return # Explicit controlled CRT boundary above; not original instruction coverage.
  self.finish_helpers(pc);self.finish_music(pc);sp=u.reg_read(UC_X86_REG_ESP);m=self.music
  if self.current_format and pc==self.current_format['returnPC']:
   f=self.current_format;assert sp==f['sp']+4
   f.update(result=struct.unpack('<i',struct.pack('<I',u.reg_read(UC_X86_REG_EAX)))[0],bytes=list(self.cstr(f['address'])+b'\0'))
   self.formats.append(f);self.current_format=None
   self.mevent('format',[f['result']],[bytes(f['format']),bytes(f['bytes'][:-1])])
  if pc==SPRINT:
   assert self.current_format is None
   fmt=self.cstr(self.u32(sp+8));assert fmt==b'%s\\graph.log'
   self.current_format=dict(sp=sp,returnPC=self.u32(sp),address=self.u32(sp+4),format=list(fmt),directory=list(self.cstr(self.u32(sp+12))))
   self.helpers.append(dict(entry=pc,kind='sprintf',sp=sp,returnPC=self.u32(sp),pop=0,firstStore=len(self.writes),eventStart=len(self.events),saved=[u.reg_read(r) for r in REGS]))
  if pc==0x4297ae:
   assert not m.music_pending and self.current_format is None and not self.helpers
   assert sp==BODY_SP
   self.music_boundary=dict(snapshot=self.snapshot_menu(),allocations=self.music_records(),eventCount=len(self.events),storeCount=len(self.writes),readCount=len(self.reads),crt=self.snapshot())
  music_active=bool(m.music_pending) or pc==0x402020
  music_pc=0x401c90<=pc<=0x401e85 or 0x401f30<=pc<=0x4020f6 or music_active and 0x4450b2<=pc<=0x4450ba
  if music_pc or music_active and (pc==0x4450c8 or pc in m.music_imports):
   event_start=len(self.events);first_store=len(self.writes)
   if music_pc:self.original(u,pc,n)
   m.music_code(u,pc,n,data)
   if pc in MUSIC_HELPERS:m.music_pending[-1].update(eventStart=event_start,firstStore=first_store)
   return
  if 0x4229cc<=pc<0x4229e2 or 0x429730<=pc<0x4297ae:
   self.original(u,pc,n);return
  return super().code(u,pc,n,data)
 def run_join(self,spec):
  self.rs=spec;self.spec['ramp']=spec.get('ramp',False)
  m=self.music;m.bind_music();self.bind();self.put(0x447174,SPRINT)
  m.music_imports[self.u32(0x4471c8)]='message'
  m.put=self.music_put;m.write_host=self.resource_output
  self.stores=[];self.events=[];self.writes=[];self.stack_stores=[];self.global_stores=[];self.global_mask=bytearray(0xb440)
  self.call_pcs={};self.regions=[];self.counts=Counter();self.helpers=[];self.returns_resource=[];self.allocations_resource=[]
  self.images={};self.surfaces={};self.dcs={};self.loader_index=-1;self.end=None;self.reads=[];self.checkpoints=[]
  self.phase='controlledCharacterMenuMusicSurface';self.reserved=None;self.provenance=[];self.stack_known=bytearray(0x10000)
  self.formats=[];self.current_format=None;self.crt_boundaries=[];self.music_boundary=None
  m.music_input=platform(**spec.get('music',{}));m.music_events=[];m.music_calls=[];m.music_formats=[];m.music_allocations=[];m.music_pending=[];m.music_end=-1;m.music_running=True
  self.uc.mem_write(STACK+0x8000,b'\xa5'*0x8000)
  self.put(ROOT_SP+0x68,0x12345678);self.stack_known[ROOT_SP+0x68-STACK:ROOT_SP+0x6c-STACK]=b'\1'*4
  self.global_inputs=[(0x44d07c,spec.get('loadFlag',1)),(0x44d020,spec.get('menu',10)),(0x4512c8,0),
                      (0x4512cc,spec.get('previous',0)),(0x457578,DEVICE),(0x44d010,spec.get('musicEnabled',1)),(0x44d000,75),(0x4546f4,0x73000001)]
  for p,v in self.global_inputs:self.put(p,v)
  for i,p in enumerate((0x44f040,0x44f044,0x44f048,0x44f04c)):self.put(p,m.music_tokens[i])
  for p in SLOTS:self.put(p,0x87654321)
  self.uc.mem_write(0x44ef04,b'bgm\\main.wma\0' if spec.get('cached') else b'old.wma\0')
  self.uc.mem_write(0x44ef38,spec.get('directory','C:\\NTSD').encode()+b'\0');self.uc.mem_write(0x451248,bytes((i*7+3)&255 for i in range(96)))
  for name,reg in REGISTER_NAMES:self.uc.reg_write(reg,WORLD if name=='ebx' else 0x12345678)
  self.uc.reg_write(UC_X86_REG_ESP,ROOT_SP);self.uc.reg_write(UC_X86_REG_EIP,0x4229cc);self.uc.reg_write(UC_X86_REG_FPCW,0x37f)
  before=self.snapshot_menu();crt_before=self.snapshot();self.active=self.resource_active=self.menu_active=self.join_active=True
  try:
   self.uc.emu_start(0x4229cc,0,count=2_000_000)
   assert self.end in ('ready','nullSpark') and not self.helpers and not m.music_pending and self.current_format is None
   assert self.music_boundary is not None and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
   assert [self.u32(BODY_SP+i) for i in (0x20,0x28,0x34,0x38)]==[0]*4
   assert [self.uc.reg_read(r) for r in REGS]==[0xffffffff,0x44d020,0,WORLD]
   assert self.music_records()==self.music_boundary['allocations']
   return dict(spec=spec,before=before,after=self.snapshot_menu(),globalInputs=self.global_inputs,rootSP=ROOT_SP,bodySP=BODY_SP,
               allocations=self.allocations_resource,checkpoints=self.checkpoints,records=self.records(),events=self.events,writes=self.writes,reads=self.reads,
               helpers=self.returns_resource,musicCalls=m.music_calls,musicBoundary=self.music_boundary,musicAllocations=self.music_records(),musicInput=m.music_input,
               formats=self.formats,crtBoundaries=self.crt_boundaries,images=self.images,surfaces=self.surfaces,dcs=self.dcs,crtBefore=crt_before,crtAfter=self.snapshot(),instructions=self.call_pcs,end=self.end,mappings=[list(x) for x in self.uc.mem_regions()])
  except Exception as e:
   p=self.capture_path.with_suffix('.failure.json');assert not p.exists()
   d=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),traceback=traceback.format_exc(),spec=spec,before=before,after=self.snapshot_menu(),events=self.events,writes=self.writes,reads=self.reads,helpers=self.returns_resource,pendingHelpers=self.helpers,musicCalls=m.music_calls,pendingMusic=m.music_pending,musicBoundary=self.music_boundary,records=self.records(False),musicAllocations=self.music_records(False),instructions=self.call_pcs,blobs=self.blobs,assets=self.assets)
   p.write_text(json.dumps(d,separators=(',',':'))+'\n');raise
  finally:self.active=self.resource_active=self.menu_active=self.join_active=m.music_running=False

def specs():
 yield dict(kind='controlledMenuMusicSurface',label='nominal')
 yield dict(kind='controlledMenuMusicSurface',label='ramp-reverse',ramp=True,reverse=True)
 yield dict(kind='controlledMenuMusicSurface',label='previous-menu10',previous=10)
 yield dict(kind='controlledMenuMusicSurface',label='current-menu0',menu=0)
 yield dict(kind='controlledMenuMusicSurface',label='music-disabled',musicEnabled=0)
 yield dict(kind='controlledMenuMusicSurface',label='cached-main',cached=True)
 yield dict(kind='controlledMenuMusicSurface',label='create-graph-negative',music=dict(createResult=-1,createPointer=0))
 yield dict(kind='controlledMenuMusicSurface',label='render-negative',music=dict(renderResult=-1))
 yield dict(kind='controlledMenuMusicSurface',label='null-wide-allocation',music=dict(nullAllocation=True))
 yield dict(kind='controlledMenuMusicSurface',label='surface-last-positive',results={'createSurface#11':1})
 yield dict(kind='controlledMenuMusicSurface',label='retained-after-missing-rface',missing=[9],results={'description#10':-1})
 yield dict(kind='controlledMenuMusicSurface',label='first-description-after-music',results={'description#1':-1})
 yield dict(kind='controlledMenuMusicSurface',label='first-object-after-music',results={'getObject#1':0})
 yield dict(kind='controlledMenuMusicSurface',label='bitmap-load-disabled',loadFlag=0)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);a=p.parse_args()
 assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};assets={}
 for i,s in enumerate(specs()):
  if a.limit is not None and i>=a.limit:break
  vm=CharacterMenuMusicSurface();vm.capture_path=a.output;c=vm.run_join(s)
  part=parts/f'{i:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets);print('completed',i,s['label'],c['end'],len(c['events']),len(c['writes']),len(c['reads']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,assets=assets,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,fullStackAddress=STACK,fullStackCount=0x10000,worldToken=WORLD,crtDataAddress=vm.db,crtDataCount=vm.ds,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
