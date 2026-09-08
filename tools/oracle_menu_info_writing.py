#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole43c690/43c710 with actual VC80 sprintf/fprintf/fclose.
Independent helpers on persistent globals. Fopen supplies a declared user-buffered
FILE (flags102); _write/_close/_isatty and same-thread PTD are boundaries. Capture
logical bytes before Windows text translation, partial writes, FILE/buffer state
and actual returns. No real filesystem, full4236d0/startup or Windows claim.
"""
import argparse,json,struct,subprocess
from oracle_crt import CRT,FILE,INPUT,PTD,STACK,STOP,DLL_SHA256
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
GLOBAL,SIZE,SP=0x44D000,0xB440,STACK+0xF000
OPEN,SPRINT,FPRINT,FCLOSE=STOP+0x40,0x7817775D,0x7813ED1F,0x781422FC
WRITE,CLOSE,ISATTY,GETPTD=0x7814E3F1,0x7814E83F,0x7814E74A,0x78132DB2
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]

class MenuInfoWriting(CRT):
 def __init__(self,control=False):
  self.active=False;super().__init__();self.control=control;self.blobs={}
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256
  self.uc.mem_map(0x400000,0x100000)
  for s in PE(raw).sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  for p,v in [(0x447190,OPEN),(0x447174,SPRINT),(0x447180,FPRINT),(0x447184,FCLOSE)]:self.put(p,v)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=GLOBAL,end=GLOBAL+SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=INPUT,end=INPUT+4095)
  self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,SIZE))
 def blob(self,data):
  raw=bytes(data);key=digest(raw)
  if key not in self.blobs:self.blobs[key]=packed(raw)
  return key
 def cstr(self,p):
  raw=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':raw.extend(self.uc.mem_read(p,1));p+=1;assert len(raw)<1000
  return bytes(raw)
 def snapshot(self):return dict(globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),file=self.blob(self.uc.mem_read(FILE,32)),buffer=dict(bytes=self.blob(self.uc.mem_read(INPUT,self.capacity)),defined=self.blob(self.mask)))
 def event(self,kind,args=(),strings=(),**extra):self.events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],**extra))
 def changed(self,uc,access,p,size,value,data):
  if not self.active:return
  if INPUT<=p and p+size<=INPUT+self.capacity:self.mask[p-INPUT:p-INPUT+size]=b'\1'*size
  elif GLOBAL<=p and p+size<=GLOBAL+SIZE:
   assert 0x43C690<=uc.reg_read(UC_X86_REG_EIP)<0x43C77F or uc.reg_read(UC_X86_REG_EIP)>=0x78100000
   if uc.reg_read(UC_X86_REG_EIP)<0x78100000:self.event('write',[p,size,value&((1<<(8*size))-1)])
  else:raise ValueError(('outside buffer',hex(p),size))
 def code(self,uc,pc,size,data):
  if not self.active:return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.pending and pc==self.pending['returnPC']:
   e=self.pending;self.pending=None;assert sp==e.pop('entrySP')+4 and e.pop('saved')==[uc.reg_read(r) for r in REGISTERS]
   e.update(result=uc.reg_read(UC_X86_REG_EAX),**self.snapshot());self.events.append(e)
  if pc==GETPTD:self.ret(PTD);return
  if pc==ISATTY:assert arg(0)==0xFFFFFFFF;self.ret(0);return
  if pc==OPEN:
   assert self.cstr(arg(0))==b'data\\adinfo.txt' and self.cstr(arg(1))==b'w'
   self.event('open',[FILE if self.available else 0],[self.cstr(arg(0)),self.cstr(arg(1))],**self.snapshot());self.ret(FILE if self.available else 0);return
  if pc==WRITE:
   assert arg(0)==0xFFFFFFFF and arg(1)==INPUT and 0<arg(2)<=self.capacity
   index=self.write_index;self.write_index+=1
   result=arg(2) if index!=self.fail_at else (-1 if self.write_mode=='error' else 0 if self.write_mode=='zero' else arg(2)-1)
   if result<0:self.put(PTD+8,28)
   self.event('writeFile',[arg(0),arg(2)],[bytes(uc.mem_read(INPUT,arg(2)))],result=result&0xFFFFFFFF,**self.snapshot());self.ret(result);return
  if pc==CLOSE:
   assert arg(0)==0xFFFFFFFF;self.event('closeFile',[arg(0)],result=self.close_result&0xFFFFFFFF,**self.snapshot())
   if self.close_result<0:self.put(PTD+8,28)
   self.ret(self.close_result);return
  if pc in (SPRINT,FPRINT,FCLOSE):
   assert self.pending is None
   e=dict(kind={SPRINT:'format',FPRINT:'print',FCLOSE:'close'}[pc],arguments=[],strings=[],returnPC=self.u32(sp),entrySP=sp,saved=[uc.reg_read(r) for r in REGISTERS])
   if pc==FCLOSE:assert arg(0)==FILE;e['arguments']=[FILE]
   else:
    fmt=self.cstr(arg(1)).decode('latin1');e['format']=fmt
    if pc==SPRINT:
     assert fmt in ('data\\ad%d.txt','sprite\\sys\\ad%d.bmp');e['arguments']=[arg(0),arg(2)]
    elif fmt=='now 0 4 <end>\n':assert arg(0)==FILE;e['arguments']=[FILE]
    else:
     assert arg(0)==FILE and fmt=='%s %d %d <end>\n';e['arguments']=[FILE,arg(3),arg(4)];e['strings']=[list(self.cstr(arg(2)))]
   self.pending=e
 def step(self,label,mode='cache',date=b'now',index=0,period=4,capacity=4096,available=True,write_mode='full',fail_at=-1,close=0):
  self.capacity=capacity;self.available=available;self.write_mode=write_mode;self.fail_at=fail_at;self.close_result=close;self.write_index=0
  backing=bytes(i%256 for i in range(capacity)) if self.control else b'\xa5'*capacity
  self.uc.mem_write(INPUT,backing);self.mask=bytearray(capacity);self.uc.mem_write(FILE,struct.pack('<8I',INPUT,capacity,INPUT,0x102,0xFFFFFFFF,0,capacity,0))
  self.put(PTD+8,0);self.put(0x44D784,index);self.put(0x44D788,period);self.uc.mem_write(0x4527B0,date+b'\0')
  self.events=[];self.pending=None;self.put(SP,STOP);self.uc.reg_write(UC_X86_REG_ESP,SP)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
  self.active=True
  try:self.uc.emu_start(0x43C690 if mode=='defaults' else 0x43C710,STOP,count=3_000_000)
  except Exception:
   print('INFO WRITE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-1:],self.pending,flush=True);raise
  finally:self.active=False
  assert self.pending is None and self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  return dict(label=label,mode=mode,date=list(date),index=index,period=period,capacity=capacity,available=available,writeMode=write_mode,failAt=fail_at,closeResult=close,backing=self.blob(backing),events=self.events,
   result=self.uc.reg_read(UC_X86_REG_EAX),endPC=STOP,endSP=SP+4,**self.snapshot())
 def capture(self):
  cases=[self.step('baseline-cache'),self.step('baseline-defaults',mode='defaults')]
  for mode in ('defaults','cache'):
   for capacity in (1,7,64,4096):
    cases.append(self.step(f'{mode}-{capacity}-missing',mode=mode,capacity=capacity,available=False,date=b'previous',index=-99,period=-1))
    for action in ('full','error','zero','short'):
     for fail_at in (0,1,2):cases.append(self.step(f'{mode}-{capacity}-{action}-{fail_at}',mode=mode,capacity=capacity,write_mode=action,fail_at=fail_at if action!='full' else -1))
    for close in (-2147483648,-1,0,1,2147483647):cases.append(self.step(f'{mode}-{capacity}-close-{close}',mode=mode,capacity=capacity,close=close))
  for index in (-2147483648,-99,-1,0,1,4,2147483647):
   for period in (-2147483648,-99,-1,0,1,4,2147483647):cases.append(self.step(f'numbers-{index}-{period}',index=index,period=period,capacity=7))
  dates=[b'',b'dont_update',b'2026/09/08/12/34/56',b'now\0ignored',b'with space\tand\r\nline',b'%s %d %%',bytes(range(128,256)),b'x'*255]
  for i,date in enumerate(dates):
   for capacity in (1,7,4096):
    for action in ('full','error','short'):cases.append(self.step(f'date-{i}-{capacity}-{action}',date=date,capacity=capacity,write_mode=action,fail_at=1 if action!='full' else -1))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,initialGlobals=self.initial_globals,adinfo=dict(path='data/adinfo.txt',bytes=self.blob((DEFAULT_SOURCE/'data/adinfo.txt').read_bytes())),cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   path=ROOT/'docs/evidence'/f'menu-info-writing{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'menu-info-writing{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-info-writing',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((path,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=MenuInfoWriting(a.control).capture();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-info-writing{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in sorted({e['kind'] for c in doc['cases'] for e in c['events']})},nativeCompared=False)
 (ROOT/'docs/evidence'/f'menu-info-writing{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
