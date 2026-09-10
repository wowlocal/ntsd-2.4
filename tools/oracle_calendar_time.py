#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Recover startup VC80 time/calendar calls from pinned game dependencies.
Unicorn2.1.4 executes real _time64/_localtime64/tzset/calendar helpers. Controlled
FILETIME/timezone/name-conversion/allocator and C-locale PTD/environment backing
are explicit research boundaries, not Windows/host/device measurements. Retain
unknown allocation-failure backing and invalid-parameter stops separately. No
game file, network endpoint or control corruption; CALENDAR_TIME_PLAN.md.
"""
import argparse,json,struct,os,datetime,random
from pathlib import Path
from oracle_crt import CRT,PTD,STACK,STOP,DLL_SHA256
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
MEM=0x26000000
TIME,LOCAL,GMT=0x78182857,0x78182153,0x781819dd
HELPERS={TIME:'time',LOCAL:'local',GMT:'gmt',0x78181e8e:'local_s',0x78181971:'tmBuffer',0x78149298:'tzInit',0x78148b84:'tzSet',0x7814931f:'isDST',0x78148ecd:'transition'}
REGS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
SAVED=[0x11223344,0x22334455,0x33445566,0x44556677]

def zone(bias=0,standard=None,daylight=None,standardBias=0,daylightBias=0):
 return dict(bias=bias,standard=standard or [0]*8,daylight=daylight or [0]*8,standardBias=standardBias,daylightBias=daylightBias,standardName='STD',daylightName='DST')
def zone_bytes(z):
 name=lambda s:s.encode('utf-16le').ljust(64,b'\0')
 return struct.pack('<i',z['bias'])+name(z['standardName'])+struct.pack('<8Hi',*z['standard'],z['standardBias'])+name(z['daylightName'])+struct.pack('<8Hi',*z['daylight'],z['daylightBias'])

class CalendarTime(CRT):
 def __init__(self,spec):
  self.active=False;super().__init__();self.spec=spec;self.blobs={};self.pcs={};self.allocations=[];self.pending=[];self.masks={}
  self.uc.mem_map(MEM,0x100000);self.put(0,0xffffffff)
  self.put(0x781c37e0,MEM+0x1000);self.put(MEM+0x1000,0) # Declared empty narrow environment.
  if spec.get('tz') is not None:
   self.put(MEM+0x1000,MEM+0x1100);self.uc.mem_write(MEM+0x1100,b'TZ='+spec['tz'].encode()+b'\0')
  self.uc.mem_write(MEM+0x200,b'\xa5'*8);self.masks[MEM+0x200]=bytearray(8)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.store)
  self.dataSection=next(s for s in PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes()).sections if s['name']=='.data')
  self.db=0x78130000+self.dataSection['rva'];self.ds=self.dataSection['virtualSize']
  self.beforeData=self.blob(self.uc.mem_read(self.db,self.ds));self.beforePTD=self.blob(self.uc.mem_read(PTD,0x200))
 def blob(self,b):
  b=bytes(b);h=digest(b)
  if h not in self.blobs:self.blobs[h]=packed(b)
  return h
 def store(self,u,access,p,n,v,data):
  if self.active and (self.db<=p<p+n<=self.db+self.ds or PTD<=p<p+n<=PTD+0x200 or MEM<=p<p+n<=MEM+0x100000):
   self.stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,bytes=(v&((1<<(8*n))-1)).to_bytes(n,'little').hex()))
   for a,m in self.masks.items():
    if a<=p<p+n<=a+len(m):m[p-a:p-a+n]=b'\1'*n
 def hostwrite(self,p,b):
  self.uc.mem_write(p,bytes(b));self.stores.append(dict(pc=None,address=p,bytes=bytes(b).hex()))
 def boundary(self,u,pc,n,data):
  if self.active:
   name=self.boundaries[pc];sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
   if name=='GetSystemTimeAsFileTime':
    self.events.append(dict(kind='filetime',value=self.spec['filetime']));self.hostwrite(arg(0),int(self.spec['filetime']).to_bytes(8,'little'));self.ret(0,4);return
   if name=='GetTimeZoneInformation':
    self.events.append(dict(kind='timezone',result=self.spec.get('zoneResult',0)))
    if self.spec.get('zoneResult',0)!=0xffffffff:self.hostwrite(arg(0),zone_bytes(self.spec['zone']))
    self.ret(self.spec.get('zoneResult',0),4);return
   if name=='WideCharToMultiByte':
    args=[arg(i) for i in range(8)];raw=bytearray();p=args[2]
    while self.u32(p)&0xffff:raw.append(self.u32(p)&0xff);p+=2
    raw.append(0);assert len(raw)<=args[5] and args[0]==args[1]==args[6]==0 and args[3]==0xffffffff
    self.events.append(dict(kind='nameConversion',bytes=list(raw),capacity=args[5]));self.hostwrite(args[4],raw);self.hostwrite(args[7],b'\0'*4);self.ret(len(raw),32);return
  super().boundary(u,pc,n,data)
 def snapshot(self):
  return dict(data=self.blob(self.uc.mem_read(self.db,self.ds)),ptd=self.blob(self.uc.mem_read(PTD,0x200)),allocations=[dict(a,bytes=self.blob(self.uc.mem_read(a['address'],a['count'])),mask=self.blob(self.masks[a['address']])) for a in self.allocations],timezone=[self.u32(p) for p in (0x781c1e10,0x781c1e14,0x781c1e18)],cache=[self.u32(0x781c1f64+4*i) for i in range(6)],names=self.blob(self.uc.mem_read(0x781c1e20,128)),initialized=self.u32(0x781c44ac),osZone=self.u32(0x781c44a4),errno=self.u32(PTD+8),tmPointer=self.u32(PTD+0x44))
 def code(self,u,pc,n,data):
  if not self.active:return
  if self.pending and pc==self.pending[-1]['returnPC'] and u.reg_read(UC_X86_REG_ESP)==self.pending[-1]['sp']+4:
   c=self.pending.pop();self.returns.append(dict(c,eax=u.reg_read(UC_X86_REG_EAX),edx=u.reg_read(UC_X86_REG_EDX)))
  if pc==STOP:self.end='returned';u.emu_stop();return
  if pc in (0x78138a70,0x78138945):self.end='invalidParameter';self.boundaryPC=pc;u.emu_stop();return
  if pc==0x781819ad:
   self.end='unknownAllocatorReturn';self.boundaryPC=pc;self.unknown=dict(address=u.reg_read(UC_X86_REG_ESP)+4,count=4,bytes=bytes(u.mem_read(u.reg_read(UC_X86_REG_ESP)+4,4)).hex());u.emu_stop();return
  if pc==0x78132db2:self.ret(PTD);return
  if pc==0x7813473d:
   sp=u.reg_read(UC_X86_REG_ESP);count=self.u32(sp+4);assert 0<count<=256
   if self.spec.get('allocationFail'):
    self.events.append(dict(kind='allocate',count=count,address=0));self.ret(0);return
   address=MEM+0x10000+len(self.allocations)*0x1000
   b=bytes(i%256 for i in range(count)) if self.spec.get('ramp') else b'\xa5'*count
   self.uc.mem_write(address,b);self.masks[address]=bytearray(count);self.allocations.append(dict(address=address,count=count,backing=self.blob(b)));self.events.append(dict(kind='allocate',count=count,address=address));self.ret(address);return
  if pc in self.boundaries:return
  assert 0x78130000<=pc<0x78194000,hex(pc)
  self.pcs[hex(pc)]=bytes(u.mem_read(pc,n)).hex();self.call_pcs[hex(pc)]=self.pcs[hex(pc)]
  if pc in HELPERS:
   sp=u.reg_read(UC_X86_REG_ESP);self.pending.append(dict(entry=pc,kind=HELPERS[pc],sp=sp,returnPC=self.u32(sp)))
 def run(self,kind,value=None):
  self.events=[];self.stores=[];self.returns=[];self.pending=[];self.end=None;self.boundaryPC=None;self.call_pcs={};self.unknown=None
  if kind=='time':args=[MEM+0x200 if self.spec.get('output') else 0];entry=TIME
  else:self.uc.mem_write(MEM+0x100,struct.pack('<q',value));args=[MEM+0x100];entry=LOCAL
  sp=STACK+0xf000;self.uc.mem_write(sp-0x4000,b'\xa5'*0x4000);self.uc.mem_write(sp,struct.pack('<'+'I'*(1+len(args)),STOP,*args));self.uc.reg_write(UC_X86_REG_ESP,sp)
  for r,v in zip(REGS,SAVED):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);before=self.snapshot();self.active=True
  observed_after=False
  try:
   self.uc.emu_start(entry,0,count=1_000_000)
   if self.end is None and self.uc.reg_read(UC_X86_REG_EIP)==STOP:
    observed_after=True;self.code(self.uc,STOP,0,None)
  finally:self.active=False
  assert self.end,(hex(self.uc.reg_read(UC_X86_REG_EIP)),self.pending)
  if self.end=='returned':assert self.uc.reg_read(UC_X86_REG_ESP)==sp+4 and not self.pending and [self.uc.reg_read(r) for r in REGS]==SAVED
  assert self.u32(0)==0xffffffff and self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  result=dict(kind=kind,value=value,before=before,after=self.snapshot(),events=self.events,stores=self.stores,returns=self.returns,end=self.end,boundaryPC=self.boundaryPC,unknown=self.unknown,instructions=self.call_pcs,eax=self.uc.reg_read(UC_X86_REG_EAX),edx=self.uc.reg_read(UC_X86_REG_EDX),endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),controlWord=0x37f)
  result['terminalObservedAfterEmulation']=observed_after
  if kind=='time':result['output']=bytes(self.uc.mem_read(MEM+0x200,8)).hex();result['outputMask']=list(self.masks[MEM+0x200])
  return result

def specifications():
 epoch=datetime.datetime(1970,1,1)
 sec=lambda y,m,d,h=0,minute=0,second=0:int((datetime.datetime(y,m,d,h,minute,second)-epoch).total_seconds())
 def rule(month,week,hour=2,day=0,year=0,minute=0,second=0,millis=0):return [year,month,day,week,hour,minute,second,millis]
 us=zone(480,rule(11,1),rule(3,2),daylightBias=-60)
 configs=[('utc',zone(),None,0),('east14',zone(-840),None,0),('west12',zone(720),None,0),('nepal',zone(-345),None,0),('us',us,None,0),('old-us',zone(300,rule(10,5),rule(4,1),daylightBias=-60),None,0),('south',zone(-600,rule(4,1,3),rule(10,1),daylightBias=-60),None,0),('half-dst',zone(-630,rule(4,1),rule(10,1),daylightBias=-30),None,0),('absolute',zone(60,rule(11,2,year=2026),rule(3,15,year=2026),daylightBias=-60),None,0),('milliseconds',zone(0,rule(11,1,0,millis=500),rule(3,2,0,millis=500),daylightBias=-60),None,0),('standard-bias',zone(-600,rule(4,1,3),rule(10,1),standardBias=30,daylightBias=-30),None,0),('api-failure',zone(),None,0xffffffff)]
 configs += [('env-'+t,us,t,0) for t in ['UTC0','PST8PDT','ABC-5:30:45XYZ','GMT+3','EST5EDT','']]
 values={0,1,59,60,3599,3600,86399,86400,259199,259200,259201,2147483647,2147483648,32535244799,-1}
 for y in [1970,1971,1972,1999,2000,2006,2007,2024,2026,2038,2100,2400,3000]:
  for m,d in [(1,1),(2,28),(3,1),(4,1),(10,1),(11,1),(12,31)]:
   for delta in [-1,0,1]:values.add(sec(y,m,d)+delta)
 # Dense independent UTC seconds around every possible relative DST rule day,
 # plus both sides of exact transitions (including the500ms controls).
 for y in [1970,2006,2007,2024,2026,2100,2400]:
  for z in [q[1] for q in configs if q[2] is None and q[3]==0]:
   for key in ['standard','daylight']:
    t=z[key]
    if not t[1]:continue
    if t[0]:day=t[3]
    else:
     first=datetime.datetime(y,t[1],1);dow=(first.weekday()+1)%7;day=1+(t[2]-dow)%7+7*(t[3]-1)
     if t[3]==5:
      try:datetime.datetime(y,t[1],day)
      except ValueError:day-=7
    moment=sec(y,t[1],day,t[4],t[5],t[6])+60*(z['bias']+(z['standardBias'] if key=='daylight' else z['daylightBias']))
    for delta in [-1,0,1,3599,3600]:values.add(moment+delta)
 common=sorted(v for v in values if 0<=v<=32535244799)+[-1]
 cases=[]
 for name,z,tz,zr in configs:
  tests=common if name in ['utc','us','south','api-failure','env-PST8PDT'] else common[::5]+common[-1:]
  if name=='utc':
   tests=sorted(set(tests)|{sec(y,m,d)+delta for y in range(1971,3001) for m,d in [(1,1),(3,1)] for delta in [-1,0]})
  cases.append(dict(label=name,zone=z,tz=tz,zoneResult=zr,ramp=len(cases)%2==1,steps=[['local',v] for v in tests]))
 # Real ordinary allocation failure, stopped before the original unknown local
 # return value is loaded; never follow that unavailable control-dependent value.
 cases += [dict(label='allocation-failure',zone=zone(),allocationFail=True,steps=[['local',1789038000]])]
 for output in [False,True]:
  for value in [0,116444736000000000-10000001,116444736000000000-1,116444736000000000,116444736000000001,116444736000000000+9999999,116444736000000000+10000000,134335116001234567,2**63-1,2**64-1]:
   cases.append(dict(label=f'clock-{value}-{output}',zone=zone(),filetime=value,output=output,steps=[['time',None]]))
 # Above the CRT's documented range selects its invalid-parameter path. Stop at
 # that actual request, preserving all prior stores without invoking Watson.
 cases.append(dict(label='above-calendar-range',zone=zone(),steps=[['local',32535244800]]))
 return cases

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=Path(a.output);assert not path.exists();path.with_name(path.stem+'-source.py').write_bytes(Path(__file__).read_bytes())
 parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();cases=[];blobs={};pcs={}
 for i,spec in enumerate(specifications()[:a.limit]):
  r=CalendarTime(spec);steps=[]
  for kind,value in spec['steps']:
   steps.append(r.run(kind,value))
   if steps[-1]['end']!='returned':break
  case=dict(spec=spec,steps=steps);cases.append(case);blobs.update(r.blobs);pcs.update(r.pcs)
  temp=parts/f'{i+1:04d}.tmp';temp.write_text(json.dumps(dict(case=case,blobs=r.blobs),separators=(',',':'))+'\n');os.replace(temp,temp.with_suffix('.json'))
  print(i+1,spec['label'],len(steps),steps[-1]['end'],flush=True)
 d=dict(scope=__doc__,producerSHA256=digest(Path(__file__).read_bytes()),dependencies={f:digest((ROOT/'tools'/f).read_bytes()) for f in ['oracle_crt.py','oracle_bitmap_drawing.py','inspect_original.py','import_ntsd.py']},exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,dataAddress=r.db,dataCount=r.ds,cases=cases,blobs=blobs,instructions=pcs)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path);print('complete',len(cases),sum(len(c['steps']) for c in cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
