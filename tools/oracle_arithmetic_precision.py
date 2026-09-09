#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original x87 load/arithmetic/store instructions under24/53/64 precision.
Declared registers, operand records and phase boundaries; no synthetic opcodes
or changed EXE constants. Sequences retain intermediates between operations.
This is arithmetic evidence, not whole gameplay or Windows FPU provenance.
"""
import json,struct,itertools,random
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from oracle_actor_input import digest
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32
from unicorn.x86_const import UC_X86_REG_ESI,UC_X86_REG_EAX,UC_X86_REG_EIP,UC_X86_REG_FPCW,UC_X86_REG_FPSW

OPERATIONS={'add':0x40e520,'subtract':0x4307be,'multiply':0x40e556,'divide':0x408425}
class Arithmetic:
 def __init__(self):
  raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(raw)==EXE_SHA256
  self.uc=Uc(UC_ARCH_X86,UC_MODE_32);self.uc.mem_map(0x400000,0x100000)
  for s in PE(raw).sections:
   if s['name']!='.rsrc':self.uc.mem_write(0x400000+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
  self.address=0x23000020;self.uc.mem_map(0x23000000,0x1000);self.instructions=set()
  self.uc.reg_write(UC_X86_REG_ESI,self.address);self.uc.reg_write(UC_X86_REG_EAX,self.address)
 def step(self,pc,end):
  self.instructions.add(pc);self.uc.emu_start(pc,0,count=1);assert self.uc.reg_read(UC_X86_REG_EIP)==end
 def load(self,bits):
  self.uc.mem_write(self.address+0x58,struct.pack('<Q',bits));self.step(0x40e51d,0x40e520)
 def run(self,ops,values,cw):
  self.uc.reg_write(UC_X86_REG_FPCW,cw);self.uc.reg_write(UC_X86_REG_FPSW,0)
  if ops and ops[0]=='divide':self.load(values[1])
  self.load(values[0])
  for n,op in enumerate(ops):
   value=values[n+1]
   if op=='divide':
    # A denominator loaded before the numerator is required by actual FDIV
    # ST,ST(1). Multi-operation division cases preload it below the first load.
    self.step(0x408425,0x408427)
   else:
    self.uc.mem_write(self.address+(0x58 if op=='subtract' else 0x40),struct.pack('<Q',value))
    pc=OPERATIONS[op];self.step(pc,pc+3)
  self.step(0x40e523,0x40e526)
  value=bytes(self.uc.mem_read(self.address+0x58,8)).hex()
  if 'divide' in ops:self.step(0x419791,0x419793)
  assert self.uc.reg_read(UC_X86_REG_FPCW)==cw and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  return value
 def probe(self,label,ops,values,cw):
  # For multiply/divide retain denominator inST1 throughout the multiply.
  if ops==['multiply','divide']:
   self.uc.reg_write(UC_X86_REG_FPCW,cw);self.uc.reg_write(UC_X86_REG_FPSW,0)
   self.load(values[2]);self.load(values[0]);self.uc.mem_write(self.address+0x40,struct.pack('<Q',values[1]))
   self.step(0x40e556,0x40e559);self.step(0x408425,0x408427);self.step(0x40e523,0x40e526)
   result=bytes(self.uc.mem_read(self.address+0x58,8)).hex();self.step(0x419791,0x419793)
   assert self.uc.reg_read(UC_X86_REG_FPCW)==cw and (self.uc.reg_read(UC_X86_REG_FPSW)>>11)&7==0
  else:result=self.run(ops,values,cw)
  return dict(label=label,operations=ops,inputs=[struct.pack('<Q',v).hex() for v in values],fpcw=cw,result=result)

def inputs():
 magnitude=[0,1,2,0xfffffffffffff,0x10000000000000,0x3e70000000000000,0x3e80000000000000,0x3ca0000000000000,
  0x3cb0000000000000,0x3fb999999999999a,0x3fefffffffffffff,0x3ff0000000000000,0x3ff0000000000001,0x4000000000000000,0x4340000000000001,0x7fefffffffffffff]
 values=[m|sign for m in magnitude for sign in (0,1<<63)]
 for op,a,b in itertools.product(OPERATIONS,values,values):
  if op=='divide' and b&0x7fffffffffffffff==0:continue
  yield f'edge-{op}-{a:x}-{b:x}',[op],[a,b]
 for bits in values:yield f'load-{bits:x}',[],[bits]
 rng=random.Random(0x445a31)
 def finite():
  while True:
   value=rng.getrandbits(64)
   if (value>>52)&0x7ff!=0x7ff:return value
 for n in range(2000):
  a,b,c=finite(),finite(),finite()
  for ops,values in [(['add'],[a,b]),(['subtract'],[a,b]),(['multiply'],[a,b]),(['divide'],[a,b]),(['multiply','add'],[a,b,c]),(['add','subtract'],[a,b,c]),(['multiply','divide'],[a,b,c])]:
   if 'divide' in ops and values[-1]&0x7fffffffffffffff==0:continue
   yield f'varied-{n}-{ops}',ops,values
 # The same midpoint witnesses as the whole4196f0 audit, plus overflow that
 # remains finite only when exponent range survives the intermediate multiply.
 for a,b,c in [(0x7fefffffffffffff,0x4000000000000000,0x4000000000000000),(1,0x3fe0000000000000,0x3fe0000000000000),
  (0x3ffc111680d7849f,0x4000000000000000,struct.unpack('<Q',struct.pack('<d',789644138))[0])]:
  yield f'extended-chain-{a:x}-{b:x}-{c:x}',['multiply','divide'],[a,b,c]

def main():
 vm=Arithmetic();cases=[]
 for n,(label,ops,values) in enumerate(inputs()):
  for cw in (0x7f,0x27f,0x37f):cases.append(vm.probe(label,ops,values,cw))
 doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,instructions=sorted(vm.instructions),cases=cases)
 raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/arithmetic-precision.json';path.write_bytes(raw)
 report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
  groups=dict(Counter('/'.join(c['operations']) or 'load' for c in cases)),instructions=sorted(vm.instructions),nativeCompared=False)
 (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
