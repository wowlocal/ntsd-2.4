#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh embedded resources through library human character menu and actual ret4.
Pinned NTSD/lib/VC80/DIBs, controlled Unicorn2.1.4/CW023f. Actual41bc90 prologue,
declared4229cc tail, music gate/11bitmaps,400Actor human body and output execute
on one CPU. Read/store/stack/register/ownership traces recover first-join/render
behavior. API/COM/GDI/allocator/PTD/time are controlled responses, not Windows.
Random-only initial seats consume no Object/catalog data. No damaged control/
protection structures, expected private inputs, source-fault continuation or
full initialized tick claim. See FRESH_CHARACTER_MENU_PLAN.md.
"""
import argparse,json,os,struct
from pathlib import Path
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
from oracle_fresh_library_menu import FreshMenu,MUSIC_ARENA,DEVICE
from oracle_lib_menu_continuation import SP,TAIL_SP,LIB,BM,TARGET,STACK,WORLD,GLOBAL,REGISTERS,EXE_SHA256,DLL_SHA256,digest
from oracle_mode_selection import POOL,ACTOR_SIZE

class FreshCharacterMenu(FreshMenu):
 def __init__(self,control=False):
  super().__init__(control)
  for p in self.actors:del self.regions[p]
  self.uc.mem_map(POOL+0x10000,0x70000)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=POOL+0x10000,end=POOL+0x7ffff)
  self.actors=[POOL+(399-i if control else i)*0x500+0x20 for i in range(400)]
  for i,p in enumerate(self.actors):
   self.add_region(p,bytes((j*37+11)&255 for j in range(ACTOR_SIZE)) if control else b'\xa5'*ACTOR_SIZE,False)
   self.write(p+0x364,struct.pack('<i',[-1,0,1,2,3,4,5][i%7]))
   self.write(WORLD+0x194+i*4,struct.pack('<I',p))
  self.character_points=[];self.character_sp=None
 def code(self,u,pc,n,data):
  if self.running and not self.prologue:
   self.graphics.finish(pc);self.music.finish(pc)
   sp=u.reg_read(UC_X86_REG_ESP)
   if pc==0x429e5a:self.character_sp=sp
   if pc in (0x42a114,0x42a1be,0x42a25a,0x42b246,0x42e0b6,0x42e0d2):
    assert sp==self.character_sp
    self.point('character-'+hex(pc));self.points[-1].update(seat=u.reg_read(UC_X86_REG_EBP),locals={str(o):self.u32(sp+o) for o in (0x20,0x28,0x34,0x38,0x3c)})
   if pc==0x401a30 and self.startup_done:
    assert u.reg_read(UC_X86_REG_ECX) in (0x45560c,0x455610,0x455614)
    self.pending.append(dict(entry=pc,entrySP=sp,pop=4,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
    self.event('soundRequest',[self.u32(sp+4)]);self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
   if pc==0x431c70:
    self.pending.append(dict(entry=pc,entrySP=sp,pop=0,returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGISTERS],firstStore=len(self.writes),eventStart=len(self.events)))
   if any(a<=pc<=b for a,b in [(0x429ebc,0x42b295),(0x42b94d,0x42b95f),(0x42e0b6,0x42e0d1),(0x431c70,0x431d0d),(0x4450a0,0x4450a0)]):
    # Parent must close outstanding child returns before the next caller PC.
    while self.pending and pc==self.pending[-1]['returnPC']:
     h=self.pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGISTERS]
     h.update(returnSP=sp,result=u.reg_read(UC_X86_REG_EAX),lastStore=len(self.writes),eventEnd=len(self.events));self.helpers.append(h)
     if h['entry']==0x43f010:self.bitmap_active=None
    self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();return
  return super().code(u,pc,n,data)
 def probe(self,spec):
  c=super().probe(spec);assert not self.graphics.helpers and not self.music.music_pending
  c['characterSP']=self.character_sp;return c

def specs():
 variants=[(f'initialize-mode-{m}',dict(globals={0x44d020:3,0x451160:m})) for m in (0,1,2,4)]
 variants += [('join',dict(buttons=[(0,0xd1,1)])),('cancel',dict(buttons=[(0,0xd2,1)])),('join-all',dict(buttons=[(i,0xd1,1) for i in range(8)])),('attack-before-jump',dict(buttons=[(0,0xd1,1),(0,0xd2,1)])),('negative-dc',dict(buttons=[(0,0xd1,1)],dcResult=-1)),('countdown-zero',dict(globals={0x44d078:0})),('countdown-negative',dict(globals={0x44d078:-1})),('countdown149',dict(globals={0x44d078:149})),('counter-wrap',dict(globals={0x451224:2147483647})),('null-wide',dict(music=dict(nullAllocation=True))),('null-spark',dict(resources=dict(nulls=[10])))]
 for control in (False,True):
  for label,fields in variants:
   g={0x44d020:1,0x451160:0,0x4512c8:0,0x44d074:0,0x44d078:150,0x451224:0,0x44d07c:1,0x4512cc:0,0x457578:DEVICE,0x4546f4:0x73000001,**{0x44f040+i*4:MUSIC_ARENA+0x2000+i*0x100 for i in range(4)}};g.update(fields.get('globals',{}))
   names={0x44fcc0+i*11:'Seat'+str(i+1) for i in range(8)}
   yield dict(label=label+('-control' if control else ''),control=control,**{k:v for k,v in fields.items() if k!='globals'},globals=g,strings={0x44ef04:'old.wma',0x44ef38:'C:\\NTSD',**names},output=dict(queriedAudio=MUSIC_ARENA+0x2400))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--manifest-only',action='store_true');a=p.parse_args();assert not a.output.exists();items=list(specs());assert len(items)==30
 if a.manifest_only:a.output.write_text(json.dumps(items,indent=2)+'\n');print('Finite cases',len(items));raise SystemExit(0)
 parts=a.output.with_suffix('.parts');parts.mkdir();cases=[];blobs={};installations=[];assets={}
 for i,s in enumerate(items):
  if a.limit is not None and i>=a.limit:break
  vm=FreshCharacterMenu(s['control']);vm.capture_path=a.output;c=vm.probe(s);temp=parts/f'{i:04d}.tmp';part=temp.with_suffix('.json');temp.write_text(json.dumps(dict(case=c,blobs=vm.blobs,installation=vm.installation,assets=vm.graphics.assets),separators=(',',':'))+'\n');os.replace(temp,part)
  cases.append(c)
  for k,v in vm.blobs.items():assert k not in blobs or blobs[k]==v;blobs[k]=v
  for k,v in vm.graphics.assets.items():assert k not in assets or assets[k]==v;assets[k]=v
  installations.append(vm.installation);print('completed',i,s['label'],c['end'],len(c['events']),flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=vm.installation['libSHA256'],crtSHA256=DLL_SHA256,cases=cases,blobs=blobs,installations=installations,assets=assets,worldAddress=WORLD,bitmapAddress=BM,target=TARGET,libraryAddress=LIB,stackAddress=STACK,entrySP=SP,tailSP=TAIL_SP,nativeCompared=False,windowsVerified=False)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=a.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,a.output);print(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw)),flush=True)
