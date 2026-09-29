#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Front-menu selectors 7 (RECORDING INFO, 4290f3..4295e9) and 8 (its
follow-up page, 4295e9..42972c) on the accepted CONTROL SETTINGS harness: a
fresh prologue, then 4275bc with 44d064 = 7 or 8 through the original selector
dispatch, the screen, presentation 42873e and the real return. Actual 423a70/
423940 bitmap font, 422f60 key characters, 423230 settings writer, 423480
settings reload with VC80 fscanf/fgets/feof, 423910/43ef50 release, bitmap and
sound children share the CPU. GetKeyState, fopen/fclose/_read bytes, the
writer's FILE, free, COM, Sleep and ShellExecuteA remain declared boundaries.
APPLICATION_FRONT_MENU_ITEMS_PLAN.md F3.
"""
import argparse,json
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from oracle_crt import DLL_SHA256,FILE
from oracle_front_menu_resources import SOURCE
from oracle_bitmap_drawing import digest
from oracle_front_control_settings import FrontControlSettings

NAME,INFO,EMAIL,FLAG,FIELD=0x44FD18,0x44F900,0x44F890,0x450BE4,0x4511C4


class FrontRecordingInfo(FrontControlSettings):
 def body_code_allowed(self,pc):
  return super().body_code_allowed(pc) or (self.controls_active and (0x4290F3<=pc<0x42972C or 0x423940<=pc<0x423B00))
 def recording_step(self,label,selector,writes=(),key_states=(),reload=None,writer=None,device_result=0,dc_result=0):
  """controls_step with the selector as a parameter; the F2 tool is unchanged."""
  self.key_states=list(key_states);self.reload_input=reload;self.reload_pending=None;self.reload_scratch=None
  w=writer or {};self.writer_input=dict(capacity=w.get('capacity',4096),available=w.get('available',True),writeMode=w.get('action','full'),failAt=w.get('failAt',-1),closeResult=w.get('close',0))
  self.settings_call=None;self.settings_calls=[];self.fills=[];self.fill=None;self.timer_index=0
  self.alt_input=dict(selector=selector,drawTarget=SOURCE,timers=[],methodResult=device_result,drawResults=[device_result,1],fillResult=0,threadHandle=0,threadID=0,lastError=0)
  self.controls_active=True;self.alt_active=True
  try:c=self.entry_step(label,list(writes)+[(0x44D064,selector)],device_result,dc_result)
  finally:self.controls_active=False;self.alt_active=False
  assert self.reload_pending is None
  c.update(entry='recording',selector=selector,keyStates=list(key_states)[:len(key_states)-len(self.key_states)],
   reload=None if reload is None else dict(reload,data=self.blob(reload['data']),file=FILE,scratch=self.reload_scratch),writer=self.writer_input,settings=self.settings_calls)
  return c


def cases(vm,limit=None):
 def inputs(x=0,y=0,held=0,previous=0,field=0,flag=0):
  return [(0x4546F0,x),(0x453CDC,y),(0x457580,held),(0x44D060,previous),(0x4511E0,0),(0x4511C8,0),(0x453DA4,0),(0x458348,3),
   (0x455634,SOURCE+16),(0x453E0C,SOURCE+32),(0x44EECC,SOURCE),(0x455610,SOURCE+16),(0x455614,SOURCE+32),(FIELD,field),(FLAG,flag)]
 logical=(DEFAULT_SOURCE/'data/control.txt').read_bytes().replace(b'\r\n',b'\n')
 seven=[('idle-0',dict(writes=inputs())),('idle-1',dict(writes=inputs(flag=1)))]
 # Region edges and their outside neighbours: flag, folder, help, Cancel, OK.
 for x,y in ((0x11F,0x186),(0x132,0x199),(0x11E,0x186),(0x133,0x199),(0x11F,0x185),(0x132,0x19A),
             (0x185,0x184),(0x2DC,0x19A),(0x184,0x184),(0x2DD,0x19A),(0x185,0x183),(0x2DC,0x19B),
             (0x2C,0x1CD),(0x1E3,0x1E4),(0x2B,0x1CD),(0x1E4,0x1E4),(0x2C,0x1CC),(0x1E3,0x1E5),
             (0x193,0x1A0),(0x22E,0x1B8),(0x192,0x1A0),(0x22F,0x1B8),(0x193,0x19F),(0x22E,0x1B9),
             (0xE7,0x1A0),(0x182,0x1B8),(0xE6,0x1A0),(0x183,0x1B8)):
  seven.append((f'hover-{x:x}-{y:x}',dict(writes=inputs(x,y))))
 # Field selection: each field's edges, the gaps, outside x, and a held-only frame.
 for x,y in ((0xD2,0xCF),(0x2DA,0xE1),(0xD1,0xCF),(0x2DB,0xE1),(0xD2,0xE2),(0xD2,0xE8),(0x2DA,0x12E),(0x2DA,0x12F),
             (0xD2,0x135),(0x2DA,0x147),(0xD2,0x148),(0xD2,0x134),(0x100,0xCE),(0x100,0x300)):
  for field in (0,EMAIL):seven.append((f'select-{x:x}-{y:x}-{field:x}',dict(writes=inputs(x,y,1,field=field))))
 seven.append(('select-held',dict(writes=inputs(0xD2,0xCF,1,1,field=INFO))))
 # Typing into each field.
 def key(field,vk,content=None,caps=0,extra=()):
  w=inputs(field=field)+[(0x455378+vk,b'd')]+[(0x455378+k,b'd') for k in extra]
  if content is not None:w.append((field,content))
  letters=sum(0x41<=k<=0x5A for k in (vk,)+tuple(extra))
  return dict(writes=w,key_states=[caps,caps]*letters)
 for field,name in ((NAME,'name'),(INFO,'info'),(EMAIL,'email')):
  for vk,caps in ((0x41,1),(0x41,0),(0x31,0),(0x20,0),(0xBE,0),(0x70,0)):seven.append((f'{name}-key-{vk:x}-{caps}',key(field,vk,caps=caps)))
  seven.append((f'{name}-return-empty',key(field,0x0D,b'\0')))
  seven.append((f'{name}-return',key(field,0x0D)))
  seven.append((f'{name}-return-text',key(field,0x0D,b'abc\0')))
  seven.append((f'{name}-backspace',key(field,0x08)))
  seven.append((f'{name}-backspace-empty',key(field,0x08,b'\0')))
  seven.append((f'{name}-keys',key(field,0x41,b'x\0',extra=(0x42,0x08,0x0D))))
 seven.append(('name-limit-63',key(NAME,0x41,b'a'*63+b'\0')))
 seven.append(('name-limit-64',key(NAME,0x41,b'a'*64+b'\0')))
 seven.append(('info-four-lines',key(INFO,0x41,b'one\ntwo\nthree\nfour\0')))
 seven.append(('info-long-line',key(INFO,0x41,b'b'*70+b'\0')))
 seven.append(('no-field-key',dict(writes=inputs()+[(0x455378+0x41,b'd')])))
 for flag in (0,1):seven.append((f'flag-click-{flag}',dict(writes=inputs(0x120,0x190,1,flag=flag))))
 seven.append(('flag-held',dict(writes=inputs(0x120,0x190,1,1,flag=1))))
 for held,previous in ((1,0),(1,1)):
  seven.append((f'folder-{held}-{previous}',dict(writes=inputs(0x200,0x190,held,previous))))
  seven.append((f'help-{held}-{previous}',dict(writes=inputs(0x100,0x1D8,held,previous))))
 for action in ('full','error'):seven.append((f'ok-{action}',dict(writes=inputs(0x120,0x1A8,1,field=NAME),writer=dict(action=action,failAt=1 if action=='error' else -1))))
 seven.append(('ok-held',dict(writes=inputs(0x120,0x1A8,1,1))))
 for chunk in (7,4096):seven.append((f'cancel-{chunk}',dict(writes=inputs(0x1A0,0x1A8,1,field=INFO),reload=dict(data=logical,chunk=chunk,closeResult=0))))
 eight=[('page-idle',dict(writes=inputs()))]
 for x,y in ((0x60,0x15C),(0x27F,0x174),(0x5F,0x15C),(0x280,0x174),(0x60,0x15B),(0x27F,0x175),
             (0x13E,0x17E),(0x1D8,0x196),(0x13D,0x17E),(0x1D9,0x196),(0x13E,0x17D),(0x1D8,0x197)):
  eight.append((f'page-hover-{x:x}-{y:x}',dict(writes=inputs(x,y))))
 for held,previous in ((1,0),(1,1)):
  eight.append((f'page-link-{held}-{previous}',dict(writes=inputs(0x100,0x168,held,previous))))
  eight.append((f'page-ok-{held}-{previous}',dict(writes=inputs(0x150,0x188,held,previous))))
 plan=[(7,l,k) for l,k in seven]+[(8,l,k) for l,k in eight]
 out=[]
 for selector,label,kw in plan[:limit]:out.append(vm.recording_step(label,selector,**kw));print('case',len(out)-1,label,len(out[-1]['events']),flush=True)
 return out


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args()
 vm=FrontRecordingInfo(a.control);captured=cases(vm,a.limit)
 doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=vm.control,parent=vm.controls_parent,initialGlobals=vm.controls_initial,cases=captured,blobs=vm.blobs,limited=a.limit is not None)
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-recording-info{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(captured),
  events={k:sum(e['kind']==k for c in captured for e in c['events']) for k in sorted({e['kind'] for c in captured for e in c['events']})},nativeCompared=False)
 (ROOT/'build/research'/f'front-recording-info{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
