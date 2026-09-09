#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole4196f0..419798 with a constructed400-slot pool and CW037f.
Original constructors, activity/hitstop/count gates, aliases and binary64 bit
patterns. Full pool/masks/global hashes and ordered writes. Masked x87 status
is recorded as source evidence, not modeled by the native game. Separate
actual VC80 sprintf controls exercise all signed-byte diagnostic inputs.
"""
import argparse,itertools,json,random,struct
from collections import Counter
from oracle_world_control import WorldControl,WORLD,POOL,BODY_SP,REGS,d,b,q,digest
from oracle_state import STOP
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ECX,UC_X86_REG_ESI,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW

class WorldImpulses(WorldControl):
 def code(self,uc,pc,size,data):
  if not self.running:return
  assert 0x4196f0<=pc<=0x419798,hex(pc);self.instructions.add(pc)
 def access(self,uc,access,address,size,value,data):
  super().access(uc,access,address,size,value,data)
  if self.running and access==UC_MEM_WRITE and POOL<=address<POOL+400*0x500:
   actor,offset=divmod(address-POOL,0x500)
   self.events.append(dict(slot=uc.reg_read(UC_X86_REG_ESI),actor=actor,offset=offset,bytes=(value&((1<<(size*8))-1)).to_bytes(size,'little').hex()))
 def execute(self):
  saved=[self.uc.reg_read(r) for r in REGS]
  self.uc.mem_write(BODY_SP-4,struct.pack('<I',STOP));self.uc.reg_write(UC_X86_REG_ESP,BODY_SP-4);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
  self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.uc.reg_write(UC_X86_REG_FPSW,0)
  self.uc.emu_start(0x4196f0,STOP,count=20000)
  assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and [self.uc.reg_read(r) for r in REGS]==saved
  assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
  assert (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  self.finished=True
 def probe(self,item,index):
  result=super().probe(item,index);result['fpsw']=self.uc.reg_read(UC_X86_REG_FPSW);return result

def bits(offset,value):return [offset,struct.pack('<Q',value).hex()]
def one(label,count,values,group='numbers',activity=1,stop=0,slot=0):
 return dict(label=label,group=group,active=[[slot,activity]],actors=[[slot,[d(0x20,count),d(0xb4,stop),*[bits(o,v) for o,v in zip((0x28,0x30,0x38),values)],q(0x40,123.5),q(0x48,-98.25),bits(0x50,0x8000000000000000)]]])
def probes():
 values=[0x3ff0000000000000,0xc00ccccccccccccd,0x8000000000000000]
 for activity,stop,count in itertools.product((0,1,127,128,255),(-2147483648,-1,0,1,2147483647),(-2147483648,-2,-1,0,1,2,2147483647)):
  yield one(f'gates-{activity}-{stop}-{count}',count,values,'gates',activity,stop,399)
 magnitude=[0,1,2,0xfffffffffffff,0x10000000000000,0x10000000000001,0x3fb999999999999a,0x3fd5555555555555,0x3fefffffffffffff,0x3ff0000000000000,0x4000000000000000,0x7fdfffffffffffff,0x7fefffffffffffff,0x7ff0000000000000,0x7ff0000000000001,0x7ff4000000001234,0x7ff8000000000000,0x7ff8123456789abc,0x7fffffffffffffff]
 for count,m,sign in itertools.product((-2147483648,-2147483647,-3,-2,-1,0,1,2,3,6,2147483646,2147483647),magnitude,(0,1<<63)):
  value=m|sign;yield one(f'bits-{count}-{value:016x}',count,[value,value^0x8000000000000000,value],'binary64')
 rng=random.Random(0x4196f0) # Test stimulus only, never game randomness.
 for n in range(320):
  values=[rng.getrandbits(64) for _ in range(3)];count=rng.randrange(-2147483648,2147483648)
  yield one(f'varied-{n}',count,values,'varied',slot=(n*137)%400)
 # Test inputs selected by exact rational midpoint search: rounding the quotient
 # first to64 significant bits and then to53 differs from a direct53-bit round.
 # No calculated expected value is supplied to either implementation.
 for n,(value,count) in enumerate([(0x3ffc111680d7849f,789644137),(0x3ffbf6b8b7201fb2,1696560701),
  (0x3ffe824c592346fa,726323949),(0x3ff251e9f18052db,663525555),(0x3ff49eaa6f145d9a,2104927986),
  (0x3ffd9ee9e08a906f,78278628),(0x3ffbf4b39dea1236,1446092060),(0x3ff69663cbaf11b3,1825008997)]):
  for sign in (1,-1):
   yield one(f'double-round-{n}-{sign}',count if sign==1 else -count-2,[value,value^0x8000000000000000,value+1],'double-rounding')
 for slot,owner,stop,count in itertools.product((0,199,399),(0,199,399),(0,1),(0,1,2,-1,2147483647)):
  if slot==owner:continue
  item=one(f'alias-{slot}-{owner}-{stop}-{count}',count,values,'aliases',stop=stop,slot=owner)
  item.update(active=[[slot,255],[owner,1]],aliases=[[slot,owner]]);yield item
 for alias in (False,True):
  yield dict(label=f'all400-{alias}',group='all-slots',active=[[i,1+(i%255)] for i in range(400)],aliases=[[i,399] for i in range(400)] if alias else [],actors=[[i,[d(0x20,i%7-3),d(0xb4,1 if i%11==0 else 0),q(0x28,i+0.1),q(0x30,-i-.3),q(0x38,i/3)]] for i in range(400)])
 yield dict(label='empty',group='empty')

def formats():
 from oracle_crt import CRT,DLL_SHA256,AREA,PTD
 from unicorn import UC_HOOK_CODE
 crt=CRT();crt.uc.hook_add(UC_HOOK_CODE,lambda uc,pc,size,data:crt.ret(PTD),begin=0x78132db2,end=0x78132db2)
 fmt=b'u%d d%d l%d r%d a%d d%d ';crt.uc.mem_write(AREA+0x18000,fmt+b'\0');cases=[]
 for i in range(256):
  inputs=[(i+j*43)%256 for j in range(6)];arguments=[n if n<128 else n-256 for n in inputs]
  crt.uc.mem_write(AREA+0x18100,b'\xa5'*128)
  result=crt.call(0x7817775d,[AREA+0x18100,AREA+0x18000,*[v&0xffffffff for v in arguments]])
  raw=bytes(crt.uc.mem_read(AREA+0x18100,128));end=raw.index(0)
  assert result==end and raw[end+1:]==b'\xa5'*(127-end)
  cases.append(dict(inputs=inputs,bytes=list(raw[:end]),result=result))
 return dict(dllSHA256=DLL_SHA256,format=list(fmt),cases=cases)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sample',action='store_true');a=p.parse_args()
 vm=WorldImpulses();cases=[]
 for n,item in enumerate(probes()):
  if a.sample and item['group'] not in ('binary64',):continue
  cases.append(vm.probe(item,n))
  if a.sample and len(cases)==12:break
  if len(cases)%250==0:print('WORLD IMPULSES',len(cases),flush=True)
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,cases=cases,instructions=sorted(vm.instructions),fpcw=0x37f,formats=formats())
 path=ROOT/'build/original'/('world-impulses-sample.json' if a.sample else 'world-impulses.json');raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),instructions=len(vm.instructions),writes=sum(len(c['events']) for c in cases),sourceStatusWords=dict(Counter(c['fpsw'] for c in cases)),formats=len(doc['formats']['cases']),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
