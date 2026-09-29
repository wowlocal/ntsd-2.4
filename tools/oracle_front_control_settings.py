#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Front-menu selector 6 (CONTROL SETTINGS, 4289c4..4290f3) on the accepted
front-menu completion harness: a fresh prologue, then 4275bc with 44d064 = 6
through the original selector dispatch, the screen, presentation 42873e and
the real return. Actual 401290 text, 422b00 key names, 422f60 key characters,
423230 settings writer, 423480 settings reload with VC80 fscanf/fgets/feof,
423910/43ef50 release, bitmap, sound and VC80 sprintf children share the CPU.
GetKeyState, fopen/fclose/_read bytes, the writer's FILE, free, COM, Sleep and
ShellExecuteA remain declared boundaries. APPLICATION_FRONT_MENU_ITEMS_PLAN.md F2.
"""
import argparse,json,struct
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from oracle_crt import DLL_SHA256,FILE,INPUT,STOP
from oracle_front_menu_completion import FrontMenuCompletion,CAPI,NETWORK,network_input
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,SOURCE,BODY_SP,ENTRY_SP,REGISTERS
from oracle_settings_loading import OPEN,CLOSE,SCAN,GETS,EOF
from oracle_bitmap_drawing import digest
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

import oracle_front_menu_completion as completion
# The screen's joystick cells format 449744 "Button: %d"; the completion
# harness records sprintf only for formats it declares.
completion.FORMATS=completion.FORMATS+(b'Button: %d',)

KEYSTATE=CAPI+48
CELLS=0x44FB70


class FrontControlSettings(FrontMenuCompletion):
 def __init__(self,control=False):
  self.controls_active=False;super().__init__(control)
  first=self.completion_step('first-natural-return')
  # A complete completion corpus (its reference replays it as this parent).
  self.controls_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope='front-menu completion parent',control=self.control,
   parent=self.completion_parent,initialGlobals=self.completion_initial,initialCRT=1,initialPointers=[0]*8,cases=[first])
  self.controls_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
  self.put(0x4471E8,KEYSTATE)
  # The GDI helper (built with __new__) reads the device/joystick labels from
  # .rdata through oracle_objects.cstr, whose read cache it lacks.
  if not hasattr(self.gdi,'formats'):self.gdi.formats={}
  self.body_helpers=self.body_helpers|{0x422B00:0,0x422F60:0,0x423480:0,0x423230:0}
 def body_code_allowed(self,pc):
  return super().body_code_allowed(pc) or (self.controls_active and (
   0x4275BC<=pc<0x427915 or 0x428806<=pc<0x4290F3 or 0x422B00<=pc<0x422F60 or 0x422F60<=pc<=0x423222 or
   0x423480<=pc<0x4236CA or 0x423230<=pc<0x423480))
 def code(self,uc,pc,size,data):
  if not self.controls_active:return super().code(uc,pc,size,data)
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if self.main_exit is None and pc==0x42873E:
   self.main_exit='present';self.main_after=self.snapshot();self.main_events=len(self.body_events)
  if pc==KEYSTATE:
   assert arg(0)==20 and self.key_states;value=self.key_states.pop(0)
   self.body_event('keyState',[20,value&0xFFFFFFFF]);self.ret(value,4);return
  if self.reload_pending and pc==self.reload_pending['returnPC']:
   e=self.reload_pending;self.reload_pending=None;assert sp==e.pop('entrySP')+4
   kind,args=e.pop('kind'),e.pop('arguments');e.pop('returnPC')
   self.body_event(kind,args,result=uc.reg_read(UC_X86_REG_EAX),position=self.stream_position(),eof=self.stream_eof(),**e)
  if pc==OPEN and not self.settings_writer.active:
   # 423480's reload (Cancel); the original has no fopen failure check.
   assert self.cstr(arg(0))==b'data\\control.txt' and self.cstr(arg(1))==b'r' and self.reload_input is not None
   self.body_event('open',[FILE],[b'data\\control.txt',b'r'])
   self.uc.mem_write(FILE,struct.pack('<8I',INPUT,0,INPUT,9,0xFFFFFFFF,0,0x10000,0))
   self.crt.data=self.reload_input['data'];self.crt.chunk=self.reload_input['chunk'];self.crt.read_position=0
   self.ret(FILE);return
  if pc==CLOSE and not self.settings_writer.active:
   assert arg(0)==FILE;self.body_event('close',[FILE,self.reload_input['closeResult']&0xFFFFFFFF]);self.ret(self.reload_input['closeResult']);return
  if pc==0x423480 and self.reload_input is not None:
   # Its 0x1f4-byte info-line scratch sits at entry SP - 0x1f8, as for the startup caller.
   self.reload_scratch=sp-0x1F8
  if self.reload_input is not None and pc in (SCAN,GETS,EOF) and 0x423480<=self.u32(sp)<0x4236CA:
   # The settings-loading corpus's representation: destinations and format.
   extra={}
   if pc==SCAN:
    assert arg(0)==FILE;fmt=self.cstr(arg(1)).decode('latin1');assert fmt in ('%d','%s %s %s %s\n','%d\n')
    args=[arg(2+i) for i in range(4 if fmt.startswith('%s') else 1)];extra=dict(format=fmt)
   elif pc==GETS:assert arg(1)==100 and arg(2)==FILE;args=[arg(0),100]
   else:assert arg(0)==FILE;args=[]
   self.reload_pending=dict(kind={SCAN:'scan',GETS:'gets',EOF:'eof'}[pc],arguments=args,returnPC=self.u32(sp),entrySP=sp,before=self.stream_position(),**extra)
  super().code(uc,pc,size,data)
 def entry_step(self,label,writes,device_result,dc_result):
  """completion_step's own sequence (inputs, prologue 4246b0..4246eb, frame
  words) with the entry 4275bc; the accepted completion tool is unchanged."""
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  net=network_input(0);self.uc.mem_write(NETWORK,b'\xa5'*0x10000);self.put(NETWORK+0x2C,NETWORK+0x100)
  for i,a in enumerate(net['addresses']):self.put(NETWORK+0x100+i*4,NETWORK+0x1000+i*4);self.put(NETWORK+0x1000+i*4,a['word'])
  self.put(NETWORK+0x100+4*len(net['addresses']),0);self.put(NETWORK+0x7000,0)
  presentation=dict(targetSurface=SOURCE,methodResult=device_result,queryResult=0,audioGetResult=0,audioSetResult=device_result,
   queriedAudio=SOURCE+48,audioVolume=-1234,dcResult=dc_result,dc=0x12345678,postResult=0)
  self.input=dict(menu=dict(targetSurface=SOURCE,panelWord=0 if self.u32(0x458420) else None,network=net),presentation=presentation,drawResults=[device_result,1])
  self.body_input=dict(presentation,drawResults=self.input['drawResults'],shellResult=31)
  self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_blits=0;self.body_end=None
  self.network.menu_input=self.input['menu'];self.network.menu_events=self.body_events;self.gdi.presentation_input=presentation;self.gdi.presentation_events=self.body_events
  self.entry='controls';self.main_exit=None;self.main_after=None;self.main_events=None;self.random_calls=[];self.rand_pending=None;self.format_pending=None
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  self.completion_active=True;self.body_active=True
  try:
   self.put(0,0x12345678);self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE);self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
   for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
   self.prologue=True;self.uc.emu_start(0x4246B0,0,count=10000);self.prologue=False
   assert self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
   self.uc.reg_write(UC_X86_REG_EBX,0);self.uc.reg_write(UC_X86_REG_EDI,SOURCE);self.put(BODY_SP+0x18,WORLD);self.put(BODY_SP+0x20,SOURCE)
   self.uc.emu_start(0x4275BC,0,count=10_000_000)
  except Exception:
   print('CONTROLS FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.body_events[-3:],flush=True);raise
  finally:self.completion_active=False;self.body_active=False;self.prologue=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and not self.body_pending and self.format_pending is None and self.rand_pending is None and self.body_clip is None,hex(self.uc.reg_read(UC_X86_REG_EIP))
  assert self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8 and self.u32(0)==0x12345678 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  return dict(label=label,entry='controls',stimulus=stimulus,input=self.input,mainExit=self.main_exit,mainAfter=self.main_after,mainEvents=self.main_events,
   events=self.body_events,helpers=self.body_returns,random=self.random_calls,after=self.snapshot(),abi=dict(endPC=STOP,endSP=ENTRY_SP+8,saved=saved,seh=0x12345678))
 def controls_step(self,label,writes=(),key_states=(),reload=None,writer=None,device_result=0,dc_result=0):
  self.key_states=list(key_states);self.reload_input=reload;self.reload_pending=None;self.reload_scratch=None
  w=writer or {};self.writer_input=dict(capacity=w.get('capacity',4096),available=w.get('available',True),writeMode=w.get('action','full'),failAt=w.get('failAt',-1),closeResult=w.get('close',0))
  self.settings_call=None;self.settings_calls=[];self.fills=[];self.fill=None;self.timer_index=0
  self.alt_input=dict(selector=6,drawTarget=SOURCE,timers=[],methodResult=device_result,drawResults=[device_result,1],fillResult=0,threadHandle=0,threadID=0,lastError=0)
  self.controls_active=True;self.alt_active=True
  try:c=self.entry_step(label,list(writes)+[(0x44D064,6)],device_result,dc_result)
  finally:self.controls_active=False;self.alt_active=False
  # 422f60 asks GetKeyState once or twice depending on the Shift byte; the
  # keyState events record the answers actually used.
  assert self.reload_pending is None
  c.update(keyStates=list(key_states)[:len(key_states)-len(self.key_states)],reload=None if reload is None else dict(reload,data=self.blob(reload['data']),file=FILE,scratch=self.reload_scratch),writer=self.writer_input,settings=self.settings_calls)
  return c


def cases(vm,limit=None):
 def inputs(x=0,y=0,held=0,previous=0,cell=0,name=0,devices=(0,0,0,0)):
  base=[(0x4546F0,x),(0x453CDC,y),(0x457580,held),(0x44D060,previous),(0x4511E0,cell),(0x4511C8,name),(0x453DA4,0),(0x458348,3),
   (0x455634,SOURCE+16),(0x453E0C,SOURCE+32),(0x44EECC,SOURCE),(0x455610,SOURCE+16),(0x455614,SOURCE+32)]
  return base+[(CELLS+80*p,d) for p,d in enumerate(devices)]
 logical=(DEFAULT_SOURCE/'data/control.txt').read_bytes().replace(b'\r\n',b'\n')
 plan=[('idle',dict(writes=inputs()))]
 for x,y in ((45,475),(46,475),(540,498),(541,499),(580,441),(736,465),(408,441),(564,465)):plan.append((f'hover-{x}-{y}',dict(writes=inputs(x,y))))
 for p in range(4):
  x=0xC2+0x8B*p
  for held,previous in ((1,0),(0,0),(1,1)):plan.append((f'device-{p}-{held}-{previous}',dict(writes=inputs(x+10,0xB6+20,held,previous,devices=(0,1,2,0)))))
  plan.append((f'name-{p}',dict(writes=inputs(x+30,0x9C+5,1))))
  for row in range(7):
   plan.append((f'cell-{p}-{row}',dict(writes=inputs(x+100,0x11B+0x16*row-5,1))))
   plan.append((f'cell-joystick-{p}-{row}',dict(writes=inputs(x+100,0x11B+0x16*row-5,1,devices=(1,1,2,2)))))
 for vk in (0x41,0x25,0x0D,0x1B,0x70,0xF9):plan.append((f'capture-key-{vk:x}',dict(writes=inputs(cell=2)+[(0x455378+vk,b'd')])))
 plan.append(('capture-none',dict(writes=inputs(cell=21))))
 for button in range(4):plan.append((f'capture-button-{button}',dict(writes=inputs(cell=25,devices=(0,1,0,0))+[(0x453FC4+48+button,b'\x01')])))
 for vk,caps in ((0x41,1),(0x41,0),(0x31,0),(0x20,0),(0x08,0),(0x0D,0),(0xBE,0)):
  plan.append((f'name-key-{vk:x}-{caps}',dict(writes=inputs(name=1)+[(0x455378+vk,b'd')],key_states=[caps,caps] if 0x41<=vk<=0x5A else [])))
 plan.append(('name-full',dict(writes=inputs(name=2)+[(0x44FCC0+11,b'abcdefghij\0'),(0x455378+0x42,b'd')],key_states=[0,0])))
 for held,previous in ((1,0),(1,1)):plan.append((f'help-link-{held}-{previous}',dict(writes=inputs(100,480,held,previous))))
 for action in ('full','error'):plan.append((f'ok-{action}',dict(writes=inputs(420,450,1),writer=dict(action=action,failAt=1 if action=='error' else -1))))
 for chunk in (7,4096):plan.append((f'cancel-{chunk}',dict(writes=inputs(600,450,1),reload=dict(data=logical,chunk=chunk,closeResult=0))))
 out=[]
 for label,kw in plan[:limit]:out.append(vm.controls_step(label,**kw));print('case',len(out)-1,label,len(out[-1]['events']),flush=True)
 return out


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args()
 vm=FrontControlSettings(a.control);captured=cases(vm,a.limit)
 doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=vm.control,parent=vm.controls_parent,initialGlobals=vm.controls_initial,cases=captured,blobs=vm.blobs,limited=a.limit is not None)
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-control-settings{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(captured),
  events={k:sum(e['kind']==k for c in captured for e in c['events']) for k in sorted({e['kind'] for c in captured for e in c['events']})},nativeCompared=False)
 (ROOT/'build/research'/f'front-control-settings{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
