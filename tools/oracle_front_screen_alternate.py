#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh World/resources/settings/screen body ->4275cb..42790f.
Actual bitmap/clip/sound/fill/worker-gate and423230/VC80 writer children share
the original CPU/stack. First EAX/caller is natural; subsequent selector,
mouse/timer/worker/device/FILE inputs are explicit controls. Stops before
main menu427915, other selectors427ca7, presentation42873e or invalid access.
No pixels, worker execution, actual file writes, whole screen loop or Windows.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256,FILE,INPUT,PTD,STACK,STOP
from oracle_front_screen_body import FrontScreenBody,HELPERS,LOCAL_SIZE
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,SOURCE,BODY_SP,REGISTERS
from oracle_front_screen_prelude import PAPI
from oracle_settings_writing import SettingsWriting
from oracle_menu_info_writing import FCLOSE
from oracle_bitmap_drawing import digest,packed,signed
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

class FrontScreenAlternate(FrontScreenBody):
 def __init__(self,control=False):
  self.alt_active=False;super().__init__(control)
  first=self.body_step('first-screen-body');assert first['continuation']=='alternateDispatch'
  self.body_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,parent=self.panel_parent,initialGlobals=self.body_initial,
   localAddress=BODY_SP,localBacking=self.local_initial,literals=self.literals,links=self.links,cases=[first])
  self.alt_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.alt_local=self.local_record();self.alt_saved=[self.uc.reg_read(r) for r in REGISTERS]
  self.body_range=(0x4275CB,0x427915);self.body_stops={0x427915:'mainMenu',0x427CA7:'otherSelector',0x42873E:'presentation'}
  self.body_helpers=HELPERS|{0x423230:0,0x4237E0:0,0x43C450:0,0x415160:0};self.body_sound_slots={0x455610,0x455614}
  self.settings_writer=SettingsWriting.__new__(SettingsWriting)
  w=self.settings_writer;w.uc=self.uc;w.blobs=self.blobs;w.control=control;w.active=False
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.alt_write,begin=STACK,end=STACK+0xFFFF)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,w.changed,begin=INPUT,end=INPUT+4095)
 def body_code_allowed(self,pc):
  return super().body_code_allowed(pc) or (self.alt_active and (0x4237E0<=pc<=0x42383F or 0x43C450<=pc<=0x43C495 or 0x415160<=pc<=0x4151C2 or pc==0x423230))
 def body_write(self,uc,access,p,size,value,data):
  if self.alt_active and self.settings_writer.active:
   assert GLOBAL<=p and p+size<=GLOBAL+GLOBAL_SIZE;self.settings_writer.changed(uc,access,p,size,value,data);return
  super().body_write(uc,access,p,size,value,data)
 def alt_write(self,uc,access,p,size,value,data):
  if self.alt_active and self.fill is not None and self.fill['address']<=p and p+size<=self.fill['address']+100 and 0x415160<=uc.reg_read(UC_X86_REG_EIP)<=0x4151C2:
   self.fill['mask'][p-self.fill['address']:p-self.fill['address']+size]=[True]*size
 def begin_settings(self,sp):
  w=self.settings_writer;c=dict(self.writer_input);self.settings_call=c
  c.update(entrySP=sp,returnPC=self.u32(sp),saved=[self.uc.reg_read(r) for r in REGISTERS])
  w.capacity=c['capacity'];w.available=c['available'];w.write_mode=c['writeMode'];w.fail_at=c['failAt'];w.close_result=c['closeResult'];w.write_index=0
  backing=self.backing(w.capacity);c['backing']=self.blob(backing);w.mask=bytearray(w.capacity);self.uc.mem_write(INPUT,backing)
  self.uc.mem_write(FILE,struct.pack('<8I',INPUT,w.capacity,INPUT,0x102,0xFFFFFFFF,0,w.capacity,0));self.put(PTD+8,0)
  w.events=[];w.pending=None;w.end='returned';w.active=True;self.body_event('call',[0x423230])
 def finish_settings(self,completed):
  w=self.settings_writer;c=self.settings_call;assert w.pending is None
  c.update(completed=completed,continuation=w.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),
   result=self.uc.reg_read(UC_X86_REG_EAX) if completed else None,events=w.events,**w.snapshot())
  if completed:
   assert c['endSP']==c['entrySP']+4 and c['saved']==[self.uc.reg_read(r) for r in REGISTERS];self.body_event('return',[0x423230,c['result']])
  self.settings_calls.append(c);self.settings_call=None;w.active=False
 def code(self,uc,pc,size,data):
  if not self.alt_active:return super().code(uc,pc,size,data)
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if self.settings_writer.active:
   if pc==self.settings_call['returnPC']:self.finish_settings(True)
   else:
    if pc==STOP+0x50:uc.reg_write(UC_X86_REG_EIP,FCLOSE);return
    self.settings_writer.code(uc,pc,size,data);return
  if pc==0x415160:
   self.fill=dict(address=sp-100,backing=self.blob(uc.mem_read(sp-100,100)),mask=[False]*100);self.fills.append(self.fill)
   self.body_event('fillRequest',[self.u32(0x455608),*[arg(i) for i in range(5)]])
  if pc==0x4151B6 and uc.reg_read(UC_X86_REG_EAX)==0:self.body_end='nullFillTarget';uc.emu_stop();return
  if pc==PAPI and self.u32(sp)==0x4151BF:
   assert arg(2)==arg(3)==0 and arg(4)==0x1000400 and arg(5)==self.fill['address']
   self.body_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),
    effects=list(uc.mem_read(arg(5),100)),defined=self.fill['mask'].copy()));self.ret(self.alt_input['fillResult'],24);return
  if pc==PAPI+16:
   assert self.timer_index<len(self.alt_input['timers']);n=self.alt_input['timers'][self.timer_index];self.timer_index+=1
   self.body_event('timer',[n]);self.ret(n);return
  if pc==PAPI+64:
   assert [arg(i) for i in range(5)]==[0,0,0x43C240,0,0] and arg(5)==BODY_SP-8
   self.put(arg(5),self.alt_input['threadID']);self.body_event('createThread',[*[arg(i) for i in range(5)],self.alt_input['threadHandle'],self.alt_input['threadID']]);self.ret(self.alt_input['threadHandle'],24);return
  if pc==PAPI+80:self.body_event('lastError',[self.alt_input['lastError']]);self.ret(self.alt_input['lastError']);return
  super().code(uc,pc,size,data)
  if pc==0x423230:self.begin_settings(sp)
 def alternate_step(self,label,writes=(),selector=None,timers=(100,100,100),method_result=0,draw_results=(0,),fill_result=0,thread=0x12345678,thread_id=0xABCD,error=5,
  capacity=64,available=True,action='full',fail_at=-1,close=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  if selector is not None:
   self.uc.reg_write(UC_X86_REG_ESP,BODY_SP)
   for r,v in zip(REGISTERS,self.alt_saved):self.uc.reg_write(r,v)
   self.uc.reg_write(UC_X86_REG_EAX,selector&0xFFFFFFFF)
  assert self.uc.reg_read(UC_X86_REG_EBX)==0 and self.uc.reg_read(UC_X86_REG_EDI)==self.u32(BODY_SP+0x20)
  self.alt_input=dict(selector=signed(self.uc.reg_read(UC_X86_REG_EAX)),drawTarget=self.uc.reg_read(UC_X86_REG_EDI),timers=list(timers),methodResult=method_result,
   drawResults=list(draw_results),fillResult=fill_result,threadHandle=thread,threadID=thread_id,lastError=error)
  self.writer_input=dict(capacity=capacity,available=available,writeMode=action,failAt=fail_at,closeResult=close)
  self.body_input=self.alt_input;self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_end=None;self.body_blits=0
  self.settings_call=None;self.settings_calls=[];self.fills=[];self.fill=None;self.timer_index=0
  self.body_active=True;self.alt_active=True
  try:self.uc.emu_start(0x4275CB,0,count=10_000_000)
  except Exception:
   print('ALTERNATE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.body_events[-3:],flush=True);raise
  finally:self.body_active=False;self.alt_active=False
  if self.settings_writer.active:
   self.body_end={'nullFile':'nullSettingsFile','unterminatedName':'unterminatedSettingsName'}[self.settings_writer.end];self.finish_settings(False)
  assert self.body_end and self.world_record()==self.old_world
  records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions];assert records==self.old_records
  return dict(label=label,stimulus=stimulus,input=self.alt_input,events=self.body_events,helpers=self.body_returns,pending=self.body_pending,settings=self.settings_calls,
   fills=[dict(backing=f['backing'],address=f['address']) for f in self.fills],continuation=self.body_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),
   globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),local=self.local_record(),world=self.old_world,records=records)
 def capture_alternate(self):
  def inputs(selector=-3,x=0,y=0,offset=0,held=0,previous=0,sound=2):
   return [(0x44D064,selector),(0x4546F0,x),(0x453CDC,y),(0x4511F4,offset),(0x457580,held),(0x44D060,previous),
    (0x44EECC,0 if sound==0 else SOURCE),(0x455610,0 if sound<2 else SOURCE+16),(0x455614,0 if sound<2 else SOURCE+32),
    (0x455608,SOURCE),(0x44D78C,794),(0x44D790,550)]
  cases=[self.alternate_step('first-natural-dispatch')]
  for selector in (-2147483648,-2,0,1,6,7,2147483647):cases.append(self.alternate_step(f'dispatch-{selector}',inputs(selector),selector=selector))
  for selector,stored in ((-3,0),(-1,-3),(0,-3),(1,0)):
   cases.append(self.alternate_step(f'caller-selector-{selector}-{stored}',inputs(stored)+[(0x4511F0,1),(0x4511E8,0),(0x4511EC,100)],selector=selector))
  for offset in (-2147483648,-600,-91,-90,-89,-17,-1,0,1,96,2147483647):
   cases.append(self.alternate_step(f'animation-{offset}',inputs(offset=offset),selector=-3,draw_results=(-1,1)))
  for i in range(40):cases.append(self.alternate_step(f'expand-sequence-{i}',inputs(x=203,y=337,held=1) if i==0 else (),selector=-3))
  for offset in (-17,-90):
   y=offset+signed(((-715827883*signed(offset+90))>>32))
   if ((-715827883*signed(offset+90))>>32)<0:y+=1
   for x in (209,465):cases.append(self.alternate_step(f'animated-choice-{offset}-{x}',inputs(x=x,y=y+175,offset=offset,held=1),selector=-3))
  for x in (202,203,208,209,442,443,464,465,552,553,561,562):
   for dy in (174,175,202,203,240,241,261,262):cases.append(self.alternate_step(f'hover-{x}-{dy}',inputs(x=x,y=96+dy),selector=-3))
  for x,y in ((209,271),(465,271),(203,337),(331,320)):
   for held,previous in ((0,0),(1,0),(2,0),(1,1)):
    for sound in (0,1,2):
     selector=-1 if y==320 else -3
     cases.append(self.alternate_step(f'click-{x}-{held}-{previous}-{sound}',inputs(selector,x,y,held=held,previous=previous,sound=sound)+[(0x4511F0,1),(0x4511E8,0),(0x4511EC,100)],selector=selector,method_result=-1))
  for label,left,right,gate in [('sentinel',b'z\0',b'a\0',-99),('now',b'now\0',b'a\0',0),('equal',b'ab\0',b'ab\0',0),('less',b'\x7f\0',b'\x80\0',0),('greater',b'\xff\0',b'\x80\0',0)]:
   for status in (-1,0,1,2):
    for thread in (0,0x87654321):cases.append(self.alternate_step(f'worker-{label}-{status}-{thread}',inputs(x=209,y=271,held=1)+[(0x44D788,gate),(0x4527B0,left),(0x451D48,right),(0x458424,status)],selector=-3,thread=thread))
  for x in (209,465):
   for capacity in (1,7,64,4096):
    for action in ('error','zero','short'):cases.append(self.alternate_step(f'writer-{x}-{capacity}-{action}',inputs(x=x,y=271,held=1),selector=-3,capacity=capacity,action=action,fail_at=1,close=-1))
    cases.append(self.alternate_step(f'null-file-{x}-{capacity}',inputs(x=x,y=271,held=1),selector=-3,capacity=capacity,available=False))
  for flags in (0,1,2,0xFFFFFFFE,0xFFFFFFFF):
   for delta in (0,149,150,151,0x7FFFFFFF,0xFFFFFFFF):
    for count in (-2147483648,-15,-1,0,13,14,2147483647):
     if count==2147483647 and delta<=150:continue
     cases.append(self.alternate_step(f'timer-{flags}-{delta}-{count}',inputs(-1)+[(0x4511F0,flags),(0x4511EC,100),(0x4511E8,count),(0x4511E4,0xFFFFFFFF)],selector=-1,timers=(100,100+delta & 0xFFFFFFFF,37) if flags&1==0 else (100+delta & 0xFFFFFFFF,37)))
  for i in range(32):cases.append(self.alternate_step(f'wait-sequence-{i}',inputs(-1)+[(0x4511F0,0),(0x4511E8,0)] if i==0 else (),selector=-1,timers=(100+i*151,100+i*151,100+i*151)))
  for x in (330,331,481,482):
   for y in (319,320,345,346):cases.append(self.alternate_step(f'cancel-{x}-{y}',inputs(-1,x,y,held=1)+[(0x4511F0,1),(0x4511E8,3),(0x4511EC,100)],selector=-1))
  for selector,slot in ((-3,0x4511A0),(-3,0x451188),(-1,0x45117C)):
   old=self.u32(slot);cases.append(self.alternate_step(f'null-bitmap-{slot:x}',inputs(selector)+[(slot,0)],selector=selector))
   # Restoration is an explicit next stimulus, not a hidden native input.
   cases.append(self.alternate_step(f'restore-bitmap-{slot:x}',[(slot,old)],selector=selector))
  cases.append(self.alternate_step('null-fill',inputs(-1)+[(0x455608,0),(0x4511F0,1),(0x4511E8,1),(0x4511EC,100)],selector=-1))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.body_parent,initialGlobals=self.alt_initial,initialLocal=self.alt_local,cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   candidate=ROOT/'build/research'/f'front-screen-alternate{suffix}.json';report=json.loads(candidate.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-screen-alternate{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-screen-alternate',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((ROOT/'docs/evidence'/candidate.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=FrontScreenAlternate(a.control).capture_alternate();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-screen-alternate{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),settings=sum(len(c['settings']) for c in doc['cases']),
  events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in sorted({e['kind'] for c in doc['cases'] for e in c['events']})},continuations={k:sum(c['continuation']==k for c in doc['cases']) for k in sorted({c['continuation'] for c in doc['cases']})},nativeCompared=False)
 (ROOT/'build/research'/f'front-screen-alternate{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
