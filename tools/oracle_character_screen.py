#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own menu3 -> eight human selection seats -> selected Naruto/Sasuke, ready.
Fresh loading/startup/mode/return/cycle parents are checked before continuing
the same CPU/stack/World. Subsequent calls supply only acquired keyboard bytes
resolved from own control.txt and the external caller ABI. Real original
character/portrait/text/fill/input/sound and complete nested returns execute.
Research capture only: Native comparison, computer/arena selection, physical
input acquisition, Windows pixels/audio and complete game validation are open.
"""
import argparse,json,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_menu_cycle import MenuCycle
from oracle_mode_screen import API as MODE_API
from oracle_menu_startup import capture as capture_startup
from oracle_front_screen_body import FrontScreenBody,HELPERS as BODY_HELPERS
from oracle_front_screen_prelude import FrontScreenPrelude
from oracle_front_menu_resources import WORLD,SOURCE,VTABLE,HEAP,SIZE,REGISTERS
from oracle_wave_loader import VTABLE as WAVE_VTABLE
from oracle_initial_loading import transport
from oracle_bitmap_drawing import digest
from oracle_catalog_sounds import pack
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBP,UC_X86_REG_ECX,UC_X86_REG_ESP,UC_X86_REG_EIP

HELPERS=BODY_HELPERS|{0x415160:0,0x431C70:0}

class CharacterScreen(MenuCycle):
 def imported(self,uc,pc,size,data):
  if not getattr(self,'character_running',False):super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not getattr(self,'character_running',False):super().checkpoint(uc,pc,size,data)
 def install_character(self):
  self.character_running=False
  self.character_regions={r['address']:r for r in self.regions}
  self.uc.hook_add(UC_HOOK_CODE,self.character_code)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.character_read)
 def character_read(self,uc,access,p,n,value,data):
  e=self.early
  if not self.character_running or e.body_bitmap is None or HEAP<=p<=HEAP+0x3FFFFFF:return
  if not 0x43F010<=uc.reg_read(UC_X86_REG_EIP)<=0x43F2FE:return
  if e.body_bitmap<=p and p+n<=e.body_bitmap+SIZE:
   r=self.character_regions[e.body_bitmap];offset=p-e.body_bitmap;assert n==4
   e.body_event('read',read=dict(offset=offset,value=self.u32(p),defined=all(r['mask'][offset:offset+n])))
 def character_checkpoint(self,pc):
  sp=self.uc.reg_read(UC_X86_REG_ESP);assert sp==self.menu_sp
  return dict(pc=pc,sp=sp,seat=self.uc.reg_read(UC_X86_REG_EBP),state=self.control_snapshot(),
   locals={str(o):self.u32(sp+o) for o in (0x20,0x28,0x34,0x38,0x3C)})
 def character_code(self,uc,pc,size,data):
  if not self.character_running:return
  e=self.early;sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.character_pending and pc==self.character_pending[-1]['returnPC']:
   c=self.character_pending.pop();assert sp==c['entrySP']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
   c.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.character_helpers.append(c)
  if pc in (0x42A114,0x42A1BE,0x42A25A,0x42B246,0x42E0D2):self.character_checkpoints.append(self.character_checkpoint(pc))
  if pc==0x42E0D2:
   assert not self.character_pending and not e.body_pending and e.prefix_return is None
   self.character_end='returned';uc.emu_stop();return
  if pc in (0x42B296,0x42B964,0x438B40):
   self.character_end='selectionStage';uc.emu_stop();return
  if pc in HELPERS:self.character_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x415160:self.start_prefix(pc,sp)
  if e.prefix_return is not None:
   at_return=pc==e.prefix_return;FrontScreenPrelude.code(e,uc,pc,size,data)
   if at_return:
    assert not e.calls_pending and e.clip_pending is None and e.format_pending is None
    self.fills.append(e.fill_backing);e.prefix_return=None;e.prefix_active=False
   return
  if pc in BODY_HELPERS and not e.body_pending:e.loading_draw_return=self.u32(sp)
  if e.body_pending or pc in BODY_HELPERS:
   if MODE_API<=pc<=MODE_API+0x30:
    offset,count={MODE_API:(8,1),MODE_API+16:(0x48,1),MODE_API+32:(0x34,2),MODE_API+48:(0x30,4)}[pc]
    self.emit('soundMethod',[arg(0),offset,*[arg(i) for i in range(1,count)]]);self.ret(self.input['methodResult'],count*4);return
   FrontScreenBody.code(e,uc,pc,size,data)
   if not e.body_pending:e.loading_draw_return=None
   return
  assert any(a<=pc<=b for a,b in [(0x429E5A,0x42B295),(0x42B94D,0x42B95F),(0x42E0B6,0x42E0D2),(0x431C70,0x431D09)]),hex(pc)
 def character_step(self,label):
  self.position(0x429E5A);assert self.u32(0x44D020) in (1,3)
  before=self.control_snapshot();retained=self.early.snapshot()
  for vt in (VTABLE,WAVE_VTABLE):
   for index,offset in enumerate((8,0x48,0x34,0x30)):self.put(vt+offset,MODE_API+index*16)
  self.input=dict(dcResult=0,dc=0x12345678,methodResult=0,drawResults=[0,1],shellResult=33,milliseconds=100,fillResult=0,fillColor=0,drawTarget=SOURCE)
  self.mode_events=[];self.character_helpers=[];self.character_pending=[];self.character_checkpoints=[];self.character_end=None;self.fills=[]
  e=self.early;e.completion_active=True;e.body_active=True;e.body_range=(0x429E5A,0x42E0D2);e.body_stops={};e.body_helpers=BODY_HELPERS;e.body_target=SOURCE
  e.body_events=self.mode_events;e.body_returns=[];e.body_pending=[];e.body_clip=None;e.body_bitmap=None;e.body_blits=0;e.body_input=self.input;e.body_sound_slots={0x45560C,0x455610,0x455614}
  e.gdi.presentation_events=self.mode_events;e.gdi.presentation_input=self.input;e.input=self.input;e.prefix_return=None
  # The input/loading guards own their own read provenance. Bitmap drawing
  # intentionally reads the constructor's untouched frame-count word even for
  # frame=-1. Preserve EVERY such read in this renderer's corpus instead of
  # letting it appear as an undefined input read on the next outer call.
  previous_reads=self.reads_before_writes;assert not previous_reads
  self.reads_before_writes=set()
  self.character_running=True
  try:
   self.uc.emu_start(0x429E5A,0,count=2_000_000);assert self.character_end is not None
  except Exception:
   print('CHARACTER FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.mode_events[-4:],flush=True);raise
  finally:
   undefined_reads=sorted(self.reads_before_writes);self.reads_before_writes=previous_reads
   self.character_running=False;e.body_active=False;e.completion_active=False;e.prefix_active=False
  case=dict(label=label,before=before,earlyBefore=retained,input=self.input,events=self.mode_events,helpers=self.character_helpers,checkpoints=self.character_checkpoints,
   fills=self.fills,readsBeforeWrites=undefined_reads,after=self.control_snapshot(),earlyAfter=e.snapshot(),continuation=self.character_end,end=self.position(self.uc.reg_read(UC_X86_REG_EIP)))
  print('CHARACTER',label,'selected',[self.u32(0x451248+4*i) for i in range(2)],'status',[self.u32(0x451288+4*i) for i in range(8)],'events',len(self.mode_events),flush=True)
  return case
 def acquire(self,changes):
  writes=[]
  for seat,button,pressed in changes:
   status=self.u32(0x450B4C+seat*4);assert 1<=status<=4
   config=0x44FB20+status*80;assert self.u32(config)==0
   key=self.u32(config+4+button*4);assert key<300
   address=0x455378+key;raw=bytes([100 if pressed else 117]);self.uc.mem_write(address,raw)
   writes.append(dict(seat=seat,button=button,pressed=pressed,address=address,bytes=raw.hex()))
  return writes
 def capture_character(self,parent):
  suffix='-control' if self.control else '';r=json.loads((ROOT/'docs/evidence'/f'menu-cycle{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
  assert digest(raw)==r['sha256'] and json.loads(raw)==json.loads(json.dumps(parent))
  print('Entire pinned menu cycle reproduced; continuing own character screen',flush=True)
  self.install_character();cases=[]
  def document():return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[a['address'] for a in self.pool],objectAddresses=self.object_addresses,cases=cases),{**self.early.blobs,**self.blobs})
  def frame(label,changes=(),first=False):
   before=self.control_snapshot();writes=self.acquire(changes)
   cycle=None if first else self.cycle_step(label+' cycle',selection=True)
   screen=self.character_step(label);assert screen['continuation']=='returned'
   self.bind_output();returned=self.return_step(label+' return',inherited=True,entry_pc=0x42E0D2)
   cases.append(dict(label=label,before=before,acquired=writes,cycle=cycle,screen=screen,returned=returned))
   (ROOT/'build/research'/f'character-screen-partial{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  frame('own-first-character-screen',first=True)
  frame('release-vs-confirm')
  def edge(label,seats,button):
   for name,pressed,stimulus in [('press-acquired',True,True),('press-applied',True,False),('release-acquired',False,True),('release-applied',False,False)]:
    frame(label+' '+name,[(seat,button,pressed) for seat in seats] if stimulus else ())
  edge('join-two-players',(0,1),4)
  edge('first-eligible-character',(0,1),3)
  for i in range(4):edge(f'second-player-right-{i}',(1,),3)
  assert [self.u32(0x451248+4*i) for i in range(2)]==[17,21]
  edge('confirm-characters',(0,1),4)
  assert [self.u32(0x451288+4*i) for i in range(2)]==[2,2]
  edge('confirm-teams',(0,1),4)
  assert [self.u32(0x451288+4*i) for i in range(2)]==[3,3]
  assert self.u32(0x4512C8)==0 and self.u32(WORLD)==2
  return document()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pending=[]
  for suffix in ('','-control'):
   report=json.loads((ROOT/'build/research'/f'character-screen{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
   assert digest(raw)==report['sha256'] and len(raw)==report['bytes'];doc=json.loads(raw);assert len(doc['cases'])==34
   refs=[]
   for name in ('menu-cycle','menu-return','mode-screen','menu-startup'):
    r=json.loads((ROOT/'docs/evidence'/f'{name}{suffix}.json').read_bytes());ref=dict(fixture=r['fixture'],sha256=r['fixtureSHA256'])
    assert (doc if not refs else previous)['parent']==ref
    refs.append(ref);previous=r
   refs.extend(r['parents'][key] for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'))
   parents=[]
   for ref in refs:
    path=fixtures/ref['fixture'];assert digest(path.read_bytes())==ref['sha256'];parents.append(str(path))
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'character-screen{suffix}-check.json';temporary.write_bytes(packed)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--character-screen',str(temporary),*parents],capture_output=True,text=True)
   print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=fixtures/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),parent=doc['parent'])
   pending.append((ROOT/'docs/evidence'/f'character-screen{suffix}.json',report,fixture,packed))
  for path,report,fixture,packed in pending:fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture_startup(a.control,vm_type=CharacterScreen,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'character-screen{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
