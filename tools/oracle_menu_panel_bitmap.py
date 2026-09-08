#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole43cc60 information-panel bitmap replacement with real43ee50/43ef50.
Independent helper calls with supplied path/device/allocator boundaries. Original
ad0/ad1 bitmaps are absent; successful controls use identified original PE DIBs.
Track ordered writes, real helper ABI, all live/dead allocation generations and
their full bytes/masks. No4236d0 caller, pixels, heap provenance or Windows claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from oracle_state import Constructors,AREA,STACK,STOP
from oracle_bitmap_drawing import digest,packed
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ECX,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP
HEAP,SIZE,GLOBAL,GLOBAL_SIZE,SP=0x28000000,0x1F50,0x44D000,0xB440,STACK+0xF000
SOURCE,VTABLE,API=AREA+0x3000,AREA+0x3C00,STOP+0x100
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]

class MenuPanelBitmap(Constructors):
 def __init__(self,control=False):
  self.active=False;self.regions=[];super().__init__();self.control=control;self.blobs={};self.sources={};self.next_address=0
  self.uc.mem_map(0,0x1000);self.uc.mem_map(HEAP,0x200000)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=HEAP,end=HEAP+0x1FFFFF)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());self.resources={r['path'][1]:r for r in self.pe.resources() if r['path'][0]==2}
  for i in range(10):self.put(SOURCE+16*i,VTABLE)
  for at,to in [(VTABLE+0x74,API),(VTABLE+8,API+16),(0x4471C8,API+32),(0x447080,API+48),(0x44717C,API+64)]:self.put(at,to)
  self.put(0x457578,SOURCE);assert self.u32(0x458420)==0
  self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
 def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xFFFFFFFF))
 def ret(self,value=0,pop=0):
  sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xFFFFFFFF);self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
 def blob(self,data):
  raw=bytes(data);key=digest(raw)
  if key not in self.blobs:self.blobs[key]=packed(raw)
  return key
 def cstr(self,p):
  raw=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':raw.extend(self.uc.mem_read(p,1));p+=1;assert len(raw)<200
  return bytes(raw)
 def event(self,kind,args=(),strings=()):self.events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))
 def locate(self,p,size=4):
  for r in reversed(self.regions):
   if r['live'] and r['address']<=p and p+size<=r['address']+SIZE:return r,p-r['address']
  raise ValueError(('unowned bitmap access',hex(p),size))
 def record(self,r):
  if not r['live']:return r['frozen']
  return dict(bytes=self.blob(self.uc.mem_read(r['address'],SIZE)),defined=self.blob(r['mask']))
 def written(self,uc,access,p,size,value,data):
  if not self.active:return
  if GLOBAL<=p and p+size<=GLOBAL+GLOBAL_SIZE:token,offset=0,p
  else:r,offset=self.locate(p,size);r['mask'][offset:offset+size]=b'\1'*size;token=r['address']
  if 0x43CC60<=uc.reg_read(UC_X86_REG_EIP)<=0x43CF3A:self.event('write',[token,offset,size,value&((1<<(size*8))-1)])
 def write_host(self,p,value):
  r,i=self.locate(p);r['mask'][i:i+4]=b'\1'*4;self.put(p,value)
 def code(self,uc,pc,size,data):
  if pc==STOP:uc.emu_stop();return
  assert self.active,hex(pc)
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
  if self.pending and pc==self.pending['returnPC']:
   c=self.pending;self.pending=None
   assert sp==c['entrySP']+4+c['pop'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
   if c['entry']==0x43EE50:assert uc.reg_read(UC_X86_REG_EAX)==c['address']
   c.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.calls.append(c)
  if pc==0x4450AC:
   assert arg(0)==SIZE and self.allocation is None
   address=0;backing=None
   if not self.null:
    if self.reuse and self.regions:address=self.regions[-1]['address'];assert not self.regions[-1]['live']
    else:
     physical=128-self.next_address if self.control else self.next_address+8
     assert 1<=physical<256;self.next_address+=1;address=HEAP+physical*0x2000+0x20
    raw=bytes(i%256 for i in range(SIZE)) if self.control else b'\xa5'*SIZE;backing=self.blob(raw)
    self.uc.mem_write(address-16,b'\x96'*16+raw+b'\x69'*16);self.regions.append(dict(address=address,mask=bytearray(SIZE),live=True))
   self.allocation=dict(address=address,backing=backing);self.event('allocate',[SIZE]);self.ret(address);return
  if pc in (0x43EE50,0x43EF50):
   address=uc.reg_read(UC_X86_REG_ECX);self.locate(address);assert self.pending is None
   if pc==0x43EE50:
    assert address==self.allocation['address'] and [arg(0),arg(2)]==[0x40,0] and self.cstr(arg(1)).decode()==self.path
    self.event('construct',[address,0x40,0],[self.path.encode()]);pop=12
   else:self.event('destroy',[address]);pop=0
   self.pending=dict(entry=pc,address=address,entrySP=sp,returnPC=self.u32(sp),pop=pop,saved=[uc.reg_read(r) for r in REGISTERS])
  if pc==0x43ED10:
   assert self.pending['entry']==0x43EE50 and self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode()==self.path
   assert [arg(i) for i in range(3)]==[SOURCE,0x40,0]
   self.event('load',[SOURCE,0x40,0],[self.path.encode()])
   if self.surface:
    self.write_host(arg(3),self.resource['width']);self.write_host(arg(4),self.resource['height'])
   self.ret(self.surface);return
  if pc==API:
   assert [arg(0),arg(1)]==[self.surface,8] and bytes(uc.mem_read(arg(2),8))==bytes(8)
   self.event('colorKey',[arg(0),8],[bytes(8)]);self.ret(self.key,12);return
  if pc==API+16:self.event('release',[arg(0)]);self.ret(self.release_result,4);return
  if pc==API+32:self.event('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16);return
  if pc==API+48:self.event('debug',strings=[self.cstr(arg(0))]);self.ret(0x87654321,4);return
  if pc==API+64:
   address=arg(0);r,_=self.locate(address);assert address==r['address'] and self.u32(address)==0
   self.event('free',[address]);r['frozen']=self.record(r);r['live']=False;self.ret(0xAABBCCDD);return
  assert 0x43CC60<=pc<=0x43CF3A or 0x43EE50<=pc<=0x43EF68 or 0x4450B2<=pc<=0x4450BA,hex(pc)
 def step(self,label,path='MENU_CLIP',null=False,missing=False,key=0,reuse=False,release=17):
  self.path=path;self.null=null;self.reuse=reuse;self.key=key;self.release_result=release;self.allocation=None;self.events=[];self.calls=[];self.pending=None
  self.uc.mem_write(0x453D40,path.encode()+b'\0');self.put(0,0x12345678)
  present=not missing and path in self.resources
  self.surface=SOURCE+16*(1+len(self.regions)%8) if present else 0
  width=height=None
  if path in self.resources:
   desc=self.resources[path];raw=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']];width,height=struct.unpack_from('<ii',raw,4)
   self.sources[path]=dict(path=path,width=width,height=height,dib=self.blob(raw))
  self.resource=dict(path=path,present=present,width=width if present else None,height=height if present else None)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
  self.put(SP,STOP);self.uc.reg_write(UC_X86_REG_ESP,SP);self.active=True
  try:self.uc.emu_start(0x43CC60,STOP,count=10000)
  except Exception:
   print('PANEL BITMAP FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-3:],flush=True);raise
  finally:self.active=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and self.pending is None
  assert saved==[self.uc.reg_read(r) for r in REGISTERS] and self.u32(0)==0x12345678
  for r in self.regions:
   assert bytes(self.uc.mem_read(r['address']-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(r['address']+SIZE,16))==b'\x69'*16
  return dict(label=label,path=path,allocation=self.allocation,resource=None if null else self.resource,surface=self.surface,colorKeyResult=key,releaseResult=release,
   calls=self.calls,events=self.events,result=self.uc.reg_read(UC_X86_REG_EAX),endPC=STOP,endSP=SP+4,globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
   records=[dict(address=r['address'],live=r['live'],storage=self.record(r)) for r in self.regions])
 def capture(self):
  missing=['sprite/sys/ad0.bmp','sprite/sys/ad1.bmp'];assert all(not (DEFAULT_SOURCE/p).exists() for p in missing)
  cases=[self.step('original-missing-ad0',path=missing[0].replace('/','\\')),self.step('original-missing-ad1',path=missing[1].replace('/','\\'))]
  modes=[dict(null=True),dict(missing=True),dict(key=-1),dict()]
  for i,old in enumerate(modes):
   for j,new in enumerate(modes):
    cases.append(self.step(f'before-{i}-{j}',**old));cases.append(self.step(f'replace-{i}-{j}',reuse=True,**new))
  for path in ('MENU_CLIP','MENU_BACK1','SPARK'):
   for key in (-2147483648,-1,0,1,2147483647):cases.append(self.step(f'key-{path}-{key}',path=path,key=key))
  for i in range(10):cases.append(self.step(f'reuse-{i}',reuse=True,missing=i%3==0,key=-1 if i%3==1 else 1,release=(0,1,0xFFFFFFFF,0x80000000,0x7FFFFFFF)[i%5]))
  return dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,initialGlobals=self.initial_globals,absentOriginalFiles=missing,sources=list(self.sources.values()),cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
  pending=[]
  for suffix in ('','-control'):
   path=ROOT/'docs/evidence'/f'menu-panel-bitmap{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'menu-panel-bitmap{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-panel-bitmap',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((path,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=MenuPanelBitmap(a.control).capture();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'menu-panel-bitmap{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),sources=len(doc['sources']),helpers=sum(len(c['calls']) for c in doc['cases']),
  events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in sorted({e['kind'] for c in doc['cases'] for e in c['events']})},success=sum(c['result']==1 for c in doc['cases']),nativeCompared=False)
 (ROOT/'docs/evidence'/f'menu-panel-bitmap{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
