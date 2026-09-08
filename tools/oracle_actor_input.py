#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Generic actor input rules, original413080..4132ef and real helper children.
Declared synthetic Actor/Frame/global probes, not game DAT or natural gameplay.
All Actor bytes/masks, guards and whole-helper ABIs are checked. No game-code
stubs; only the separately checked constructor's memset is a host boundary.
"""
import argparse,base64,hashlib,itertools,json,os,struct,subprocess,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_state import Constructors,AREA,ACTOR_SIZE,STACK,STOP
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP

OBJECT=0x50000000
REGS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
COMBOS=[0x412800,0x4128F0,0x4129E0,0x412AC0,0x412BA0,0x412C90,0x412D80,0x412E60,0x412F40]
BUFFERS=[0xbe,0xbf,0xc0,0xc3,0xc4,0xc5,0xc2]
ROUTES=[(0xc2,0xbe,0x30),(0xc3,0xbe,0x30),(0xc4,0xbe,0x34),(0xc5,0xbe,0x38),
 (0xc2,0xbf,0x3c),(0xc3,0xbf,0x3c),(0xc4,0xbf,0x40),(0xc5,0xbf,0x44),(0xbf,0xbe,0x48)]
def d(offset,value):return [offset,struct.pack('<I',value&0xffffffff).hex()]
def b(offset,value):return [offset,bytes([value&255]).hex()]
def f(index,offset,value):return [index,*d(offset,value)]
def digest(data):return hashlib.sha256(data).hexdigest()

class ActorInput(Constructors):
 def __init__(self):
  super().__init__();self.running=False;self.instructions=set();self.uc.mem_map(OBJECT,0x40000)
  self.uc.hook_add(UC_HOOK_CODE,self.code)
  self.uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=AREA,end=AREA+0x3fff)
  self.templates={}
  for fill in ('a5','ramp'):
   raw=b'\xa5'*ACTOR_SIZE if fill=='a5' else bytes(i&255 for i in range(ACTOR_SIZE))
   self.templates[fill]=self.capture('actor',raw,0x100 if fill=='a5' else 0x1400)
 def code(self,uc,pc,size,data):
  if not self.running:return
  if pc==self.until:uc.emu_stop();return
  self.instructions.add(pc)
  assert any(a<=pc<=b for a,b in [(0x40E170,0x40E48A),(0x412800,0x4132EF)]),hex(pc)
 def read(self,uc,access,address,size,value,data):
  if self.running:
   assert self.target<=address<address+size<=self.target+self.size
   assert all(self.mask[address-self.target:address-self.target+size]),(hex(uc.reg_read(UC_X86_REG_EIP)),hex(address-self.target),size)
 def call(self,entry,args=(),stop=STOP,pop=0):
  sp=STACK+0xf000;saved=[0x11223344,0x22334455,0x33445566,0x44556677]
  self.uc.mem_write(sp,struct.pack('<'+'I'*(1+len(args)),STOP,*[v&0xffffffff for v in args]))
  self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,self.target)
  for reg,value in zip(REGS,saved):self.uc.reg_write(reg,value)
  self.until=stop;self.running=True
  try:self.uc.emu_start(entry,0,count=20000)
  finally:self.running=False
  assert self.uc.reg_read(UC_X86_REG_EIP)==stop
  if stop==STOP:
   assert self.uc.reg_read(UC_X86_REG_ESP)==sp+4+pop
   assert [self.uc.reg_read(r) for r in REGS]==saved
  else:assert self.uc.reg_read(UC_X86_REG_ESP)==sp-20
  return self.uc.reg_read(UC_X86_REG_EAX)
 def probe(self,item,index):
  item=dict(item);item['fill']='a5' if index%2==0 else 'ramp';t=self.templates[item['fill']]
  self.target=int(t['address'],16);self.size=ACTOR_SIZE;self.mask=t['defined'].copy();self.writes=[]
  self.uc.mem_write(self.target-16,b'\x96'*16+bytes.fromhex(t['bytes'])+b'\x69'*16)
  patches=[d(0x368,OBJECT),*item.get('actor',[])];item['actor']=patches
  for offset,hexadecimal in patches:
   raw=bytes.fromhex(hexadecimal);self.uc.mem_write(self.target+offset,raw);self.mask[offset:offset+len(raw)]=[True]*len(raw)
  obj=bytearray(0x40000);struct.pack_into('<I',obj,0x6f4,item.get('sourceID',2))
  for n in (0,2,3,300):obj[0x7a4+n*0x178]=1
  struct.pack_into('<i',obj,0x7a4+2*0x178+0x4c,100)
  struct.pack_into('<i',obj,0x7a4+3*0x178+0x4c,20)
  for n,offset,hexadecimal in item.get('frames',[]):
   raw=bytes.fromhex(hexadecimal);obj[0x7a4+n*0x178+offset:0x7a4+n*0x178+offset+len(raw)]=raw
  self.uc.mem_write(OBJECT,bytes(obj))
  globals_={0x44d034:1,0x458428:0};globals_.update(dict(item.get('globals',[])));item['globals']=list(globals_.items())
  for address,value in globals_.items():self.uc.mem_write(address,struct.pack('<I',value&0xffffffff))
  before=bytes(self.uc.mem_read(0x44d000,0xb440));op=item['operation']
  if op=='edges':self.call(0x413080,(1,0),stop=0x413208)
  elif op=='prefix':self.call(0x413080,(1,item.get('mode',0)),stop=0x4132EF)
  elif op=='combos':
   for entry in COMBOS:self.call(entry,(item.get('mode',0),) if entry==0x412F40 else (),pop=4 if entry==0x412F40 else 0)
  elif op=='actions':
   # Explicit interior-slice probe, valid enclosing stack with the original
   # zero EBP from41308c. No helper trampoline replaces the source body.
   sp=STACK+0xf000;self.uc.reg_write(UC_X86_REG_ESP,sp-20);self.uc.reg_write(UC_X86_REG_ESI,self.target);self.uc.reg_write(UC_X86_REG_EBP,0)
   self.until=0x4132EF;self.running=True
   try:self.uc.emu_start(0x41324C,0,count=20000)
   finally:self.running=False
   assert self.uc.reg_read(UC_X86_REG_EIP)==self.until and self.uc.reg_read(UC_X86_REG_ESP)==sp-20
  elif op=='transfer':self.call(0x40E2D0,(item['target'],),pop=4)
  elif op=='invalidates':item['result']=self.call(0x40E170,(item['key'],item['advanced']),pop=8)
  else:raise ValueError(op)
  assert bytes(self.uc.mem_read(OBJECT,len(obj)))==bytes(obj) and bytes(self.uc.mem_read(0x44d000,0xb440))==before
  assert self.uc.mem_read(self.target-16,16)==b'\x96'*16 and self.uc.mem_read(self.target+ACTOR_SIZE,16)==b'\x69'*16
  item.update(after=bytes(self.uc.mem_read(self.target,ACTOR_SIZE)).hex(),defined=bytes(self.mask).hex())
  return item

def probes():
 for value in (-128,-1,0,1,5,6,127):
  for previous,current in itertools.product((0,1,2,255),repeat=2):
   yield dict(label=f'edges-{value}-{previous}-{current}',operation='edges',actor=[*[b(o,value) for o in BUFFERS+[0xc1]],*[b(o,previous) for o in range(0xc6,0xcd)],*[b(o,current) for o in range(0xcd,0xd4)]])
 for mask,key,flag in itertools.product(range(128),(0x55,0x44,0x4c,0x52,0x64,0x6a,0x61,0,255),(0,1,2,-1)):
  yield dict(label=f'invalidate-{mask}-{key}-{flag}',operation='invalidates',key=key,advanced=flag,actor=[b(o,5 if mask>>i&1 else 4) for i,o in enumerate(BUFFERS)])
 for enabled,target,present,cost in itertools.product((0,1),(2,-2,999,-999),(0,1),(0,100,101,1999,2000,-1001,2147483647,-2147483648)):
  dest=0 if abs(target)==999 else abs(target)
  for hp,mp in ((20,100),(21,100),(0,-1)):
   yield dict(label=f'transfer-{enabled}-{target}-{present}-{cost}-{hp}-{mp}',operation='transfer',target=target,
    actor=[d(0x2fc,hp),d(0x308,mp),d(0x34c,2147483647),d(0x350,2147483647),b(0x80,255),*[b(o,5) for o in BUFFERS]],
    frames=[f(dest,0,present),f(dest,0x4c,cost)],globals=[[0x44d034,enabled]])
 for route,(direction,finish,field) in enumerate(ROUTES):
  for progress,mask in itertools.product((0,1,2,3,4,255),range(128)):
   yield dict(label=f'combo-{route}-{progress}-{mask}',operation='combos',actor=[b(0xd4+route,progress),*[b(o,5 if mask>>i&1 else 4) for i,o in enumerate(BUFFERS)]],frames=[f(0,field,2)])
 for route,weapon,target,hp,mp in itertools.product(range(9),(0,2,101),(-2,0,2,399,999),(0,500),(99,100)):
  field=ROUTES[route][2]
  yield dict(label=f'combo-gates-{route}-{weapon}-{target}-{hp}-{mp}',operation='combos',actor=[b(0xd4+route,3),d(0x98,weapon),d(0x2fc,hp),d(0x308,mp)],frames=[f(0,field,target)])
 for source,hp,gate,previous,owner in itertools.product((2,6),(177,178),(0,1),(-1,0),(0,1)):
  yield dict(label=f'ja-special-{source}-{hp}-{gate}-{previous}-{owner}',operation='combos',sourceID=source,
   actor=[b(0xdc,3),b(0xbe,5),d(0x2fc,hp),d(0x324,previous),d(0x328,owner),d(0x338,123)],frames=[f(0,0x48,300)],globals=[[0x458428,gate]])
 for values,targets in itertools.product(itertools.product((-128,-1,0,1,5),repeat=3),((2,3,-2),(399,2,3),(0,2,3),(0,0,2))):
  yield dict(label=f'actions-{values}-{targets}',operation='actions',actor=[b(o,v) for o,v in zip((0xbe,0xc0,0xbf),values)],frames=[f(0,o,v) for o,v in zip((0x24,0x28,0x2c),targets)])
 for mask,progress,mode in itertools.product(range(128),(0,1,2,3),(0,1,4)):
  yield dict(label=f'prefix-{mask}-{progress}-{mode}',operation='prefix',mode=mode,
   actor=[*[b(0xcd+i,(mask>>i)&1) for i in range(7)],*[b(o,progress) for o in range(0xd4,0xdd)]],
   frames=[*[f(0,o,2) for o in range(0x30,0x4c,4)],f(0,0x24,3),f(2,0x24,-3),f(3,0x28,999)])

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--accept',action='store_true');a=p.parse_args()
 vm=ActorInput();cases=[vm.probe(item,i) for i,item in enumerate(probes())]
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,cases=cases,instructions=sorted(vm.instructions))
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/actor-input.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),operations=dict(Counter(c['operation'] for c in cases)),nativeCompared=False)
 (ROOT/'build/research/actor-input.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
 if a.accept:
  # Test the raw, newly executed source results before publishing a fixture.
  env=dict(os.environ,NTSD_ACTOR_INPUT_CORPUS=str(path))
  subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalActorInputTests'],env=env,check=True)
  payload=raw[:-1];packed=(json.dumps(dict(count=len(payload),sha256=digest(payload),deflate=base64.b64encode(zlib.compress(payload,9,wbits=-15)).decode()),separators=(',',':'))+'\n').encode()
  fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-actor-input.json';fixture.write_bytes(packed)
  report.update(nativeCompared=True,fixture=fixture.name,fixtureSHA256=digest(packed),fixtureBytes=len(packed))
  (ROOT/'docs/evidence/actor-input.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
