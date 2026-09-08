#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh early menus -> actual424741/41bc90 -> full initial loading41c581.
One game CPU/stack/World and retained early resources. New observers attach
without replacing PE globals, registers, stack, World or loaded resources.
Common MENU_WAIT uses its real early bitmap/clip children through COM; the
whole source catalog,18+400 WAVs,400-slot pool and10 UI constructors follow.
File/CRT/device/clock/allocator inputs are explicit. No Windows/full-match claim.
"""
import argparse,json,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_front_menu_loop import FrontMenuLoop
from oracle_front_menu_resources import WORLD,WORLD_PREFIX,GLOBAL,GLOBAL_SIZE,SOURCE,VTABLE,BODY_SP,REGISTERS
from oracle_front_screen_body import FrontScreenBody
from oracle_front_screen_prelude import PAPI
from oracle_initial_loading import InitialLoading,transport
from oracle_catalog_sounds import pack
from oracle_bitmap_drawing import digest
from oracle_state import STACK
from unicorn.x86_const import UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_ECX,UC_X86_REG_EAX,UC_X86_REG_EDX,UC_X86_REG_EFLAGS

class EarlyMenus(FrontMenuLoop):
 def __init__(self,control=False):
  self.continuing_loading=False;self.loading_draw_return=None
  super().__init__(control)
 def before_front_resources(self):
  super().before_front_resources()
  # Explicit platform bindings BEFORE the first early menu, retained thereafter.
  for p,v in [(0x44EECC,SOURCE),(0x453E0C,SOURCE),(0x455634,SOURCE),(0x458348,3 if self.control else 1)]:self.put(p,v)
  self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
  self.uc.mem_write(WORLD-16,b'\x96'*16);self.uc.mem_write(WORLD+WORLD_PREFIX,b'\x69'*16)
 def code(self,uc,pc,size,data):
  if not self.continuing_loading:super().code(uc,pc,size,data)
 def memset(self,uc,pc,size,data):
  if not self.continuing_loading:super().memset(uc,pc,size,data)
 def body_code_allowed(self,pc):
  return pc==self.loading_draw_return or super().body_code_allowed(pc)

class MenuLoading(InitialLoading):
 def __init__(self,early,**loading_options):
  self.early=early;self.draw_calls=[]
  early.continuing_loading=True
  # This observer now only returns; do not cross into Python for every catalog
  # instruction. The loading observer owns code checks; early memory masks and
  # the explicit real drawing callback remain active.
  early.uc.hook_del(early.front_code_hook)
  uc=early.uc;registers=[*REGISTERS,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_ECX,UC_X86_REG_EAX,UC_X86_REG_EDX,UC_X86_REG_EFLAGS]
  before=early.snapshot();stack=bytes(uc.mem_read(STACK,0x10000));saved=[uc.reg_read(r) for r in registers]
  world=dict(address=WORLD,size=WORLD_PREFIX,kind='world',initial=early.world_initial,mask=early.world_mask)
  super().__init__(early.control,uc=uc,existing_world=world,second_pointer=0x2D000020,**loading_options)
  assert self.uc is uc and early.snapshot()==before and bytes(uc.mem_read(STACK,0x10000))==stack and [uc.reg_read(r) for r in registers]==saved
  # Same declared COM objects; bind their methods to the attached adapters.
  wave=self.wave;wave.p={};wave.prefix_draw=self.prefix_draw
  self.put(VTABLE+0x0C,wave.stub_base+0x10C)
  self.put(VTABLE+0x2C,wave.stub_base+0x22C)
  wave.imports[PAPI]='blit'
 def prefix_draw(self,uc,pc,size,data):
  e=self.early;sp=uc.reg_read(UC_X86_REG_ESP)
  if e.loading_draw_return is None:
   if pc==PAPI:
    # Real43e940 Blt on the same raw target surface used by the early menu.
    assert self.u32(sp)==0x43E975;self.wave.imported(uc,pc,size,data);return True
   if pc!=0x43F010:return False
   args=[uc.reg_read(UC_X86_REG_ECX)]+[self.u32(sp+4+i*4) for i in range(6)]
   self.wave.prefix_events.append(dict(presentation=dict(kind='bitmap',arguments=args,strings=[])))
   e.loading_draw_return=self.u32(sp);e.body_active=True;e.body_stops={};e.body_helpers={0x43F010:24,0x43EF70:0}
   e.body_events=[];e.body_returns=[];e.body_pending=[];e.body_clip=None;e.body_bitmap=None;e.body_blits=0;e.body_input=dict(drawResults=[0,1])
   self.draw_pending=dict(entrySP=sp,returnPC=e.loading_draw_return,input=args,drawResults=e.body_input['drawResults'])
  FrontScreenBody.code(e,uc,pc,size,data)
  if pc==e.loading_draw_return:
   assert not e.body_pending and e.body_clip is None and sp==self.draw_pending['entrySP']+28
   self.draw_calls.append(dict(**self.draw_pending,events=e.body_events,helpers=e.body_returns,returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX)))
   e.body_active=False;e.loading_draw_return=None;return False
  return True

def capture(control):
 early=EarlyMenus(control);parent=early.capture_loop()
 assert early.u32(WORLD)==2 and early.uc.reg_read(UC_X86_REG_EIP)==0x41BC90
 entry=dict(pc=early.uc.reg_read(UC_X86_REG_EIP),sp=early.uc.reg_read(UC_X86_REG_ESP),returnPC=early.u32(BODY_SP-8),target=early.u32(BODY_SP-4))
 vm=MenuLoading(early);loading,catalog,sounds=vm.continue_loading()
 assert early.loading_draw_return is None and len(vm.draw_calls)==1
 parent.update(scope=__doc__,loadingEntry=entry,loadingDraws=vm.draw_calls,afterLoading=early.snapshot())
 return parent,loading,catalog,sounds

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   path=ROOT/'build/research'/f'menu-loading{suffix}.json';report=json.loads(path.read_bytes());paths=[];fixtures=[]
   for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'):
    r=report[key];raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256'];doc=json.loads(raw)
    if key=='menu-loading-catalog':
     doc.pop('scans');doc.pop('readsBeforeWrites');doc['events']=[e for e in doc['events'] if e['kind']=='mirror-blit'];doc=transport(doc,doc['blobs'])
    packed=pack(doc).encode();temporary=ROOT/'build/original'/f'{key}{suffix}-check.json';temporary.write_bytes(packed);paths.append(str(temporary))
    fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+r['corpus']);r.update(fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed));fixtures.append((fixture,packed))
   r=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-loading',*paths],capture_output=True,text=True);print(r.stdout,end='',flush=True)
   if r.returncode:print(r.stderr,end='',flush=True);r.check_returncode()
   report.update(nativeCompared=True,nativeComparison=r.stdout.strip());pending.append((ROOT/'docs/evidence'/path.name,report,fixtures))
  for path,report,fixtures in pending:
   for fixture,data in fixtures:fixture.write_bytes(data)
   path.write_text(json.dumps(report,indent=2)+'\n')
  return
 docs=capture(a.control);suffix='-control' if a.control else '';report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,nativeCompared=False)
 for key,doc in zip(('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'),docs):
  raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'{key}{suffix}.json';path.write_bytes(raw);report[key]=dict(corpus=path.name,sha256=digest(raw),bytes=len(raw))
 (ROOT/'build/research'/f'menu-loading{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
