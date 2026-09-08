#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh early resources/settings/body/dispatch ->main menu and real ret4.
Actual bitmap/clip/sound/network/overlay/presentation/shutdown children, VC80
rand/sprintf and World1 transition share the existing CPU/stack. First main
entry retains the original full caller. Later menu/tail entries are explicit
controls with a freshly executed SEH/cookie prologue; World1 executes the whole
dispatcher. OS/COM/file/thread responses remain boundaries. No raster, Windows,
whole screen loop, enabled optional panel or full startup/match claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256,PTD,STOP
from oracle_front_screen_alternate import FrontScreenAlternate
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,WORLD,SOURCE,VTABLE,BODY_SP,ENTRY_SP,REGISTERS
from oracle_front_screen_body import BAPI,HELPERS
from oracle_front_screen_prelude import PAPI
from oracle_main_menu import MainMenu,NETWORK,NETWORK_STUB,network_input
from oracle_menu_presentation import FORMATS
from oracle_bitmap_drawing import digest,packed,signed
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

CAPI=STOP+0xA000
POINTERS=0x4588A8

class FrontMenuCompletion(FrontScreenAlternate):
 def __init__(self,control=False):
  self.completion_active=False;super().__init__(control)
  first=self.alternate_step('first-natural-dispatch');assert first['continuation']=='mainMenu'
  self.completion_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,parent=self.body_parent,initialGlobals=self.alt_initial,initialLocal=self.alt_local,cases=[first])
  self.completion_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));assert self.crt.random_state==1 and bytes(self.uc.mem_read(POINTERS,8))==bytes(8)
  self.body_stops={};self.body_range=(0x427915,0x428806)
  self.body_helpers=HELPERS|{p:0 for p in (0x422AC0,0x423B00,0x402B60,0x402AD0,0x402A60,0x4028A0,0x402810,0x401F30,0x43E940,0x4019B0,0x401D30,0x43D2A0,0x43D280,0x423910,0x43EF50)}
  self.network=MainMenu.__new__(MainMenu);self.network.uc=self.uc;self.network.cstr=self.cstr;self.network.menu_active=True;self.network.menu_imports={}
  for i,(iat,name) in enumerate([(0x4472A8,'startup'),(0x4472AC,'hostname'),(0x447268,'hostLookup'),(0x447270,'htons'),(0x447264,'addressText'),(0x44726C,'socket'),
   (0x447274,'asyncSelect'),(0x447278,'bind'),(0x44727C,'listen'),(0x4472A4,'closeSocket'),(0x4471C8,'message')]):
   address=NETWORK_STUB+i*16;self.put(iat,address);self.network.menu_imports[address]=name
  for offset,name in [(0,'queryInterface'),(8,'release'),(0x1C,'audioVolumeSet'),(0x20,'audioVolumeRead'),(0x2C,'flip'),(0x3C,'volumeSet')]:
   address=CAPI+0x100+offset*4;self.put(VTABLE+offset,address);self.gdi.presentation_imports[address]=name
  self.put(0x4471EC,CAPI+16);self.gdi.presentation_imports[CAPI+16]='postMessage'
  self.put(0x44717C,CAPI+32);self.put(0x447198,0x7816D5F0)
  self.freed=set();self.prologue=False
 def body_event(self,kind,args=(),strings=(),**extra):
  if self.completion_active and kind=='text':return # GDI helper's real events are retained.
  super().body_event(kind,args,strings,**extra)
 def body_write(self,uc,access,p,size,value,data):
  if self.completion_active:return # Complete globals/World/owned records at phase exits.
  super().body_write(uc,access,p,size,value,data)
 def body_code_allowed(self,pc):
  return super().body_code_allowed(pc) or (self.completion_active and (
   0x4246B0<=pc<=0x424736 or 0x422AC0<=pc<=0x422AF7 or 0x423B00<=pc<=0x423B14 or 0x4242AF<=pc<=0x4242B2 or
   0x402810<=pc<=0x402D63 or 0x43F38A<=pc<0x43F3FC or 0x43E940<=pc<=0x43E99E or 0x423910<=pc<=0x423938 or 0x43EF50<=pc<=0x43EF68 or
   0x4019B0<=pc<=0x401A26 or 0x401D30<=pc<=0x401D90 or 0x401F30<=pc<=0x401FFF or 0x43D280<=pc<=0x43D2B7 or 0x4450B2<=pc<=0x4450BA or
   0x78130000<=pc<0x78230000 or STOP+0x6000<=pc<STOP+0x8000 or pc==0x4450A0))
 def memset(self,uc,pc,size,data):
  if not self.completion_active:return super().memset(uc,pc,size,data)
  sp=uc.reg_read(UC_X86_REG_ESP);assert [self.u32(sp+i) for i in (4,8,12)]==[0x44F340,0,200]
  self.uc.mem_write(0x44F340,bytes(200));self.ret(0x44F340)
 def snapshot(self):
  return dict(globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),world=self.world_record(),crtState=self.crt.random_state,pointers=list(self.uc.mem_read(POINTERS,8)),
   records=[dict(address=r['address'],live=r['address'] not in self.freed,storage=self.record(r)) for r in self.regions])
 def code(self,uc,pc,size,data):
  if not self.completion_active:return super().code(uc,pc,size,data)
  if self.prologue and pc==0x4246EB:uc.emu_stop();return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if pc==STOP:
   assert not self.body_pending and self.format_pending is None and self.rand_pending is None and self.body_clip is None
   self.body_end='returned';uc.emu_stop();return
  if self.entry=='main' and self.main_exit is None and pc in (0x42873E,0x4287DE):
   self.main_exit='present' if pc==0x42873E else 'returnWithoutPresentation';self.main_after=self.snapshot();self.main_events=len(self.body_events)
  if self.rand_pending and pc==0x422AD2:
   before=self.rand_pending;self.rand_pending=None;self.random_calls.append(dict(before=before['state'],after=self.crt.random_state,result=uc.reg_read(UC_X86_REG_EAX)))
   assert sp==before['sp']+4
  if pc==0x422AC0:self.table_start=self.crt.random_state;self.table_index=len(self.random_calls)
  if pc==0x422AF7:
   assert len(self.random_calls)-self.table_index==3000;self.body_event('randomTable',[self.table_start,self.crt.random_state])
  if pc==0x7816D5F0:
   assert self.rand_pending is None and self.u32(sp)==0x422AD2;self.rand_pending=dict(state=self.crt.random_state,sp=sp)
  if pc==0x78132DB2:self.ret(PTD);return
  if self.format_pending and pc==self.format_pending['returnPC']:
   f=self.format_pending;self.format_pending=None;assert sp==f['sp']+4
   raw=self.cstr(f['destination']);assert len(raw)==uc.reg_read(UC_X86_REG_EAX)
   self.body_event('formatAddress' if f['format']==b'%s' else 'format',[len(raw)],[raw] if f['format']==b'%s' else [f['format'],raw])
  if pc==0x7817775D:
   fmt=self.cstr(arg(1));assert fmt==b'%s' or fmt in FORMATS
   assert self.format_pending is None;self.format_pending=dict(sp=sp,returnPC=self.u32(sp),destination=arg(0),format=fmt)
  if pc==0x423B00:
   self.body_event('panel',[arg(0),arg(1)]);pointer=self.u32(0x458420);assert pointer==0 or pointer==NETWORK+0x7000 and self.u32(pointer)==0
  if pc in self.network.menu_imports:self.network.menu_imported(uc,pc,size,data);return
  if pc in self.gdi.presentation_imports and pc>=CAPI:self.gdi.presentation_imported(uc,pc,size,data);return
  if pc==PAPI and self.u32(sp)==0x43E975:self.gdi.com('blit');return
  if pc==CAPI+32:
   p=arg(0);assert p in [r['address'] for r in self.regions] and p not in self.freed
   self.freed.add(p);self.body_event('free',[p]);self.ret();return
  super().code(uc,pc,size,data)
 def completion_step(self,label,writes=(),entry='main',network=None,mode=None,device_result=0,dc_result=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  net=network or network_input(0);self.uc.mem_write(NETWORK,b'\xa5'*0x10000);self.put(NETWORK+0x2C,NETWORK+0x100)
  for i,a in enumerate(net['addresses']):self.put(NETWORK+0x100+i*4,NETWORK+0x1000+i*4);self.put(NETWORK+0x1000+i*4,a['word'])
  self.put(NETWORK+0x100+4*len(net['addresses']),0);self.put(NETWORK+0x7000,0)
  presentation=dict(targetSurface=SOURCE,methodResult=device_result,queryResult=0,audioGetResult=0,audioSetResult=device_result,
   queriedAudio=SOURCE+48,audioVolume=-1234,dcResult=dc_result,dc=0x12345678,postResult=0)
  self.input=dict(menu=dict(targetSurface=SOURCE,panelWord=0 if self.u32(0x458420) else None,network=net),presentation=presentation,drawResults=[device_result,1])
  self.body_input=dict(presentation,drawResults=self.input['drawResults'],shellResult=31)
  self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_blits=0;self.body_end=None
  self.network.menu_input=self.input['menu'];self.network.menu_events=self.body_events;self.gdi.presentation_input=presentation;self.gdi.presentation_events=self.body_events
  self.entry=entry;self.main_exit=None;self.main_after=None;self.main_events=None;self.random_calls=[];self.rand_pending=None;self.format_pending=None
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  self.completion_active=True;self.body_active=True
  try:
   if label!='first-natural-return':
    self.put(0,0x12345678);self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE);self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
    for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
    if entry!='worldOne':
     self.prologue=True;self.uc.emu_start(0x4246B0,0,count=10000);self.prologue=False
     assert self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
     self.uc.reg_write(UC_X86_REG_EBX,0);self.uc.reg_write(UC_X86_REG_EDI,SOURCE);self.put(BODY_SP+0x18,WORLD);self.put(BODY_SP+0x20,SOURCE)
   self.uc.emu_start({'main':0x427915,'tail':0x42873E,'worldOne':0x4246B0}[entry],0,count=10_000_000)
  except Exception:
   print('COMPLETION FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.body_events[-3:],flush=True);raise
  finally:self.completion_active=False;self.body_active=False;self.prologue=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and not self.body_pending and self.format_pending is None and self.rand_pending is None and self.body_clip is None
  assert self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8 and self.u32(0)==0x12345678 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  return dict(label=label,entry=entry,stimulus=stimulus,input=self.input,mainExit=self.main_exit,mainAfter=self.main_after,mainEvents=self.main_events,
   events=self.body_events,helpers=self.body_returns,random=self.random_calls,after=self.snapshot(),abi=dict(endPC=STOP,endSP=ENTRY_SP+8,saved=saved,seh=0x12345678))
 def capture_completion(self):
  def inputs(x=300,y=222,held=0,previous=0,offset=0):
   return [(0x4546F0,x),(0x453CDC,y),(0x457580,held),(0x44D060,previous),(0x453DA4,offset),(0x44D064,0),(0x458348,3),
    (0x455634,SOURCE+16),(0x453E0C,SOURCE+32),(0x44EECC,SOURCE),(0x455610,SOURCE+16),(0x450B70,0),(0x44F190,0),(0x4553F2,b'\x75\x75')]
  cases=[self.completion_step('first-natural-return')]
  for offset in (-2147483648,-240,0,27,2147483647):
   for x in (275,276,520,521):
    for dy in (14,15,39,40,45,70,71,77,102,103,107,132,133,137,162,163):
     cases.append(self.completion_step(f'hover-{offset}-{x}-{dy}',inputs(x,signed(offset+202+dy),offset=offset)))
  for row,dy in enumerate((20,50,80,110,140),1):
   for held,previous in ((0,0),(1,0),(2,0),(1,1)):
    cases.append(self.completion_step(f'click-{row}-{held}-{previous}',inputs(y=202+dy,held=held,previous=previous),device_result=-1))
  for index in range(5):cases.append(self.completion_step(f'network-addresses-{index}',inputs(y=252,held=1),network=network_input(index)))
  for field,value in [('startupResult',-1),('version',0),('hostnameResult',-1),('hostEntryAddress',0),('socketResult',0xFFFFFFFF),('asyncResult',1),('bindResult',-1),('listenResult',-1)]:
   net=network_input(0);net[field]=value;cases.append(self.completion_step(f'network-{field}',inputs(y=252,held=1),network=net))
  for notice in (0,1,2,3,4):
   for timer in (0,239,240,2147483647):
    cases.append(self.completion_step(f'notice-{notice}-{timer}',inputs()+[(0x450B70,notice),(0x450B6C,timer),(0x450BFC,0),(0x44FD98,b'test_\xe9%s.lfr\0'),(0x44F190,2)],dc_result=-1 if timer==239 else 0))
  for volume in (-2147483648,-1,0,50,100,2147483647):
   for keys in (b'\x64\x75',b'\x75\x64',b'\x64\x64'):
    cases.append(self.completion_step(f'volume-{volume}-{keys.hex()}',inputs()+[(0x44D000,volume),(0x4553F2,keys),(0x44F040,SOURCE+32)]+[(0x45560C+4*i,SOURCE+16*i) for i in range(5)],device_result=-1))
  for mode in (-1,0,1,2,3,4):cases.append(self.completion_step(f'present-{mode}',inputs()+[(0x458348,mode)],entry='tail'))
  for i in range(3):cases.append(self.completion_step(f'held-tail-{i}',inputs(x=62,y=514,held=1)+[(0x458438,0),(0x45843C,0),(0x44F040,0),(0x44F044,0),(0x44F048,0),(0x44F04C,0)] if i==0 else (),entry='tail'))
  cases.append(self.completion_step('choose-match',inputs(y=222,held=1)))
  cases.append(self.completion_step('natural-world-one',entry='worldOne'))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.completion_parent,initialGlobals=self.completion_initial,initialCRT=1,initialPointers=[0]*8,cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   candidate=ROOT/'build/research'/f'front-menu-completion{suffix}.json';report=json.loads(candidate.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-menu-completion{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-menu-completion',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((ROOT/'docs/evidence'/candidate.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=FrontMenuCompletion(a.control).capture_completion();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-menu-completion{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),randomCalls=sum(len(c['random']) for c in doc['cases']),
  events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in sorted({e['kind'] for c in doc['cases'] for e in c['events']})},nativeCompared=False)
 (ROOT/'build/research'/f'front-menu-completion{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
