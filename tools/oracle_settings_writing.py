#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole423230 settings writer with actual VC80 fprintf/fclose.
Independent helper calls on persistent PE/global storage; first field inputs
are explicitly derived from original control.txt, not Windows startup. Shared
declared FILE flags102/output buffer and descriptor IO boundaries retain every
print/flush/close snapshot. Names share raw globals and11-byte strides. Null
FILE stops BEFORE first fprintf423260; unterminated strings stop before the
first out-of-domain read. No real filesystem, menu caller or Windows claim.
"""
import argparse,json,struct,subprocess
from oracle_menu_info_writing import MenuInfoWriting,GLOBAL,SIZE,SP,OPEN,FPRINT,REGISTERS
from oracle_crt import FILE,INPUT,PTD,STOP,DLL_SHA256
from oracle_bitmap_drawing import digest,packed
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ESP,UC_X86_REG_EIP

NAME=0x44FCC0
LITERALS=[(0x449134,10),(0x449120,10),(0x449660,11)]

class SettingsWriting(MenuInfoWriting):
 def __init__(self,control=False):
  super().__init__(control)
  self.defaults=[dict(address=p,bytes=list(self.uc.mem_read(p,n))) for p,n in LITERALS]
 def changed(self,uc,access,p,size,value,data):
  if not self.active:return
  if INPUT<=p and p+size<=INPUT+self.capacity:self.mask[p-INPUT:p-INPUT+size]=b'\1'*size
  else:
   pc=uc.reg_read(UC_X86_REG_EIP);assert GLOBAL<=p and p+size<=GLOBAL+SIZE and 0x423230<=pc<=0x423475,(hex(pc),hex(p),size)
   self.event('write',[p,size,value&((1<<(8*size))-1)])
 def code(self,uc,pc,size,data):
  if not self.active:return
  sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
  if pc==0x423260 and self.u32(sp)==0:
   self.end='nullFile';uc.emu_stop();return
  if pc in (0x423297,0x4232C1,0x423437,0x423456):
   p=uc.reg_read(UC_X86_REG_EAX)
   if not GLOBAL<=p<GLOBAL+SIZE:self.end='unterminatedName';uc.emu_stop();return
  if pc==OPEN:
   assert self.cstr(arg(0))==b'data\\control.txt' and self.cstr(arg(1))==b'w'
   self.event('open',[FILE if self.available else 0],[self.cstr(arg(0)),self.cstr(arg(1))],**self.snapshot());self.ret(FILE if self.available else 0);return
  if pc==FPRINT:
   assert self.pending is None and arg(0)==FILE
   fmt=self.cstr(arg(1)).decode('latin1');args=[FILE];strings=[]
   if fmt in ('%d ','%d\n'):args.append(arg(2))
   elif fmt in ('%s','%s\n'):strings=[list(self.cstr(arg(2)))]
   elif fmt=='%s %s %s %s\n':strings=[list(self.cstr(arg(2+i))) for i in range(4)]
   else:assert fmt=='\n',repr(fmt)
   self.pending=dict(kind='print',arguments=args,strings=strings,format=fmt,returnPC=self.u32(sp),entrySP=sp,saved=[uc.reg_read(r) for r in REGISTERS]);return
  super().code(uc,pc,size,data)
 def writer_step(self,label,writes=(),capacity=4096,available=True,action='full',fail_at=-1,close=0):
  stimulus=[]
  for p,v in writes:
   raw=struct.pack('<I',v&0xFFFFFFFF) if isinstance(v,int) else v;self.uc.mem_write(p,raw);stimulus.append(dict(address=p,bytes=raw.hex()))
  self.capacity=capacity;self.available=available;self.write_mode=action;self.fail_at=fail_at;self.close_result=close;self.write_index=0
  backing=bytes(i%256 for i in range(capacity)) if self.control else b'\xa5'*capacity
  self.uc.mem_write(INPUT,backing);self.mask=bytearray(capacity);self.uc.mem_write(FILE,struct.pack('<8I',INPUT,capacity,INPUT,0x102,0xFFFFFFFF,0,capacity,0));self.put(PTD+8,0)
  self.events=[];self.pending=None;self.end='returned';self.put(SP,STOP);self.uc.reg_write(UC_X86_REG_ESP,SP)
  saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
  self.active=True
  try:self.uc.emu_start(0x423230,STOP,count=10_000_000)
  except Exception:
   print('SETTINGS WRITE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-2:],self.pending,flush=True);raise
  finally:self.active=False
  pc=self.uc.reg_read(UC_X86_REG_EIP);assert self.pending is None
  if self.end=='returned':assert pc==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and saved==[self.uc.reg_read(r) for r in REGISTERS]
  else:assert pc in (0x423260,0x423297,0x4232C1,0x423437,0x423456)
  return dict(label=label,stimulus=stimulus,capacity=capacity,available=available,writeMode=action,failAt=fail_at,closeResult=close,backing=self.blob(backing),events=self.events,
   continuation=self.end,result=self.uc.reg_read(UC_X86_REG_EAX) if self.end=='returned' else None,endPC=pc,endSP=self.uc.reg_read(UC_X86_REG_ESP),**self.snapshot())
 def capture_settings(self):
  raw=(DEFAULT_SOURCE/'data/control.txt').read_bytes();logical=raw.replace(b'\r\n',b'\n');lines=logical.splitlines();source=[]
  for group in range(4):
   words=[int(x) for x in lines[group].split()];assert len(words)==11
   source.extend((0x44FB70+group*0x50+i*4,n) for i,n in enumerate(words))
  source.extend((NAME+i*11,name.replace(b'`',b' ')+b'\0') for i,name in enumerate(lines[4].split()))
  source.extend([(0x450BE8,int(lines[5])),(0x450BE4,int(lines[6])),(0x44FD18,lines[7]+b'\0'),(0x44F890,lines[8]+b'\0'),(0x44F900,lines[9]+b'\0')])
  cases=[self.writer_step('original-control-fields',source),self.writer_step('repeat-source-fields')]
  values=(-2147483648,-99,-1,0,1,2147483647)
  for shift in range(len(values)):
   writes=[(0x44FB70+g*0x50+i*4,values[(g*11+i+shift)%len(values)]) for g in range(4) for i in range(11)]
   writes += [(0x450BE8,values[shift]),(0x450BE4,values[-1-shift])]
   for capacity in (1,7,64,4096):cases.append(self.writer_step(f'numbers-{shift}-{capacity}',writes,capacity=capacity))
  for empty in range(16):
   writes=[(NAME+i*11,(b'\0staleTAIL!' if empty&(1<<i) else f'P{i} Q{i}'.encode()+b'\0')) for i in range(4)]
   cases.append(self.writer_step(f'empty-names-{empty}',writes,capacity=7))
  names=[b' ',b'`',b"'",b'A` B',b'  two  words  ',b'%s %d %%',b'with\ttab\r\nline',bytes(range(128,256))]
  names += [(b' a`b'*150)[:n] for n in (10,11,12,21,22,33,43,44,87,99,111,255,511)]
  for i,name in enumerate(names):
   for capacity in (1,7,4096):
    cases.append(self.writer_step(f'overlapping-name-{i}-{capacity}',[(NAME,name+b'\0')],capacity=capacity))
  for i in range(4):cases.append(self.writer_step(f'overlap-repeat-{i}',[(NAME,b'A `B C `D '*8+b'\0')] if i==0 else (),capacity=7))
  for empty in range(8):
   fields=[0x44FD18,0x44F900,0x44F890]
   cases.append(self.writer_step(f'empty-metadata-{empty}',[(p,b'\0stale metadata tail\0' if empty&(1<<i) else b'field %s ` \x80\xff\0') for i,p in enumerate(fields)],capacity=7))
  for capacity in (1,7,64,4096):
   cases.append(self.writer_step(f'null-file-{capacity}',capacity=capacity,available=False))
   for action in ('error','zero','short'):
    for fail_at in (0,1,2,5,10,48,100):cases.append(self.writer_step(f'io-{capacity}-{action}-{fail_at}',capacity=capacity,action=action,fail_at=fail_at))
   for close in (-2147483648,-1,0,1,2147483647):cases.append(self.writer_step(f'close-{capacity}-{close}',capacity=capacity,close=close))
  cases.append(self.writer_step('unterminated-name',[(NAME,b'\xa5'*(GLOBAL+SIZE-NAME))],capacity=7))
  written=b''.join(bytes(e['strings'][0]) for e in cases[0]['events'] if e['kind']=='writeFile');assert written==logical,(written,logical)
  return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,initialGlobals=self.initial_globals,
   source=dict(path='data/control.txt',raw=self.blob(raw),logical=self.blob(logical)),defaults=self.defaults,cases=cases,blobs=self.blobs)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
 if a.accept:
  subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True);pending=[]
  for suffix in ('','-control'):
   candidate=ROOT/'build/research'/f'settings-writing{suffix}.json';report=json.loads(candidate.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
   data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'settings-writing{suffix}-check.json';temp.write_bytes(data)
   result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--settings-writing',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
   if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
   fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((ROOT/'docs/evidence'/candidate.name,report,fixture,data))
  for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
  return
 doc=SettingsWriting(a.control).capture_settings();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'settings-writing{suffix}.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),
  events={kind:sum(e['kind']==kind for c in doc['cases'] for e in c['events']) for kind in sorted({e['kind'] for c in doc['cases'] for e in c['events']})},nativeCompared=False)
 (ROOT/'build/research'/f'settings-writing{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
