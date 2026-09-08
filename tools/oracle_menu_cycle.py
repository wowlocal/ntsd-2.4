#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Research in progress: repeat whole4246b0 from the own first menu return.
Fresh early/loading/startup/first mode and return are reproved on one CPU.
Only outer caller ABI and acquired keyboard bytes are supplied afterwards.
No Actor/phase/menu/loaded-state replacement. Stop before character selection.
Native comparison, window input acquisition and Windows validation remain open.
"""
import argparse,json,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_menu_return import MenuReturn,API as RETURN_API
from oracle_mode_screen import API as MODE_API
from oracle_menu_startup import capture as capture_startup
from oracle_front_menu_resources import WORLD,SOURCE,VTABLE,ENTRY_SP,REGISTERS
from oracle_wave_loader import VTABLE as WAVE_VTABLE
from oracle_state import STOP
from oracle_music_playback import platform as music_platform
from oracle_initial_loading import transport
from oracle_bitmap_drawing import digest
from oracle_catalog_sounds import pack
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_ESP,UC_X86_REG_EIP

class MenuCycle(MenuReturn):
 def imported(self,uc,pc,size,data):
  if not getattr(self,'cycle_prefix',False):super().imported(uc,pc,size,data)
 def checkpoint(self,uc,pc,size,data):
  if not getattr(self,'cycle_prefix',False):super().checkpoint(uc,pc,size,data)
 def cycle_code(self,uc,pc,size,data):
  # The previous full call cached a block spanning this logical boundary.
  # Stop at the actual instruction even when emu_start(until) is crossed.
  if self.input_running and pc==0x41C5E5:
   uc.emu_stop();return
  if not self.cycle_prefix:return
  if pc==0x41C581:
   self.cycle_end=True;uc.emu_stop();return
  assert (0x4246B0<=pc<=0x424741 or 0x41BC90<=pc<=0x41BE92),hex(pc)
 def bind_output(self):
  for offset in (0,8,0x1C,0x20,0x2C,0x3C):
   for table in [VTABLE,WAVE_VTABLE,*[self.u32(token) for token in self.music_tokens]]:self.put(table+offset,RETURN_API+offset*4)
 def cycle_step(self,label,pressed=None,selection=False,gameplay=False):
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.u32(WORLD)==2
  before=self.control_snapshot();retained=self.early.snapshot();stimulus=[]
  # The first player's attack binding is read from OWN loaded control.txt.
  if pressed is not None:
   status=self.u32(0x450B4C);assert 1<=status<=4
   config=0x44FB20+status*80;assert self.u32(config)==0
   key=self.u32(config+4+4*4);assert key<300
   p=0x455378+key;raw=bytes([100 if pressed else 117]);self.uc.mem_write(p,raw)
   stimulus.append(dict(address=p,bytes=raw.hex()))
  assert self.u32(0)==0x12345678
  assert [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
  self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE)
  self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  self.cycle_prefix=True;self.cycle_end=False;self.phase='cycle-prefix'
  try:self.uc.emu_start(0x4246B0,0,count=10000);assert self.cycle_end
  finally:self.cycle_prefix=False
  self.body_sp=self.uc.reg_read(UC_X86_REG_ESP);assert self.body_sp==0x1000E9BC
  self.commands_address=self.body_sp+0x434
  paused=self.u32(self.body_sp+0x38);assert paused==0
  assert self.u32(0x44D05C)==0 and self.u32(0x450B84)==0
  prefix=dict(after=self.control_snapshot(),paused=paused,phase=self.u32(0x450B90),commands=list(self.uc.mem_read(self.commands_address,10)),playback=list(self.uc.mem_read(self.body_sp+0x440,10)),end=self.position(0x41C581))
  local=self.step(label+' local',parent=True,paused=paused);assert not local['dispatch']
  control=self.control_step(label+' control',paused=paused,inherited=True)
  replay=self.replay_step(label+' replay',paused=paused,inherited=True)
  outcome=self.round_step(label+' round',paused=paused,inherited=True)
  if gameplay:
   assert outcome['endPC']==0x41E339 and not local['dispatch']
   return dict(label=label,stimulus=stimulus,before=before,earlyBefore=retained,prefix=prefix,local=local,inputControl=control,replay=replay,round=outcome,
    after=self.control_snapshot(),earlyAfter=self.early.snapshot(),end=self.position(0x41E339))
  assert outcome['continuation']=='menu'
  self.music_initial=self.control_snapshot()
  music=self.music_step(label+' music',kind='menu',inherited=True,cfg=music_platform(createPointer=self.music_tokens[0],queryPointers=self.music_tokens[1:]))
  self.resource_initial=self.control_snapshot();self.resource_music=[self.record(r) for r in self.music_allocations]
  resources=self.resource_step(label+' resources',inherited=True);assert not resources['allocations']
  mode=returned=None
  if not selection:
   for vt in (VTABLE,WAVE_VTABLE):
    for index,offset in enumerate((8,0x48,0x34,0x30)):self.put(vt+offset,MODE_API+index*16)
   mode=self.mode_step(label+' mode',inherited=True)
   self.bind_output();returned=self.return_step(label+' return',inherited=True)
  result=dict(label=label,stimulus=stimulus,before=before,earlyBefore=retained,prefix=prefix,local=local,inputControl=control,replay=replay,round=outcome,music=music,resources=resources,mode=mode,returned=returned,after=self.control_snapshot(),earlyAfter=self.early.snapshot(),end=dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP)))
  print('CYCLE',label,'phase',prefix['phase'],'menu',self.u32(0x44D020),'control events',len(control['events']),'at',hex(self.uc.reg_read(UC_X86_REG_EIP)),flush=True)
  return result
 def capture_return(self,first,after_cycle=None):
  suffix='-control' if self.control else '';r=json.loads((ROOT/'docs/evidence'/f'mode-screen{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
  assert digest(raw)==r['sha256'];old=json.loads(raw)
  assert first['cases']==old['cases'][:1] and all(old['blobs'][k]==v for k,v in first['blobs'].items())
  self.install_return();own=self.return_step('own-first-whole-early-return',inherited=True)
  report=json.loads((ROOT/'docs/evidence'/f'menu-return{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'];old=json.loads(raw)
  actual=transport(dict(case=own),{**self.early.blobs,**self.blobs});expected=transport(dict(case=old['cases'][0]),old['blobs']);assert actual==expected
  print('Pinned FIRST mode and complete own return reproduced; repeating whole outer caller',flush=True)
  self.cycle_prefix=False;self.uc.hook_add(UC_HOOK_CODE,self.cycle_code)
  cases=[]
  def document():return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=cases),{**self.early.blobs,**self.blobs})
  for label,pressed,selection in [('own-idle-phase-zero',None,False),('attack-acquired-phase-one',True,False),('held-attack-phase-zero',None,False),('release-next-selection',False,True)]:
   cases.append(self.cycle_step(label,pressed,selection))
   (ROOT/'build/research'/f'menu-cycle-partial{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  assert [c['prefix']['phase'] for c in cases]==[0,1,0,1]
  assert self.u32(0x44D020)==3
  result=document()
  return result if after_cycle is None else after_cycle(self,result)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[];fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
  for suffix in ('','-control'):
   report=json.loads((ROOT/'build/research'/f'menu-cycle{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
   assert digest(raw)==report['sha256'] and len(raw)==report['bytes'];doc=json.loads(raw);assert len(doc['cases'])==4
   returning=json.loads((ROOT/'docs/evidence'/f'menu-return{suffix}.json').read_bytes());screen=json.loads((ROOT/'docs/evidence'/f'mode-screen{suffix}.json').read_bytes());startup=json.loads((ROOT/'docs/evidence'/f'menu-startup{suffix}.json').read_bytes())
   assert doc['parent']==dict(fixture=returning['fixture'],sha256=returning['fixtureSHA256'])
   assert returning['parent']==dict(fixture=screen['fixture'],sha256=screen['fixtureSHA256'])
   assert screen['parent']==dict(fixture=startup['fixture'],sha256=startup['fixtureSHA256'])
   refs=[doc['parent'],returning['parent'],screen['parent'],*[startup['parents'][key] for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds')]]
   parents=[]
   for ref in refs:
    parent=fixtures/ref['fixture'];assert digest(parent.read_bytes())==ref['sha256'];parents.append(str(parent))
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'menu-cycle{suffix}-check.json';temporary.write_bytes(packed)
   r=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-cycle',str(temporary),*parents],capture_output=True,text=True)
   print(r.stdout,end='',flush=True)
   if r.returncode:print(r.stderr,end='',flush=True);r.check_returncode()
   fixture=fixtures/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=r.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),parent=doc['parent'])
   pending.append((ROOT/'docs/evidence'/f'menu-cycle{suffix}.json',report,fixture,packed))
  for path,report,fixture,packed in pending:fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture_startup(a.control,vm_type=MenuCycle,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first)))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-cycle{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
