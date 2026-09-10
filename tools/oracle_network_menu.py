#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Recover whole NTSD network menus with original bitmap/text/sound children.

Pinned EXE/lib.dll/VC80 on Unicorn2.1.4. Install the actual relocated library
before the World constructor and fresh early menu resources. Trace original
menu instructions, live hostname provenance, retained DLL DC and actual helper
returns. Platform/COM/keyboard/network responses are controlled adapters, not
Windows, device or external network operations. No control-field corruption.
The full caller/output joins and acceptance criteria are in NETWORK_MENU_PLAN.
"""
import argparse,json,struct,os
from pathlib import Path
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from oracle_crt import DLL_SHA256,PTD,STOP
from oracle_front_menu_loop import FrontMenuLoop
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,BODY_SP,REGISTERS,SOURCE,ENTRY_SP
from oracle_front_screen_body import HELPERS
from oracle_front_screen_prelude import PAPI,FrontScreenPrelude
from oracle_front_menu_completion import CAPI
from oracle_bitmap_drawing import digest
from oracle_network_notification import exports
from oracle_crt import prepare
from lib_runtime_loader import install_library,BASE as LIB_BASE,API as LIB_API
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_EDI,UC_X86_REG_FPCW

HOST= WORLD+0x7d8
NAPI=0x3000b000
HOSTENT=0x37000000
PRODUCER_SHA256=digest(Path(__file__).read_bytes())
NETWORK_IATS={0x447268:'hostLookup',0x44726c:'socket',0x447270:'htons',0x447280:'addressWord',0x447284:'hostByAddress',0x447288:'connect',0x447294:'send',0x447298:'receive',0x44729c:'cleanup',0x4472a0:'sendTo',0x4472a4:'closeSocket',0x4471c8:'message'}

class NetworkMenu(FrontMenuLoop):
 def __init__(self,control=False):
  self.installing=False;self.network_active=False;self.background_active=False;self.library_pcs={};self.library_writes=[];self.hostname_mask=bytearray(51)
  super().__init__(control)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.network_write)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.network_read)
  self.put(0x4471e8,NAPI)
  self.uc.mem_map(HOSTENT,0x1000)
  self.network_imports={NAPI+0x100+i*16:name for i,name in enumerate(NETWORK_IATS.values())}
  self.actual_memset=exports(PE(prepare().read_bytes()))['memset']
 def before_world_constructor(self):
  self.installing=True
  try:self.installation=install_library(self.uc)
  finally:self.installing=False
  pe=PE((DEFAULT_SOURCE/'lib.dll').read_bytes())
  self.library_imports={LIB_API+16*i:item['name'] for i,item in enumerate(pe.imports())}
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.library_write,begin=LIB_BASE+0x3000,end=LIB_BASE+0x30a0)
  self.hostname_initial=self.backing(51);self.uc.mem_write(HOST,self.hostname_initial)
 def library_write(self,uc,access,address,size,value,data):
  assert address==LIB_BASE+0x306e and size==4,(hex(address),size)
  self.library_writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=address,size=size,value=value&0xffffffff))
 def written(self,uc,access,address,size,value,data):
  if HOST<=address<address+size<=HOST+51:
   self.hostname_mask[address-HOST:address-HOST+size]=b'\1'*size;return
  super().written(uc,access,address,size,value,data)
 def body_write(self,uc,access,address,size,value,data):
  if self.network_active:return
  super().body_write(uc,access,address,size,value,data)
 def network_write(self,uc,access,address,size,value,data):
  if not self.network_active:return
  pc=uc.reg_read(UC_X86_REG_EIP)
  if self.exit_capture is not None and self.exit_capture['frame']<=address<address+size<=self.exit_capture['frame']+256:
   o=address-self.exit_capture['frame'];self.exit_mask[o:o+size]=b'\1'*size
  if BODY_SP+0x14<=address<address+size<=BODY_SP+0x414:
   self.network_local_mask[address-BODY_SP-0x14:address-BODY_SP-0x14+size]=b'\1'*size
   self.network_own_mask[address-BODY_SP-0x14:address-BODY_SP-0x14+size]=b'\1'*size
   self.network_local_writes.append(dict(pc=pc,address=address,bytes=(value&((1<<(8*size))-1)).to_bytes(size,'little').hex(),origin='CPU'))
  if GLOBAL<=address<address+size<=GLOBAL+GLOBAL_SIZE or WORLD<=address<address+size<=HOST+51:
   raw=(value&((1<<(8*size))-1)).to_bytes(size,'little');self.network_writes.append(dict(pc=pc,address=address,bytes=raw.hex()))
   if 0x427ca7<=pc<0x428420:self.body_event('write',[address,size,int.from_bytes(raw,'little')])
 def network_read(self,uc,access,address,size,value,data):
  if self.network_active and BODY_SP+0x14<=address<address+size<=BODY_SP+0x414 and 0x428420<=uc.reg_read(UC_X86_REG_EIP)<0x42873e:
   offset=address-BODY_SP-0x14
   self.network_local_reads.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=address,bytes=bytes(uc.mem_read(address,size)).hex(),ownKnown=list(self.network_own_mask[offset:offset+size])))
  if self.network_active and (HOST<=address<address+size<=HOST+51 or 0x455378<=address<address+size<=0x455378+300):
   self.network_reads.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=address,bytes=bytes(uc.mem_read(address,size)).hex()))
 def body_code_allowed(self,pc):
  return super().body_code_allowed(pc) or self.network_active and (0x427ca7<=pc<0x42873e or 0x422f60<=pc<=0x423222 or 0x402d70<=pc<=0x402eb6 or 0x43f38a<=pc<0x43f3fc or pc==0x4450a0 or 0x4450b2<=pc<=0x4450ba or 0x423910<=pc<=0x423938 or 0x43ef50<=pc<=0x43ef68 or 0x78130000<=pc<0x78230000)
 def memset(self,uc,pc,size,data):
  if self.network_active:return # Let the original4450a0 trampoline reach VC80.
  return super().memset(uc,pc,size,data)
 def network_request(self,name,args=(),payload=b'',result=0,output=b'',host_address=None):
  r=dict(kind=name,arguments=list(args),bytes=list(payload),response=dict(result=result,bytes=list(output),hostAddress=host_address))
  self.body_event('network',[len(self.network_requests)]);self.network_requests.append(r)
 def network_imported(self,pc):
  name=self.network_imports[pc];sp=self.uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i);s=self.menu_input['network']
  if name=='closeSocket':
   n=s.get('closeResult',-1);self.network_request(name,[arg(0)],result=n);self.ret(n,4)
  elif name=='socket':
   n=s.get('socketResult',0x34560003);self.network_request(name,[arg(i) for i in range(3)],result=n);self.ret(n,12)
  elif name in ('hostLookup','hostByAddress'):
   n=HOSTENT if s.get('hostSuccess' if name=='hostLookup' else 'fallbackSuccess',True) else 0;address=s.get('hostAddress',0x0100007f)
   payload=self.cstr(arg(0)) if name=='hostLookup' else bytes(self.uc.mem_read(arg(0),4));args=[] if name=='hostLookup' else [arg(1),arg(2)]
   self.put(HOSTENT+12,HOSTENT+0x100);self.put(HOSTENT+0x100,HOSTENT+0x200);self.put(HOSTENT+0x200,address)
   self.network_request(name,args,payload,n,host_address=address);self.ret(n,4 if name=='hostLookup' else 12)
  elif name=='addressWord':
   n=s.get('addressWordResult',0x0100007f);self.network_request(name,payload=self.cstr(arg(0)),result=n);self.ret(n,4)
  elif name=='htons':
   n=int.from_bytes(struct.pack('>H',arg(0)&0xffff),'little');self.network_request(name,[arg(0)],result=n);self.ret(n,4)
  elif name=='connect':
   assert arg(2)==16;n=s.get('connectResult',0);self.network_request(name,[arg(0),16],self.uc.mem_read(arg(1),16),n);self.ret(n,12)
  elif name=='send':
   assert arg(2)==77;n=s.get('sendResult',77);self.network_request(name,[arg(0),77,arg(3)],self.uc.mem_read(arg(1),77),n);self.ret(n,16)
  elif name=='receive':
   count=arg(2);assert count in (100,77,3001)
   defaults=[b'u can connect\0',b'11110000'+b'0'*68+b'\0',bytes((i*7+3)&255 for i in range(3001))]
   entry=s.get('receives',[]);i=self.receive_index;self.receive_index+=1
   payload=bytes(entry[i]['bytes']) if entry else defaults[i];n=entry[i].get('result',len(payload)) if entry else len(payload);assert len(payload)<=count
   self.network_request(name,[arg(0),count,arg(3)],result=n,output=payload)
   if payload:
    self.uc.mem_write(arg(1),payload)
    write=dict(pc=pc,address=arg(1),bytes=payload.hex(),origin='API')
    if BODY_SP+0x14<=arg(1)<arg(1)+len(payload)<=BODY_SP+0x414:
     self.network_local_mask[arg(1)-BODY_SP-0x14:arg(1)-BODY_SP-0x14+len(payload)]=b'\1'*len(payload)
     self.network_own_mask[arg(1)-BODY_SP-0x14:arg(1)-BODY_SP-0x14+len(payload)]=b'\1'*len(payload);self.network_local_writes.append(write)
    else:
     assert arg(1)==0x44ff90;self.network_writes.append(write)
   self.ret(n,16)
  elif name=='cleanup':
   n=s.get('cleanupResult',0);self.network_request(name,result=n);self.ret(n)
  elif name=='sendTo':
   assert arg(5)==16;payload=bytes(self.uc.mem_read(arg(1),arg(2)))+bytes(self.uc.mem_read(arg(4),16));n=s.get('sendToResult',arg(2))
   self.network_request(name,[arg(0),arg(2),arg(3),arg(5)],payload,n);self.ret(n,24)
  elif name=='message':
   n=s.get('messageResult',1);self.network_request(name,[arg(0),arg(3)],self.cstr(arg(1))+b'\0'+self.cstr(arg(2))+b'\0',n);self.ret(n,16)
  else:raise AssertionError(name)
 def code(self,uc,pc,size,data):
  if self.installing:return
  if self.network_active and (0x400000<=pc<0x446000 or 0x78130000<=pc<0x78230000 or LIB_BASE<=pc<LIB_BASE+0x5000):self.network_pcs[pc]=bytes(uc.mem_read(pc,size)).hex()
  if LIB_BASE<=pc<LIB_BASE+0x5000:
   assert LIB_BASE+0x1298<=pc<=LIB_BASE+0x1309 or pc in [LIB_BASE+x for x in (0x1c7e,0x1c84,0x1c8a,0x1c90)],hex(pc)
   self.library_pcs[pc]=bytes(uc.mem_read(pc,size)).hex();return
  if pc in getattr(self,'library_imports',{}):
   name=self.library_imports[pc];sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
   if name in ('SetBkMode','SetTextColor'):
    self.body_event('setBackgroundMode' if name=='SetBkMode' else 'setTextColor',[arg(0),arg(1)]);self.ret(0xffffffff,8)
   elif name=='lstrlenA':
    raw=self.cstr(arg(0));self.body_event('stringLength',strings=[raw]);self.ret(len(raw),4)
   elif name=='TextOutA':
    self.body_event('textOut',[arg(0),arg(1),arg(2),arg(4)],[bytes(uc.mem_read(arg(3),arg(4)))]);self.ret(0,20)
   else:raise AssertionError(('Unexpected library API',name))
   return
  if self.background_active:
   if self.network_imports.get(pc)=='message':
    sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
    self.emit('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16);return
   if self.gdi.presentation_imports.get(pc)=='release':
    sp=uc.reg_read(UC_X86_REG_ESP);self.emit('release',[self.u32(sp+4)]);self.ret(17,4);return
   FrontScreenPrelude.code(self,uc,pc,size,data)
   if pc!=self.prefix_return:return
   assert not self.calls_pending and self.format_pending is None
   self.background_active=False;self.prefix_active=False;self.input=self.saved_background_input
   self.background_capture=dict(allocation=self.allocation,bitmapInput=self.bitmap_input)
   self.body_returns.extend(self.helper_returns)
  if self.network_active:
   sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
   if pc==0x402d70:
    assert self.exit_capture is None;frame=sp-0x104;self.exit_mask=bytearray(256)
    self.exit_capture=dict(frame=frame,entrySP=sp,returnPC=self.u32(sp),before=self.blob(uc.mem_read(frame,256)))
   if self.exit_capture is not None and pc==self.exit_capture['returnPC'] and 'after' not in self.exit_capture:
    self.exit_capture.update(after=self.blob(uc.mem_read(self.exit_capture['frame'],256)),written=self.blob(self.exit_mask),returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX))
   if pc in (0x42873e,0x4287de):
    assert not self.body_pending and self.format_pending is None and sp==BODY_SP
    self.body_end={0x42873e:'presentation',0x4287de:'epilogue'}[pc];uc.emu_stop();return
   if pc==0x428808:raise AssertionError('Unimplemented selector after declared network menu1/2/3')
   if self.format_pending and pc==self.format_pending['returnPC']:
    f=self.format_pending;self.format_pending=None;assert sp==f['sp']+4
    raw=self.cstr(f['destination']);assert len(raw)==uc.reg_read(UC_X86_REG_EAX)
    self.body_event('format',[len(raw)],[f['format'],raw]);self.network_formats.append(dict(**f,result=uc.reg_read(UC_X86_REG_EAX),bytes=list(raw)+[0]))
   if pc==0x7817775d:
    fmt=self.cstr(arg(1));assert fmt in (b' Your IP Address: %s',b'%s'),fmt
    assert self.format_pending is None
    self.format_pending=dict(sp=sp,returnPC=self.u32(sp),destination=arg(0),format=fmt)
   if pc==0x78132db2:self.ret(PTD);return
   if pc==NAPI:
    assert arg(0)==20;assert self.key_state_index<len(self.menu_input['keyStates'])
    n=self.menu_input['keyStates'][self.key_state_index];self.key_state_index+=1;self.body_event('keyState',[20,n&0xffffffff]);self.ret(n,4);return
   if pc in self.network_imports:self.network_imported(pc);return
   if pc==0x423840:
    assert self.format_pending is None and self.background_capture is None and self.timer_index<len(self.menu_input['timers'])
    self.saved_background_input=self.input;self.input=dict(drawTarget=SOURCE,milliseconds=self.menu_input['timers'][self.timer_index]);self.timer_index+=1
    self.prefix_return=self.u32(sp);self.prefix_events=self.body_events;self.calls_pending=[];self.helper_returns=[];self.clip_pending=None;self.fill_effects=None;self.current_bitmap=None
    self.allocation=None;self.bitmap_input=None;self.null_allocation=False;self.missing=(self.background_boundary or {}).get('missing',False);self.key=(self.background_boundary or {}).get('colorKeyResult',0)
    self.background_active=True;self.prefix_active=True;FrontScreenPrelude.code(self,uc,pc,size,data);return
   if pc==CAPI+32:
    pointer=arg(0);assert pointer in [r['address'] for r in self.regions] and pointer not in self.freed
    self.freed.add(pointer);self.body_event('free',[pointer]);self.ret();return
   self.network_pcs[pc]=bytes(uc.mem_read(pc,size)).hex()
  super().code(uc,pc,size,data)
 def body_step(self,*args,**kwargs):
  before=self.u32(LIB_BASE+0x306e);start=len(self.library_writes)
  c=super().body_step(*args,**kwargs);c.update(libraryDCBefore=before,libraryDCAfter=self.u32(LIB_BASE+0x306e),libraryWrites=self.library_writes[start:]);return c
 def completion_step(self,*args,**kwargs):
  before=self.u32(LIB_BASE+0x306e);start=len(self.library_writes)
  c=super().completion_step(*args,**kwargs);c.update(libraryDCBefore=before,libraryDCAfter=self.u32(LIB_BASE+0x306e),libraryWrites=self.library_writes[start:]);return c
 def finish_network(self,label):
  # Continue the actual predecessor's PC, including the no-presentation error
  # route. Do not recreate a prologue or redirect an error to the display tail.
  pc=self.uc.reg_read(UC_X86_REG_EIP);assert pc in (0x42873e,0x4287de) and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
  self.configure('completion');before=self.u32(LIB_BASE+0x306e);start=len(self.library_writes)
  presentation=dict(targetSurface=SOURCE,methodResult=0,queryResult=0,audioGetResult=0,audioSetResult=0,queriedAudio=SOURCE+48,audioVolume=-1234,dcResult=0,dc=0x12345678,postResult=0)
  self.input=dict(presentation=presentation,drawResults=[0,1]);self.body_input=dict(presentation,drawResults=[0,1],shellResult=31)
  self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_blits=0;self.body_end=None
  self.gdi.presentation_input=presentation;self.gdi.presentation_events=self.body_events
  self.entry='tail' if pc==0x42873e else 'epilogue';self.main_exit=None;self.main_after=None;self.main_events=None
  self.random_calls=[];self.rand_pending=None;self.format_pending=None;self.completion_active=True;self.body_active=True
  try:self.uc.emu_start(pc,0,count=1000000)
  finally:self.completion_active=False;self.body_active=False
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  # The earlier constructor hook stops at STOP before the later completion
  # hook runs. The stopped PC/ABI prove the return, not a nonexistent callback.
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and not self.body_pending and self.format_pending is None and self.rand_pending is None and self.body_clip is None,dict(label=label,pc=hex(self.uc.reg_read(UC_X86_REG_EIP)),sp=hex(self.uc.reg_read(UC_X86_REG_ESP)),pending=self.body_pending,format=self.format_pending,random=self.rand_pending,clip=self.body_clip,lastEvents=self.body_events[-5:])
  assert self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8 and self.u32(0)==0x12345678 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  return dict(label=label,entry=self.entry,stimulus=[],input=self.input,events=self.body_events,helpers=self.body_returns,random=self.random_calls,after=self.snapshot(),
   abi=dict(entryPC=pc,endPC=STOP,endSP=ENTRY_SP+8,saved=saved,seh=0x12345678,fpcw=self.uc.reg_read(UC_X86_REG_FPCW)),libraryDCBefore=before,libraryDCAfter=self.u32(LIB_BASE+0x306e),libraryWrites=self.library_writes[start:])
 def loop_step(self,*args,**kwargs):
  c=super().loop_step(*args,**kwargs)
  for phase in c['phases']:
   for r in phase['value'].get('records',[]):r['live']=r['address'] not in self.freed
  return c
 def parent_capture(self):
  return dict(scope=__doc__,exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,installation=self.installation,
   control=self.control,libraryEnabled=True,parent=self.loop_parent,initialGlobals=self.loop_initial,initialCRT=self.loop_crt,
   hostnameInitial=self.blob(self.hostname_initial),hostname=dict(bytes=self.blob(self.uc.mem_read(HOST,51)),defined=self.blob(self.hostname_mask)),
   libraryDCAfter=self.u32(LIB_BASE+0x306e),libraryInstructions=[dict(address=a,bytes=v) for a,v in sorted(self.library_pcs.items())],blobs=self.blobs)
 def network_step(self,label,timers=(100,)*6,key_states=(0,)*600,dc_result=0,draw_result=0,network=None,background_boundary=None):
  assert self.uc.reg_read(UC_X86_REG_EIP)==0x427ca7 and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
  assert self.uc.reg_read(UC_X86_REG_EBX)==0 and self.uc.reg_read(UC_X86_REG_EDI)==SOURCE
  assert self.u32(BODY_SP+0x18)==WORLD and self.u32(BODY_SP+0x20)==SOURCE
  # Explicit resource-availability control after the real dispatcher. No
  # earlier prefix or initialized ownership claim is attributed to this input.
  if background_boundary is not None:self.put(0x4511ac,0)
  self.background_boundary=background_boundary
  before=self.snapshot();host_before=dict(bytes=self.blob(self.uc.mem_read(HOST,51)),defined=self.blob(self.hostname_mask))
  dc_before=self.u32(LIB_BASE+0x306e);start=len(self.library_writes)
  self.menu_input=dict(timers=list(timers),keyStates=list(key_states),dcResult=dc_result,drawResults=[draw_result],methodResult=0,fillResult=0,dc=0x12345678,shellResult=31,network=network or {})
  self.body_input=self.menu_input;self.alt_input=self.menu_input;self.gdi.presentation_input=self.menu_input
  self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_end=None;self.body_blits=0;self.timer_index=0
  self.fills=[];self.fill=None;self.key_state_index=0;self.network_reads=[];self.network_writes=[];self.network_formats=[];self.network_pcs={};self.format_pending=None;self.network_requests=[];self.receive_index=0;self.background_capture=None;self.exit_capture=None
  local_before=self.blob(self.uc.mem_read(BODY_SP+0x14,0x400));self.network_local_mask=bytearray(0x400);self.network_own_mask=bytearray(0x400);self.network_local_reads=[];self.network_local_writes=[]
  # Only this tick's actual body writes carry native provenance. Source private
  # stack bytes from earlier calls stay preserved, not adopted as initialized.
  if self.u32(0x44d064)==0:self.network_own_mask[:len(self.local_mask)-0x14]=self.local_mask[0x14:]
  # Actual prologue arguments were asserted above. Native supplies these same
  # World/draw-target semantic inputs; this does not import private stack bytes.
  self.network_own_mask[4:8]=b'\1'*4;self.network_own_mask[12:16]=b'\1'*4
  self.gdi.presentation_events=self.body_events;self.body_helpers=HELPERS|{0x415160:0,0x422f60:0,0x402d70:0,0x423910:0,0x43ef50:0};self.body_range=(0x427ca7,0x42873e);self.body_stops={};self.body_sound_slots={0x455610,0x455614}
  saved_iats={iat:self.u32(iat) for iat in list(NETWORK_IATS)+[0x447160]}
  for i,iat in enumerate(NETWORK_IATS):self.put(iat,NAPI+0x100+i*16)
  self.put(0x447160,self.actual_memset)
  self.body_active=True;self.alt_active=True;self.network_active=True
  entry=dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=BODY_SP,eax=self.uc.reg_read(UC_X86_REG_EAX),registers=[self.uc.reg_read(r) for r in REGISTERS],fpcw=self.uc.reg_read(UC_X86_REG_FPCW),semanticArguments=dict(world=WORLD,drawTarget=SOURCE))
  try:self.uc.emu_start(0x427ca7,0,count=1000000)
  finally:
   self.body_active=False;self.alt_active=False;self.network_active=False
   for iat,value in saved_iats.items():self.put(iat,value)
  assert self.body_end and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP and not self.body_pending
  assert self.uc.reg_read(UC_X86_REG_FPCW)==entry['fpcw']
  formats=[dict(f,format=list(f['format'])) for f in self.network_formats]
  return dict(label=label,input=self.menu_input,entry=entry,before=before,hostnameBefore=host_before,backgroundBoundary=background_boundary,
   after=self.snapshot(),hostnameAfter=dict(bytes=self.blob(self.uc.mem_read(HOST,51)),defined=self.blob(self.hostname_mask)),
   libraryDCBefore=dc_before,libraryDCAfter=self.u32(LIB_BASE+0x306e),libraryWrites=self.library_writes[start:],
   events=self.body_events,helpers=self.body_returns,background=self.background_capture,exitFrame=self.exit_capture,fills=[dict(backing=f['backing'],address=f['address']) for f in self.fills],
   reads=self.network_reads,writes=self.network_writes,localReads=self.network_local_reads,localWrites=self.network_local_writes,formats=formats,networkRequests=self.network_requests,
   localBefore=local_before,localAfter=self.blob(self.uc.mem_read(BODY_SP+0x14,0x400)),localWritten=self.blob(self.network_local_mask),
   instructions=[dict(address=a,bytes=v) for a,v in sorted(self.network_pcs.items())],
   continuation=self.body_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=BODY_SP,endFPCW=self.uc.reg_read(UC_X86_REG_FPCW))

def matrix_cases(suite):
 """Finite declared inputs at whole-caller starts; no pointer/control damage.
 The initial connected chain stays separate from these selector/timer controls.
 """
 def state(selector=3,x=0,y=0,held=0,previous=0):
  return [(0x44d064,selector),(0x4546f0,x),(0x453cdc,y),(0x457580,held),(0x44d060,previous),(0x4511b0,0),(0x455378,bytes(300)),(0x44f1ae,b'\0')]
 if suite=='volume':
  yield 'volume-key122',state()+[(0x4553f2,b'\x64')],{}
  return
 if suite=='resources':
  for name,options in [('loaded',{}),('missing',{'missing':True}),('color-key-error',{'colorKeyResult':-1})]:
   yield 'background-boundary-'+name,state(1),dict(background_boundary=options)
  for result in (24,-1):
   yield f'cancel-enabled-notice-{result}',state(1,400,345,1)+[(0x44f1b4,0x3456000b),(0x44f1b0,1),(0x44f208,b'\x7f\x01\x02\x03')],dict(network={'sendToResult':result})
  return
 if suite.startswith('partial-'):
  responses=[dict(bytes=[]),dict(bytes=list(b'11110000'+bytes(24)+b'_'*44+b'\0')),dict(bytes=list(bytes(3001)))]
  if suite!='partial-greeting':
   responses[0]['bytes']=list(b'u can connect\0');responses[1]['bytes']=[] if suite=='partial-flags' else list(b'11110000')
  yield 'unsupported-'+suite,state()+[(0x4511b0,1),(0x44fcc0,b'A\0'+bytes(42))],dict(network={'receives':responses})
  return
 if suite=='matrix':
  rectangles=[('forum',1,368,790,449,536),('host',1,260,547,274,300),('client',1,260,547,305,330),('cancel',1,260,547,336,361),('server-back',2,322,472,361,386),('client-connect',3,239,389,357,382),('client-back',3,411,561,357,382)]
  for name,selector,x0,x1,y0,y1 in rectangles:
   x=(x0+x1)//2;y=(y0+y1)//2
   points=[(x0,y),(x0-1,y),(x1,y),(x1+1,y),(x,y0),(x,y0-1),(x,y1),(x,y1+1),(x,y)]
   for i,(px,py) in enumerate(points):
    for held,previous in [(0,0),(1,0),(2,0),(1,1)]:
     yield f'boundary-{name}-{i}-{held}-{previous}',state(selector,px,py,held,previous)+[(0x4511d4,0),(0x4511f0,2),(0x4511d8,100)],{}
  for shift in (0,100):
   for key in range(300):
    if key%64==0:yield f'key-reset-{shift}-{key}',state(1,300,310,1),{}
    # Key16 aliases the Shift byte. Its actual100 overrides the nominal path.
    yield f'key-{shift}-{key}',state()+[(0x455388,bytes([shift])),(0x455378+key,b'\x64')],{}
  yield 'length-reset',state(1,300,310,1),{}
  yield 'length-empty-backspace',state()+[(0x455380,b'\x64')],{}
  yield 'length-one',state()+[(0x4553b9,b'\x64')],{}
  yield 'length-zero',state()+[(0x455380,b'\x64')],{}
  printable=list(range(48,58))+list(range(65,91))+list(range(96,106))+[32,186,187,188,189,190,191,192,219,220,221,222]
  yield 'length-fill-50',state()+[(0x455378+k,b'\x64') for k in printable],{}
  yield 'length-backspace-to49',state()+[(0x455380,b'\x64')],{}
  yield 'length-49-two-keys',state()+[(0x4553b9,b'\x64\x64')],{}
  yield 'length-retained-full',[],{}
  yield 'length-backspace-then-retained',[(0x455380,b'\x64')],{}
  yield 'simultaneous-back-enter-shift-letters',state()+[(0x455378+k,b'\x64') for k in (8,13,16,65,66,90)],dict(key_states=[1,0,1,0,1,0])
  for pending in (0,2):yield f'pending-{pending}',state()+[(0x4511b0,pending),(0x4553b9,b'\x64')],{}
  for flags in (0,1,2,3,0x80000101):
   for elapsed in (0,149,150,151):
    yield f'timer-flags-{flags}-{elapsed}',state(2)+[(0x4511f0,flags),(0x4511d8,100),(0x4511d4,0)],dict(timers=[100+elapsed]*6)
  for phase in (-2147483648,-1,0,1,3,13,14,2147483647):
   for elapsed in ([151] if phase==2147483647 else [0,151]):
    yield f'timer-phase-{phase}-{elapsed}',state(2)+[(0x4511f0,2),(0x4511d8,100),(0x4511d4,phase)],dict(timers=[100+elapsed]*6)
  yield 'timer-unsigned-wrap',state(2)+[(0x4511f0,2),(0x4511d8,0xffffff80),(0x4511d4,13)],dict(timers=[23]*6)
  yield 'server-connected-byte2',state(2)+[(0x44f1ae,b'\2'),(0x4511d4,0)],{}
  for name,options in [('loaded',{}),('missing',{'missing':True}),('color-key-error',{'colorKeyResult':-1})]:
   yield 'background-boundary-'+name,state(1),dict(background_boundary=options)
  for result in (24,-1):
   yield f'cancel-enabled-notice-{result}',state(1,400,345,1)+[(0x44f1b4,0x3456000b),(0x44f1b0,1),(0x44f208,b'\x7f\x01\x02\x03')],dict(network={'sendToResult':result})
 # These complete ordinary operation errors and ignored numeric results. Full
 # response bytes are independent of return values, as in the retained client.
 yield 'client-error-hostname-reset',state(1,300,310,1),{}
 bounded_names=b'A\0'+bytes(42)
 for field,value in [('socketResult',-1),('hostSuccess',False),('connectResult',-1),('greetingMismatch',True),('sendResult',-1),('receiveResults',-1)]:
  network={field:value}
  if field=='hostSuccess':network['fallbackSuccess']=False
  if field=='greetingMismatch':network={'receives':[dict(bytes=list(b'no\0'))]}
  if field=='receiveResults':network={'receives':[dict(bytes=list(b'u can connect\0'),result=-1),dict(bytes=list(b'11110000'+bytes(24)+b'_'*44+b'\0'),result=-1),dict(bytes=list(bytes(3001)),result=-1)]}
  if field=='sendResult':network['receives']=[dict(bytes=list(b'u can connect\0')),dict(bytes=list(b'11110000'+bytes(24)+b'_'*44+b'\0')),dict(bytes=list(bytes(3001)))]
  yield 'client-operation-'+field,state()+[(0x4511b0,1),(0x44fcc0,bounded_names)],dict(network=network)
 if suite=='matrix':
  yield 'client-fallback-success',state()+[(0x4511b0,1),(0x44fcc0,bounded_names)],dict(network={'hostSuccess':False,'receives':[dict(bytes=list(b'u can connect\0')),dict(bytes=list(b'11110000'+bytes(24)+b'_'*44+b'\0')),dict(bytes=list(bytes(3001)))]})
  yield 'client-partial-rng',state()+[(0x4511b0,1),(0x44fcc0,bounded_names)],dict(network={'receives':[dict(bytes=list(b'u can connect\0')),dict(bytes=list(b'11110000'+bytes(24)+b'_'*44+b'\0')),dict(bytes=[],result=0)]})
  yield 'server-connected-byte1',state(2)+[(0x44f1ae,b'\1'),(0x4511d4,0)],{}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--control',action='store_true');p.add_argument('--parent-only',action='store_true');p.add_argument('--suite',choices=['probe','errors','matrix','volume','resources','partial-greeting','partial-flags','partial-names'],default='probe');a=p.parse_args();path=ROOT/a.output;assert not path.exists()
 parts=path.with_suffix('.parts');parts.mkdir(exist_ok=False);part_pins=[];known_blobs=set()
 def checkpoint(value):
  additions={k:v for k,v in vm.blobs.items() if k not in known_blobs};known_blobs.update(additions)
  raw=(json.dumps(dict(value=value,blobs=additions),separators=(',',':'))+'\n').encode();name=f'{len(part_pins):04d}.json';temp=parts/(name+'.tmp');temp.write_bytes(raw);os.replace(temp,parts/name)
  part_pins.append(dict(path=name,sha256=digest(raw),bytes=len(raw)));temp=parts/'index.tmp';temp.write_text(json.dumps(part_pins,indent=2)+'\n');os.replace(temp,parts/'index.json')
 vm=NetworkMenu(a.control);doc=vm.parent_capture();doc['producerSHA256']=PRODUCER_SHA256;checkpoint(doc)
 if not a.parent_only:
  # Actual main-menu network selection creates the listener/address state.
  mouse=lambda x,y,h:[(0x4546f0,x),(0x453cdc,y),(0x457580,h)]
  calls=[dict(loop=vm.loop_step('next-natural-frame'))]
  checkpoint(calls[-1])
  calls.append(dict(loop=vm.loop_step('open-network',mouse(300,252,1))))
  checkpoint(calls[-1])
  for label,stimulus in [('choice-idle',mouse(0,0,0)),('choose-client',mouse(300,310,1)),('client-idle',mouse(0,0,0)),('client-type',[(0x455378+65,b'\x64')]),('client-enter',[(0x455385,b'\x64')]),('client-connect',[]),('controlled-host-choice',mouse(300,280,1)+[(0x44d064,1)]),('server-idle',mouse(0,0,0)),('server-dots',[(0x4511d4,3)]),('server-back',mouse(400,370,1)),('choice-release',mouse(0,0,0)),('choice-cancel',mouse(400,345,1))]:
   before=vm.loop_step(label,stimulus);assert before['continuation']=='otherSelector'
   ui=vm.network_step(label);assert ui['continuation']=='presentation'
   tail=vm.finish_network(label);call=dict(loop=before,network=ui,tail=tail);calls.append(call);checkpoint(call)
  calls.append(dict(loop=vm.loop_step('main-after-network-cancel',mouse(0,0,0))))
  checkpoint(calls[-1])
  if a.suite!='probe':
   # The fresh early-menu parent does not initialize DirectSound. Volume keys
   # unconditionally dispatch through five sound slots. Bind those declared
   # platform objects for the controlled matrix; this is not an own audio-init
   # join. The existing mapped COM objects/VTABLE supply their actual methods.
   bindings=[(0x45560c+4*i,SOURCE+16*i) for i in range(5)]
   doc['platformAudioBindings']=[dict(address=p,value=v) for p,v in bindings]
   call=dict(loop=vm.loop_step('controlled-audio-device-binding',mouse(0,0,0)+bindings));calls.append(call);checkpoint(call)
   for label,stimulus,options in matrix_cases(a.suite):
    before=vm.loop_step(label,stimulus);assert before['continuation']=='otherSelector',(label,before['continuation'])
    ui=vm.network_step(label,**options);tail=vm.finish_network(label);call=dict(loop=before,network=ui,tail=tail);calls.append(call);checkpoint(call)
    if len(calls)%50==0:print(json.dumps(dict(calls=len(calls),label=label,parts=str(parts))),flush=True)
   if a.suite=='matrix':
    for label in ['connected-world-one','connected-loading-entry']:
     call=dict(loop=vm.loop_step(label));calls.append(call);checkpoint(call)
   if a.suite.startswith('partial-'):doc['unsupportedOwnRead']=dict(case=len(calls)-1,offset={'partial-greeting':0x270,'partial-flags':0xf4,'partial-names':0x114}[a.suite],count=1)
  doc['calls']=calls;doc['sources']=list(vm.background_sources.values());doc['blobs']=vm.blobs
 doc['suite']=a.suite;doc['checkpointParts']=part_pins
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path)
 print(json.dumps(dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),sourceSHA256=PRODUCER_SHA256,nativeCompared=False),indent=2))
if __name__=='__main__':main()
