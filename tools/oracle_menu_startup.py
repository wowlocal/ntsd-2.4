#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own fresh early menus/loading -> local/control/replay/round -> music/resources.
Same CPU/World/stack throughout the natural first phase1 path to429e5a.
No post-loading game-state stimuli, replay buffers, paused-entry jump or new
World. Platform/CRT/allocator boundaries remain explicit; no Windows/UI claim.
"""
import argparse,json,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
import oracle_menu_loading
from oracle_menu_loading import EarlyMenus,MenuLoading
from oracle_menu_resources import MenuResources
from oracle_music_playback import platform as music_platform
from oracle_initial_loading import transport
from oracle_catalog_sounds import pack
from oracle_front_menu_resources import WORLD,BODY_SP
from oracle_wave_loader import digest
from unicorn.x86_const import UC_X86_REG_EIP,UC_X86_REG_ESP

class MenuStartup(MenuLoading,MenuResources):
 def position(self,pc):
  assert self.uc.reg_read(UC_X86_REG_EIP)==pc
  return dict(pc=pc,sp=self.uc.reg_read(UC_X86_REG_ESP))
 def startup(self):
  entry=self.position(0x41C581)
  self.body_sp=entry['sp'];self.commands_address=self.body_sp+0x434
  paused=self.u32(self.body_sp+0x38);assert paused==0 and self.u32(0x450B90)==1
  retained=self.early.snapshot()
  local=self.step('own-first-local-input',parent=True,paused=paused)
  self.position(0x41C5E5)
  # No playback/recording allocation has occurred in this natural path.
  assert self.u32(0x4588A8)==self.u32(0x4588AC)==0
  before=self.early.snapshot();self.install_boundaries(replay_buffers=False)
  assert self.early.snapshot()==before
  self.messages={};initial=self.control_snapshot()
  control=self.control_step('own-first-input-control',paused=paused,inherited=True)
  self.position(0x41D5DB)
  replay=self.replay_step('own-first-replay-tail',paused=paused,inherited=True)
  self.position(0x41D714)
  outcome=self.round_step('own-first-round',paused=paused,inherited=True)
  assert outcome['continuation']=='menu';self.position(0x4229CC)
  self.music_initial=self.control_snapshot();self.install_music()
  cfg=music_platform(createPointer=self.music_tokens[0],queryPointers=[*self.music_tokens[1:]])
  music=self.music_step('own-first-menu-music',kind='menu',inherited=True,cfg=cfg)
  self.menu_sp=self.position(0x4297AE)['sp']
  self.resource_initial=self.control_snapshot();self.resource_music=[self.record(r) for r in self.music_allocations]
  self.install_resources()
  resources=self.resource_step('own-first-character-menu-resources',inherited=True)
  end=self.position(0x429E5A)
  return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   entry=entry,end=end,worldAddress=self.world_address,objectAddresses=self.object_addresses,
   actorAddresses=[r['address'] for r in self.pool],initialContext=initial,local=local,inputControl=control,replay=replay,
   round=outcome,music=music,resources=resources,sources=list(self.resource_sources.values()),messages=self.messages,
   after=self.control_snapshot(),retainedBefore=retained,retainedAfter=self.early.snapshot()),{**self.early.blobs,**self.blobs})

def capture(control=False,vm_type=MenuStartup,after=None):
 early=EarlyMenus(control);saved_initial=list(early.uc.mem_read(0x458588,0x320));parent=early.capture_loop()
 entry=dict(pc=early.uc.reg_read(UC_X86_REG_EIP),sp=early.uc.reg_read(UC_X86_REG_ESP),returnPC=early.u32(BODY_SP-8),target=early.u32(BODY_SP-4))
 assert entry['pc']==0x41BC90 and early.u32(WORLD)==2
 vm=vm_type(early,music_arena=0x31000000,resource_arena=0x32000000,control_api=0x33000000,music_api_address=0x33001000,resource_api=0x33002000)
 loading,catalog,sounds=vm.continue_loading()
 parent.update(scope=oracle_menu_loading.__doc__,loadingEntry=entry,loadingDraws=vm.draw_calls,afterLoading=early.snapshot())
 suffix='-control' if control else '';report=json.loads((ROOT/'docs/evidence'/f'menu-loading{suffix}.json').read_bytes());parents={}
 for key,doc in zip(('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'),(parent,loading,catalog,sounds)):
  p=report[key];raw=(ROOT/'build/original'/p['corpus']).read_bytes()
  assert digest(raw)==p['sha256'] and json.loads(raw)==json.loads(json.dumps(doc)),key
  parents[key]=dict(fixture=p['fixture'],sha256=p['fixtureSHA256'])
 print('Entire pinned early-menu/loading parent reproduced; continuing own state',flush=True)
 doc=vm.startup();doc['parents']=parents;doc['savedAtFirstMenu']=saved_initial
 return doc if after is None else after(vm,doc)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[];fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
  for suffix in ('','-control'):
   path=ROOT/'build/research'/f'menu-startup{suffix}.json';report=json.loads(path.read_bytes())
   raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'];doc=json.loads(raw)
   packed=pack(doc).encode();temporary=ROOT/'build/original'/f'menu-startup{suffix}-check.json';temporary.write_bytes(packed)
   parents=[]
   for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'):
    ref=doc['parents'][key];parent=fixtures/ref['fixture'];assert digest(parent.read_bytes())==ref['sha256'];parents.append(str(parent))
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-startup',str(temporary),*parents],capture_output=True,text=True)
   print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=fixtures/('original-'+report['corpus'])
   report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
   pending.append((ROOT/'docs/evidence'/path.name,report,fixture,packed))
  for path,report,fixture,packed in pending:
   fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=capture(a.control);suffix='-control' if a.control else ''
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-startup{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parents=doc['parents'],nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
