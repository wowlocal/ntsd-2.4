#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own fresh startup429e5a -> actual mode screen431d10 through ret16.
Real fill/background/bitmap/clip/text/key-name/input/sound/release helpers.
First screen continues the same CPU, World and stack; later outer callers and
mouse/controller/device inputs are declared probes. No restored game state.
Worker children, enabled optional panel and replay files remain explicit open
boundaries. No Windows raster/audio, application UI or complete-match claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_menu_startup import MenuStartup,capture as capture_startup
from oracle_front_screen_body import FrontScreenBody,BAPI,HELPERS as BODY_HELPERS
from oracle_front_screen_prelude import FrontScreenPrelude,PAPI
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,SOURCE,VTABLE,REGISTERS
from oracle_wave_loader import VTABLE as WAVE_VTABLE
from oracle_initial_loading import transport
from oracle_catalog_sounds import pack
from oracle_bitmap_drawing import digest
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBP,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

API=0x33003000
HELPERS=BODY_HELPERS|{0x415160:0,0x423840:0,0x43EE50:12,0x4236D0:0,0x431B70:0,0x423910:0,0x43EF50:0,0x4019B0:0,0x423B00:0,0x422B00:0}

class ModeScreen(MenuStartup):
 def imported(self,uc,pc,size,data):
  # The early SetColorKey token overlaps the old catalog import arena. That
  # inactive catalog observer must not consume and return the mode-menu call.
  if not getattr(self,'mode_running',False):super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not getattr(self,'mode_running',False):super().checkpoint(uc,pc,size,data)
 def install_mode(self):
  self.mode_running=False;self.uc.mem_map(API,0x1000)
  for vt in (VTABLE,WAVE_VTABLE):
   for index,offset in enumerate((8,0x48,0x34,0x30)):self.put(vt+offset,API+index*16)
  self.put(0x44717C,API+0x100);self.put(0x4471F0,API+0x110)
  # Loading replaced the clock import; background selection uses this source API.
  self.put(0x447250,PAPI+16);self.put(0x447174,0x7817775D);self.put(0x447098,BAPI+0x150)
  self.uc.hook_add(UC_HOOK_CODE,self.mode_code)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.mode_write,begin=0x10000000,end=0x1000FFFF)
  self.mode_entry_sp=self.menu_sp-20;self.mode_body=self.mode_entry_sp-0x718
  self.local_address=self.mode_body+0x10;self.local_size=0x704
 def mode_write(self,uc,access,p,n,value,data):
  if self.mode_running and self.local_address<=p and p+n<=self.local_address+self.local_size:
   self.local_mask[p-self.local_address:p-self.local_address+n]=b'\1'*n
 def local_record(self):return dict(bytes=self.blob(self.uc.mem_read(self.local_address,self.local_size)),defined=self.blob(self.local_mask))
 def emit(self,kind,args=(),strings=()):self.mode_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))
 def start_prefix(self,pc,sp):
  e=self.early;e.prefix_return=self.u32(sp);e.prefix_active=True;e.calls_pending=[];e.helper_returns=[];e.clip_pending=None;e.format_pending=None
  e.fill_effects=None;e.fill_backing=None;e.current_bitmap=None;e.blit_count=0
  e.missing=False;e.key=0;e.null_allocation=False;e.allocation=None;e.bitmap_input=None
  e.prefix_events=self.mode_events
 def mode_code(self,uc,pc,size,data):
  if not self.mode_running:return
  e=self.early;sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.mode_pending and pc==self.mode_pending[-1]['returnPC']:
   c=self.mode_pending.pop();assert sp==c['entrySP']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
   c.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.mode_helpers.append(c)
   if c['entry']==0x422B00:self.emit('keyName',[c['key'],self.u32(c['width'])],[self.cstr(c['string'])])
  if pc==0x429EB7:
   assert not self.mode_pending and not e.body_pending and e.prefix_return is None
   assert sp==self.menu_sp and self.mode_saved==[uc.reg_read(r) for r in REGISTERS]
   self.mode_end='returned';uc.emu_stop();return
  if pc in (0x43249C,0x423B1A,0x43C780,0x43CC60,0x43C690,0x43C710):
   self.mode_end={0x43249C:'playback',0x423B1A:'enabledPanel'}.get(pc,'workerChild');uc.emu_stop();return
  if pc in HELPERS:
   item=dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS])
   if pc==0x422B00:item.update(key=arg(0),string=arg(1),width=arg(2))
   self.mode_pending.append(item)
  if pc==0x431D10:
   assert sp==self.mode_entry_sp and [arg(i) for i in range(4)]==[SOURCE,0x44D020,0x451160,0x4512C8] and uc.reg_read(UC_X86_REG_ECX)==WORLD
   self.mode_saved=[uc.reg_read(r) for r in REGISTERS]
  if pc in (0x415160,0x423840):self.start_prefix(pc,sp)
  if e.prefix_return is not None:
   at_return=pc==e.prefix_return
   FrontScreenPrelude.code(e,uc,pc,size,data)
   if at_return:
    assert not e.calls_pending and e.clip_pending is None and e.format_pending is None
    if e.fill_backing is not None:self.fills.append(e.fill_backing)
    if e.allocation is not None:self.backgrounds.append(dict(allocation=e.allocation,input=e.bitmap_input))
    e.prefix_return=None;e.prefix_active=False
   return
  if pc in BODY_HELPERS and not e.body_pending:e.loading_draw_return=self.u32(sp)
  if e.body_pending or pc in BODY_HELPERS:
   if API<=pc<=API+0x30:
    offset,count={API:(8,1),API+16:(0x48,1),API+32:(0x34,2),API+48:(0x30,4)}[pc]
    self.emit('soundMethod',[arg(0),offset,*[arg(i) for i in range(1,count)]]);self.ret(self.input['methodResult'],count*4);return
   FrontScreenBody.code(e,uc,pc,size,data)
   if not e.body_pending:e.loading_draw_return=None
   return
  if pc in (PAPI+32,PAPI+48):
   assert arg(0)==0x4554A4;self.emit('enter' if pc==PAPI+32 else 'leave',[arg(0)]);self.ret(0,4);return
  if pc in (BAPI+0x150,BAPI+0x160):FrontScreenBody.code(e,uc,pc,size,data);return
  if pc==API:self.emit('method',[arg(0),8]);self.ret(self.input['methodResult'],4);return
  if pc==API+0x100:
   pointer=arg(0);assert pointer in [r['address'] for r in e.regions] and pointer not in e.freed
   e.freed.add(pointer);self.emit('free',[pointer]);self.ret(0);return
  if pc==API+0x110:self.emit('postQuit',[arg(0)]);self.ret(0,4);return
  if pc==0x423B00:self.emit('panel',[arg(0),arg(1)])
  assert any(a<=pc<=b for a,b in [(0x429E5A,0x429EB2),(0x431D10,0x432AAA),(0x431B70,0x431C64),(0x422B00,0x422F59),
   (0x4236D0,0x4237D3),(0x423B00,0x423B1A),(0x4242AF,0x4242B2),(0x423910,0x423938),(0x43EF50,0x43EF68),(0x4019B0,0x401A26),(0x4450B2,0x4450BA)]),hex(pc)
 def mode_step(self,label,writes=(),inherited=False,milliseconds=100,dc=0,method=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  if not inherited:
   assert self.u32(0x44D020)==10
   self.uc.reg_write(UC_X86_REG_ESP,self.menu_sp)
   #4297db/de (or429e4e/57 after constructors) establish these constants
   #on EVERY real outer call; a preceding431d10 may clobber volatile EDX/ECX.
   for r,v in [(UC_X86_REG_EBX,0xFFFFFFFF),(UC_X86_REG_ESI,0),(UC_X86_REG_EBP,0x44D020),(UC_X86_REG_EDI,WORLD),
               (UC_X86_REG_EDX,1),(UC_X86_REG_ECX,2)]:self.uc.reg_write(r,v)
  else:assert self.uc.reg_read(UC_X86_REG_EIP)==0x429E5A
  assert self.uc.reg_read(UC_X86_REG_EDX)==1 and self.uc.reg_read(UC_X86_REG_ECX)==2
  before=self.control_snapshot();early_before=self.early.snapshot()
  self.input=dict(dcResult=dc,dc=0x12345678,methodResult=method,drawResults=[0,1],shellResult=33,milliseconds=milliseconds,fillResult=0,fillColor=0x122565,drawTarget=SOURCE)
  self.mode_events=[];self.mode_helpers=[];self.mode_pending=[];self.mode_end=None;self.mode_saved=None;self.fills=[];self.backgrounds=[]
  backing=self.blob(self.uc.mem_read(self.local_address,self.local_size));self.local_mask=bytearray(self.local_size)
  e=self.early;e.completion_active=True;e.body_active=True;e.body_range=(0x431D10,0x432AAB);e.body_stops={};e.body_helpers=BODY_HELPERS;e.body_target=SOURCE
  e.body_events=self.mode_events;e.body_returns=[];e.body_pending=[];e.body_clip=None;e.body_bitmap=None;e.body_blits=0;e.body_input=self.input;e.body_sound_slots={0x455610}
  e.gdi.presentation_events=self.mode_events;e.gdi.presentation_input=self.input;e.input=self.input;e.prefix_return=None
  self.mode_running=True
  try:
   self.uc.emu_start(0x429E5A,0,count=5_000_000)
   assert self.mode_end is not None
  except Exception:
   print('MODE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.mode_events[-3:],flush=True);raise
  finally:self.mode_running=False;e.body_active=False;e.completion_active=False;e.prefix_active=False
  after=self.control_snapshot()
  assert all(before[k]==after[k] for k in before if k!='globals')
  return dict(label=label,inherited=inherited,stimulus=stimulus,input=self.input,backing=backing,local=self.local_record(),
   fills=self.fills,backgrounds=self.backgrounds,events=self.mode_events,helpers=self.mode_helpers,pending=self.mode_pending,
   continuation=self.mode_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),saved=self.mode_saved,
   before=before,after=after,earlyBefore=early_before,earlyAfter=e.snapshot())
 def capture_screen(self,parent):
  suffix='-control' if self.control else '';r=json.loads((ROOT/'docs/evidence'/f'menu-startup{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
  assert digest(raw)==r['sha256'] and json.loads(raw)==json.loads(json.dumps(parent))
  print('Entire pinned startup reproduced; continuing actual mode screen',flush=True)
  before=self.control_snapshot();self.install_mode();assert before==self.control_snapshot()
  cases=[self.mode_step('own-first-mode-screen',inherited=True)]
  def document():
   return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']),
    worldAddress=WORLD,actorAddresses=[a['address'] for a in self.pool],localAddress=self.local_address,cases=cases,sources=list(self.early.background_sources.values())),{**self.early.blobs,**self.blobs})
  # A development checkpoint permits native diagnosis of the first own frame
  # while the larger probe corpus continues. Acceptance only uses the full file.
  (ROOT/'build/research'/f'mode-screen-first{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  unchanged_menu=[self.record(r) for r in self.menu_bitmaps];unchanged_music=[self.record(r) for r in self.music_allocations]
  def defaults(mode=0,x=0,y=0,held=0,help=0):
   return [(0x44D020,10),(0x451160,mode),(0x4513C0,help),(0x4546F0,x),(0x453CDC,y),(0x457580,held),(0x4513C4,0),
    (0x453DA4,0),(0x45757C,0),(0x44F1AF,b'\0'),(0x451320,bytes(32)),
    *[(a['address']+0xCD,bytes(7)) for a in self.pool[:8]]]
  for i in range(3):cases.append(self.mode_step(f'idle-{i}'))
  cases.append(self.mode_step('click-help',defaults(x=300,y=222,held=1)))
  for i in range(4):cases.append(self.mode_step(f'help-next-frame-{i}'))
  for mode in range(8):
   for network in (0,1,127,128,255):cases.append(self.mode_step(f'row-{mode}-{network}',defaults(mode=mode)+[(0x44F1AF,bytes([network]))]))
  for mode in (-2147483648,-1,0,5,6,7,8,2147483647):
   for mask in range(8):
    writes=defaults(mode=mode)
    for seat,button in enumerate((0,1,4)):
     if mask&(1<<seat):writes.append((self.pool[seat]['address']+0xCD+button,b'\1'))
    cases.append(self.mode_step(f'buttons-{mode}-{mask}',writes,method=-1))
  for number in range(13):cases.append(self.mode_step(f'background-{number+1}',defaults()+[(0x4511AC,0)],milliseconds=number))
  key_codes=[*range(256),-2147483648,-1,256,2147483647]
  for start in range(0,len(key_codes),28):
   writes=defaults(help=1)
   for index,key in enumerate(key_codes[start:start+28]):writes.append((0x44FB74+(index//7)*80+(index%7)*4,key))
   cases.append(self.mode_step(f'key-labels-{start}',writes))
  for shift in (-2147483648,-491,0,23,2147483647):
   y=((shift+491+2**31)%2**32)-2**31
   for x in (591,592,611,612,685,686,692,693):
    for dy in (0,1,19,20,30,31,59,60):
     mouse_y=((y+dy+2**31)%2**32)-2**31
     cases.append(self.mode_step(f'link-hitbox-{shift}-{x}-{dy}',defaults(x=x,y=mouse_y)+[(0x45757C,shift)]))
  for x,y in ((612,492),(693,492),(592,522)):
   for held,previous in ((0,0),(1,0),(2,0),(1,1)):
    cases.append(self.mode_step(f'link-click-{x}-{held}-{previous}',defaults(x=x,y=y,held=held)+[(0x4513C4,previous),(0x455610,SOURCE)],method=-1))
  for offset in (-2147483648,-600,0,27,2147483647):
   for x in (-1,222,223,573,574,775,776,2147483647):
    for dy in (194,195,431,432):
     y=((offset+dy+2**31)%2**32)-2**31
     cases.append(self.mode_step(f'mouse-tail-{offset}-{x}-{dy}',defaults(x=x,y=y,held=1)+[(0x453DA4,offset)]))
  for dc in (-1,0,1):cases.append(self.mode_step(f'device-dc-{dc}',defaults(help=1),dc=dc,method=-1))
  cases.append(self.mode_step('source-confirm-vs',defaults()+[(self.pool[0]['address']+0xD1,b'\1')]))
  assert unchanged_menu==[self.record(r) for r in self.menu_bitmaps] and unchanged_music==[self.record(r) for r in self.music_allocations]
  return document()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[];fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
  for suffix in ('','-control'):
   path=ROOT/'build/research'/f'mode-screen{suffix}.json';report=json.loads(path.read_bytes())
   raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'] and len(raw)==report['bytes']
   doc=json.loads(raw);assert len(doc['cases'])==632 and doc['cases'][0]['inherited'] and not doc['cases'][0]['stimulus']
   ref=doc['parent'];startup=fixtures/ref['fixture'];assert digest(startup.read_bytes())==ref['sha256']
   startup_report=json.loads((ROOT/'docs/evidence'/f'menu-startup{suffix}.json').read_bytes())
   assert startup.name==startup_report['fixture'] and ref['sha256']==startup_report['fixtureSHA256']
   parents=[str(startup)]
   for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'):
    ref=startup_report['parents'][key];parent=fixtures/ref['fixture'];assert digest(parent.read_bytes())==ref['sha256'];parents.append(str(parent))
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'mode-screen{suffix}-check.json';temporary.write_bytes(packed)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--mode-screen',str(temporary),*parents],capture_output=True,text=True)
   print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=fixtures/('original-'+report['corpus'])
   report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),
    parent=doc['parent'],events=sum(len(c['events']) for c in doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),
    backgrounds=sum(len(c['backgrounds']) for c in doc['cases']),playback=sum(c['continuation']=='playback' for c in doc['cases']))
   pending.append((ROOT/'docs/evidence'/path.name,report,fixture,packed))
  # Neither corpus becomes an accepted fixture until BOTH native comparisons pass.
  for path,report,fixture,packed in pending:
   fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture_startup(a.control,vm_type=ModeScreen,after=lambda vm,parent:vm.capture_screen(parent));suffix='-control' if a.control else ''
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'mode-screen{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
