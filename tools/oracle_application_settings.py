#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own WinMain/loop/front resources -> whole423480 settings on the same CPU/stack.
Pinned NTSD EXE/VC80/control.txt, Unicorn2.1.4. Actual fscanf/fgets/feof and
ordinary cookie/SEH instructions execute; fopen/fclose, translated _read and
thread services stay declared. Trace private scratch provenance, full states,
ordered calls/stores and missing-FILE boundary. No scratch injection, CRT reset,
control/protection corruption, bypass, original file writes or Windows claim.
Research only; APPLICATION_SETTINGS_PLAN.md. Whole dispatcher remains pending.
"""
import argparse,json,os,struct
from pathlib import Path
from unicorn.x86_const import *
from oracle_bitmap_surface_loading import BitmapSurface,specs as bitmap_specs,TRACE_STACK,TRACE_SIZE,REGS
from oracle_application_dispatch_entry import BASE,FULL_SIZE,STACK
from oracle_settings_loading import OPEN,CLOSE,SCAN,GETS,EOF
from oracle_crt import CRT,FILE,INPUT,DLL_SHA256
from oracle_bitmap_drawing import digest
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
BODY_SP=0x1000ea74
ENTRY_SP=BODY_SP-4
SCRATCH=ENTRY_SP-0x1f8
SCRATCH_SIZE=0x1f4

def key(value):return digest(json.dumps(value,sort_keys=True,separators=(',',':')).encode())
class ApplicationSettings(BitmapSurface):
 def __init__(self):self.settings_active=False;super().__init__()
 def boundary(self,u,pc,n,data):
  if not self.settings_active:return super().boundary(u,pc,n,data)
  if pc in (OPEN,CLOSE):return
  if self.boundaries.get(pc)=='_read':
   sp=u.reg_read(UC_X86_REG_ESP);assert self.u32(sp+4)==0xffffffff and self.u32(sp+8)==INPUT
   count=self.u32(sp+12);raw=self.data[self.read_position:self.read_position+min(count,self.chunk)];self.read_position+=len(raw)
   self.io.append(dict(pc=pc,returnPC=self.u32(sp),before=self.read_position-len(raw),count=count,result=len(raw),bytes=raw.hex(),eventIndex=len(self.events)))
   self.write_host(INPUT,raw);self.ret(len(raw));return
  return CRT.boundary(self,u,pc,n,data)
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.settings_active:return
  pc=u.reg_read(UC_X86_REG_EIP);raw=(v&((1<<(n*8))-1)).to_bytes(n,'little');self.settings_stores.append(dict(pc=pc,address=p,bytes=raw.hex(),eventIndex=len(self.events)))
  if BASE<=p<p+n<=BASE+FULL_SIZE:self.settings_mask[p-BASE:p-BASE+n]=b'\1'*n
  if SCRATCH<=p<p+n<=SCRATCH+SCRATCH_SIZE:self.scratch_mask[p-SCRATCH:p-SCRATCH+n]=b'\1'*n
  if BASE<=p<p+n<=BASE+FULL_SIZE and (0x423480<=pc<0x4236ca or pc==0x427092):
   self.events.append(dict(kind='write',arguments=[p,n,v&((1<<(n*8))-1)]))
 def observe_stack_read(self,u,access,p,n,v,data):
  super().observe_stack_read(u,access,p,n,v,data)
  if self.settings_active and SCRATCH<=p<p+n<=SCRATCH+SCRATCH_SIZE:
   self.scratch_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex(),written=list(self.scratch_mask[p-SCRATCH:p-SCRATCH+n]),parentKnown=list(self.stack_known[p-STACK:p-STACK+n]),storeCount=len(self.settings_stores),eventIndex=len(self.events)))
 def position(self):return self.read_position-self.u32(FILE+4)
 def eof_value(self):return bool(self.u32(FILE+12)&16)
 def settings_state(self):
  return dict(globals=self.blob(self.uc.mem_read(BASE,FULL_SIZE)),mask=self.blob(self.settings_mask),scratch=self.blob(self.uc.mem_read(SCRATCH,SCRATCH_SIZE)),scratchMask=self.blob(self.scratch_mask),stack=self.blob(self.uc.mem_read(TRACE_STACK,TRACE_SIZE)),knownStack=self.blob(self.stack_known[TRACE_STACK-STACK:TRACE_STACK-STACK+TRACE_SIZE]),pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),cw=self.uc.reg_read(UC_X86_REG_FPCW),seh=self.u32(0),registers=[self.uc.reg_read(r) for r in REGS],storeCount=len(self.settings_stores))
 def code(self,u,pc,n,data):
  if not self.settings_active:return super().code(u,pc,n,data)
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.settings_pending and pc==self.settings_pending['returnPC']:
   e=self.settings_pending;self.settings_pending=None
   assert sp==e['entrySP']+4 and [u.reg_read(r) for r in REGS]==e['saved']
   e.update(result=u.reg_read(UC_X86_REG_EAX),position=self.position(),eof=self.eof_value(),state=self.settings_state());self.events.append(e)
  if pc==0x42709b:
   assert sp==BODY_SP and self.closed and self.settings_pending is None;self.settings_end='ready';u.emu_stop();return
  if pc==0x4234db and not self.present:
   assert sp==ENTRY_SP-0x21c;self.settings_end='nullFile';u.emu_stop();return
  if pc==OPEN:
   assert self.cstr(arg(0))==b'data\\control.txt' and self.cstr(arg(1))==b'r'
   self.events.append(dict(kind='open',arguments=[FILE if self.present else 0],strings=['data\\control.txt','r'],state=self.settings_state()))
   self.write_host(FILE,struct.pack('<8I',INPUT,0,INPUT,9,0xffffffff,0,0x10000,0));self.ret(FILE if self.present else 0);return
  if pc==CLOSE:
   assert arg(0)==FILE and self.present and not self.closed
   self.closed=True;self.events.append(dict(kind='close',arguments=[FILE,self.close_result&0xffffffff],state=self.settings_state()));self.ret(self.close_result);return
  if pc in self.boundaries:return
  assert 0x423480<=pc<0x4236ca or 0x427089<=pc<0x42709b or 0x4450b2<=pc<=0x4450ba or 0x78130000<=pc<0x781c0000,hex(pc)
  self.original(u,pc,n)
  if pc==0x423480:
   assert sp==ENTRY_SP and self.u32(sp)==0x42708e;self.helper_saved=[u.reg_read(r) for r in REGS]
  if pc==0x42708e:
   assert sp==BODY_SP and [u.reg_read(r) for r in REGS]==self.helper_saved
   self.events.append(dict(kind='settingsReturn',arguments=[],result=u.reg_read(UC_X86_REG_EAX),state=self.settings_state()))
  if pc in (SCAN,GETS,EOF):
   assert self.settings_pending is None and self.present and not self.closed
   e=dict(kind={SCAN:'scan',GETS:'gets',EOF:'eof'}[pc],before=self.position(),returnPC=self.u32(sp),entrySP=sp,saved=[u.reg_read(r) for r in REGS])
   if pc==SCAN:
    assert arg(0)==FILE;fmt=self.cstr(arg(1)).decode();assert fmt in ('%d','%s %s %s %s\n','%d\n');e.update(format=fmt,arguments=[arg(2+i) for i in range(4 if fmt.startswith('%s') else 1)])
   elif pc==GETS:
    assert arg(1)==100 and arg(2)==FILE and arg(0) in (0x44fd18,0x44f890,SCRATCH);e['arguments']=[arg(0),100]
   else:assert arg(0)==FILE;e['arguments']=[]
   self.settings_pending=e
 def run_settings(self,s,data):
  b=super().run(s['resource']);assert b['end']=='settings' and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
  parent=json.loads(json.dumps(b));parent_key=key(parent)
  # Existing CRT/PTD and stack are retained. Only future declared fopen/scan
  # imports are rebound; no CRT image, private stack or game data is restored.
  for p,v in [(0x447190,OPEN),(0x447184,CLOSE),(0x447188,SCAN),(0x44719c,GETS),(0x44718c,EOF)]:self.uc.mem_write(p,struct.pack('<I',v))
  self.data=data;self.chunk=s.get('chunk',4096);self.read_position=0;self.present=s.get('present',True);self.close_result=s.get('close',0);self.closed=False;self.settings_pending=None;self.settings_end=None
  self.events=[];self.settings_stores=[];self.scratch_reads=[];self.io=[];self.settings_mask=bytearray(FULL_SIZE);self.scratch_mask=bytearray(SCRATCH_SIZE);self.stack_stores=[];self.stores=[];self.call_pcs={};self.global_stores=[];self.global_mask=bytearray(0xb440)
  before=self.settings_state();crt_before=self.snapshot();self.active=self.settings_active=True;self.phase='applicationSettings'
  try:self.uc.emu_start(0x427089,0,count=5_000_000)
  except Exception as e:
   self.capture_path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,state=self.settings_state(),events=self.events,stores=self.settings_stores,reads=self.scratch_reads,io=self.io,instructions=self.call_pcs,blobs=self.blobs),separators=(',',':'))+'\n');raise
  finally:self.active=self.settings_active=False
  assert self.settings_end is not None and self.settings_pending is None
  for r in parent['records']:assert self.blob(self.uc.mem_read(r['address'],0x1f50))==r['bytes']
  assert bytes(self.uc.mem_read(0x458b00,0x7d8))==bytes(0x7d8)
  return parent_key,parent,dict(spec=s,parent=parent_key,input=self.blob(data),before=before,after=self.settings_state(),crtBefore=crt_before,crtAfter=self.snapshot(),events=self.events,stores=self.settings_stores,stackStores=self.stack_stores,crtStores=self.stores,reads=self.scratch_reads,io=self.io,instructions=self.call_pcs,end=self.settings_end)

def specs():
 raw=(DEFAULT_SOURCE/'data/control.txt').read_bytes();logical=raw.replace(b'\r\n',b'\n');prefix=logical[:logical.index(b'<No name>')]
 for i,s in enumerate(s for s in bitmap_specs() if s['kind']=='own' and s.get('nulls')!=[1]):yield dict(label=f'own-resource-{i}',resource=s),logical
 for label,data,options in [('raw',raw,{}),('chunk1',logical,dict(chunk=1)),('chunk7',logical,dict(chunk=7)),('trailing-lf',logical+b'\n',{}),('empty',b'',{}),('profile-tail-absent',prefix+b'name\nemail',{}),('info99',prefix+b'name\nemail\n'+b'i'*99,{}),('info198',prefix+b'name\nemail\n'+b'i'*198,{}),('backtick',logical.replace(b'1 2 3 4\n',b'one`a two``b ```four `\n'),{}),('missing-file',logical,dict(present=False)),('close-negative',logical,dict(close=-1))]:
  yield dict(label=label,resource=dict(kind='own',windowParam=0),**options),data
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--limit',type=int);p.add_argument('--offset',type=int,default=0);a=p.parse_args();assert not a.output.exists();parts=a.output.with_suffix('.parts');parts.mkdir();parents={};cases=[];blobs={};assets={}
 for i,(s,data) in enumerate(list(specs())[a.offset:]):
  if a.limit is not None and i>=a.limit:break
  vm=ApplicationSettings();vm.capture_path=a.output;h,parent,c=vm.run_settings(s,data);parents[h]=parent;cases.append(c);blobs.update(vm.blobs);assets.update(vm.assets)
  out=parts/f'{i:04d}.json';temp=out.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,parent=parent,blobs=vm.blobs,assets=vm.assets),separators=(',',':'))+'\n');os.replace(temp,out);print('completed',i,s['label'],c['end'],len(c['events']),len(c['reads']),flush=True)
 raw=(DEFAULT_SOURCE/'data/control.txt').read_bytes();d=dict(scope=__doc__,exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,source=dict(path='data/control.txt',raw=vm.blob(raw),logical=vm.blob(raw.replace(b'\r\n',b'\n'))),cases=cases,parents=parents,blobs={**blobs,**vm.blobs},assets=assets,scratchAddress=SCRATCH,scratchCount=SCRATCH_SIZE,stackAddress=TRACE_STACK,stackCount=TRACE_SIZE,nativeCompared=False,windowsVerified=False)
 data=(json.dumps(d,separators=(',',':'))+'\n').encode();a.output.write_bytes(data);print(dict(cases=len(cases),parents=len(parents),bytes=len(data),sha256=digest(data)),flush=True)
