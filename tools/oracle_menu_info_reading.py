#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Recover whole43c4a0 startup adinfo reader with actual VC80 scan/format calls.

Pinned game EXE/CRT in Unicorn2.1.4; declared fopen/fclose, translated _read,
C-locale PTD/thread boundaries. Trace field provenance, retained values, actual
instruction/return/store order. Missing files can read unknown local bytes:
preserve actual source return, separately reject native unknown reads. No buffer
corruption, cookie/control mutation, game-file write, network or Windows claim.
See MENU_INFO_READING_PLAN.md; reference execution is development tooling only.
"""
import argparse,json,struct,os
from pathlib import Path
from oracle_crt import CRT,FILE,INPUT,PTD,STACK,STOP,DLL_SHA256
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
GLOBAL,SIZE,SP=0x44d000,0xb440,STACK+0xf000
LOCAL,LOCAL_SIZE=SP-0xbc,0xb8
OPEN,CLOSE=STOP+0x40,STOP+0x50
FSCAN,SCAN,SPRINT=0x78175f0b,0x78177dc4,0x7817775d
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
SAVED=[0x11223344,0x22334455,0x33445566,0x44556677]

class MenuInfoReading(CRT):
 def __init__(self):
  self.active=False;super().__init__();self.blobs={};self.all_pcs={}
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256
  self.uc.mem_map(0x400000,0x100000)
  for s in PE(raw).sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  for p,v in [(0x447190,OPEN),(0x447188,FSCAN),(0x447184,CLOSE),(0x447158,SCAN),(0x447174,SPRINT)]:self.put(p,v)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=GLOBAL,end=GLOBAL+SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_WRITE,self.changed,begin=LOCAL,end=LOCAL+LOCAL_SIZE-1)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read_local,begin=LOCAL,end=LOCAL+LOCAL_SIZE-1)
  self.initial=bytes(self.uc.mem_read(GLOBAL,SIZE))
 def blob(self,data):
  raw=bytes(data);h=digest(raw)
  if h not in self.blobs:self.blobs[h]=packed(raw)
  return h
 def cstr(self,p):
  out=bytearray()
  while self.uc.mem_read(p,1)!=b'\0':out.extend(self.uc.mem_read(p,1));p+=1;assert len(out)<200
  return bytes(out)
 def state(self):
  return dict(globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),globalMask=self.blob(self.global_mask),local=self.blob(self.uc.mem_read(LOCAL,LOCAL_SIZE)),localMask=self.blob(self.local_mask))
 def changed(self,u,access,p,n,value,data):
  if not self.active:return
  region=1 if LOCAL<=p<LOCAL+LOCAL_SIZE else 0;base=LOCAL if region else GLOBAL;mask=self.local_mask if region else self.global_mask
  assert 0<=p-base<p-base+n<=len(mask),(hex(p),n)
  mask[p-base:p-base+n]=b'\1'*n
  self.stores.append(dict(region=region,offset=p-base,bytes=(value&((1<<(n*8))-1)).to_bytes(n,'little').hex(),pc=u.reg_read(UC_X86_REG_EIP),eventIndex=len(self.events)))
 def read_local(self,u,access,p,n,value,data):
  if not self.active:return
  assert LOCAL<=p<p+n<=LOCAL+LOCAL_SIZE,(hex(p),n)
  pc=u.reg_read(UC_X86_REG_EIP);known=all(self.local_mask[p-LOCAL:p-LOCAL+n])
  if 0x43c4a0<=pc<=0x43c685:
   self.reads.append(dict(pc=pc,offset=p-LOCAL,count=n,known=known,bytes=bytes(u.mem_read(p,n)).hex()))
   if not known and self.unknown is None:self.unknown=dict(offset=p-LOCAL,count=n,eventCount=len(self.events),storeCount=len(self.stores),**self.state())
 def boundary(self,u,pc,n,data):
  if self.active and self.boundaries[pc]=='_read':
   sp=u.reg_read(UC_X86_REG_ESP);assert self.u32(sp+4)==0xffffffff and self.u32(sp+8)==INPUT
   count=self.u32(sp+12);index=self.read_index;self.read_index+=1
   if self.spec['readFailAt']==index:
    self.put(PTD+8,5);result=-1;raw=b''
   else:
    raw=self.data[self.read_position:self.read_position+min(count,self.chunk)];self.read_position+=len(raw);result=len(raw);u.mem_write(INPUT,raw)
   self.io.append(dict(position=self.read_position,count=count,result=result,bytes=raw.hex()))
   self.ret(result);return
  super().boundary(u,pc,n,data)
 def code(self,u,pc,n,data):
  if not self.active:return
  if pc not in self.boundaries and pc not in (OPEN,CLOSE,STOP):
   assert 0x43c4a0<=pc<=0x43c685 or 0x4450b2<=pc<0x4450bc or 0x78100000<=pc<0x78200000,hex(pc)
   v=bytes(u.mem_read(pc,n)).hex();self.pcs[hex(pc)]=v;self.all_pcs[hex(pc)]=v
  sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if self.pending and pc==self.pending['returnPC']:
   e=self.pending;self.pending=None
   assert sp==e.pop('sp')+4 and [u.reg_read(r) for r in REGISTERS]==e.pop('saved')
   e.update(result=u.reg_read(UC_X86_REG_EAX),state=self.state());self.events.append(e)
  if pc==OPEN:
   assert self.cstr(arg(0))==b'data\\adinfo.txt' and self.cstr(arg(1))==b'r'
   self.uc.mem_write(FILE,struct.pack('<8I',INPUT,0,INPUT,9,0xffffffff,0,0x10000,0))
   self.events.append(dict(kind='open',arguments=[FILE if self.present else 0],strings=[list(self.cstr(arg(0))),list(self.cstr(arg(1)))],state=self.state()))
   self.ret(FILE if self.present else 0);return
  if pc==CLOSE:
   assert arg(0)==FILE;self.events.append(dict(kind='close',arguments=[self.spec['close']&0xffffffff],state=self.state()));self.ret(self.spec['close']);return
  if pc in (FSCAN,SCAN,SPRINT):
   assert self.pending is None;fmt=self.cstr(arg(1)).decode('latin1')
   e=dict(kind={FSCAN:'tokens',SCAN:'scan',SPRINT:'format'}[pc],format=fmt,returnPC=self.u32(sp),sp=sp,saved=[u.reg_read(r) for r in REGISTERS])
   if pc==FSCAN:
    assert arg(0)==FILE and fmt=='%s %s %s %s'
    assert [arg(i) for i in range(2,6)]==[0x4527b0,LOCAL+0x50,LOCAL+0x84,LOCAL+0x1c]
    e['arguments']=[]
   elif pc==SPRINT:
    assert fmt in ('data\\ad%d.txt','sprite\\sys\\ad%d.bmp');e['arguments']=[arg(0),arg(2)]
   else:
    assert fmt in ('%04d/%02d/%02d/%02d/%02d/%02d','%d')
    count=6 if fmt!='%d' else 1
    e['arguments']=[arg(0)]+[arg(i) for i in range(2,2+count)]
    e['strings']=[list(self.cstr(arg(0)))]
   self.pending=e
 def step(self,spec,own_globals=None):
  self.spec=spec;self.uc.mem_write(GLOBAL,self.initial if own_globals is None else own_globals)
  if own_globals is None:
   for p,v in [(0x44d784,spec['index']),(0x44d788,spec['period'])]:self.put(p,v)
   self.uc.mem_write(0x4527b0,b'previous-date\0');self.uc.mem_write(0x453c68,b'previous-text-path\0');self.uc.mem_write(0x453d40,b'previous-bitmap-path\0')
  backing=bytes(i%256 for i in range(LOCAL_SIZE)) if spec['ramp'] else b'\xa5'*LOCAL_SIZE
  self.uc.mem_write(LOCAL,backing);self.put(SP,STOP);self.uc.reg_write(UC_X86_REG_ESP,SP)
  for r,v in zip(REGISTERS,SAVED):self.uc.reg_write(r,v)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f)
  self.local_mask=bytearray(LOCAL_SIZE);self.global_mask=bytearray(SIZE);self.events=[];self.stores=[];self.reads=[];self.io=[];self.pcs={};self.pending=None;self.unknown=None
  self.present=spec['input'] is not None;self.data=b'' if not self.present else bytes(spec['input']);self.chunk=spec['chunk'];self.read_position=0;self.read_index=0;self.put(PTD+8,0)
  before=self.state();self.active=True
  try:self.uc.emu_start(0x43c4a0,STOP,count=3_000_000)
  finally:self.active=False
  assert self.pending is None and self.uc.reg_read(UC_X86_REG_EIP)==STOP
  assert self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and [self.uc.reg_read(r) for r in REGISTERS]==SAVED
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  return dict(spec=spec,before=before,after=self.state(),events=self.events,stores=self.stores,reads=self.reads,io=self.io,unknown=self.unknown,instructions=self.pcs,result=self.uc.reg_read(UC_X86_REG_EAX),endPC=STOP,endSP=SP+4,saved=SAVED,controlWord=0x37f)

def specs():
 raw=(DEFAULT_SOURCE/'data/adinfo.txt').read_bytes();out=[]
 def add(label,content,**kw):
  out.append(dict(label=label,input=None if content is None else list(content),index=37,period=9,chunk=4096,close=0,readFailAt=-1,**kw))
 add('original',raw);add('missing',None);add('empty',b'');add('whitespace',b' \t\r\n');add('now',b'now 0 4 <end>');add('dont-update',b'dont_update 2 7 <end>')
 date=b'2026/09/10/12/34/56';add('date',date+b' 3 5 <end>')
 for i in range(4):add('partial-'+str(i),b' '.join([b'now',b'3',b'5',b'<end>'][:i]))
 for end in (b'<END>',b'<end>x',b'x',b'<end>\0x'):add('end-'+end.hex(),b'now 1 2 '+end)
 for d in (b'nowX',b'dont_updateX',b'0/0/0/0/0/0',b'9999/99/99/99/99/99',b'-1/-1/-1/-1/-1/-1',b'20260/09/10/12/34/56',b'2026/009/10/12/34/56',b'2026-09/10/12/34/56',b'2026/09/10/12/34/56junk',b'+1/+1/+1/+1/+1/+1'):
  add('date-'+d.hex(),d+b' 3 5 <end>')
 for i in range(6):
  for v in (b'x',b'-99',b'',b'+'):
   fields=date.split(b'/');fields[i]=v;d=b'/'.join(fields);add('field-'+str(i)+'-'+v.hex(),d+b' 3 5 <end>')
 for i in range(6):add('date-short-'+str(i),b'/'.join(date.split(b'/')[:i])+b' 3 5 <end>')
 for i in (1,2):
  for v in (b'x',b'+',b'-99',b'-1',b'2147483647',b'-2147483648',b'4294967296',b'4294967197',b'17junk'):
   f=[b'now',b'3',b'5',b'<end>'];f[i]=v;add('number-'+str(i)+'-'+v.decode(),b' '.join(f))
 for idx,per in [(-99,9),(37,-99),(-99,-99),(-2147483648,2147483647)]:
  add('retained-'+str(idx)+'-'+str(per),b'now x x <end>');out[-1].update(index=idx,period=per)
 for chunk in (1,7):
  for content in (raw,date+b' 3 5 <end>',b'now x x <end>',b'now 3 5 <end>\0ignored'):
   add('chunk-'+str(chunk)+'-'+content.hex(),content);out[-1]['chunk']=chunk
 for close in (-2147483648,-1,1,2147483647):
  add('close-'+str(close),raw);out[-1]['close']=close
 for chunk in (1,7,4096):
  for fail in (0,1,2):
   add('readfail-'+str(chunk)+'-'+str(fail),raw);out[-1].update(chunk=chunk,readFailAt=fail)
 return [dict(s,ramp=ramp,label=s['label']+('-ramp' if ramp else '-a5')) for ramp in (False,True) for s in out]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=Path(a.output)
 assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
 source=Path(__file__).read_bytes();path.with_name(path.stem+'-source.py').write_bytes(source)
 runner=MenuInfoReading();cases=[]
 for i,s in enumerate(specs()[:a.limit]):
  c=runner.step(s);cases.append(c);part=parts/f'{i+1:04d}.json';temp=part.with_suffix('.tmp');temp.write_text(json.dumps(dict(case=c,blobs=runner.blobs),separators=(',',':'))+'\n');os.replace(temp,part)
  print(i+1,s['label'],c['result'],'unknown' if c['unknown'] else 'known',flush=True)
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,producerSHA256=digest(source),dependencies={n:digest((ROOT/'tools'/n).read_bytes()) for n in ['oracle_crt.py','oracle_bitmap_drawing.py','inspect_original.py','import_ntsd.py']},adinfo=dict(path='data/adinfo.txt',sha256=digest((DEFAULT_SOURCE/'data/adinfo.txt').read_bytes())),cases=cases,blobs=runner.blobs,instructions=runner.all_pcs)
 raw=(json.dumps(d,separators=(',',':'))+'\n').encode();temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path)
 print(json.dumps(dict(cases=len(cases),unknown=sum(c['unknown'] is not None for c in cases),bytes=len(raw),sha256=digest(raw),instructions=len(runner.all_pcs))),flush=True)
if __name__=='__main__':main()
