#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Controlled whole431d10 mode screen with actual installed lib.dll text.
Pinned NTSD EXE/lib.dll, Unicorn2.1.4, nine declared Actor records/eight seats
and five deterministic bitmap records. Execute original installer, prologue,
fill/bitmap/clip/input/sound/release/key-name/text and normal ret16. Trace full
bytes/masks, stack/read provenance and retained DC. COM/GDI/lstrlenA/free/quit/
critical-section/Sleep/Shell are research requests, never host operations.
Playback/panel/worker stops remain separate; no source-fault continuation,
control/protection corruption, bypass, expected-state import, own catalog,
Windows/device or complete-game claim. See LIB_MODE_SCREEN_PLAN.md.
"""
import argparse,json,os,struct,datetime,traceback
from pathlib import Path
from oracle_mode_selection import ModeSelection,GLOBAL,GSIZE,WORLD,POOL,HEAP,API,STACK,STOP,REGISTERS,EXE_SHA256
from oracle_bitmap_drawing import digest,signed
from lib_runtime_loader import install_library,BASE as LIB,API as LIB_API
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *

BM,TARGET,TABLE,MAPI,SP=0x27000020,HEAP+0x6000,HEAP+0x6100,STOP+0x2000,STACK+0xf000
BODY=SP-0x718
EXTRA={MAPI+i*16:name for i,name in enumerate(('blit','getDC','releaseDC','enter','leave','sleep','shell','length'))}
HELPERS={0x431d10:16,0x415160:0,0x43f010:24,0x43ef70:0,0x401290:0,0x431b70:0,0x401a30:4,0x4236d0:0,0x423b00:0,0x422b00:0,0x423910:0,0x43ef50:0,0x4019b0:0,0x4450b2:0}

class LibModeScreen(ModeSelection):
 def __init__(self,control=False):
  super().__init__(control)
  self.installation=install_library(self.uc)
  self.lib_api={LIB_API+i*16:x['name'] for i,x in enumerate(PE((DEFAULT_SOURCE/'lib.dll').read_bytes()).imports())}
  self.uc.mem_map(BM&~0xfff,0x10000);self.uc.mem_map(MAPI,0x1000)
  self.put(TARGET,TABLE)
  for off,name in [(0x14,'blit'),(0x44,'getDC'),(0x68,'releaseDC')]:self.put(TABLE+off,next(p for p,n in EXTRA.items() if n==name))
  for iat,name in [(0x4470a0,'enter'),(0x44709c,'leave'),(0x447098,'sleep'),(0x4471b8,'shell'),(0x447084,'length')]:self.put(iat,next(p for p,n in EXTRA.items() if n==name))
  self.add_region(STACK,bytes(0x10000),False)
  self.add_region(LIB,bytes(self.uc.mem_read(LIB,0x5000)),True)
  for i in range(5):
   raw=bytearray(0x1f50);struct.pack_into('<4I',raw,0,self.tokens[0]+i*16,64,64,500)
   for j in range(500):
    for off,v in [(0x10,(j%8)*8),(0x7e0,(j%8)*8),(0xfb0,8),(0x1780,8)]:struct.pack_into('<I',raw,off+j*4,v)
   self.add_region(BM+i*0x2000,raw,True);self.live[BM+i*0x2000]=True
  # Use this independently declared bitmap for the ordinary existing background.
  del self.regions[self.bitmap];del self.live[self.bitmap]
  self.bitmap=BM
  for lo,hi in [(STACK,STACK+0xffff),(LIB,LIB+0x4fff),(BM,BM+0xffff)]:
   self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=lo,end=hi)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read)
 def add_region(self,p,raw,known):
  self.uc.mem_write(p,bytes(raw));self.regions[p]=dict(address=p,size=len(raw),mask=bytearray([int(known)])*len(raw))
 def write(self,p,raw):
  super().write(p,raw)
  if self.running:self.writes.append(dict(pc=None,address=p,bytes=bytes(raw).hex(),eventIndex=len(self.events)))
 def written(self,u,access,p,n,v,data):
  if not self.running:return
  super().written(u,access,p,n,v,data);self.writes[-1]['eventIndex']=len(self.events)
 def read(self,u,access,p,n,v,data):
  if not self.running:return
  r=next((r for r in self.regions.values() if r['address']<=p<p+n<=r['address']+r['size']),None)
  if r is None:return
  off=p-r['address'];self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),known=list(r['mask'][off:off+n]),storeCount=len(self.writes),eventIndex=len(self.events)))
  if self.bitmap_active is not None and self.bitmap_active<=p<p+n<=self.bitmap_active+0x1f50 and 0x43f010<=u.reg_read(UC_X86_REG_EIP)<=0x43f2fe:
   assert n==4;self.event('read',read=dict(offset=p-self.bitmap_active,value=self.u32(p),defined=all(r['mask'][off:off+n])))
 def event(self,kind,args=(),strings=(),**extra):self.events.append(dict(kind=kind,arguments=list(args),strings=[list(x) for x in strings],**extra))
 def cstr(self,p):
  raw=bytearray()
  for i in range(4096):
   b=self.uc.mem_read(p+i,1)[0]
   if b==0:
    if self.running:
     r=next((r for r in self.regions.values() if r['address']<=p<p+len(raw)+1<=r['address']+r['size']),None)
     if r is None:
      assert 0x447000<=p<p+len(raw)+1<=0x44d000,hex(p)
      known=[1]*(len(raw)+1);kind='pinnedEXE'
     else:
      off=p-r['address'];known=list(r['mask'][off:off+len(raw)+1]);kind='owned'
     self.api_reads.append(dict(address=p,count=len(raw)+1,bytes=(bytes(raw)+b'\0').hex(),known=known,kind=kind,storeCount=len(self.writes),eventIndex=len(self.events),pc=self.uc.reg_read(UC_X86_REG_EIP)))
    return bytes(raw)
   raw.append(b)
  raise AssertionError(('Unterminated controlled string',hex(p)))
 def code(self,u,pc,n,data):
  if not self.running:return
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  while self.pending and pc==self.pending[-1]['returnPC']:
   h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS],h
   h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
   if h['entry']==0x43f010:self.bitmap_active=None
   if h['entry']==0x422b00:self.event('keyName',[h['key'],self.u32(h['width'])],[self.cstr(h['string'])])
  if self.clip is not None and pc==self.clip['returnPC']:
   h=self.clip;self.clip=None
   self.event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],visible=u.reg_read(UC_X86_REG_EAX)==1))
  if pc in (STOP,0x43249c,0x423b1a,0x43c780,0x43cc60,0x43c690,0x43c710):
   self.end={STOP:'returned',0x43249c:'playback',0x423b1a:'enabledPanel'}.get(pc,'workerChild')
   if pc==STOP:assert not self.pending and self.clip is None and sp==SP+20
   u.emu_stop();return
  if pc in HELPERS:
   h=dict(entry=pc,entrySP=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events))
   if pc==0x422b00:h.update(key=arg(0),string=arg(1),width=arg(2))
   if pc==0x401290:h.update(text=list(self.cstr(arg(1))),arguments=[arg(i) for i in (0,2,3,4,5)],textAddress=arg(1))
   self.pending.append(h)
  if pc==0x415160:self.fill_before=bytes(u.mem_read(sp-100,100))
  if pc==0x401a30:assert u.reg_read(UC_X86_REG_ECX)==0x455610;self.event('soundRequest',[arg(0)])
  if pc==0x43f010:self.bitmap_active=u.reg_read(UC_X86_REG_ECX);self.event('draw',[self.bitmap_active,*[arg(i) for i in range(6)]])
  if pc==0x43ef70:
   src=[arg(i) for i in range(4)];dst=[u.reg_read(UC_X86_REG_ECX),u.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   assert self.clip is None;self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  if pc==0x423b00:self.event('panel',[arg(0),arg(1)])
  if pc in EXTRA:
   name=EXTRA[pc]
   if name=='blit':
    assert arg(0)==TARGET
    if arg(5):
     assert arg(2)==0 and arg(3)==0
     effects=list(u.mem_read(arg(5),100));mask=[i<4 or 0x50<=i<0x54 for i in range(100)]
     self.event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=effects,defined=mask))
    else:self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',u.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=None))
    self.ret(self.spec.get('methodResult',-1),24)
   elif name=='getDC':
    self.event(name,[arg(0)]);self.write(arg(1),struct.pack('<I',self.spec.get('dc',0x76543210)));self.ret(self.spec.get('dcResult',0),8)
   elif name=='releaseDC':self.event(name,[arg(0),arg(1)]);self.ret(self.spec.get('methodResult',-1),8)
   elif name in ('enter','leave'):self.event(name,[arg(0)]);self.ret(0,4)
   elif name=='sleep':self.event(name,[arg(0)]);self.ret(0,4)
   elif name=='shell':self.event(name,[arg(0),arg(3),arg(4),arg(5)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(33,24)
   elif name=='length':self.ret(len(self.cstr(arg(0))),4)
   return
  if pc in self.lib_api:
   name=self.lib_api[pc]
   if name in ('SetBkMode','SetTextColor'):self.event('setBackgroundMode' if name=='SetBkMode' else 'setTextColor',[arg(0),arg(1)]);self.ret(self.spec.get('methodResult',-1),8)
   elif name=='lstrlenA':raw=self.cstr(arg(0));self.event('stringLength',strings=[raw]);self.ret(len(raw),4)
   elif name=='TextOutA':self.event('textOut',[arg(0),arg(1),arg(2),arg(4)],[bytes(u.mem_read(arg(3),arg(4)))]);self.ret(self.spec.get('methodResult',-1),20)
   else:raise AssertionError(('Unexpected library dependency',name))
   return
  if API<=pc<=API+0x30:
   offset,pop={API:(8,4),API+16:(0x48,4),API+32:(0x34,8),API+48:(0x30,16)}[pc]
   self.event('soundMethod' if any(h['entry']==0x401a30 for h in self.pending) else 'method',[arg(0),offset,*[arg(i) for i in range(1,pop//4)]]);self.ret(self.spec.get('methodResult',-1),pop);return
  if pc==API+0x100:assert self.live[arg(0)];self.live[arg(0)]=False;self.event('free',[arg(0)]);self.ret();return
  if pc==API+0x120:self.event('postQuit',[arg(0)]);self.ret(0,4);return
  assert any(a<=pc<=z for a,z in [(0x401290,0x401290),(0x431d10,0x432aaa),(0x431b70,0x431c64),(0x422b00,0x422f59),(0x415160,0x41521d),(0x43ef50,0x43f2fe),(0x4236d0,0x4237d3),(0x423b00,0x423b1a),(0x4242af,0x4242b2),(0x423910,0x423938),(0x401a30,0x401a6f),(0x4019b0,0x401a26),(0x4450b2,0x4450ba),(LIB+0x1298,LIB+0x1309),(LIB+0x1c7e,LIB+0x1c95)]),hex(pc)
  self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex()
 def probe(self,spec):
  self.spec=spec;self.running=False
  if spec.get('panelHeader'):self.add_region(HEAP+0x6200,struct.pack('<I',1),True)
  for p,v in self.defaults():self.write(p,struct.pack('<I',v&0xffffffff) if isinstance(v,int) else v)
  defaults={0x455608:TARGET,0x44d78c:794,0x44d790:550,0x4511ac:BM,0x4511a0:BM+0x2000,0x451178:BM+0x4000,0x45117c:BM+0x6000,0x451170:BM+0x8000,0x4513c0:0,0x458420:0,0x458424:0,0x4546f0:0,0x453cdc:0,0x4513c4:0,0x457580:0,0x453da4:0,0x45757c:0,0x44d77c:1,0x44d778:0}
  defaults.update({int(p):v for p,v in spec.get('globals',{}).items()})
  for p,v in defaults.items():self.write(p,struct.pack('<I',v&0xffffffff))
  for i,key in enumerate(spec.get('keys',[0]*28)):self.write(0x44fb74+(i//7)*80+(i%7)*4,struct.pack('<I',key&0xffffffff))
  for seat,offset,value in spec.get('buttons',[]):self.write(self.actors[seat]+offset,bytes([value]))
  self.uc.mem_write(STACK,b'\xa5'*0x10000);self.regions[STACK]['mask']=bytearray(0x10000)
  for i,v in enumerate([STOP,TARGET,0x44d020,0x451160,0x4512c8]):self.write(SP+i*4,struct.pack('<I',v))
  for reg,v in zip(REGISTERS,[0x11223344,0x22334455,0x33445566,0x44556677]):self.uc.reg_write(reg,v)
  self.uc.reg_write(UC_X86_REG_ECX,WORLD);self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
  self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.helpers=[];self.pending=[];self.pcs={};self.clip=None;self.bitmap_active=None;self.fill_before=None;self.end=None
  before=self.snapshot();self.running=True
  try:
   self.uc.emu_start(0x431d10,0,count=2_000_000)
   assert self.end is not None
  except Exception as e:
   f=self.capture_path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),traceback=traceback.format_exc(),spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.running=False
  return dict(spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),fillBacking=None if self.fill_before is None else self.blob(self.fill_before),actorAddresses=self.actors)

def specs():
 for mode in range(8):
  for network in [0,1,127,128,255]:yield dict(label=f'row-{mode}-{network}',globals={0x451160:mode,0x44f1af:network})
 for dc in [-2147483648,-1,0,1,2147483647]:
  for help in [0,1]:yield dict(label=f'dc-{dc}-help-{help}',dcResult=dc,globals={0x4513c0:help})
 keys=[*range(256),-2147483648,-1,256,2147483647]
 for i in range(0,len(keys),28):yield dict(label=f'keys-{i}',globals={0x4513c0:1},keys=(keys[i:i+28]+[0]*28)[:28])
 for x,y in [(612,492),(693,492),(592,522)]:
  for held,previous in [(0,0),(1,0),(2,0),(1,1)]:yield dict(label=f'link-{x}-{held}-{previous}',globals={0x4546f0:x,0x453cdc:y,0x457580:held,0x4513c4:previous})
 for mode in [0,5,6,7]:
  for mask in range(8):yield dict(label=f'buttons-{mode}-{mask}',globals={0x451160:mode},buttons=[(i,button,1) for i,button in enumerate([0xcd,0xce,0xd1]) if mask&(1<<i)])
 for i,result in enumerate([0,-1,1,-2147483648,2147483647,0]):yield dict(label=f'retained-{i}',chain=True,dcResult=result,dc=0x12345600+i,globals={0x4513c0:1})
 yield dict(label='enabled-panel',panelHeader=True,globals={0x458420:HEAP+0x6200})
 yield dict(label='worker-child',globals={0x458424:2})

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--boundaries-only',action='store_true');a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];chain=None
 for i,s in enumerate(specs()):
  if a.boundaries_only and s['label'] not in ('enabled-panel','worker-child'):continue
  if a.limit is not None and i>=a.limit:break
  if s.get('chain'):
   if chain is None:chain=LibModeScreen(True)
   vm=chain
  else:vm=LibModeScreen(bool(i%2))
  vm.capture_path=a.output;c=vm.probe(s);part=parts/f'{i:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c);blobs.update(vm.blobs);installations.append(vm.installation);print('completed',i,s['label'],c['end'],len(c['events']),len(c['writes']),len(c['reads']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],installations=installations,cases=cases,blobs=blobs,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,bodySP=BODY,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
