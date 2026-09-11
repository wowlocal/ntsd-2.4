#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole controlled431d10 with installed lib text and enabled423b00 panel.
Pinned NTSD EXE/lib.dll under Unicorn2.1.4; actual installer, screen/panel,
bitmap/clip/fill/input/sound/release/key-name/text and ret16 execute. Trace
read/store/stack/masks and live resource release order for compatibility.
COM/GDI/timer/Sleep/Shell/free/quit are research requests, not host operations.
Stop before playback, zero DIV or repeated ineligible scan; no fault continuation,
control/protection corruption, expected private-state input or Windows/device
claim. Finite inputs and own initialized boundary: MODE_PANEL_SCREEN_PLAN.md.
"""
import argparse,json,os,struct
from pathlib import Path
from oracle_lib_mode_screen import LibModeScreen,LIB,BM,TARGET,SP,BODY,STACK,STOP,WORLD,EXE_SHA256
from oracle_menu_panel_draw import PanelDraw,RECTS,TIMER
from oracle_bitmap_drawing import digest
from unicorn.x86_const import UC_X86_REG_ESP,UC_X86_REG_EIP

class ModePanelScreen(PanelDraw):
 def __init__(self,control=False):
  LibModeScreen.__init__(self,control)
  self.put(0x447250,TIMER);self.panel=BM+(0xc000 if control else 0xa000);self.guide=BM+0x6000
  raw=bytes((i*37+11)&255 for i in range(0x1f50)) if control else b'\xa5'*0x1f50
  self.add_region(self.panel,raw,False);self.live[self.panel]=True
  self.write(self.panel,struct.pack('<4I',self.tokens[0]+80,794,550,11))
  for i in range(13):
   rect=RECTS[i] if i<11 else [i%8*8,i%8*8,8,8]
   for off,v in zip((0x10,0x7e0,0xfb0,0x1780),rect):self.write(self.panel+off+4*i,struct.pack('<i',v))
 def code(self,u,pc,n,data):
  if not self.running:return
  if 0x423b00<=pc<0x4242dc or pc==TIMER:
   if pc==0x423b00:
    sp=u.reg_read(UC_X86_REG_ESP);self.event('panel',[self.u32(sp+4),self.u32(sp+8)])
   PanelDraw.code(self,u,pc,n,data)
  else:LibModeScreen.code(self,u,pc,n,data)
 def probe(self,spec):
  self.running=False;self.scans={};PanelDraw.configure(self,spec)
  for p,v in spec.get('strings',{}).items():assert len(v.encode())<100;self.write(int(p),v.encode()+b'\0')
  # Parent declares the same caller defaults. Preserve content and bind the
  # separate panel/badge as ordinary owned inputs before its actual prologue.
  globals={0x458420:self.panel,0x451188:BM+0x4000,0x44d780:0,**spec.get('globals',{})}
  result=LibModeScreen.probe(self,dict(spec,globals=globals))
  result['endPC']=self.uc.reg_read(UC_X86_REG_EIP);result['scans']=self.scans
  return result

def cases():
 def make(label,g=None,s=None,**kw):return dict(label=label,globals=g or {},strings=s or {},**kw)
 yield make('nominal')
 yield make('help',{0x4513c0:1},keys=list(range(28)))
 yield make('main-click',{0x4546f0:591,0x453cdc:200,0x457580:1})
 yield make('banner18-below',{0x4546f0:101,0x453cdc:1000,0x457580:1},{0x454a18+18*100:'http://example.invalid/banner18'})
 notice={0x4554bc:2,0x44d03c:1};url={0x453da8:'http://example.invalid/update'}
 yield make('notice-hover',{**notice,0x4546f0:1,0x453cdc:1,0x457580:1},url)
 yield make('notice-blink',{**notice,0x4511b4:29,0x4546f0:397},url)
 yield make('left',{0x4546f0:751,0x453cdc:190,0x457580:1})
 yield make('right',{0x4546f0:770,0x453cdc:190,0x457580:1})
 yield make('timer',{0x44d780:-1},milliseconds=0xffffffff)
 confirm={'buttons':[(2,0xd1,1)]}
 yield make('confirm-release',**confirm)
 yield make('release-then-notice',{**notice,0x4546f0:1,0x453cdc:1,0x457580:1},url,**confirm)
 yield make('outer-link-before-banner',{0x4546f0:612,0x453cdc:492,0x457580:1,0x4583b8:600,0x453c08:490,0x453f70:100,0x453ce0:30},{0x454a18:'http://example.invalid/banner0'})
 yield make('negative-dc-notice',{**notice,0x4513c0:1},url,dcResult=-1)
 yield make('playback-before-panel',{0x451160:6},**confirm)
 yield make('zero-timer-range',{0x44d780:-1},{0x4546f8+i*100:'?' for i in range(8)})
 yield make('no-navigation-row',{0x4546f0:751,0x453cdc:190,0x457580:1,**{0x452928+i*4:-1 for i in range(8)},**{0x4546d0+i*4:-1 for i in range(8)}})

def specs():
 for control in (False,True):
  for s in cases():
   g={0x458420:BM+(0xc000 if control else 0xa000),0x451188:BM+0x4000,0x44d780:0,**s['globals']}
   yield dict(s,globals=g,control=control,label=s['label']+('-control' if control else ''))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();items=list(specs());assert len(items)==32
 if a.manifest_only:a.output.write_text(json.dumps(items,indent=2)+'\n');print('Finite cases',len(items));raise SystemExit(0)
 parts=a.output.with_suffix('.parts');parts.mkdir();out=[];blobs={};installations=[]
 for i,s in enumerate(items):
  if a.limit is not None and i>=a.limit:break
  vm=ModePanelScreen(s['control']);vm.capture_path=a.output;c=vm.probe(s);assert c['spec']==s
  part=parts/f'{i:04d}.json';tmp=part.with_suffix('.tmp');tmp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation),separators=(',',':'))+'\n');os.replace(tmp,part)
  out.append(c)
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  installations.append(vm.installation);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],cases=out,blobs=blobs,installations=installations,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,bodySP=BODY,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();tmp=a.output.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,a.output);print(dict(cases=len(out),bytes=len(raw),sha256=digest(raw)),flush=True)
