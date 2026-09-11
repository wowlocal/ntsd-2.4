#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole controlled423b00 with cold blink tail through4242d7 and real ret.
Pinned NTSD EXE/lib.dll on Unicorn2.1.4, actual installer and bitmap/fill/sound
children. Valid declared atlas, global content rows, timer and mouse/previous
pointer inputs recover drawing order, integer wrap and live aliases. Full
bytes/masks/store/read/ABI observations remain reference evidence. COM/timer/
Sleep/Shell are adapters, never host device/URL actions. Stop before zero DIV
or a repeated ineligible navigation cycle; no fault continuation, arbitrary
control/protection corruption, expected-state import or Windows/gameplay claim.
See MENU_PANEL_DRAW_PLAN.md. This is a panel, not a returned whole own menu.
"""
import argparse,datetime,json,os,struct,traceback
from pathlib import Path
from oracle_lib_mode_screen import LibModeScreen,LIB,BM,TARGET,TABLE,MAPI,SP,STACK,STOP,GLOBAL,GSIZE,REGISTERS,EXE_SHA256
from oracle_bitmap_drawing import digest,signed
from unicorn.x86_const import *

TIMER,ALT=MAPI+0x100,TARGET+0x20
RECTS=[[0,0,397,34],[397,0,397,34],[0,34,198,194],[198,34,198,194],[396,34,198,194],[594,34,198,194],[0,228,198,194],[198,228,198,194],[396,228,198,194],[594,228,198,194],[0,422,794,128]]

class PanelDraw(LibModeScreen):
 def __init__(self,control=False):
  super().__init__(control);self.put(0x447250,TIMER);self.put(ALT,TABLE)
  self.panel=BM+(0x8000 if control else 0);self.guide=BM+(0x2000 if control else 0x6000)
  for i in range(5):
   p=BM+i*0x2000;raw=bytes((j*37+11)&255 for j in range(0x1f50)) if control else b'\xa5'*0x1f50
   self.uc.mem_write(p,raw);self.regions[p]['mask']=bytearray(0x1f50)
   self.write(p,struct.pack('<4I',self.tokens[0]+i*16,64,64,13))
   for j in range(13):
    for off,v in ((0x10,j%8*8),(0x7e0,j%8*8),(0xfb0,8),(0x1780,8)):self.write(p+off+j*4,struct.pack('<I',v))
  self.write(self.panel+4,struct.pack('<3I',794,550,11))
  for i,rect in enumerate(RECTS):
   for off,v in zip((0x10,0x7e0,0xfb0,0x1780),rect):self.write(self.panel+off+4*i,struct.pack('<i',v))
 def code(self,u,pc,n,data):
  if not self.running:return
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if pc==STOP or 0x423b00<=pc<0x4242dc:
   while self.pending and pc==self.pending[-1]['returnPC']:
    h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS],h
    h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
    if h['entry']==0x43f010:self.bitmap_active=None
   if pc==STOP:
    assert not self.pending and self.clip is None and sp==SP+4;self.end='returned';u.emu_stop();return
   if pc==0x423b00:self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
   if pc==0x423be8 and u.reg_read(UC_X86_REG_ESI)==0:self.end='zeroTimerRange';u.emu_stop();return
   if pc in (0x423ed0,0x423fb1):
    self.scans[pc]=self.scans.get(pc,0)+1
    if self.scans[pc]>8:self.end='noSelectableRow';u.emu_stop();return
   self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  if pc==TIMER:self.event('timer',[self.spec.get('milliseconds',17)]);self.ret(self.spec.get('milliseconds',17));return
  if pc==MAPI: # Blt boundary accepts the independent draw-target argument.
   assert arg(0) in (TARGET,ALT)
   if arg(5):
    assert arg(2)==0 and arg(3)==0
    self.event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=list(u.mem_read(arg(5),100)),defined=[i<4 or 0x50<=i<0x54 for i in range(100)]))
   else:self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',u.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=None))
   self.ret(self.spec.get('methodResult',-1),24);return
  super().code(u,pc,n,data)
 def configure(self,spec):
  for p,v in self.defaults():self.write(p,struct.pack('<I',v&0xffffffff) if isinstance(v,int) else v)
  fields={0x458420:self.panel,0x455608:TARGET,0x44d78c:794,0x44d790:550,0x45117c:self.guide,0x451188:BM+0x4000,
          0x44d780:0,0x458418:0,0x45841c:4,0x453da4:0,0x4546f0:0,0x453cdc:0,0x457580:0,0x4513c4:0,0x4554bc:0,0x44d03c:1,0x4511b4:0}
  for p,v in fields.items():self.write(p,struct.pack('<I',v&0xffffffff))
  for i in range(8):
   for p,v in ((0x452928+i*4,i*100),(0x4546d0+i*4,i*100+100),(0x453f50+i*4,60)):self.write(p,struct.pack('<i',v))
   self.write(0x4546f8+i*100,(f'http://example.invalid/ta{i}' if i<2 else '?').encode()+b'\0')
  for i in range(24):
   for p,v in ((0x4583b8+i*4,100),(0x453c08+i*4,250),(0x453f70+i*4,60),(0x453ce0+i*4,40)):self.write(p,struct.pack('<i',v))
   self.write(0x454a18+i*100,b'?\0')
  self.write(0x453da8,b'?\0')
 def run_panel(self,spec):
  self.running=False;self.spec=spec
  if not spec.get('retained'):self.configure(spec)
  for p,v in spec.get('globals',{}).items():self.write(int(p),struct.pack('<I',v&0xffffffff))
  for p,v in spec.get('strings',{}).items():assert len(v.encode())<100;self.write(int(p),v.encode()+b'\0')
  self.write(self.panel,struct.pack('<I',0 if spec.get('nullSurface') else self.tokens[0]+(64 if self.control else 0)))
  self.uc.mem_write(STACK,b'\xa5'*0x10000);self.regions[STACK]['mask']=bytearray(0x10000)
  for i,v in enumerate([STOP,spec.get('previousAddress',0x4513c4),spec.get('target',TARGET)]):self.write(SP+i*4,struct.pack('<I',v))
  for reg,v in zip(REGISTERS,[0x11223344,0x22334455,0x33445566,0x44556677]):self.uc.reg_write(reg,v)
  self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
  self.events=[];self.writes=[];self.reads=[];self.api_reads=[];self.helpers=[];self.pending=[];self.pcs={};self.clip=None;self.bitmap_active=None;self.fill_before=None;self.end=None;self.scans={}
  before=self.snapshot();self.running=True
  try:
   self.uc.emu_start(0x423b00,0,count=500_000);assert self.end is not None
  except Exception as e:
   f=self.capture_path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),error=repr(e),errorText=str(e),traceback=traceback.format_exc(),spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.running=False
  return dict(spec=spec,before=before,after=self.snapshot(),events=self.events,writes=self.writes,reads=self.reads,apiReads=self.api_reads,helpers=self.helpers,pending=self.pending,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),scans=self.scans)

def cases():
 def make(label,globals=None,strings=None,**kw):return dict(label=label,globals=globals or {},strings=strings or {},**kw)
 yield make('nominal')
 yield make('null-wrapper',{0x458420:0})
 yield make('null-surface',nullSurface=True)
 for maximum in (1,2,10,61,2147483647):
  for now in (0,1,2147483647,2147483648,4294967295):
   yield make(f'initial-{maximum}-{now}',{0x44d780:-1,**{0x4546d0+i*4:maximum for i in range(8)}},milliseconds=now)
 for row in range(8):
  for progress in (-1,0,2,3,4,48,49,58,59,60,69,70):
   yield make(f'row-{row}-progress-{progress}',{0x44d780:row*100,0x45841c:progress},{0x4546f8+row*100:f'http://example.invalid/ta{row}'})
 for x in (590,591,1000):
  for y in (199,200,392,393):
   for held,previous in ((0,0),(1,0),(1,1)):
    yield make(f'ta-hover-{x}-{y}-{held}-{previous}',{0x4546f0:x,0x453cdc:y,0x457580:held,0x4513c4:previous})
 for x in (750,751,768,769,770,1000):
  for y in (181,182,199,200):
   for held,previous in ((0,0),(1,0),(1,1)):
    yield make(f'arrow-{x}-{y}-{held}-{previous}',{0x4546f0:x,0x453cdc:y,0x457580:held,0x4513c4:previous})
 for x in (751,770):yield make(f'previous-alias-{x}',{0x4546f0:x,0x453cdc:190,0x457580:1},previousAddress=0x457580)
 for row in range(24):
  for x,y in ((100,251),(101,250),(160,251),(101,289),(101,290),(101,1000)):
   yield make(f'banner-{row}-{x}-{y}',{0x4546f0:x,0x453cdc:y,0x457580:1},{0x454a18+row*100:f'http://example.invalid/ba{row}'})
 for x,y in ((998,998),(999,998),(998,999),(1000,1000),(-2147483648,-2147483648)):
  yield make(f'minimum-{x}-{y}',{0x4583b8:x,0x453c08:y},{0x454a18:'http://example.invalid/minimum'})
 for duration in (0,4,9,10,2147483647,-2147483648):
  yield make(f'duration-{duration}',{0x453f50:duration,0x45841c:3})
 for progress in (-2147483648,-1,0,28,29,30,58,59,60,2147483647):
  for x,y in ((0,0),(397,0),(0,34),(-1,-1)):
   yield make(f'notice-{progress}-{x}-{y}',{0x4511b4:progress,0x4554bc:2,0x4546f0:x,0x453cdc:y,0x457580:1},{0x453da8:'http://example.invalid/update'})
 for version in (-2147483648,0,1,2147483647):yield make(f'notice-version-{version}',{0x4554bc:version},{0x453da8:'http://example.invalid/update'})
 yield make('overlapping-banners',{0x4546f0:101,0x453cdc:251,0x457580:1},{0x454a18+i*100:f'http://example.invalid/overlap{i}' for i in range(24)})
 yield make('alternate-draw-target',{0x4546f0:591,0x453cdc:200},target=ALT)
 yield make('zero-timer-range',{0x44d780:-1},{0x4546f8+i*100:'?' for i in range(8)})
 yield make('no-navigation-row',{0x4546f0:751,0x453cdc:190,0x457580:1,**{0x452928+i*4:-1 for i in range(8)},**{0x4546d0+i*4:-1 for i in range(8)}})
 for step in range(64):
  yield make(f'retained-{step}',{0x4554bc:2,0x457580:0},{0x453da8:'http://example.invalid/update'},chain=True,retained=step>0)

def extension_cases():
 yield dict(label='maximum-every-row',globals={0x44d780:-1,**{0x4546d0+i*4:(i+1)*100 for i in range(8)}},strings={0x4546f8+i*100:f'http://example.invalid/maximum{i}' for i in range(8)})
 for label,x,y in [('main',591,200),('left',1001,190),('right',1020,190)]:
  yield dict(label='hover-after-duration-'+label,globals={0x45841c:61,0x4546f0:x,0x453cdc:y},strings={})
 yield dict(label='forward-wrap-from-seven',globals={0x44d780:700,0x4546f0:770,0x453cdc:190,0x457580:1},strings={0x4546f8+7*100:'http://example.invalid/wrap7'})

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--manifest-only',action='store_true');p.add_argument('--extension-only',action='store_true');p.add_argument('--limit',type=int);a=p.parse_args();assert not a.output.exists()
 specs=[dict(s,control=control,label=s['label']+('-control' if control else '')) for control in (False,True) for s in (extension_cases() if a.extension_only else cases())]
 if a.manifest_only:a.output.write_text(json.dumps(specs,indent=2)+'\n');print('Finite cases',len(specs));raise SystemExit(0)
 parts=a.output.with_suffix('.parts');parts.mkdir();out=[];blobs={};installations=[];chains={}
 for i,s in enumerate(specs):
  if a.limit is not None and i>=a.limit:break
  if s.get('chain'):
   if s['control'] not in chains:chains[s['control']]=PanelDraw(s['control'])
   vm=chains[s['control']]
  else:vm=PanelDraw(s['control'])
  vm.capture_path=a.output;c=vm.run_panel(s);part=parts/f'{i:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation),separators=(',',':'))+'\n');os.replace(temp,part)
  out.append(c);blobs.update(vm.blobs);installations.append(vm.installation);print('completed',i,s['label'],c['end'],len(c['events']),len(c['writes']),len(c['reads']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],cases=out,blobs=blobs,installations=installations,entrySP=SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(out),bytes=len(raw),sha256=digest(raw)),flush=True)
