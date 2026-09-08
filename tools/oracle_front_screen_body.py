#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh early resources/settings/prefix/panel update ->42712c..4275cb.
Actual401290 GDI request helper,401a30 sound and43f010/43ef70 bitmap children
run on the same CPU/stack. First entry has no restored state. Later caller and
mouse/worker/device inputs are declared controls, not whole screen iterations.
GDI/COM/Sleep/ShellExecute are observed boundaries without external IO. No
pixel/worker/alternate-screen/Windows claim; native comparison still required.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_menu_panel_update import MenuPanelUpdate
from oracle_menu_presentation import MenuPresentation
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,HEAP,SOURCE,VTABLE,BODY_SP,REGISTERS,SIZE
from oracle_front_screen_prelude import PAPI
from oracle_bitmap_drawing import signed,digest,packed
from oracle_state import STOP
from unicorn import UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDI,UC_X86_REG_ESI,UC_X86_REG_ESP,UC_X86_REG_EIP

BAPI,LOCAL_SIZE=STOP+0x4000,0xC0
HELPERS={0x401290:0,0x401A30:4,0x43F010:24,0x43EF70:0}
LITERALS=[(0x4498D8,28),(0x4498B8,31),(0x449204,29)]

class FrontScreenBody(MenuPanelUpdate):
 body_range=(0x42712C,0x4275CB)
 body_stops={0x4275CB:"alternateDispatch"}
 body_helpers=HELPERS
 body_sound_slots={0x455610}
 def body_code_allowed(self,pc):return self.body_range[0]<=pc<self.body_range[1] or 0x401290<=pc<=0x4012FE or 0x401A30<=pc<=0x401A6F or 0x43EF70<=pc<=0x43F2FE
 def __init__(self,control=False):
  self.body_active=False;super().__init__(control)
  first=self.update_step('first-natural-update');assert first['continuation']=='ready'
  # Inventory the original control DIB without executing another parent case.
  source=self.screen_parent['sources'][0];assert source['path']=='MENU_BACK1'
  self.panel_parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,parent=self.screen_parent,initialGlobals=self.update_initial,
   absentOriginalFiles=['data/ad0.txt','data/ad1.txt','sprite/sys/ad0.bmp','sprite/sys/ad1.bmp'],sources=[source],cases=[first])
  self.body_initial=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.local_initial=self.blob(self.uc.mem_read(BODY_SP,LOCAL_SIZE));self.local_mask=bytearray(LOCAL_SIZE)
  self.body_saved=[self.uc.reg_read(r) for r in REGISTERS]
  self.literals=[dict(address=p,bytes=list(self.uc.mem_read(p,n))) for p,n in LITERALS]
  self.links=[dict(address=p,bytes=list(self.cstr(p))) for p in (0x44989C,0x449884,0x44986C,0x4496B4)]
  self.gdi=MenuPresentation.__new__(MenuPresentation);self.gdi.uc=self.uc;self.gdi.presentation_active=True
  self.gdi.presentation_imports={}
  for i,(iat,name) in enumerate([(0x44702C,'setBackgroundColor'),(0x447034,'setTextColor'),(0x447038,'textOut'),(0x447084,'stringLength')]):
   target=BAPI+i*16;self.put(iat,target);self.gdi.presentation_imports[target]=name
  for offset,target in [(0x44,BAPI+0x100),(0x68,BAPI+0x110),(0x48,BAPI+0x120),(0x34,BAPI+0x130),(0x30,BAPI+0x140)]:self.put(VTABLE+offset,target)
  self.put(0x447098,BAPI+0x150);self.put(0x4471B8,BAPI+0x160)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.body_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.body_write,begin=BODY_SP,end=BODY_SP+LOCAL_SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.body_read,begin=HEAP,end=HEAP+0x3FFFFFF)
 def body_event(self,kind,args=(),strings=(),**extra):self.body_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],**extra))
 def local_record(self):return dict(bytes=self.blob(self.uc.mem_read(BODY_SP,LOCAL_SIZE)),defined=self.blob(self.local_mask))
 def body_write(self,uc,access,p,size,value,data):
  if not self.body_active:return
  pc=uc.reg_read(UC_X86_REG_EIP);assert self.body_range[0]<=pc<self.body_range[1],hex(pc)
  if BODY_SP<=p and p+size<=BODY_SP+LOCAL_SIZE:
   self.local_mask[p-BODY_SP:p-BODY_SP+size]=b'\1'*size;self.body_event('writeLocal',[p-BODY_SP,size,value&((1<<(8*size))-1)])
  else:
   assert GLOBAL<=p and p+size<=GLOBAL+GLOBAL_SIZE
   self.body_event('write',[p,size,value&((1<<(8*size))-1)])
 def body_read(self,uc,access,p,size,value,data):
  if not self.body_active or self.body_bitmap is None or not 0x43F010<=uc.reg_read(UC_X86_REG_EIP)<=0x43F2FE:return
  if self.body_bitmap<=p and p+size<=self.body_bitmap+SIZE:
   assert size==4;r,offset=self.locate(p,size);self.body_event('read',read=dict(offset=offset,value=self.u32(p),defined=all(r['mask'][offset:offset+4])))
 def code(self,uc,pc,size,data):
  if not self.body_active:return super().code(uc,pc,size,data)
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  while self.body_pending and pc==self.body_pending[-1]['returnPC']:
   c=self.body_pending.pop();assert sp==c['entrySP']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
   c.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.body_returns.append(c)
   if c['entry']==0x43F010:self.body_bitmap=None
  if self.body_clip and pc==self.body_clip['returnPC']:
   c=self.body_clip;self.body_clip=None
   self.body_event('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['sourcePointers']],
    destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
   assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
  if pc in self.body_stops:
   assert sp==BODY_SP and not self.body_pending and self.body_clip is None;self.body_end=self.body_stops[pc];uc.emu_stop();return
  if pc in (0x401295,0x43F04B,0x43F12B,0x43F2E6):
   register=UC_X86_REG_ESI if pc in (0x401295,0x43F04B) else UC_X86_REG_EAX
   if uc.reg_read(register)==0:
    self.body_end={0x401295:'nullTextTarget',0x43F04B:'nullBitmap',0x43F12B:'nullDrawTarget',0x43F2E6:'nullDrawTarget'}[pc];uc.emu_stop();return
  if pc in self.body_helpers:
   self.body_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=self.body_helpers[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
  if pc==0x401290:
   self.body_event('text',[arg(0),arg(2),arg(3),arg(4),arg(5)],[self.cstr(arg(1))])
  elif pc==0x401A30:
   assert uc.reg_read(UC_X86_REG_ECX) in self.body_sound_slots and arg(0)==0;self.body_event('soundRequest',[0])
  elif pc==0x43F010:
   self.body_bitmap=uc.reg_read(UC_X86_REG_ECX);self.body_event('draw',[self.body_bitmap,*[arg(i) for i in range(6)]])
  elif pc==0x43EF70:
   assert self.body_clip is None
   src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
   self.body_clip=dict(returnPC=self.u32(sp),sourcePointers=src,destinationPointers=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
  elif pc in self.gdi.presentation_imports:self.gdi.presentation_imported(uc,pc,size,data);return
  elif pc in (BAPI+0x100,BAPI+0x110):self.gdi.com('getDC' if pc==BAPI+0x100 else 'releaseDC');return
  elif pc in (BAPI+0x120,BAPI+0x130,BAPI+0x140):
   offset,count={BAPI+0x120:(0x48,1),BAPI+0x130:(0x34,2),BAPI+0x140:(0x30,4)}[pc]
   self.body_event('soundMethod',[arg(0),offset,*[arg(i) for i in range(1,count)]]);self.ret(self.body_input['methodResult'],count*4);return
  elif pc==BAPI+0x150:self.body_event('sleep',[arg(0)]);self.ret(0,4);return
  elif pc==BAPI+0x160:
   self.body_event('shell',[arg(0),arg(3),arg(4),arg(5)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(self.body_input['shellResult'],24);return
  elif pc in (PAPI+32,PAPI+48):
   assert arg(0)==0x4554A4;self.body_event('enter' if pc==PAPI+32 else 'leave',[arg(0)]);self.ret(0,4);return
  elif pc==PAPI:
   assert arg(0)==getattr(self,'body_target',self.u32(BODY_SP+0x20)) and arg(5)==0 # Unmirrored calls have no DDBLTFX.
   self.body_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
    destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=list(uc.mem_read(arg(5),100)) if arg(5) else None))
   result=self.body_input['drawResults'][self.body_blits%len(self.body_input['drawResults'])];self.body_blits+=1;self.ret(result,24);return
  assert self.body_code_allowed(pc),hex(pc)
 def body_step(self,label,writes=(),dc_result=0,method_result=0,draw_results=(0,),shell_result=33):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  self.body_input=dict(dcResult=dc_result,dc=0x12345678,methodResult=method_result,drawResults=list(draw_results),shellResult=shell_result)
  self.body_events=[];self.body_returns=[];self.body_pending=[];self.body_clip=None;self.body_bitmap=None;self.body_end=None;self.body_blits=0
  self.gdi.presentation_input=self.body_input;self.gdi.presentation_events=self.body_events
  if label!='first-screen-body':
   self.uc.reg_write(UC_X86_REG_ESP,BODY_SP)
   for r,v in zip(REGISTERS,self.body_saved):self.uc.reg_write(r,v)
  self.body_active=True
  try:self.uc.emu_start(0x42712C,0,count=100000)
  except Exception:
   print('BODY FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.body_events[-4:],flush=True);raise
  finally:self.body_active=False
  assert self.body_end and self.world_record()==self.old_world
  records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions];assert records==self.old_records
  return dict(label=label,stimulus=stimulus,input=self.body_input,events=self.body_events,helpers=self.body_returns,pending=self.body_pending,continuation=self.body_end,
   endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),local=self.local_record(),world=self.old_world,records=records)
 def capture_body(self):
  def inputs(x=0,y=0,shift=0,status=0,setting=0,held=0,previous=0,sound=0,offset=0):
   return [(0x4546F0,x),(0x453CDC,y),(0x45757C,shift),(0x458424,status),(0x450BE8,setting),(0x457580,held),(0x44D060,previous),
    (0x44EECC,0 if sound==0 else SOURCE),(0x455610,0 if sound<2 else SOURCE+16),(0x453DA4,offset),(0x44D064,0),(0x455608,SOURCE),(0x44D78C,794),(0x44D790,550)]
  cases=[self.body_step('first-screen-body')]
  for shift in (-2147483648,-491,0,23,2147483647):
   base=signed(shift+491)
   for x in (591,592,611,612,685,686,692,693):
    for dy in (0,1,19,20,30,31,59,60,61):cases.append(self.body_step(f'hover-{shift}-{x}-{dy}',inputs(x=x,y=signed(base+dy),shift=shift)))
  for status in (-2147483648,-1,0,1,2,3,2147483647):
   for setting in (-1,0,1,2):
    for x,y in ((724,17),(725,17),(725,18),(2147483647,-2147483648)):
     cases.append(self.body_step(f'button-{status}-{setting}-{x}-{y}',inputs(x=x,y=y,status=status,setting=setting,held=1,sound=2),method_result=-1))
  for x,y in ((612,492),(693,492),(592,522),(725,17)):
   for previous,held in ((0,0),(0,1),(0,2),(1,1)):
    for sound in (0,1,2):cases.append(self.body_step(f'click-{x}-{y}-{previous}-{held}-{sound}',inputs(x=x,y=y,previous=previous,held=held,sound=sound)))
  for dc in (-2147483648,-1,0,1,2147483647):
   for x,y in ((0,0),(612,492),(592,522)):cases.append(self.body_step(f'dc-{dc}-{x}-{y}',inputs(x=x,y=y,held=1,sound=2),dc_result=dc,method_result=-1,shell_result=0))
  for offset in (-2147483648,-600,-97,-96,-95,0,453,454,455,2147483647):
   for viewport in ((794,550),(0,0),(-1,-1)):
    cases.append(self.body_step(f'geometry-{offset}-{viewport}',inputs(offset=offset)+[(0x44D78C,viewport[0]),(0x44D790,viewport[1])],draw_results=(-1,1)))
  for i in range(4):cases.append(self.body_step(f'held-sequence-{i}',inputs(x=725,y=17,held=1) if i==0 else ()))
  cases.append(self.body_step('null-text-target',inputs()+[(0x455608,0)]))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.panel_parent,initialGlobals=self.body_initial,
   localAddress=BODY_SP,localBacking=self.local_initial,literals=self.literals,links=self.links,cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   candidate=ROOT/'build/research'/f'front-screen-body{suffix}.json';report=json.loads(candidate.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-screen-body{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-screen-body',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data))
   pending.append((ROOT/'docs/evidence'/candidate.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=FrontScreenBody(a.control).capture_body();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
 path=ROOT/'build/original'/f'front-screen-body{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  events=sum(len(c['events']) for c in doc['cases']),helpers=sum(len(c['helpers']) for c in doc['cases']),nativeCompared=False)
 (ROOT/'build/research'/f'front-screen-body{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
