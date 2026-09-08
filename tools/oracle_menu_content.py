#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole43c780 menu-information parser with actual VC80 sprintf/fgets/sscanf.
Independent helper calls on persistent globals; raw scratch backing, translated
_read bytes and fopen/fclose are explicit boundaries. Original ad0/ad1 files
are absent; present-file controls come from the recovered format, not replacement
assets. No Windows/network/whole-screen claim. Native acceptance is separate.
"""
import argparse,json,struct,subprocess
from oracle_crt import CRT,FILE,INPUT,STACK,STOP,DLL_SHA256
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
GLOBAL,SIZE,SP=0x44D000,0xB440,STACK+0xF000
LOCAL,LOCAL_SIZE=SP-0x454,0x450
OPEN,CLOSE=STOP+0x40,STOP+0x50
PRINTF,GETS,SCAN=0x7817775D,0x7817A00D,0x78177DC4
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]

class MenuContent(CRT):
 local_base=LOCAL
 def __init__(self,control=False):
  self.active=False;super().__init__();self.control=control;self.blobs={}
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256
  self.uc.mem_map(0x400000,0x100000)
  for s in PE(raw).sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  for at,to in [(0x447190,OPEN),(0x447184,CLOSE),(0x447174,PRINTF),(0x44719C,GETS),(0x447158,SCAN)]:self.put(at,to)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=GLOBAL,end=GLOBAL+SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=LOCAL,end=LOCAL+LOCAL_SIZE-1)
  self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,SIZE))
 def blob(self,data):
  raw=bytes(data);key=digest(raw)
  if key not in self.blobs:self.blobs[key]=packed(raw)
  return key
 def cstr(self,p):
  out=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':out.extend(self.uc.mem_read(p,1));p+=1;assert len(out)<10000
  return bytes(out)
 def scratch(self):return dict(bytes=self.blob(self.uc.mem_read(self.local_base,LOCAL_SIZE)),defined=self.blob(self.local_mask))
 def changed(self,uc,access,address,size,value,data):
  if not self.active:return
  if self.local_base<=address and address+size<=self.local_base+LOCAL_SIZE:self.local_mask[address-self.local_base:address-self.local_base+size]=b'\1'*size
  else:
   assert GLOBAL<=address and address+size<=GLOBAL+SIZE
   if 0x43C780<=uc.reg_read(UC_X86_REG_EIP)<0x43CC54:self.events.append(dict(kind='write',arguments=[address,size,value&((1<<(8*size))-1)]))
 def target(self,p):
  if self.local_base<=p<self.local_base+LOCAL_SIZE:return [1,p-self.local_base]
  assert GLOBAL<=p<GLOBAL+SIZE,hex(p);return [0,p]
 def code(self,uc,pc,size,data):
  if not self.active:return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if self.pending and pc==self.pending['returnPC']:
   e=self.pending;self.pending=None;assert sp==e.pop('entrySP')+4 and e.pop('saved')==[uc.reg_read(r) for r in REGISTERS]
   result=uc.reg_read(UC_X86_REG_EAX)
   e.update(result=(int(result!=0) if e['kind']=='gets' else result),globals=self.blob(uc.mem_read(GLOBAL,SIZE)),scratch=self.scratch())
   if e['kind']=='gets':e.update(position=self.read_position-self.u32(FILE+4),eof=bool(self.u32(FILE+12)&16))
   self.events.append(e)
  if pc==OPEN:
   path=self.cstr(arg(0));assert self.cstr(arg(1))==b'r'
   self.events.append(dict(kind='open',arguments=[FILE if self.present else 0],strings=[list(path),list(b'r')]))
   self.uc.mem_write(FILE,struct.pack('<8I',INPUT,0,INPUT,9,0xFFFFFFFF,0,0x10000,0));self.ret(FILE if self.present else 0);return
  if pc==CLOSE:
   assert arg(0)==FILE and not self.closed;self.closed=True;self.events.append(dict(kind='close',arguments=[FILE,self.close_result&0xFFFFFFFF]));self.ret(self.close_result);return
  if pc in (0x43C817,0x43C8CB,0x43C9D8,0x43CAB4,0x43CB4E,0x43CBF9):
   ptr=self.u32(sp);assert self.local_base<=ptr<self.local_base+LOCAL_SIZE
   if 0 not in uc.mem_read(ptr,self.local_base+LOCAL_SIZE-ptr):self.end='unterminatedInput';uc.emu_stop();return
  if pc in (PRINTF,GETS,SCAN):
   assert self.pending is None
   e=dict(kind={PRINTF:'format',GETS:'gets',SCAN:'scan'}[pc],returnPC=self.u32(sp),entrySP=sp,saved=[uc.reg_read(r) for r in REGISTERS])
   if pc==GETS:
    assert arg(1)==500 and arg(2)==FILE;e.update(arguments=self.target(arg(0))+[500],before=self.read_position-self.u32(FILE+4))
   else:
    fmt=self.cstr(arg(1)).decode('latin1');e.update(format=fmt)
    if pc==PRINTF:
     assert fmt in ('data\\ad%d.txt','sprite\\sys\\ad%d.bmp');e.update(arguments=[arg(0),arg(2)])
    else:
     count=fmt.count('%');assert count<=7 and fmt in ('%d ','%s %d %d %d %d %s %s','%s %d %d %d %s %s','%s %d %s %s','%s %d %d %s','%s')
     e.update(arguments=[arg(0)-self.local_base]+[v for i in range(count) for v in self.target(arg(2+i))])
   self.pending=e
 def step(self,label,content,index=0,chunk=4096,close=0):
  backing=bytes(i%256 for i in range(LOCAL_SIZE)) if self.control else b'\xa5'*LOCAL_SIZE
  self.uc.mem_write(LOCAL,backing);self.local_mask=bytearray(LOCAL_SIZE)
  self.put(0x44D784,index);self.data=content or b'';self.read_position=0;self.chunk=chunk;self.present=content is not None
  self.pending=None;self.events=[];self.closed=False;self.close_result=close;self.end='returned'
  self.uc.reg_write(UC_X86_REG_ESP,SP);self.put(SP,STOP)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
  self.active=True
  try:self.uc.emu_start(0x43C780,STOP,count=3_000_000)
  except Exception:
   print('CONTENT FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-1:],self.pending,flush=True);raise
  finally:self.active=False
  assert self.pending is None
  if self.end=='returned':assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  return dict(label=label,input=None if content is None else self.blob(content),index=index,chunk=chunk,closeResult=close,backing=self.blob(backing),events=self.events,
   continuation=self.end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),result=self.uc.reg_read(UC_X86_REG_EAX),globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),scratch=self.scratch())
 def capture(self):
  baseline=['data/ad0.txt','data/ad1.txt','sprite/sys/ad0.bmp','sprite/sys/ad1.bmp'];assert all(not (DEFAULT_SOURCE/p).exists() for p in baseline)
  lines=['123\n']+[f'ba {i+1} {i+2} {i+3} {i+4} ?row{i} bae\n' for i in range(24)]+[f'ta {i+1} {i+2} {i+3} http://example.invalid/{i} tae\n' for i in range(8)]+['un 7 ?unknown une\n','y -15 23 ye\n','<end>\n']
  raw=''.join(lines).encode();probes=[('valid',raw),('empty',b''),('bad-header',b'bad\n'),('sentinel-header',b'-99\n'),('overflow-header',raw.replace(b'123\n',b'4294967296\n',1))]
  for i in range(len(lines)):
   probes.append((f'truncated-{i}',''.join(lines[:i]).encode()))
   changed=lines.copy();changed[i]='wrong\n';probes.append((f'bad-line-{i}',''.join(changed).encode()))
  for row in (1,24,25,32,33,34):
   for mode in ('sentinel','url','end','partial','nul','long'):
    changed=lines.copy();parts=changed[row].split()
    if mode=='sentinel':parts[1]='-99'
    elif mode=='url':parts[-2]='Xbad'
    elif mode=='end':parts[-1]+='x'
    elif mode=='partial':parts=parts[:2]
    elif mode=='nul':parts[0]+='\0tail'
    else:parts[-2]='h'+'q'*140
    changed[row]=' '.join(parts)+'\n';probes.append((f'{mode}-{row}',''.join(changed).encode()))
  cases=[self.step('original-missing-ad0',None),self.step('original-missing-ad1',None,index=1)]
  for label,content in probes:
   for chunk in (1,7,4096):cases.append(self.step(label+f'-{chunk}',content,chunk=chunk))
  for index in (-2147483648,-99,-1,0,1,2147483647):cases.append(self.step(f'index-{index}',raw,index=index))
  for close in (-2147483648,-1,0,1,2147483647):cases.append(self.step(f'close-{close}',raw,close=close))
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,initialGlobals=self.initial_globals,absentOriginalFiles=baseline,
   adinfo=dict(path='data/adinfo.txt',bytes=self.blob((DEFAULT_SOURCE/'data/adinfo.txt').read_bytes())),cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[]
  for suffix in ('','-control'):
   path=ROOT/'docs/evidence'/f'menu-content{suffix}.json';report=json.loads(path.read_bytes())
   raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'menu-content{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-content',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus'])
   report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data))
   pending.append((path,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=MenuContent(a.control).capture();suffix='-control' if a.control else ''
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-content{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in ('format','open','gets','scan','write','close')},
  continuations={k:sum(c['continuation']==k for c in doc['cases']) for k in ('returned','unterminatedInput')},nativeCompared=False)
 (ROOT/'docs/evidence'/f'menu-content{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
