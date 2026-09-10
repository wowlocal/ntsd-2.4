#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continuous original WinMain43cf40..43d100 startup on one Unicorn2.1.4 CPU.
Recover seed/calendar/shared stack and window->panel->music->input/audio ordering
from pinned NTSD EXE/VC80/adinfo/DIB/WAVs. Platform/COM/file/allocator responses
are controlled inputs; no original file writes, external network or control/
protection corruption. Earlier CRT/NLS and actual Windows/window/device remain
open. Preserve unknown private backing, actual stopped boundaries and full bytes;
no expected child state injection. Development tooling; WINMAIN_STARTUP_PLAN.md.
"""
import argparse,json,struct,os,types
from collections import Counter
from pathlib import Path
from oracle_startup_output import StartupOutput,BASE,SIZE,SP,START,END,SPRINT,CURSOR
from oracle_calendar_time import MEM,zone,REGS,SAVED
from oracle_crt import CRT,PTD,STACK,STOP,FILE,INPUT,DLL_SHA256
from oracle_window_initialization import WindowInitialization,COM,METHODS,HELPERS as WINDOW_HELPERS
from oracle_startup_panel import StartupPanel,CONTENT_LOCAL,CONTENT_SIZE,INFO_LOCAL,INFO_SIZE,ENTRIES as PANEL_ENTRIES
from oracle_menu_info_reading import MenuInfoReading,OPEN,CLOSE,FSCAN,SCAN
from oracle_menu_content import MenuContent,GETS
from oracle_menu_info_writing import MenuInfoWriting,FPRINT,FCLOSE
from oracle_menu_panel_bitmap import MenuPanelBitmap,HEAP,SOURCE,VTABLE as PANEL_VTABLE,API as PANEL_API
from oracle_input_startup import InputStartup,device
from oracle_menu_sound_startup import MenuSoundStartup,PATHS
from oracle_wave_loader import WaveLoader,platform as wave_platform,data_size,DEVICE,VTABLE as AUDIO_VTABLE
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
WINAPI,INAPI=STOP+0x7000,STOP+0x2000
WINMAIN,FINISH,ENTRYSP=0x43cf40,0x43d100,SP+0x34
TEMP,FIRST,SECOND=0x2a000020,0x27000020,0x29000020

class Events(list):
 def __init__(self,parent,kind):super().__init__();self.parent=parent;self.kind=kind
 def append(self,value):super().append(value);self.parent.events.append(dict(kind=self.kind,event=value))

class WinMainStartup(StartupOutput):
 def __init__(self,spec):
  super().__init__(spec);self.phase=None;self.stages=[]
  self.pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes())
  self.install_window();self.install_panel();self.install_input()
  self.entry_imports={WINAPI+0x500:'timeGetTime',WINAPI+0x510:'initializeCriticalSection',WINAPI+0x520:'coInitialize'}
  for p,v in [(0x447250,WINAPI+0x500),(0x4470ec,0x7816d5e3),(0x4470b4,WINAPI+0x510),(0x4472b4,WINAPI+0x520)]:self.put(p,v)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.observe_stack_read,begin=STACK,end=STACK+0xffff)
  self.initialGlobals=self.blob(self.uc.mem_read(BASE,SIZE))
 def install_window(self):
  w=self.window=WindowInitialization.__new__(WindowInitialization);w.u=self.uc;w.capturing=False
  w.put=self.put;w.ret=self.ret;w.u32=self.u32;w.string=self.cstr
  self.uc.mem_map(COM,0x100000);w.com_methods={}
  for family,items in METHODS.items():
   for offset,(name,n) in items.items():w.com_methods[STOP+0x6000+len(w.com_methods)*16]=(family,name,n)
  w.boundaries={};names={'GetSystemMetrics','LoadIconA','LoadCursorA','RegisterClassA','CreateWindowExA','UpdateWindow','ShowWindow','DirectDrawCreate','OutputDebugStringA'}
  for item in self.pe.imports():
   if item['name'] not in names:continue
   p=CURSOR if item['name']=='LoadCursorA' else PANEL_API+48 if item['name']=='OutputDebugStringA' else WINAPI+len(w.boundaries)*16
   self.put(int(item['iatVA'],16),p);w.boundaries[p]=('',item['name'])
  request=w.request
  def observed_request(*args,**kwargs):
   result=request(*args,**kwargs);w.events[-1]['stackStoreCount']=len(self.stack_stores);w.events[-1]['globalStoreCount']=len(self.global_stores);w.events[-1]['rootEventIndex']=len(self.events)-1;return result
  w.request=observed_request
 def install_panel(self):
  r=self.panel=StartupPanel.__new__(StartupPanel);r.uc=self.uc;r.running=False;r.ramp=self.spec.get('ramp',False);r.blobs=self.blobs;r.all_pcs={};r.sources={};r.pe=self.pe
  r.put=self.put;r.ret=self.ret;r.cstr=self.cstr;r.boundaries=self.boundaries;r.visited=self.visited
  for address,count in [(0x22000000,0x10000),(HEAP,0x200000)]:self.uc.mem_map(address,count)
  for p,v in [(0x447190,OPEN),(0x447184,CLOSE),(0x447188,FSCAN),(0x447158,SCAN),(0x447174,SPRINT),(0x44719c,GETS),(0x447180,FPRINT),(0x44717c,PANEL_API+64),(0x4471c8,PANEL_API+32),(0x447080,PANEL_API+48)]:self.put(p,v)
  self.music.music_imports[PANEL_API+32]='message'
  for i in range(10):self.put(SOURCE+16*i,PANEL_VTABLE)
  self.put(PANEL_VTABLE+0x74,PANEL_API);self.put(PANEL_VTABLE+8,PANEL_API+16)
  r.info=MenuInfoReading.__new__(MenuInfoReading);r.content=MenuContent.__new__(MenuContent);r.panel=MenuPanelBitmap.__new__(MenuPanelBitmap);r.writer=MenuInfoWriting.__new__(MenuInfoWriting)
  for child in (r.info,r.content,r.panel,r.writer):child.uc=self.uc;child.blobs=self.blobs;child.active=False;child.control=r.ramp;child.boundaries=self.boundaries;child.put=self.put;child.ret=self.ret
  r.info.all_pcs={};r.panel.regions=[];r.panel.next_address=0;r.panel.heap_base=HEAP;r.panel.device=0
  desc=next(s for s in self.pe.resources() if s['path']==[2,'MENU_BACK1',1028]);dib=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']];width,height=struct.unpack_from('<ii',dib,4)
  r.dib=dict(path='MENU_BACK1',width=width,height=height,dib=self.blob(dib))
  begin=r.begin
  def start_child(entry,sp):
   begin(entry,sp);r.child_object.events=Events(self,'panel-'+r.current['kind'])
   if r.current['kind']=='bitmap':r.panel.device=self.u32(0x457578)
  r.begin=start_child
 def install_input(self):
  a=self.input=InputStartup.__new__(InputStartup);a.uc=self.uc;a.running=False;a.callback_running=False;a.joy_frame=None;a.blobs=self.blobs;a.blob=self.blob;a.put=self.put;a.ret=self.ret
  a.stub_base=INAPI;a.prefix=False;a.prefix_draw=None;a.regions={};a.second_pointer=SECOND
  for p,n in [(0x24000000,0x10000),(TEMP&~4095,0x200000),(FIRST&~4095,0x200000),(SECOND&~4095,0x200000)]:self.uc.mem_map(p,n)
  self.put(DEVICE,AUDIO_VTABLE);a.imports={}
  for index,(iat,name) in enumerate([(0x447254,'open'),(0x447258,'descend'),(0x44725c,'close'),(0x44723c,'read'),(0x447238,'ascend')]):
   p=INAPI+index*16;self.put(iat,p);a.imports[p]=name
  a.imports[PANEL_API+32]='message'
  for offset,name in [(0xc,'create'),(0x2c,'lock'),(0x50,'restore'),(0x4c,'unlock')]:
   p=INAPI+0x100+offset;self.put(AUDIO_VTABLE+offset,p);a.imports[p]=name
  self.put(0x447010,STOP+0x500);self.put(AUDIO_VTABLE+0x18,STOP+0x510)
  a.joy_imports={}
  for i,(iat,name) in enumerate({0x447234:'numberDevices',0x447240:'position',0x447244:'threshold',0x447248:'capture',0x44724c:'capabilities'}.items()):
   p=STOP+0x600+i*16;self.put(iat,p);a.joy_imports[p]=name
  a.source_files={p:(DEFAULT_SOURCE/p.replace('\\','/')).read_bytes() for p in PATHS};a.all_pcs={}
  def host_write(address,raw):
   WaveLoader.host_write(a,address,raw);self.write_host(address,raw)
  a.host_write=host_write
  def begin_wave(sp):
   index=len(a.loads);assert index<5;a.wave_entry_sp=sp;destination=self.uc.reg_read(UC_X86_REG_ECX);a.path=self.cstr(self.u32(sp+4));assert a.path.decode()==PATHS[index] and destination==0x45560c+index*4
   a.raw=a.source_files[PATHS[index]];changes=dict(a.spec.get('waves',{}).get(str(index),{}))
   if changes.pop('shortData',False):changes['dataReadResult']=data_size(a.raw)-1
   a.p=wave_platform(a.raw,index,destination=destination,device=self.u32(0x44eecc),ramp=a.spec['ramp'],**changes);a.allocation=TEMP+index*0x60000;a.p['firstPointer']=FIRST+index*0x60000
   if a.p['secondPointer']:a.p['secondPointer']=SECOND+index*0x60000
   self.put(a.p['buffer'],AUDIO_VTABLE)
   a.current=dict(label=PATHS[index],path=list(a.path),file=self.blob(a.raw),input=a.p,entrySP=sp,outputBefore=self.u32(destination),beforeGlobals=a.state())
   a.regions={};a.events=[];a.device_format=a.descriptor=None;a.descents=a.reads=a.locks=0
   a.region('first',a.p['firstPointer'],a.p['firstCount'])
   if a.p['secondPointer']:a.region('second',a.p['secondPointer'],a.p['secondCount'])
   a.record_event('load',[destination],[a.path])
  a.begin_wave=begin_wave
 def boundary(self,u,pc,n,data):
  if self.active:
   if self.phase=='panel':return self.panel.boundary(u,pc,n,data)
   if self.phase=='window' and (pc in self.window.boundaries or pc in self.window.com_methods):return
   if self.phase=='input' and (pc in self.input.imports or pc in self.input.joy_imports or pc in (STOP+0x500,STOP+0x510)):return
   if pc in self.entry_imports:return
  super().boundary(u,pc,n,data)
 def write_host(self,p,b):
  super().write_host(p,b)
  if self.active:
   if self.db<=p<p+len(b)<=self.db+self.ds or PTD<=p<p+len(b)<=PTD+0x200:self.stores.append(dict(pc=None,address=p,bytes=bytes(b).hex()))
   if STACK<=p<p+len(b)<=STACK+0x10000:self.stack_known[p-STACK:p-STACK+len(b)]=b'\1'*len(b)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.active:return
  if STACK<=p<p+n<=STACK+0x10000:self.stack_known[p-STACK:p-STACK+n]=b'\1'*n
  if self.phase=='window':self.window.observe_write(u,access,p,n,v,data)
  elif self.phase=='panel':
   if BASE<=p<p+n<=BASE+SIZE or STACK<=p<p+n<=STACK+0x10000 or HEAP<=p<p+n<=HEAP+0x200000 or INPUT<=p<p+n<=INPUT+4096:self.panel.changed(u,access,p,n,v,data)
  elif self.phase=='input':
   if BASE<=p<p+n<=BASE+SIZE:self.input.global_write(u,access,p,n,v,data)
   if STACK<=p<p+n<=STACK+0x10000:self.input.stack_written(u,access,p,n,v,data)
 def observe_stack_read(self,u,access,p,n,v,data):
  if not self.active:return
  if self.phase=='panel':self.panel.read_local(u,access,p,n,v,data)
  if self.phase=='input':
   before=len(self.input.caps_reads);self.input.read_caps(u,access,p,n,v,data)
   if len(self.input.caps_reads)>before:
    item=self.input.caps_reads[-1];item['actualEarlierWriteMask']=list(self.stack_known[p-STACK:p-STACK+n])
    item['lastStores']=[w for w in self.stack_stores if w['address']<p+n and p<w['address']+len(bytes.fromhex(w['bytes']))][-8:]
    if self.input.own_boundary is not None and 'rootEventCount' not in self.input.own_boundary:self.mark_boundary(self.input.own_boundary)
  if self.phase=='panel' and self.panel.own_boundary is not None and 'rootEventCount' not in self.panel.own_boundary:self.mark_boundary(self.panel.own_boundary)
 def mark_boundary(self,boundary):
  boundary.update(rootEventCount=len(self.events),globalStoreCount=len(self.global_stores),rootGlobals=self.blob(self.uc.mem_read(BASE,SIZE)))
 def snapshot_stage(self,name):
  s=dict(name=name,pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),globals=self.blob(self.uc.mem_read(BASE,SIZE)),crt=self.snapshot(),eventCount=len(self.events),stackStoreCount=len(self.stack_stores),registers=[self.uc.reg_read(r) for r in REGS])
  self.stages.append(s)
 def begin_phase(self,name):
  self.phase=name;self.snapshot_stage(name+'-entry')
  if name=='window':
   w=self.window;w.spec=self.spec.get('window',{});w.show_reads=[];w.objects=[];w.events=Events(self,'window');w.counts=Counter();w.frames=[];w.backings=[];w.pending_helpers=[];w.helper_returns=[];w.case_instructions={};w.mask=bytearray(SIZE);w.global_writes=[];w.capturing=True
  elif name=='panel':
   r=self.panel;r.spec=self.spec['panel'];r.current=None;r.child_object=None;r.children=[];r.parent_events=Events(self,'panelCaller');r.stores=[];r.stack_writes=[];r.pcs={};r.own_boundary=None;r.end=None;r.global_mask=bytearray(SIZE);r.stack_mask=bytearray(0x10000);r.running=True
   self.panel_stack_initial=self.blob(self.uc.mem_read(CONTENT_LOCAL,CONTENT_SIZE))
  elif name=='input':
   a=self.input;a.spec=self.spec['input'];a.ordered=Events(self,'input');a.loads=[];a.current=None;a.pending=[];a.returns=[];a.pcs={};a.stores=[];a.joy_requests=[];a.caps_states=[];a.caps_reads=[];a.own_boundary=None;a.joy_return=None;a.joy_frame=None;a.stack_mask=bytearray(0x10000);a.global_mask=bytearray(SIZE);a.running=True
 def code(self,u,pc,n,data):
  if not self.active:return
  sp=u.reg_read(UC_X86_REG_ESP)
  if pc in self.entry_imports:
   name=self.entry_imports[pc];arg=lambda i:self.u32(sp+4+i*4)
   if name=='timeGetTime':args=[];result=self.spec['milliseconds'];pop=0
   elif name=='initializeCriticalSection':
    args=[arg(0)];assert args==[0x4554a4];result=0;pop=4
   else:args=[arg(0)];assert args==[0];result=self.spec.get('comResult',0);pop=4
   self.events.append(dict(kind=name,arguments=args,result=result))
   if name=='initializeCriticalSection':self.write_host(arg(0),bytes(self.spec['criticalSection']))
   self.ret(result,pop);return
  if pc==0x43cf63:self.snapshot_stage('seed-return');assert self.u32(PTD+0x14)==self.spec['milliseconds']
  if pc==0x43bec0:self.begin_phase('window')
  if self.phase=='window':
   if pc==0x43cf85:
    self.window.code(u,pc,n,data);self.window.case_instructions.pop(pc,None);assert not self.window.pending_helpers and not self.window.frames;self.window.capturing=False;self.snapshot_stage('window-return');self.phase='prefix'
   else:
    pixel=self.window.com_methods.get(pc,('','',0))[1]=='pixelFormat'
    pixel_address=self.u32(sp+8) if pixel else None
    self.window.code(u,pc,n,data)
    if pixel and 'bytes' in self.window.events[-1]['response']:
     raw=bytes(self.window.events[-1]['response']['bytes']);assert bytes(u.mem_read(pixel_address,len(raw)))==raw
     self.stack_stores.append(dict(pc=None,address=pixel_address,bytes=raw.hex()))
     self.stack_known[pixel_address-STACK:pixel_address-STACK+len(raw)]=b'\1'*len(raw)
    if pc not in self.window.boundaries and pc not in self.window.com_methods:self.original(u,pc,n)
    return
  if pc==0x43cf94:self.begin_phase('panel')
  if self.phase=='panel':
   if pc==START:
    if self.panel.current:self.panel.finish()
    self.panel_stack_return=self.blob(u.mem_read(CONTENT_LOCAL,CONTENT_SIZE))
    self.panel.running=False;self.snapshot_stage('panel-return');self.phase='output'
   else:
    self.panel.code(u,pc,n,data)
    if self.panel.own_boundary is not None and 'rootEventCount' not in self.panel.own_boundary:self.mark_boundary(self.panel.own_boundary)
    if hex(pc) in self.panel.pcs:self.original(u,pc,n)
    return
  if pc==END:
   self.snapshot_stage('output-return')
   if self.spec.get('stopAfterOutput'):self.end='intermediateOutputBoundary';u.emu_stop();return
   self.begin_phase('input')
  if self.phase=='input':
   a=self.input
   if pc==0x43d08e:
    assert a.joy_frame and sp==a.joy_frame['sp']+4
    a.joy_return=dict(eax=u.reg_read(UC_X86_REG_EAX),sp=sp,globals=a.state(),saved=[u.reg_read(r) for r in REGS]);a.joy_frame=None;MenuSoundStartup.allowed(a,u,pc,n,data)
   elif pc not in a.imports and pc not in a.joy_imports and pc not in (STOP+0x500,STOP+0x510):a.allowed(u,pc,n,data)
   if pc in a.pcs:self.original(u,pc,n)
   if pc==FINISH:
    assert not a.pending and len(a.loads)==5 and a.current is None;a.running=False;self.snapshot_stage('input-return');self.end='startupBoundary';u.emu_stop();return
   if pc==0x40187a and a.p['createResult']!=0:self.end='invalidCreateContinuation';self.boundaryPC=pc;return
   if pc in a.imports:a.imported(u,pc,n,data)
   elif pc in a.joy_imports:a.joy_api(u,pc,n,data)
   elif pc in (STOP+0x500,STOP+0x510):a.device_api(u,pc,n,data)
   elif pc==0x4450a0:a.memset(u,pc,n,data)
   elif pc in (0x4450ac,0x4450a6,0x4450c2):a.crt(u,pc,n,data)
   return
  if WINMAIN<=pc<START:self.original(u,pc,n);return
  super().code(u,pc,n,data)
 def run_whole(self):
  self.events=[];self.stores=[];self.returns=[];self.pending=[];self.end=None;self.boundaryPC=None;self.call_pcs={};self.unknown=None
  self.formats=[];self.current_format=None;self.local_inputs=[];self.calendar_results=[];self.provenance=[];self.reserved=None;self.global_stores=[];self.global_mask=bytearray(SIZE);self.stack_stores=[];self.stack_known=bytearray(0x10000)
  self.music.music_input=self.spec['music'];self.music.music_events=[];self.music.music_calls=[];self.music.music_formats=[];self.music.music_end=-1
  self.stimulus=[]
  for address,value in self.spec.get('writes',[]):
   raw=struct.pack('<I',value&0xffffffff);self.uc.mem_write(address,raw);self.stimulus.append(dict(address=address,bytes=raw.hex()))
  self.beforeGlobals=self.blob(self.uc.mem_read(BASE,SIZE))
  self.uc.mem_write(STACK+0x8000,b'\xa5'*0x8000);self.uc.reg_write(UC_X86_REG_ESP,ENTRYSP)
  self.uc.mem_write(ENTRYSP,struct.pack('<5I',STOP,self.spec.get('instance',0x400000),0,0,self.spec.get('show',10)&0xffffffff))
  for r,v in zip(REGS,SAVED):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);before=self.snapshot();self.phase='prefix';self.active=True
  try:self.uc.emu_start(WINMAIN,0,count=15_000_000)
  except Exception as error:
   failure=dict(error=repr(error),pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),phase=self.phase,events=self.events,stages=self.stages,stores=self.stores,globalStores=self.global_stores,stackStores=self.stack_stores,globals=self.blob(self.uc.mem_read(BASE,SIZE)),crt=self.snapshot(),instructions=self.call_pcs,blobs=self.blobs)
   path=self.capture_path.with_suffix('.failure.json');assert not path.exists();path.write_text(json.dumps(failure,separators=(',',':'))+'\n');raise
  finally:self.active=False
  assert self.end,(hex(self.uc.reg_read(UC_X86_REG_EIP)),self.phase,self.pending)
  if self.end=='startupBoundary':assert self.uc.reg_read(UC_X86_REG_ESP)==SP-8 and not self.pending
  assert self.u32(0)==0xffffffff and self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  w=self.window;r=self.panel;a=self.input
  return dict(spec=self.spec,stimulus=self.stimulus,beforeGlobals=self.beforeGlobals,before=before,after=self.snapshot(),initialGlobals=self.initialGlobals,globals=self.blob(self.uc.mem_read(BASE,SIZE)),globalMask=self.blob(self.global_mask),events=self.events,stores=self.stores,globalStores=self.global_stores,stackStores=self.stack_stores,stages=self.stages,formats=self.formats,localInputs=self.local_inputs,calendarResults=self.calendar_results,provenance=self.provenance,returns=self.returns,end=self.end,boundaryPC=self.boundaryPC,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),controlWord=0x37f,instructions=self.call_pcs,
   window=dict(backings=w.backings,events=w.events,objects=w.objects,helpers=w.helper_returns),
   panel=dict(children=r.children,events=r.parent_events,ownBoundary=r.own_boundary,stackInitial=self.panel_stack_initial,stackAtReturn=self.panel_stack_return,stackAtStartupEnd=self.blob(self.uc.mem_read(CONTENT_LOCAL,CONTENT_SIZE)),records=[dict(address=q['address'],live=q['live'],storage=r.panel.record(q)) for q in r.panel.regions]),
   music=dict(calls=self.music.music_calls,allocations=[dict(address=q['address'],backing=self.blob(q['initial']),bytes=self.blob(self.uc.mem_read(q['address'],q['size'])),mask=self.blob(q['mask'])) for q in self.music.music_allocations]),
   input=None if not hasattr(a,'loads') else dict(loads=a.loads,events=a.ordered,joyRequests=a.joy_requests,capsStates=a.caps_states,capsReads=a.caps_reads,ownBoundary=a.own_boundary,joystickReturn=a.joy_return,helperReturns=a.returns))

def specifications():
 import copy
 from oracle_startup_panel import specifications as panel_specs
 from oracle_music_playback import platform
 from oracle_input_startup import specifications as input_specs
 panel=panel_specs()[0]['steps'][0];inputs=input_specs()[1];inputs['device']['cooperativeResult']=0
 base=dict(label='original-entry',milliseconds=123456789,filetime=134335116000000000,zone=zone(),criticalSection=list(struct.pack('<6I',0,0xffffffff,0,0,0,0)),panel=panel,music=platform(),input=inputs)
 yield copy.deepcopy(base)
 for mode,results in [(1,{}),(1,{'createSurface#1':-1}),(1,{'createSurface#1':-1,'createSurface#2':-1}),(0,{'createWindow#1':0}),(0,{'directDrawCreate#1':-1}),(0,{'createClipper#1':-1})]:
  s=copy.deepcopy(base);s.update(label='window-'+str(mode)+'-'+json.dumps(results,sort_keys=True),window=dict(mode=mode,results=results),writes=[(0x458430,mode)]);yield s
 for name,value in [('zero-seed',0),('max-seed',0xffffffff)]:
  s=copy.deepcopy(base);s.update(label=name,milliseconds=value,show=-1,comResult=0x80004005,writes=[(0x458420,0x12345678)]);yield s
 valid=next(c['steps'][0] for c in panel_specs() if c['label']=='bitmap-live-0-a5')
 for name,change in [('valid',{}),('missing-bitmap',{'bitmap':'missing'}),('null-bitmap',{'bitmap':'null'})]:
  s=copy.deepcopy(base);s.update(label=name,panel=dict(copy.deepcopy(valid),**change));yield s
 for period in [-1,24855,24856,2147483647]:
  s=copy.deepcopy(base);s.update(label='period-'+str(period),panel=copy.deepcopy(valid));s['panel']['info']=list(f'now 0 {period} <end>'.encode());yield s
 for name in ['missing-info','empty-content']:
  s=copy.deepcopy(base);s.update(label=name,panel=copy.deepcopy(next(c['steps'][0] for c in panel_specs() if c['label']==name+'-a5')));yield s
 for name in ['no-device-False','unknown-first-caps-False','unknown-second-only-False','retained-caps-False','audio-disabled-False']:
  s=copy.deepcopy(base);s.update(label=name,input=copy.deepcopy(next(q for q in input_specs() if q['label']==name)));yield s
 for i in range(5):
  s=copy.deepcopy(base);s['label']='missing-wave-'+str(i);s['input']['waves']={str(i):dict(stream=0)};yield s
 for i in [0,4]:
  s=copy.deepcopy(base);s['label']='failed-buffer-'+str(i);s['input']['waves']={str(i):dict(createResult=-1)};yield s
 for name,changes in [('music-create',{'createResult':-1,'createPointer':0}),('music-render',{'renderResult':-1}),('music-allocation',{'nullAllocation':True})]:
  s=copy.deepcopy(base);s.update(label=name,music=platform(**changes));yield s
 for name,changes in [('tm-allocation',{'allocationFail':True}),('clock-before-epoch',{'filetime':116444736000000000-1})]:
  s=copy.deepcopy(base);s.update(label=name,**changes);yield s

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--stop-after-output',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args();path=Path(a.output);assert not path.exists();path.with_name(path.stem+'-source.py').write_bytes(Path(__file__).read_bytes());parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();cases=[];blobs={};pcs={}
 for spec in list(specifications())[:a.limit]:
  if a.stop_after_output:spec['stopAfterOutput']=True
  r=WinMainStartup(spec);r.capture_path=path;c=r.run_whole();cases.append(c);blobs.update(r.blobs);pcs.update(r.pcs);temp=parts/f'{len(cases):04d}.tmp';temp.write_text(json.dumps(dict(case=c,blobs=r.blobs),separators=(',',':'))+'\n');os.replace(temp,temp.with_suffix('.json'));print(spec['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,producerSHA256=digest(Path(__file__).read_bytes()),dependencies={f:digest((ROOT/'tools'/f).read_bytes()) for f in ['oracle_startup_output.py','oracle_calendar_time.py','oracle_crt.py','oracle_window_initialization.py','oracle_startup_panel.py','oracle_input_startup.py','oracle_menu_sound_startup.py','oracle_wave_loader.py']},exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,cases=cases,blobs=blobs,instructions=pcs,sources=[dict(path=p,sha256=digest(raw),count=len(raw)) for p,raw in r.input.source_files.items()],panelDIB=r.panel.dib)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
