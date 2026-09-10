#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole43cf94..43cfb4 startup reader/content/panel/default selection.

Pinned EXE/VC80 in one Unicorn2.1.4 CPU/stack; real calls/returns, shared local
provenance and owned bitmap generations. Translated file IO, allocator, original
MENU_BACK1 DIB/COM and output FILE are controlled boundaries. No network/file
mutation, control corruption, full WinMain/Windows/app claim. Unknown locals are
retained as source evidence and separate native rejection boundaries. No source
after-state is injected. See STARTUP_PANEL_PLAN.md; development tooling only.
"""
import argparse,json,os,struct
from pathlib import Path
from oracle_crt import CRT,FILE,INPUT,PTD,STACK,STOP,DLL_SHA256
from oracle_menu_info_reading import MenuInfoReading,LOCAL as INFO_LOCAL,LOCAL_SIZE as INFO_SIZE,OPEN,CLOSE,FSCAN,SCAN,SPRINT,SAVED,REGISTERS
from oracle_menu_content import MenuContent,LOCAL as CONTENT_LOCAL,LOCAL_SIZE as CONTENT_SIZE,GETS
from oracle_menu_info_writing import MenuInfoWriting,FPRINT,FCLOSE,GETPTD,WRITE,CLOSE as CLOSE_FILE,ISATTY
from oracle_menu_panel_bitmap import MenuPanelBitmap,HEAP,SIZE as BITMAP_SIZE,SOURCE,VTABLE,API
from oracle_bitmap_drawing import digest,packed,signed
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,SIZE,SP=0x44d000,0xb440,STACK+0xf004
ENTRIES={0x43c4a0:'info',0x43c780:'content',0x43cc60:'bitmap',0x43c690:'defaults'}

class StartupPanel(CRT):
 def __init__(self,ramp=False):
  self.running=False;super().__init__();self.ramp=ramp;self.blobs={};self.all_pcs={};self.sources={}
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256;self.pe=PE(raw)
  self.uc.mem_map(0x400000,0x100000)
  for s in self.pe.sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  self.uc.mem_map(0x22000000,0x10000);self.uc.mem_map(HEAP,0x200000)
  for p,v in [(0x447190,OPEN),(0x447184,CLOSE),(0x447188,FSCAN),(0x447158,SCAN),(0x447174,SPRINT),(0x44719c,GETS),(0x447180,FPRINT),(0x44717c,API+64),(0x4471c8,API+32),(0x447080,API+48)]:self.put(p,v)
  for i in range(10):self.put(SOURCE+16*i,VTABLE)
  self.put(VTABLE+0x74,API);self.put(VTABLE+8,API+16);self.put(0x457578,SOURCE);self.put(0,0xffffffff)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  for a,b in [(BASE,BASE+SIZE-1),(STACK,STACK+0xffff),(HEAP,HEAP+0x1fffff),(INPUT,INPUT+4095)]:self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=a,end=b)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_local,begin=STACK,end=STACK+0xffff)
  self.info=MenuInfoReading.__new__(MenuInfoReading);self.content=MenuContent.__new__(MenuContent);self.panel=MenuPanelBitmap.__new__(MenuPanelBitmap);self.writer=MenuInfoWriting.__new__(MenuInfoWriting)
  for child in (self.info,self.content,self.panel,self.writer):child.uc=self.uc;child.blobs=self.blobs;child.active=False;child.control=ramp;child.boundaries=self.boundaries
  self.info.all_pcs={};self.panel.regions=[];self.panel.next_address=0;self.panel.heap_base=HEAP;self.panel.device=SOURCE
  self.initial_globals=self.blob(self.uc.mem_read(BASE,SIZE))
  desc=next(s for s in self.pe.resources() if s['path']==[2,'MENU_BACK1',1028]);dib=raw[desc['fileOffset']:desc['fileOffset']+desc['size']];w,h=struct.unpack_from('<ii',dib,4)
  self.dib=dict(path='MENU_BACK1',width=w,height=h,dib=self.blob(dib))
 def blob(self,b):
  b=bytes(b);h=digest(b)
  if h not in self.blobs:self.blobs[h]=packed(b)
  return h
 def cstr(self,p):
  out=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':out.extend(self.uc.mem_read(p,1));p+=1;assert len(out)<2000
  return bytes(out)
 def changed(self,u,access,p,n,v,data):
  if not self.running:return
  c=self.current;kind=c['kind'] if c else None
  if BASE<=p<p+n<=BASE+SIZE:
   self.global_mask[p-BASE:p-BASE+n]=b'\1'*n
   self.stores.append(dict(child=len(self.children),eventIndex=len(self.child_object.events) if c else 0,address=p,bytes=(v&((1<<(8*n))-1)).to_bytes(n,'little').hex(),pc=u.reg_read(UC_X86_REG_EIP)))
  if CONTENT_LOCAL<=p<p+n<=CONTENT_LOCAL+CONTENT_SIZE:
   self.stack_mask[p-STACK:p-STACK+n]=b'\1'*n
   self.stack_writes.append(dict(child=len(self.children),address=p,bytes=(v&((1<<(8*n))-1)).to_bytes(n,'little').hex(),pc=u.reg_read(UC_X86_REG_EIP)))
  if kind=='info' and (BASE<=p<p+n<=BASE+SIZE or INFO_LOCAL<=p<p+n<=INFO_LOCAL+INFO_SIZE):self.info.changed(u,access,p,n,v,data)
  elif kind=='content' and (BASE<=p<p+n<=BASE+SIZE or CONTENT_LOCAL<=p<p+n<=CONTENT_LOCAL+CONTENT_SIZE):self.content.changed(u,access,p,n,v,data)
  elif kind=='bitmap' and (BASE<=p<p+n<=BASE+SIZE or HEAP<=p<HEAP+0x200000):self.panel.written(u,access,p,n,v,data)
  elif kind=='defaults' and (BASE<=p<p+n<=BASE+SIZE or INPUT<=p<p+n<=INPUT+self.writer.capacity):self.writer.changed(u,access,p,n,v,data)
 def read_local(self,u,access,p,n,v,data):
  if self.running and self.current and self.current['kind']=='info' and INFO_LOCAL<=p<p+n<=INFO_LOCAL+INFO_SIZE:
   self.info.read_local(u,access,p,n,v,data)
   if self.info.unknown and self.own_boundary is None:self.own_boundary=dict(kind='info',child=len(self.children),**self.info.unknown)
 def boundary(self,u,pc,n,data):
  if self.running and self.current:
   if self.current['kind']=='bitmap' and API<=pc<=API+64:return
   if self.boundaries[pc]=='_read':
    sp=u.reg_read(UC_X86_REG_ESP);assert self.u32(sp+4)==0xffffffff and self.u32(sp+8)==INPUT
    count=self.u32(sp+12);index=self.read_index;self.read_index+=1
    if index==self.read_fail_at:self.put(PTD+8,5);value=b'';result=-1
    else:value=self.data[self.read_position:self.read_position+min(count,self.chunk)];self.read_position+=len(value);result=len(value);u.mem_write(INPUT,value)
    self.current['io'].append(dict(position=self.read_position,count=count,result=result,bytes=value.hex()));self.ret(result);return
  super().boundary(u,pc,n,data)
 def begin(self,entry,sp):
  assert sp==SP-4
  kind=ENTRIES[entry];self.current=dict(kind=kind,entry=entry,entrySP=sp,returnPC=self.u32(sp),saved=[self.uc.reg_read(r) for r in REGISTERS],beforeGlobals=self.blob(self.uc.mem_read(BASE,SIZE)),io=[])
  self.parent_events.append(dict(kind='call',arguments=[entry]));s=self.spec
  if kind in ('info','content'):
   self.data=bytes(s['info' if kind=='info' else 'content'] or []);self.chunk=s['chunk'];self.read_position=0;self.read_index=0;self.read_fail_at=s['infoReadFailAt'] if kind=='info' else -1
  if kind=='info':
   r=self.info;r.spec=dict(close=s['infoClose']);r.present=s['info'] is not None;r.pending=None;r.events=[];r.stores=[];r.reads=[];r.unknown=None;r.pcs={};r.global_mask=bytearray(SIZE);r.local_mask=bytearray(INFO_SIZE)
   self.current.update(localAddress=INFO_LOCAL,backing=self.blob(self.uc.mem_read(INFO_LOCAL,INFO_SIZE)),initialLocalMask=self.blob(r.local_mask));self.child_object=r
  elif kind=='content':
   r=self.content;r.local_base=CONTENT_LOCAL;r.local_mask=bytearray(CONTENT_SIZE);r.local_mask[0x398:0x398+INFO_SIZE]=self.info.local_mask
   r.present=s['content'] is not None;r.closed=False;r.close_result=s['contentClose'];r.pending=None;r.events=[];r.end='returned';r.read_position=0
   self.current.update(localAddress=CONTENT_LOCAL,backing=self.blob(self.uc.mem_read(CONTENT_LOCAL,CONTENT_SIZE)),initialLocalMask=self.blob(r.local_mask),input=None if s['content'] is None else self.blob(bytes(s['content'])),index=signed(self.u32(0x44d784)),chunk=s['chunk'],closeResult=s['contentClose']);self.child_object=r
  elif kind=='bitmap':
   p=self.panel;mode=s['bitmap'];p.path=self.cstr(0x453d40).decode();p.null=mode=='null';p.reuse=True;p.key=s['key'];p.release_result=s['release'];p.allocation=None;p.events=[];p.calls=[];p.pending=None
   p.surface=0 if mode=='missing' else SOURCE+16*(1+len(p.regions)%8);p.resource=dict(path=p.path,present=p.surface!=0,width=self.dib['width'] if p.surface else None,height=self.dib['height'] if p.surface else None)
   self.current.update(surface=p.surface,colorKeyResult=p.key,releaseResult=p.release_result,source=self.dib);self.child_object=p
  else:
   w=self.writer;w.capacity=s['capacity'];w.available=s['writeOpen'];w.write_mode=s['writeMode'];w.fail_at=s['writeFailAt'];w.close_result=s['writeClose'];w.write_index=0;w.events=[];w.pending=None
   backing=bytes(i%256 for i in range(w.capacity)) if self.ramp else b'\xa5'*w.capacity;self.uc.mem_write(INPUT,backing);w.mask=bytearray(w.capacity)
   self.uc.mem_write(FILE,struct.pack('<8I',INPUT,w.capacity,INPUT,0x102,0xffffffff,0,w.capacity,0));self.put(PTD+8,0)
   self.current.update(capacity=w.capacity,available=w.available,writeMode=w.write_mode,failAt=w.fail_at,closeResult=w.close_result,backing=self.blob(backing));self.child_object=w
  self.child_object.active=True
 def finish(self,completed=True):
  c=self.current;r=self.child_object;kind=c['kind'];c.update(completed=completed,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),result=self.uc.reg_read(UC_X86_REG_EAX) if completed else None,events=r.events,globals=self.blob(self.uc.mem_read(BASE,SIZE)))
  assert r.pending is None
  if completed:
   assert c['endSP']==c['entrySP']+4 and c['saved']==[self.uc.reg_read(x) for x in REGISTERS]
   self.parent_events.append(dict(kind='return',arguments=[c['entry'],c['result']]))
  if kind=='info':c.update(localState=r.state(),stores=r.stores,reads=r.reads,unknown=r.unknown)
  elif kind=='content':c.update(scratch=r.scratch())
  elif kind=='bitmap':c.update(allocation=r.allocation,resource=None if r.null else r.resource,calls=r.calls,records=[dict(address=q['address'],live=q['live'],storage=r.record(q)) for q in r.regions])
  else:c.update(**r.snapshot())
  r.active=False;self.children.append(c);self.current=None;self.child_object=None
 def code(self,u,pc,n,data):
  if not self.running:return
  if self.current and pc==self.current['returnPC']:self.finish()
  if pc==0x43cfb4:self.end='returned';u.emu_stop();return
  excluded=set(self.boundaries)|{OPEN,CLOSE,0x4450ac,0x43ed10,GETPTD,WRITE,CLOSE_FILE,ISATTY,API,API+16,API+32,API+48,API+64}
  if pc not in excluded:
   assert 0x43cf94<=pc<0x43cfb4 or 0x43c4a0<=pc<=0x43c708 or 0x43c780<=pc<=0x43cf3a or 0x43ee50<=pc<=0x43ef68 or 0x4450b2<=pc<0x4450bc or 0x78100000<=pc<0x78200000,hex(pc)
   value=bytes(u.mem_read(pc,n)).hex();self.pcs[hex(pc)]=value;self.all_pcs[hex(pc)]=value
  if pc in ENTRIES:assert self.current is None;self.begin(pc,u.reg_read(UC_X86_REG_ESP))
  if not self.current:return
  kind=self.current['kind'];r=self.child_object
  if kind=='content':
   r.read_position=self.read_position
   if pc in (0x43c817,0x43c8cb,0x43c9d8,0x43cab4,0x43cb4e,0x43cbf9):
    p=self.u32(u.reg_read(UC_X86_REG_ESP));o=p-CONTENT_LOCAL;assert 0<=o<CONTENT_SIZE
    while o<CONTENT_SIZE:
     if not r.local_mask[o] and self.own_boundary is None:self.own_boundary=dict(kind='content',child=len(self.children),offset=o,count=1,eventCount=len(r.events),globals=self.blob(u.mem_read(BASE,SIZE)),scratch=r.scratch());break
     if u.mem_read(CONTENT_LOCAL+o,1)==b'\0':break
     o+=1
   r.code(u,pc,n,data)
  elif kind=='defaults':
   if pc==CLOSE:u.reg_write(UC_X86_REG_EIP,FCLOSE);return
   if pc==OPEN:
    # Read and write opens have distinct declared FILE responses at one IAT.
    assert self.cstr(self.u32(u.reg_read(UC_X86_REG_ESP)+8))==b'w'
   r.code(u,pc,n,data)
  else:r.code(u,pc,n,data)
 def step(self,s):
  self.spec=s;self.current=None;self.child_object=None;self.children=[];self.parent_events=[];self.stores=[];self.stack_writes=[];self.pcs={};self.own_boundary=None;self.end=None
  self.uc.mem_write(SP-0x2000,bytes(i%256 for i in range(0x2000)) if self.ramp else b'\xa5'*0x2000)
  self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x37f)
  for r,v in zip(REGISTERS,SAVED):self.uc.reg_write(r,v)
  self.global_mask=bytearray(SIZE);self.stack_mask=bytearray(0x10000);before=self.blob(self.uc.mem_read(BASE,SIZE));stack_before=self.blob(self.uc.mem_read(CONTENT_LOCAL,CONTENT_SIZE));self.running=True
  try:self.uc.emu_start(0x43cf94,0,count=10_000_000)
  finally:self.running=False
  if self.current:
   assert self.current['kind']=='content' and self.content.end=='unterminatedInput';self.end='unterminatedInput';self.finish(False)
  assert self.end and self.u32(0)==0xffffffff
  if self.end=='returned':assert self.uc.reg_read(UC_X86_REG_ESP)==SP and [self.uc.reg_read(r) for r in REGISTERS]==SAVED
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  return dict(spec=s,beforeGlobals=before,globals=self.blob(self.uc.mem_read(BASE,SIZE)),globalMask=self.blob(self.global_mask),children=self.children,events=self.parent_events,stores=self.stores,stackWrites=self.stack_writes,stackInitial=stack_before,stackFinal=self.blob(self.uc.mem_read(CONTENT_LOCAL,CONTENT_SIZE)),stackMask=self.blob(self.stack_mask[CONTENT_LOCAL-STACK:CONTENT_LOCAL-STACK+CONTENT_SIZE]),ownBoundary=self.own_boundary,instructions=self.pcs,end=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),eax=self.uc.reg_read(UC_X86_REG_EAX),controlWord=0x37f,records=[dict(address=q['address'],live=q['live'],storage=self.panel.record(q)) for q in self.panel.regions])

def specifications():
 raw=(DEFAULT_SOURCE/'data/adinfo.txt').read_bytes();lines=['123\n']+[f'ba {i+1} {i+2} {i+3} {i+4} ?row{i} bae\n' for i in range(24)]+[f'ta {i+1} {i+2} {i+3} ?text{i} tae\n' for i in range(8)]+['un 7 ?link une\n','y -15 23 ye\n','<end>\n'];valid=''.join(lines).encode()
 def s(label,info=raw,content=None,**kw):
  result=dict(label=label,info=None if info is None else list(info),content=None if content is None else list(content),chunk=4096,bitmap='live',key=0,release=17,infoClose=0,contentClose=0,infoReadFailAt=-1,capacity=7,writeOpen=True,writeMode='full',writeFailAt=-1,writeClose=0);result.update(kw);return result
 cases=[dict(label='original',steps=[s('original')]),dict(label='missing-info',steps=[s('missing-info',info=None)]),dict(label='empty-content',steps=[s('empty-content',content=b'')])]
 for info in (b'',b'bad 3 5 <end>',b'now 3 5 bad',b'now x x <end>',b'2026/09/10/12/34/56 3 5 <end>',b'dont_update -99 4 <end>'):
  cases.append(dict(label='info-'+info.hex(),steps=[s('info',info=info,content=valid)]))
 for mode in ('live','missing','null'):
  for key in (-1,0,1):cases.append(dict(label=f'bitmap-{mode}-{key}',steps=[s('bitmap',content=valid,bitmap=mode,key=key)]))
 for i in range(len(lines)):
  cases.append(dict(label='truncated-'+str(i),steps=[s('truncated',content=''.join(lines[:i]).encode())]))
 for chunk in (1,7,4096):
  for fail in (0,1,2):cases.append(dict(label=f'info-read-{chunk}-{fail}',steps=[s('read',content=valid,chunk=chunk,infoReadFailAt=fail)]))
 for available,mode,close in [(False,'full',0),(True,'error',0),(True,'zero',-1),(True,'short',-1),(True,'full',-1)]:
  for capacity in (1,7,4096):cases.append(dict(label=f'write-{available}-{mode}-{capacity}',steps=[s('write',capacity=capacity,writeOpen=available,writeMode=mode,writeFailAt=0 if mode!='full' else -1,writeClose=close)]))
 for old in ('live','missing','null','key'):
  for new in ('live','missing','null','key'):
   cases.append(dict(label=f'own-replace-{old}-{new}',steps=[s('old',content=valid,bitmap='live' if old=='key' else old,key=-1 if old=='key' else 0),s('new',content=valid,bitmap='live' if new=='key' else new,key=-1 if new=='key' else 0)]))
 return [dict(c,ramp=ramp,label=c['label']+('-ramp' if ramp else '-a5')) for ramp in (False,True) for c in cases]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=Path(a.output);assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
 source=Path(__file__).read_bytes();path.with_name(path.stem+'-source.py').write_bytes(source);cases=[];blobs={};pcs={}
 for i,s in enumerate(specifications()[:a.limit]):
  r=StartupPanel(s['ramp']);steps=[r.step(step) for step in s['steps']];c=dict(spec=s,initialGlobals=r.initial_globals,steps=steps,dib=r.dib);cases.append(c);blobs.update(r.blobs);pcs.update(r.all_pcs)
  part=parts/f'{i+1:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=r.blobs),separators=(',',':'))+'\n');os.replace(temp,part)
  print(i+1,s['label'],[(q['end'],q['ownBoundary']['kind'] if q['ownBoundary'] else 'known') for q in steps],flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,producerSHA256=digest(source),dependencies={n:digest((ROOT/'tools'/n).read_bytes()) for n in ['oracle_crt.py','oracle_menu_info_reading.py','oracle_menu_content.py','oracle_menu_panel_bitmap.py','oracle_menu_info_writing.py','oracle_state.py','oracle_bitmap_drawing.py','import_ntsd.py','inspect_original.py']},cases=cases,blobs=blobs,instructions=pcs)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
