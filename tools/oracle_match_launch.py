#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own Start -> prelude/preparation/enabled music/recording -> complete return
and next whole outer entry BEFORE41e339 gameplay. Fresh full MATCH_SELECTION
and all its parents execute on the same CPU/stack/World/catalog/RNG. Only
declared OS time/device/allocator responses and outer caller ABI are supplied.
No game-state replacement, disabled music, replay metadata or RNG stimuli.
Research capture: native comparison, app integration and Windows output open.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256,PTD
from oracle_match_selection import MatchSelection
from oracle_menu_startup import capture as capture_startup
from oracle_music_playback import platform as music_platform
from oracle_front_menu_resources import WORLD,REGISTERS
from oracle_objects import DEVICE,STUB
from oracle_loaded_catalog import CATALOG,BG_BASE,BG_SIZE
from oracle_initial_loading import transport
from oracle_bitmap_drawing import digest
from oracle_catalog_sounds import pack
from oracle_state import STOP
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_ESP,UC_X86_REG_EIP

API,REPLAY,REPLAY_SIZE=0x33005000,0x72000020,0x630E18
HELPERS={0x4061D0:0,0x417170:0,0x40C030:4,0x40C0E0:4,0x431C70:0,0x43D280:0,0x43D2C0:0,0x401A30:4,0x43EE50:12}

class MatchLaunch(MatchSelection):
 def memset(self,uc,pc,size,data):
  if getattr(self,'launch_running',False):
   sp=uc.reg_read(UC_X86_REG_ESP);dst,value,count=[self.u32(sp+i) for i in (4,8,12)]
   if dst==0x455378:
    assert self.u32(sp)==0x431D09 and (value,count)==(0x75,300)
    self.write_host(dst,bytes([value])*count);self.ret(dst);return
  super().memset(uc,pc,size,data)
 def launch_state(self):
  return dict(state=self.control_snapshot(),early=self.early.snapshot(),
   backgrounds=[self.slice_record(self.catalog,BG_BASE+i*BG_SIZE,BG_SIZE) for i in range(101)],
   bitmaps=[dict(address=b['address'],storage=self.record(self.region(b['address'],1))) for b in self.bitmaps],
   music=[dict(address=r['address'],storage=self.record(r)) for r in self.music_allocations],released=self.launch_released.copy())
 def launch_code(self,uc,pc,size,data):
  if not self.launch_running:return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.launch_pending and pc==self.launch_pending[-1]['returnPC']:
   h=self.launch_pending.pop();assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS]
   h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.launch_helpers.append(h)
  if self.launch_random and pc==self.launch_random['returnPC']:
   r=self.launch_random;self.launch_random=None
   self.launch_events.append(dict(kind='random',**r,result=uc.reg_read(UC_X86_REG_EAX),index=self.u32(0x450BCC),counter=self.u32(0x450C34)))
  if self.launch_format and pc==self.launch_format['returnPC']:
   f=self.launch_format;self.launch_format=None;assert sp==f['entrySP']+4
   raw=self.cstr(f['destination']);assert len(raw)==uc.reg_read(UC_X86_REG_EAX)
   self.launch_events.append(dict(kind='format',**f,result=len(raw),bytes=list(raw)))
  if pc==self.launch_stop:
   assert not self.launch_pending and self.launch_random is None and self.launch_format is None
   self.launch_finished=True;uc.emu_stop();return
  if pc in HELPERS:
   self.launch_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x4061D0:
   slot=next(i for i,r in enumerate(self.pool) if r['address']==uc.reg_read(UC_X86_REG_ECX))
   self.launch_events.append(dict(kind='reconstruct',slot=slot))
  elif pc==0x417170:
   assert self.launch_random is None
   self.launch_random=dict(returnPC=self.u32(sp),stream=arg(0),range=arg(1),beforeIndex=self.u32(0x450BCC),beforeCounter=self.u32(0x450C34))
  elif pc in (0x40C030,0x40C0E0):
   assert uc.reg_read(UC_X86_REG_ECX)==CATALOG
   self.launch_events.append(dict(kind='loadLayers' if pc==0x40C030 else 'releaseLayers',index=arg(0)))
  elif pc==0x431C70:
   assert uc.reg_read(UC_X86_REG_ECX)==WORLD;self.launch_events.append(dict(kind='resetInput'))
  elif pc==0x401A30:
   assert uc.reg_read(UC_X86_REG_ECX)==0x455610 and self.u32(0x455610)==0
   self.launch_events.append(dict(kind='soundRequest',slot=0x455610,loop=arg(0)))
  elif pc==0x43D2C0:
   assert self.u32(sp)==0x42D701 and [arg(1),arg(2)]==[WORLD+4,WORLD+0x194]
   self.launch_events.append(dict(kind='replayEntry',mode=arg(0),activity=arg(1),actors=arg(2)))
  if pc==0x7817775D:
   fmt=self.cstr(arg(1));assert fmt in (b'%4d%02d%02d_%02d%02d%02d',b'%s.lfr') and self.launch_format is None
   self.launch_format=dict(entrySP=sp,returnPC=self.u32(sp),destination=arg(0),format=list(fmt))
  if pc==0x78132DB2:self.ret(PTD);return
  if pc==API:
   assert self.u32(sp)==0x42D05C and arg(0)==self.menu_sp+0x814
   uc.mem_write(arg(0),struct.pack('<8H',*self.launch_time));self.launch_events.append(dict(kind='localTime',values=self.launch_time));self.ret(0,4);return
  if pc==API+16:
   assert self.u32(sp)==0x43D2DE and [arg(0),arg(1)]==[1,REPLAY_SIZE] and not self.replay_memory
   r=self.add_backing(REPLAY,REPLAY_SIZE,'recording');uc.mem_write(REPLAY,bytes(REPLAY_SIZE));r['mask'][:]=b'\1'*REPLAY_SIZE
   self.replay_memory.append(dict(region=r,live=True));self.launch_events.append(dict(kind='calloc',address=REPLAY,count=1,size=REPLAY_SIZE));self.ret(REPLAY);return
  if pc==API+32:
   target=uc.reg_read(UC_X86_REG_ECX);assert arg(0)==DEVICE and self.u32(sp)==0x40C120
   assert target in [b['address'] for b in self.bitmaps] and target not in self.launch_released
   self.launch_events.append(dict(kind='surfaceRelease',address=target));self.ret(0,4);return
  if pc==API+48:
   target=arg(0);assert self.u32(sp)==0x40C125 and self.launch_events[-1]==dict(kind='surfaceRelease',address=target)
   self.launch_released.append(target);self.launch_events.append(dict(kind='free',address=target));self.ret();return
  assert any(a<=pc<=b for a,b in [(0x42CF8A,0x42E0D2),(0x4061D0,0x4064CD),(0x417170,0x4171BC),(0x40C030,0x40C15E),
   (0x431C70,0x431D10),(0x401A30,0x401A6F),(0x43D280,0x43D29C),(0x43D2C0,0x43DB38),(0x43EE50,0x43EF85),(0x43ED10,0x43ED10),
   (0x4450A0,0x4450BA),(STUB,STUB+0x310),(0x78130000,0x7822FFFF),(STOP+0x6000,STOP+0x7FFF)]),hex(pc)
 def launch_step(self,label,start,stop):
  self.position(start);before=self.launch_state();self.launch_stop=stop;self.launch_finished=False
  self.launch_events=[];self.launch_helpers=[];self.launch_pending=[];self.launch_random=self.launch_format=None
  bitmap_start=len(self.bitmaps);event_start=len(self.events);self.phase='match-launch';self.launch_running=True
  previous_reads=self.reads_before_writes;assert not previous_reads;self.reads_before_writes=set()
  try:
   for _ in range(20):
    self.uc.emu_start(self.uc.reg_read(UC_X86_REG_EIP),0,count=2_000_000)
    if self.launch_finished:break
   assert self.launch_finished and self.uc.reg_read(UC_X86_REG_ESP)==self.menu_sp
  except Exception:
   print('LAUNCH FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.launch_events[-5:],flush=True);raise
  finally:
   reads=sorted(self.reads_before_writes);self.reads_before_writes=previous_reads;self.launch_running=False
  result=dict(label=label,before=before,after=self.launch_state(),events=self.launch_events,helpers=self.launch_helpers,readsBeforeWrites=reads,
   bitmapEvents=self.events[event_start:],newBitmaps=self.bitmaps[bitmap_start:],end=self.position(stop))
  print('LAUNCH',label,'events',len(self.launch_events),'bitmaps',len(self.bitmaps)-bitmap_start,'RNG',self.u32(0x450BCC),self.u32(0x450C34),flush=True)
  return result
 def capture_character(self,parent):
  old=super().capture_character(parent);suffix='-control' if self.control else ''
  report=json.loads((ROOT/'docs/evidence'/f'match-selection{suffix}.json').read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
  print('Entire pinned MATCH_SELECTION reproduced; continuing own Start',flush=True)
  self.launch_running=False;self.launch_released=[];self.launch_time=[2026,9,3,9,12,34,56,789]
  self.uc.mem_map(API,0x1000);self.uc.mem_map(REPLAY&~4095,0x640000)
  self.uc.hook_add(UC_HOOK_CODE,self.launch_code)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.track_read,begin=REPLAY,end=REPLAY+REPLAY_SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.track_write,begin=REPLAY,end=REPLAY+REPLAY_SIZE-1)
  self.put(0x4470A4,API);self.put(0x4471B0,API+16);self.put(0x447174,0x7817775D)
  self.put(DEVICE+0x108,API+32);self.put(DEVICE+0x174,STUB+0x300);self.put(0x44717C,API+48)
  cases=[]
  def document():return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
   parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),worldAddress=WORLD,actorAddresses=[r['address'] for r in self.pool],
   objectAddresses=self.object_addresses,localTime=self.launch_time,cases=cases),{**self.early.blobs,**self.blobs})
  def save():
   (ROOT/'build/research'/f'match-launch-partial{suffix}.json').write_text(json.dumps(document(),separators=(',',':'))+'\n')
  for label,start,stop in [('prelude',0x42CF8A,0x42D1FF),('preparation',0x42D1FF,0x42D6B6)]:
   cases.append(self.launch_step(label,start,stop));save()
  self.music_initial=self.control_snapshot();self.bind_music()
  music=self.music_step('own-match-music',path=self.cstr(0x44EED0),kind='match',inherited=True,cfg=music_platform(createPointer=self.music_tokens[0],queryPointers=self.music_tokens[1:]))
  cases.append(dict(label='music',music=music,after=self.launch_state()));save()
  # The shared music adapter binds sprintf to its pinned CRT boundary. The
  # menu output observer executes sprintf directly in this same DLL/CPU.
  self.put(0x447174,0x7817775D)
  for label,start,stop in [('preparation-tail',0x42D6BB,0x42D6ED),('recording',0x42D6ED,0x42D704),('menu-continuation',0x42D704,0x42E0D2)]:
   cases.append(self.launch_step(label,start,stop));save()
  assert self.u32(0x450C34)==0 and self.u32(0x4588A8)==REPLAY and self.u32(0x4588AC)==0
  self.bind_output();returned=self.return_step('own-Start-complete-return',inherited=True,entry_pc=0x42E0D2)
  cases.append(dict(label='returned',returned=returned,after=self.launch_state()));save()
  self.put(0x44717C,self.control_api+6*16)
  cycle=self.cycle_step('own-first-gameplay-entry',gameplay=True)
  cases.append(dict(label='gameplay-entry',cycle=cycle,after=self.launch_state()));save()
  return document()

def accept():
 subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
 fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pending=[]
 for suffix in ('','-control'):
  report=json.loads((ROOT/'build/research'/f'match-launch{suffix}.json').read_bytes())
  raw=(ROOT/'build/original'/report['corpus']).read_bytes()
  assert digest(raw)==report['sha256'] and len(raw)==report['bytes'];doc=json.loads(raw)
  assert [c['label'] for c in doc['cases']]==['prelude','preparation','music','preparation-tail','recording','menu-continuation','returned','gameplay-entry']
  assert doc['cases'][-1]['cycle']['end']['pc']==0x41E339 and not doc['cases'][-1]['cycle']['stimulus']
  assert doc['cases'][2]['music']['kind']=='match' and doc['cases'][2]['music']['inherited'] and not doc['cases'][2]['music']['stimulus']
  refs=[];previous=doc
  for name in ('match-selection','character-screen','menu-cycle','menu-return','mode-screen','menu-startup'):
   r=json.loads((ROOT/'docs/evidence'/f'{name}{suffix}.json').read_bytes());ref=dict(fixture=r['fixture'],sha256=r['fixtureSHA256'])
   assert previous['parent']==ref;refs.append(ref);previous=r
  refs.extend(r['parents'][key] for key in ('menu-loading','menu-loading-state','menu-loading-catalog','menu-loading-sounds'))
  parents=[]
  for ref in refs:
   path=fixtures/ref['fixture'];assert digest(path.read_bytes())==ref['sha256'];parents.append(str(path))
  packed=pack(doc).encode();temporary=ROOT/'build/original'/f'match-launch{suffix}-check.json';temporary.write_bytes(packed)
  result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--match-launch',str(temporary),*parents],capture_output=True,text=True)
  print(result.stdout,end='',flush=True)
  if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
  fixture=fixtures/('original-'+report['corpus'])
  report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed),parent=doc['parent'])
  pending.append((ROOT/'docs/evidence'/f'match-launch{suffix}.json',report,fixture,packed))
 # Neither accepted corpus is replaced until BOTH independent comparisons pass.
 for path,report,fixture,packed in pending:fixture.write_bytes(packed);path.write_text(json.dumps(report,indent=2)+'\n')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:accept();return
 doc=capture_startup(a.control,vm_type=MatchLaunch,after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
 suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'match-launch{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
