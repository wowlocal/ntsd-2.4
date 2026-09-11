#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Declared4229cc menu continuation through actual429730 and422ab8 returns.
Pinned NTSD/lib/VC80 under Unicorn2.1.4. Actual41bc90 prologue establishes
normal cookie/SEH storage, then a declared menu context skips the intervening
phase/gameplay body. Execute cached resource prefix, whole library mode/panel,
network notice, real CRT overlay, volume/present and ret4. Full reads/stores,
stack/register/owned resource records recover compatibility and provenance.
API/COM/GDI/PTD/time responses are research adapters, not Windows/device/host
operations. No private expected-state input, damaged control/protection bytes,
fault continuation or full initialized tick claim. LIB_MENU_CONTINUATION_PLAN.
"""
import argparse,json,os,struct,datetime,traceback
from pathlib import Path
from oracle_mode_panel_screen import ModePanelScreen
from oracle_lib_mode_screen import LibModeScreen,LIB,BM,TARGET,TABLE,MAPI,SP,BODY,STACK,STOP,WORLD,GLOBAL,GSIZE,REGISTERS,EXE_SHA256
from oracle_menu_panel_draw import PanelDraw,TIMER
from oracle_bitmap_drawing import digest,signed
from oracle_crt import CRT,prepare,DLL_SHA256,AREA as CRT_AREA,PTD
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import *

SPRINT=0x7817775d
TAIL_SP=SP-0x644
EXTRA_HELPERS={0x429730:12,0x4028a0:0,0x402810:0,0x401f30:0,0x43e940:0,SPRINT:0}
COM_METHODS={MAPI+0x300+i*16:(off,count) for i,(off,count) in enumerate(((0,3),(0x1c,2),(0x20,2),(0x2c,3),(0x3c,2)))}

class MenuContinuation(ModePanelScreen):
 def __init__(self,control=False):
  super().__init__(control)
  crt=CRT();pe=PE(prepare().read_bytes());self.uc.mem_map(pe.base,0x100000)
  self.add_region(pe.base,bytes(crt.uc.mem_read(pe.base,0x100000)),True)
  self.uc.mem_map(CRT_AREA,0x20000);self.add_region(CRT_AREA,bytes(crt.uc.mem_read(CRT_AREA,0x20000)),True)
  self.uc.mem_map(0,0x1000);self.add_region(0,struct.pack('<I',0x12345678),True)
  self.uc.mem_map(STOP+0x6000,0x3000);crt.uc=self.uc;crt.boundaries={a:n for a,n in crt.boundaries.items() if not STOP<=a<STOP+0x10000}
  for i,item in enumerate(pe.imports()):
   address=STOP+0x6000+i*16;self.put(int(item['iatVA'],16),address);crt.boundaries[address]=item['name']
  for address in crt.boundaries:self.uc.hook_add(UC_HOOK_CODE,crt.boundary,begin=address,end=address)
  self.crt=crt;self.put(0x447174,SPRINT)
  for lo,hi in [(0,3),(pe.base,pe.base+0xfffff),(CRT_AREA,CRT_AREA+0x1ffff)]:self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=lo,end=hi)
  for pc,(off,count) in COM_METHODS.items():self.put(0x26005000+off,pc);self.put(TABLE+off,pc)
  self.formats={p:bytes(self.uc.mem_read(p,48)).split(b'\0')[0] for p in (0x4477f0,0x4477d8,0x4477bc,0x4477a8)}
  self.prologue=False
 def point(self,name):
  self.points.append(dict(kind=name,pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),storeCount=len(self.writes),readCount=len(self.reads),eventCount=len(self.events),records=self.snapshot()))
 def code(self,u,pc,n,data):
  if not self.running:return
  if self.prologue:
   if pc==0x41bcd0:u.emu_stop();return
   assert 0x41bc90<=pc<0x41bcd0;self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  if pc in self.crt.boundaries:return
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending[-1]
   self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
   h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
   if h['entry']==0x43f010:self.bitmap_active=None
   if h['entry']==0x422b00:self.event('keyName',[h['key'],self.u32(h['width'])],[self.cstr(h['string'])])
   if h['entry']==SPRINT:
    raw=self.cstr(h['destination']);assert len(raw)==h['result'];h['output']=raw.hex();self.event('format',[len(raw)],[bytes(h['format']),raw])
  if pc==STOP:
   assert not self.pending and self.clip is None and sp==SP+8 and self.u32(0)==0x12345678
   assert self.saved==[u.reg_read(r) for r in REGISTERS];self.end='returned';self.point('returned');u.emu_stop();return
  if pc==0x431d10:self.screenSP=sp
  if pc==0x429eb7:
   # Finish the actual screen return before recording its owned local lifetime.
   while self.pending and pc==self.pending[-1]['returnPC']:
    h=self.pending.pop();assert h['entry']==0x431d10 and sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
    h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
   self.point('screenReturned')
  if pc in (0x4229e2,0x422a95):self.point('menuReturned' if pc==0x4229e2 else 'matchBeforeReturn')
  if pc in EXTRA_HELPERS:
   h=dict(entry=pc,entrySP=sp,pop=EXTRA_HELPERS[pc],returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events))
   if pc==SPRINT:
    assert arg(1) in self.formats;h.update(destination=arg(0),format=list(self.formats[arg(1)]))
   self.pending.append(h)
  if pc in COM_METHODS:
   off,count=COM_METHODS[pc]
   if off==0:self.event('queryInterface',[arg(0)],[bytes(u.mem_read(arg(1),16))]);self.write(arg(2),struct.pack('<I',self.output['queriedAudio']));result=self.output['queryResult']
   elif off==0x20:self.event('audioVolumeRead',[arg(0)]);self.write(arg(1),struct.pack('<i',self.output['audioVolume']));result=self.output['audioGetResult']
   else:self.event('method',[arg(0),off,*[arg(i) for i in range(1,count)]]);result=self.output['audioSetResult'] if off==0x1c else self.output['methodResult']
   self.ret(result,count*4);return
  if pc==MAPI and self.u32(sp)==0x43e975:
   self.event('method',[arg(0),0x14,*[arg(i) for i in range(1,6)]],[bytes(u.mem_read(arg(1),16))]);self.ret(self.output['methodResult'],24);return
  if any(lo<=pc<hi for lo,hi in [(0x4229cc,0x422abb),(0x429730,0x4297e7),(0x429e5a,0x429ebc),(0x42e0d2,0x42e0fc),(0x402810,0x402a60),(0x401f30,0x402000),(0x43e940,0x43e99f),(0x78130000,0x78230000)]):
   self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  super().code(u,pc,n,data)
 def probe(self,spec):
  self.running=False;self.spec=spec;PanelDraw.configure(self,spec)
  fields={0x455608:TARGET,0x44d78c:794,0x44d790:550,0x4511ac:BM,0x4511a0:BM+0x2000,0x451178:BM+0x4000,0x45117c:BM+0x6000,0x451170:BM+0x8000,0x451188:BM+0x4000,0x4513c0:0,0x458420:self.panel,0x458424:0,0x4546f0:0,0x453cdc:0,0x4513c4:0,0x457580:0,0x453da4:0,0x45757c:0,0x44d77c:1,0x44d778:0,
   0x4512cc:10,0x44d07c:0,0x44d010:1,0x44d058:0,0x44d000:50,0x44f190:0,0x450b70:0,0x450b6c:0,0x450bfc:0,0x458348:3,0x455634:TARGET,0x453e0c:self.tokens[8],0x451158:123,0x451154:456}
  fields.update(spec.get('globals',{}))
  for p,v in fields.items():self.write(int(p),struct.pack('<I',v&0xffffffff))
  for i in range(5):self.write(0x45560c+i*4,struct.pack('<I',self.tokens[2+i]))
  self.write(0x4553f2,bytes(spec.get('volumeKeys',[0x75,0x75])));self.write(0x44fd98,b'Naruto-Sasuke.lfr\0');self.write(0x453ccc,struct.pack('<4i',-7,20,807,563))
  for p,v in spec.get('strings',{}).items():assert len(v.encode())<100;self.write(int(p),v.encode()+b'\0')
  for seat,off,value in spec.get('buttons',[]):self.write(self.actors[seat]+off,bytes([value]))
  for i in range(28):self.write(0x44fb74+(i//7)*80+(i%7)*4,struct.pack('<I',i))
  self.output=dict(targetSurface=TARGET,methodResult=spec.get('methodResult',-1),queryResult=0,audioGetResult=0,audioSetResult=-1,queriedAudio=self.tokens[7],audioVolume=-1234,dcResult=spec.get('dcResult',0),dc=spec.get('dc',0x76543210),postResult=0);self.output.update(spec.get('output',{}))
  self.uc.mem_write(STACK,b'\xa5'*0x10000);self.regions[STACK]['mask']=bytearray(0x10000)
  for p,v in [(SP,STOP),(SP+4,TARGET),(TAIL_SP+0x68,TARGET)]:self.write(p,struct.pack('<I',v))
  self.saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,self.saved):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
  self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.helpers=[];self.pending=[];self.pcs={};self.clip=None;self.bitmap_active=None;self.fill_before=None;self.end=None;self.scans={};self.points=[];self.screenSP=None
  before=self.snapshot();self.running=True;self.prologue=True
  try:
   self.uc.emu_start(0x41bc90,0,count=1000);self.prologue=False;assert self.uc.reg_read(UC_X86_REG_ESP)==TAIL_SP
   self.point('declaredTail');self.uc.reg_write(UC_X86_REG_EBX,WORLD)
   self.uc.emu_start(0x4229cc,0,count=2_000_000);assert self.end is not None
  except Exception as e:
   f=self.capture_path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),traceback=traceback.format_exc(),pc=hex(self.uc.reg_read(UC_X86_REG_EIP)),spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.running=False
  return dict(spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans,points=self.points,actorAddresses=self.actors,screenSP=self.screenSP,output=self.output,saved=self.saved)

def cases():
 def make(label,g=None,s=None,**kw):return dict(label=label,globals=g or {},strings=s or {},**kw)
 yield make('nominal')
 for countdown,network in [(0,1),(1,0),(1,1),(1,127),(1,128),(2147483647,1)]:yield make(f'network-{countdown}-{network}',{0x44d058:countdown,0x44f1af:network})
 yield make('network-negative-dc',{0x44d058:2,0x44f1af:1},dcResult=-1)
 for notice,timer,block in [(1,0,0),(2,0,0),(3,0,0),(4,0,0),(1,240,0),(3,239,0),(3,0,1),(3,2147483647,0)]:yield make(f'overlay-{notice}-{timer}-{block}',{0x450b70:notice,0x450b6c:timer,0x450bfc:block})
 for volume,keys in [(99,[0x75,0x64]),(0,[0x64,0x75]),(2147483647,[0x64,0x64])]:yield make(f'volume-{volume}',{0x44d000:volume},volumeKeys=keys)
 for key in ['queryResult','audioGetResult']:yield make('failure-'+key,volumeKeys=[0x75,0x64],output={key:-1})
 for mode in [-1,1,2]:yield make(f'present-{mode}',{0x458348:mode})
 yield make('confirm-release',buttons=[(2,0xd1,1)])
 yield make('panel-click',{0x4546f0:591,0x453cdc:200,0x457580:1})
 yield make('help',{0x4513c0:1})
 yield make('playback',{0x451160:6},buttons=[(2,0xd1,1)])
 yield make('zero-timer-range',{0x44d780:-1},{0x4546f8+i*100:'?' for i in range(8)})
 yield make('no-navigation-row',{0x4546f0:751,0x453cdc:190,0x457580:1,**{0x452928+i*4:-1 for i in range(8)},**{0x4546d0+i*4:-1 for i in range(8)}})

def specs():
 for control in (False,True):
  for s in cases():yield dict(s,control=control,label=s['label']+('-control' if control else ''))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();items=list(specs())
 if a.manifest_only:a.output.write_text(json.dumps(items,indent=2)+'\n');print('Finite cases',len(items));raise SystemExit(0)
 parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[]
 for i,s in enumerate(items):
  if a.limit is not None and i>=a.limit:break
  vm=MenuContinuation(s['control']);vm.capture_path=a.output;c=vm.probe(s);temp=parts/f'{i:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c)
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  installations.append(vm.installation);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
