#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole WinMain43cfb4..43d078 startup dates, music and cursor.
Pinned EXE/MSVCR80, one Unicorn2.1.4 CPU/stack. Real calendar, integer sprintf
and music instructions; FILETIME/timezone/name conversion, COM/file/allocation
and cursor responses are controlled research inputs. Recover operation order,
wrapping expiry arithmetic and actual tm allocation-failure stack provenance.
Stop BEFORE caller NULL reads or at CRT invalid-parameter requests; no Watson,
control corruption, external network or game-file mutation. Not Windows, device,
full CRT/WinMain or native shipping execution. See STARTUP_OUTPUT_PLAN.md.
"""
import argparse,datetime,json,os,struct
from pathlib import Path
from oracle_calendar_time import CalendarTime,zone,MEM,TIME,LOCAL,GMT,REGS,SAVED
from oracle_crt import PTD,STACK,STOP,DLL_SHA256
from oracle_music_playback import MusicPlayback,platform,ARENA,API,TOKENS,HELPERS as MUSIC_HELPERS
from oracle_catalog_sounds import REGISTERS
from oracle_bitmap_drawing import digest,packed,signed
from inspect_original import PE
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from unicorn import UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,SIZE,SP=0x44d000,0xb440,STACK+0xf004
START,END,SPRINT=0x43cfb4,0x43d078,0x7817775d
CURSOR=API+0x500

class StartupOutput(CalendarTime):
 def __init__(self,spec):
  super().__init__(spec)
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256;pe=PE(raw)
  self.uc.mem_map(0x400000,0x100000)
  for s in pe.sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  self.uc.mem_map(ARENA,0x400000)
  m=self.music=MusicPlayback.__new__(MusicPlayback)
  m.uc=self.uc;m.music_api_address=API;m.music_arena=ARENA;m.music_tokens=TOKENS;m.music_allocations=[];m.music_pending=[];m.music_running=False
  for name in ('put','ret','u32','cstr','add_backing','region','write_host','mevent'):setattr(m,name,getattr(self,name))
  m.bind_music()
  for p,v in [(0x447174,SPRINT),(0x4471ac,TIME),(0x4471a8,LOCAL),(0x4471dc,CURSOR),(0x4471f8,CURSOR+16)]:self.put(p,v)
  self.initialGlobals=self.blob(self.uc.mem_read(BASE,SIZE))
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_stack,begin=STACK,end=STACK+0xffff)
 def cstr(self,p):
  out=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':out.extend(self.uc.mem_read(p,1));p+=1;assert len(out)<2000
  return bytes(out)
 def put(self,p,v):
  b=struct.pack('<I',v&0xffffffff)
  if self.active:self.write_host(p,b)
  else:self.uc.mem_write(p,b)
 def write_host(self,p,b):
  b=bytes(b)
  if BASE<=p<p+len(b)<=BASE+SIZE:
   self.global_mask[p-BASE:p-BASE+len(b)]=b'\1'*len(b);self.global_stores.append(dict(pc=None,address=p,bytes=b.hex(),eventIndex=len(self.events)))
  elif ARENA+0x10000<=p<p+len(b)<=ARENA+0x400000:
   r=self.region(p,len(b));r['mask'][p-r['address']:p-r['address']+len(b)]=b'\1'*len(b)
  if STACK<=p<p+len(b)<=STACK+0x10000:self.stack_stores.append(dict(pc=None,address=p,bytes=b.hex()))
  self.uc.mem_write(p,b)
 def hostwrite(self,p,b):
  super().hostwrite(p,b)
  if STACK<=p<p+len(b)<=STACK+0x10000:self.stack_stores.append(dict(pc=None,address=p,bytes=bytes(b).hex()))
 def store(self,u,access,p,n,v,data):
  super().store(u,access,p,n,v,data)
  if not self.active:return
  raw=(v&((1<<(n*8))-1)).to_bytes(n,'little').hex();pc=u.reg_read(UC_X86_REG_EIP)
  if BASE<=p<p+n<=BASE+SIZE:
   self.global_mask[p-BASE:p-BASE+n]=b'\1'*n;self.global_stores.append(dict(pc=pc,address=p,bytes=raw,eventIndex=len(self.events)))
  if STACK<=p<p+n<=STACK+0x10000:self.stack_stores.append(dict(pc=pc,address=p,bytes=raw))
  if ARENA+0x10000<=p<p+n<=ARENA+0x400000:
   r=self.region(p,n);r['mask'][p-r['address']:p-r['address']+n]=b'\1'*n
 def read_stack(self,u,access,p,n,v,data):
  if self.active and self.reserved is not None and p<=self.reserved<p+n:
   self.provenance.append(dict(kind='reservedRead',pc=u.reg_read(UC_X86_REG_EIP),address=p,count=n,bytes=bytes(u.mem_read(p,n)).hex()))
 def add_backing(self,p,n,kind):
  b=bytes(i%256 for i in range(n)) if self.spec.get('ramp') else b'\xa5'*n
  self.uc.mem_write(p,b);return dict(address=p,size=n,kind=kind,initial=b,mask=bytearray(n))
 def region(self,p,n):
  return next(r for r in self.music.music_allocations if r['address']<=p<p+n<=r['address']+r['size'])
 def mevent(self,kind,args=(),strings=(),result=0,pointer=None,raw=None):
  e=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],response=dict(result=result,pointer=pointer,bytes=None if raw is None else list(raw)))
  self.music.music_events.append(e);self.events.append(dict(kind='music',music=e))
 def boundary(self,u,pc,n,data):
  if self.active and (pc in self.music.music_imports or pc in (CURSOR,CURSOR+16)):return
  super().boundary(u,pc,n,data)
 def original(self,u,pc,n):
  b=bytes(u.mem_read(pc,n)).hex();self.pcs[hex(pc)]=b;self.call_pcs[hex(pc)]=b
 def code(self,u,pc,n,data):
  if not self.active:return
  sp=u.reg_read(UC_X86_REG_ESP)
  # Finish actual CRT children at EXE return PCs as well as DLL callers.
  if self.pending and pc==self.pending[-1]['returnPC'] and sp==self.pending[-1]['sp']+4:
   c=self.pending.pop();self.returns.append(dict(c,eax=u.reg_read(UC_X86_REG_EAX),edx=u.reg_read(UC_X86_REG_EDX)))
  if self.current_format and pc==self.current_format['returnPC']:
   c=self.current_format;assert sp==c['sp']+4;c.update(result=signed(u.reg_read(UC_X86_REG_EAX)),bytes=list(self.cstr(c['address'])+b'\0'));self.formats.append(c);self.current_format=None
   if c['address'] in (0x451d48,0x458350):self.events.append(dict(kind='dateFormat',address=c['address'],values=c['values'],bytes=c['bytes'],result=c['result']))
   else:self.mevent('format',[c['result']],[bytes(c['format']),bytes(c['bytes'][:-1])])
  if pc==0x43cfbe:self.provenance.append(dict(kind='timeReturn',pc=pc,ecx=u.reg_read(UC_X86_REG_ECX),eax=u.reg_read(UC_X86_REG_EAX),edx=u.reg_read(UC_X86_REG_EDX)))
  if pc==LOCAL:
   seconds=struct.unpack('<q',u.mem_read(self.u32(sp+4),8))[0];self.local_inputs.append(seconds)
  if pc==0x78181971:
   self.reserved=sp-4;self.provenance.append(dict(kind='tmEntry',pc=pc,ecx=u.reg_read(UC_X86_REG_ECX),reserved=self.reserved))
  if pc==0x781819ad:
   # The actual caller's _time64(0), not imported expected stack bytes, is
   # required to have produced this slot. Execute the recorded load only then.
   t=next(e for e in self.provenance if e['kind']=='timeReturn')
   e=next(e for e in self.provenance if e['kind']=='tmEntry')
   writes=[w for w in self.stack_stores if w['address']==self.reserved]
   assert t['ecx']==e['ecx']==0 and sp+4==self.reserved and self.u32(self.reserved)==0
   assert writes[-1]['pc']==0x78181971 and writes[-1]['bytes']=='00000000'
   self.provenance.append(dict(kind='knownAllocatorReturn',pc=pc,address=self.reserved,bytes=bytes(u.mem_read(self.reserved,4)).hex()))
   self.original(u,pc,n);return
  if pc in (0x43cfd3,0x43d028):
   pointer=u.reg_read(UC_X86_REG_EAX);self.calendar_results.append(dict(pointer=pointer,bytes=None if pointer==0 else list(u.mem_read(pointer,36))))
   if pointer==0:self.end='nullCalendarRead';self.boundaryPC=pc;u.emu_stop();return
  if pc==END:self.end='returned';u.emu_stop();return
  if pc==SPRINT:
   assert self.current_format is None
   address,fmt=self.u32(sp+4),self.cstr(self.u32(sp+8))
   assert fmt in (b'%04d/%02d/%02d/%02d/%02d/%02d',b'%s\\graph.log')
   values=[signed(self.u32(sp+12+4*i)) for i in range(6)] if fmt[1:2]!=b's' else []
   self.current_format=dict(address=address,format=list(fmt),values=values,sp=sp,returnPC=self.u32(sp))
  if pc in (CURSOR,CURSOR+16):
   args=[self.u32(sp+4),self.u32(sp+8)] if pc==CURSOR else [self.u32(sp+4)]
   result=self.spec.get('cursor',0x29000001) if pc==CURSOR else self.spec.get('previousCursor',0)
   self.events.append(dict(kind='loadCursor' if pc==CURSOR else 'setCursor',arguments=args,result=result));self.ret(result,4*len(args));return
  m=self.music
  if pc==0x43d061:
   assert len(m.music_pending)==1;c=m.music_pending.pop();assert c['entry']==0x402020 and sp==c['entrySP']+4 and c['saved']==[u.reg_read(r) for r in REGISTERS]
   c.update(returnSP=sp,returned=u.reg_read(UC_X86_REG_EAX));m.music_calls.append(c);m.music_running=False
  music_pc=(0x401c90<=pc<=0x401e85 or 0x401f30<=pc<=0x4020f6 or 0x4450b2<=pc<=0x4450ba)
  if pc==0x402020:m.music_running=True
  if music_pc or pc==0x4450c8 or pc in m.music_imports:
   if music_pc:self.original(u,pc,n)
   m.music_code(u,pc,n,data);return
  if START<=pc<END:self.original(u,pc,n);return
  super().code(u,pc,n,data)
 def run(self,step):
  self.spec.update(step);stimulus=[]
  for p,v in step.get('writes',[]):
   raw=struct.pack('<I',v&0xffffffff) if isinstance(v,int) else bytes(v)
   self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  self.events=[];self.stores=[];self.returns=[];self.pending=[];self.end=None;self.boundaryPC=None;self.call_pcs={};self.unknown=None
  self.formats=[];self.current_format=None;self.local_inputs=[];self.calendar_results=[];self.provenance=[];self.reserved=None
  self.global_stores=[];self.global_mask=bytearray(SIZE);self.stack_stores=[]
  m=self.music;m.music_input=self.spec.get('music',platform());m.music_events=[];m.music_calls=[];m.music_formats=[];m.music_end=-1
  assert not m.music_pending
  self.uc.mem_write(STACK+0x8000,b'\xa5'*0x8000);self.uc.reg_write(UC_X86_REG_ESP,SP)
  for r,v in zip(REGS,SAVED):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f)
  before=self.snapshot();beforeGlobals=self.blob(self.uc.mem_read(BASE,SIZE));self.active=True
  try:self.uc.emu_start(START,0,count=2_000_000)
  finally:self.active=False
  assert self.end,(hex(self.uc.reg_read(UC_X86_REG_EIP)),self.pending)
  if self.end=='returned':assert self.uc.reg_read(UC_X86_REG_ESP)==SP-8 and not self.pending and not m.music_pending and self.current_format is None
  assert self.u32(0)==0xffffffff and self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  return dict(input=step,stimulus=stimulus,before=before,after=self.snapshot(),beforeGlobals=beforeGlobals,globals=self.blob(self.uc.mem_read(BASE,SIZE)),globalMask=self.blob(self.global_mask),globalStores=self.global_stores,events=self.events,stores=self.stores,returns=self.returns,formats=self.formats,localInputs=self.local_inputs,calendarResults=self.calendar_results,provenance=self.provenance,stackStores=self.stack_stores,musicCalls=m.music_calls,musicAllocations=[dict(address=r['address'],backing=self.blob(r['initial']),bytes=self.blob(self.uc.mem_read(r['address'],r['size'])),mask=self.blob(r['mask'])) for r in m.music_allocations],end=self.end,boundaryPC=self.boundaryPC,instructions=self.call_pcs,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),registers=[self.uc.reg_read(r) for r in REGS],eax=self.uc.reg_read(UC_X86_REG_EAX),controlWord=0x37f)

def specifications():
 epoch=datetime.datetime(1970,1,1)
 seconds=lambda y,m,d,h=0,minute=0,second=0:int((datetime.datetime(y,m,d,h,minute,second)-epoch).total_seconds())
 def step(value=1789038000,period=4,**more):
  return dict(filetime=116444736000000000+value*10000000,writes=[(0x44d788,period),(0x44ef38,list(b'C:\\NTSD\0')),(0x4546f4,0x29000100)],**more)
 def spec(label,steps,z=None,**more):return dict(label=label,zone=z or zone(),steps=steps,**more)
 yield spec('ordinary',[step()])
 yield spec('tm-allocation-failure',[step()],allocationFail=True)
 for value in [0,1,259199,259200,259201,2147483647,2147483648,seconds(2000,2,28,23,59,59),seconds(2024,2,29),seconds(2026,12,31,23,59,59),32534899200]:
  yield spec('time-'+str(value),[step(value)])
 for period in [-2147483648,-49712,-24857,-24856,-24855,-24854,-99,-4,-1,0,1,24854,24855,24856,24857,49711,49712,2147483647]:
  yield spec('period-'+str(period),[step(period=period)])
 for label,z,tz,zr in [('us',zone(480,[0,11,0,1,2,0,0,0],[0,3,0,2,2,0,0,0],daylightBias=-60),None,0),('south',zone(-600,[0,4,0,1,3,0,0,0],[0,10,0,1,2,0,0,0],daylightBias=-60),None,0),('half',zone(-630,[0,4,0,1,2,0,0,0],[0,10,0,1,2,0,0,0],daylightBias=-30),None,0),('env',zone(),'PST8PDT',0),('api-failure',zone(),None,0xffffffff)]:
  yield spec(label,[step(seconds(2026,3,6,10)),dict(filetime=116444736000000000+seconds(2026,10,30,9)*10000000)],z,tz=tz,zoneResult=zr,ramp=True)
 for name,cfg in [('create-fail',platform(createResult=-1,createPointer=0)),('render-fail',platform(renderResult=-1)),('null-wide',platform(nullAllocation=True)),('convert-none',platform(conversion='none')),('convert-partial',platform(conversion='partial')),('convert-opaque',platform(conversion='opaque')),('get-fail',platform(getResult=-1)),('query-fail',platform(queryResults=[-1]*4)),('file-zero',platform(fileResult=0))]:
  yield spec(name,[step(music=cfg)])
 yield spec('own-repeat',[step(),dict(filetime=134335116001234567),dict(filetime=134336844001234567,writes=[(0x44ef04,list(b'other.wma\0'))])],ramp=True)
 yield spec('disabled-control',[dict(step(),writes=step()['writes']+[(0x44d010,0)])])
 yield spec('cursor-null',[step(cursor=0,previousCursor=0xffffffff)])
 yield spec('negative-expiry',[step(0,-1)])
 yield spec('above-calendar-range',[step(32535244800)])
 yield spec('unsigned-clock-before-epoch',[dict(step(),filetime=116444736000000000-1)])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=Path(a.output);assert not path.exists()
 path.with_name(path.stem+'-source.py').write_bytes(Path(__file__).read_bytes());parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();cases=[];blobs={};pcs={}
 for i,spec in enumerate(list(specifications())[:a.limit]):
  r=StartupOutput(spec.copy());steps=[]
  for s in spec['steps']:
   steps.append(r.run(s))
   if steps[-1]['end']!='returned':break
  case=dict(spec=spec,initialGlobals=r.initialGlobals,steps=steps);cases.append(case);blobs.update(r.blobs);pcs.update(r.pcs)
  temp=parts/f'{i+1:04d}.tmp';temp.write_text(json.dumps(dict(case=case,blobs=r.blobs),separators=(',',':'))+'\n');os.replace(temp,temp.with_suffix('.json'));print(i+1,spec['label'],len(steps),steps[-1]['end'],flush=True)
 doc=dict(scope=__doc__,producerSHA256=digest(Path(__file__).read_bytes()),dependencies={f:digest((ROOT/'tools'/f).read_bytes()) for f in ['oracle_calendar_time.py','oracle_crt.py','oracle_music_playback.py','oracle_bitmap_drawing.py','inspect_original.py','import_ntsd.py']},exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,globalAddress=BASE,globalCount=SIZE,dataAddress=r.db,dataCount=r.ds,cases=cases,blobs=blobs,instructions=pcs)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(cases),sum(len(c['steps']) for c in cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
