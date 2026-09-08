#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own first431d10 ret16 ->429730 ret12 ->41bc90 ret4 ->4246b0 ret4.
Fresh full early-menu/loading/startup and the pinned FIRST mode screen execute
on one CPU/stack/World. Later4229e2 caller probes retain own game state but stop
before the match epilogue422a95. Actual notice/volume/overlay/present children;
OS/COM/clock/allocator inputs remain explicit. No Windows pixels/audio/full match.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256,PTD
from oracle_mode_screen import ModeScreen
from oracle_menu_startup import capture as capture_startup
from oracle_front_screen_body import FrontScreenBody,HELPERS as BODY_HELPERS
from oracle_front_screen_prelude import FrontScreenPrelude,PAPI
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,SOURCE,VTABLE,BODY_SP,ENTRY_SP,REGISTERS
from oracle_wave_loader import VTABLE as WAVE_VTABLE
from oracle_state import STOP
from oracle_initial_loading import transport
from oracle_catalog_sounds import pack
from oracle_bitmap_drawing import digest
from oracle_menu_presentation import FORMATS
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EDX,UC_X86_REG_ESP,UC_X86_REG_EIP

API=0x33004000
HELPERS=BODY_HELPERS|{0x415160:0,0x4028A0:0,0x402810:0,0x401F30:0,0x43E940:0}

class MenuReturn(ModeScreen):
 def imported(self,uc,pc,size,data):
  if not getattr(self,'return_running',False):super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not getattr(self,'return_running',False):super().checkpoint(uc,pc,size,data)
 def install_return(self):
  self.return_running=False;self.uc.mem_map(API,0x1000)
  e=self.early;e.gdi.cstr=self.cstr
  for offset,name in [(0,'queryInterface'),(8,'release'),(0x1C,'audioVolumeSet'),(0x20,'audioVolumeRead'),(0x2C,'flip'),(0x3C,'volumeSet')]:
   address=API+offset*4;e.gdi.presentation_imports[address]=name
   for table in [VTABLE,WAVE_VTABLE,*[self.u32(token) for token in self.music_tokens]]:self.put(table+offset,address)
  self.uc.hook_add(UC_HOOK_CODE,self.return_code)
 def return_code(self,uc,pc,size,data):
  if not self.return_running:return
  e=self.early;sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.return_pending and pc==self.return_pending[-1]['returnPC']:
   h=self.return_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS]
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.return_helpers.append(h)
  points={0x4229E2:'menuReturned',0x422A95:'matchBeforeReturn',0x424746:'loadingReturned',0x4287DE:'heldCleared',STOP:'earlyReturned'}
  if pc in points:
   self.return_checkpoints.append(dict(kind=points[pc],pc=pc,sp=sp,saved=[uc.reg_read(r) for r in REGISTERS],seh=self.u32(0),globals=self.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE))))
   if pc==0x4229E2:self.return_sp=sp
  if pc==(STOP if self.return_inherited else 0x422A95):
   assert not self.return_pending and not e.body_pending and self.return_format is None
   self.return_finished=True;uc.emu_stop();return
  if pc in HELPERS:self.return_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x415160:self.start_prefix(pc,sp)
  if e.prefix_return is not None:
   at_return=pc==e.prefix_return;FrontScreenPrelude.code(e,uc,pc,size,data)
   if at_return:
    assert not e.calls_pending and e.clip_pending is None and e.format_pending is None
    self.fills.append(e.fill_backing);e.prefix_return=None;e.prefix_active=False
   return
  if self.return_format and pc==self.return_format['returnPC']:
   f=self.return_format;self.return_format=None;assert sp==f['sp']+4
   raw=self.cstr(f['destination']);assert len(raw)==uc.reg_read(UC_X86_REG_EAX)
   self.emit('format',[len(raw)],[f['format'],raw])
  if pc==0x7817775D:
   fmt=self.cstr(arg(1));assert fmt in FORMATS
   assert self.return_format is None;self.return_format=dict(sp=sp,returnPC=self.u32(sp),destination=arg(0),format=fmt)
  if pc==0x78132DB2:self.ret(PTD);return
  if pc in e.gdi.presentation_imports:e.gdi.presentation_imported(uc,pc,size,data);return
  if pc==PAPI and self.u32(sp)==0x43E975:e.gdi.com('blit');return
  if pc==PAPI+16:self.emit('timer',[self.input['milliseconds']]);self.ret(self.input['milliseconds']);return
  if pc in BODY_HELPERS and not e.body_pending:e.loading_draw_return=self.u32(sp)
  if e.body_pending or pc in BODY_HELPERS:
   FrontScreenBody.code(e,uc,pc,size,data)
   if not e.body_pending:e.loading_draw_return=None
   return
  assert any(a<=pc<=b for a,b in [(0x429EB7,0x429EB7),(0x42E0D2,0x42E0F9),(0x4229E2,0x422AB8),(0x424746,0x424750),(0x4287DE,0x428805),
   (0x402810,0x402A5F),(0x401F30,0x401FFF),(0x43E940,0x43E99E),(0x4450B2,0x4450BA),(0x78130000,0x7822FFFF),(STOP+0x6000,STOP+0x7FFF)]),hex(pc)
 def return_step(self,label,writes=(),inherited=False,method=0,dc=0,query=0,get=0,milliseconds=100,entry_pc=0x429EB7):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  assert entry_pc in (0x429EB7,0x42E0D2)
  if inherited:assert self.uc.reg_read(UC_X86_REG_EIP)==entry_pc
  else:self.uc.reg_write(UC_X86_REG_ESP,self.return_sp)
  before=self.control_snapshot();retained=self.early.snapshot()
  p=dict(targetSurface=SOURCE,methodResult=method,queryResult=query,audioGetResult=get,audioSetResult=method,queriedAudio=self.music_tokens[4],audioVolume=-1234,dcResult=dc,dc=0x12345678,postResult=0)
  self.input=dict(p,milliseconds=milliseconds,fillColor=0,fillResult=method,drawResults=[method,1])
  self.mode_events=[];self.return_helpers=[];self.return_pending=[];self.return_checkpoints=[];self.return_format=None;self.fills=[]
  self.return_inherited=inherited;self.return_finished=False
  e=self.early;e.completion_active=True;e.body_active=True;e.body_range=(0x4229E2,0x422ABB);e.body_stops={};e.body_helpers=BODY_HELPERS;e.body_target=SOURCE
  e.body_events=self.mode_events;e.body_pending=[];e.body_returns=[];e.body_bitmap=None;e.body_clip=None;e.body_blits=0;e.body_input=self.input;e.input=self.input;e.prefix_return=None
  e.gdi.presentation_input=p;e.gdi.presentation_events=self.mode_events
  self.return_running=True
  try:
   self.uc.emu_start(entry_pc if inherited else 0x4229E2,0,count=2_000_000);assert self.return_finished
  except Exception:
   print('RETURN FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.mode_events[-4:],flush=True);raise
  finally:self.return_running=False;e.body_active=False;e.completion_active=False;e.prefix_active=False
  after=self.control_snapshot();assert all(before[k]==after[k] for k in before if k!='globals')
  if inherited:
   assert self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8 and self.u32(0)==0x12345678
   assert [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
  return dict(label=label,inherited=inherited,stimulus=stimulus,input=dict(presentation=p,milliseconds=milliseconds,drawResults=self.input['drawResults']),
   before=before,after=after,earlyBefore=retained,earlyAfter=e.snapshot(),fills=self.fills,events=self.mode_events,helpers=self.return_helpers,checkpoints=self.return_checkpoints)
 def capture_return(self,first):
  suffix='-control' if self.control else '';report=json.loads((ROOT/'docs/evidence'/f'mode-screen{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'];parent=json.loads(raw)
  assert first['cases']==parent['cases'][:1] and all(parent['blobs'][k]==v for k,v in first['blobs'].items())
  assert all(s in parent['sources'] for s in first['sources'])
  print('Pinned FIRST mode screen reproduced; continuing own outer returns',flush=True)
  old=self.control_snapshot();self.install_return();assert old==self.control_snapshot()
  cases=[self.return_step('own-first-whole-early-return',inherited=True)]
  def document():
   return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),
    worldAddress=WORLD,actorAddresses=[a['address'] for a in self.pool],objectAddresses=self.object_addresses,cases=cases),{**self.early.blobs,**self.blobs})
  # Diagnostic-only first return; acceptance requires the complete95-case file.
  (ROOT/'build/research'/f'menu-return-first{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  def defaults():return [(0x44D058,0),(0x44F1AF,b'\0'),(0x44D020,10),(0x44F190,0),(0x450B70,0),(0x450BFC,0),(0x4553F2,b'\x75\x75')]
  for countdown in (-2147483648,-1,0,1,2,2147483647):
   for network in (0,1,127,128,255):cases.append(self.return_step(f'network-notice-{countdown}-{network}',defaults()+[(0x44D058,countdown),(0x44F1AF,bytes([network]))],method=-1))
  for menu in (-2147483648,-1,0,1,3,10,2147483647):
   for clock in (0,0xFFFFFFFF):cases.append(self.return_step(f'menu-timer-{menu}-{clock}',defaults()+[(0x44D020,menu),(0x451158,123),(0x451154,456),(0x457580,1)],milliseconds=clock))
  for mode in (-2147483648,-1,0,1,2,3,4,2147483647):cases.append(self.return_step(f'present-{mode}',defaults()+[(0x458348,mode)],method=-1))
  for notice in (0,1,2,3,4):
   for timer in (0,239,240,2147483647):cases.append(self.return_step(f'overlay-{notice}-{timer}',defaults()+[(0x450B70,notice),(0x450B6C,timer),(0x44F190,2),(0x44FD98,b'test_\xe9%s.lfr\0')],dc=-1 if timer==239 else 0))
  # Real owned common buffers at an explicit missing-WinMain slot boundary.
  buffers=[self.u32(0x451DB0+4*i) for i in range(5)];assert all(buffers)
  for volume in (-2147483648,-1,0,50,100,2147483647):
   for keys in (b'\x64\x75',b'\x75\x64',b'\x64\x64'):
    cases.append(self.return_step(f'volume-{volume}-{keys.hex()}',defaults()+[(0x44D000,volume),(0x4553F2,keys),*[(0x45560C+4*i,p) for i,p in enumerate(buffers)]],method=-1))
  for query,get in ((-1,0),(1,0),(0,-1),(0,1)):
   cases.append(self.return_step(f'music-query-{query}-{get}',defaults()+[(0x4553F2,b'\x75\x64')],query=query,get=get,method=-1))
  return document()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[];fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
  for suffix in ('','-control'):
   path=ROOT/'build/research'/f'menu-return{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
   assert digest(raw)==report['sha256'] and len(raw)==report['bytes'];doc=json.loads(raw)
   assert len(doc['cases'])==95 and doc['cases'][0]['inherited'] and not doc['cases'][0]['stimulus']
   mode=json.loads((ROOT/'docs/evidence'/f'mode-screen{suffix}.json').read_bytes());startup=json.loads((ROOT/'docs/evidence'/f'menu-startup{suffix}.json').read_bytes())
   assert doc['parent']==dict(fixture=mode['fixture'],sha256=mode['fixtureSHA256'])
   assert mode['parent']==dict(fixture=startup['fixture'],sha256=startup['fixtureSHA256'])
   refs=[doc['parent'],mode['parent'],*[startup['parents'][key] for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds')]]
   parents=[]
   for ref in refs:
    parent=fixtures/ref['fixture'];assert digest(parent.read_bytes())==ref['sha256'];parents.append(str(parent))
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'menu-return{suffix}-check.json';temporary.write_bytes(packed)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-return',str(temporary),*parents],capture_output=True,text=True)
   print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=fixtures/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),parent=doc['parent'],
    events=sum(len(c['events']) for c in doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),checkpoints=sum(len(c['checkpoints']) for c in doc['cases']))
   pending.append((ROOT/'docs/evidence'/path.name,report,fixture,packed))
  for path,report,fixture,packed in pending:fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture_startup(a.control,vm_type=MenuReturn,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first)))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-return{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
