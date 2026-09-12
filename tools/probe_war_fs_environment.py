#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "capstone==5.0.7"]
# ///
"""Four original NTSD instructions verify the War harness FS/NULL separation.
Pinned EXE supplies prologue FS load/store and40c116/43d2fd data accesses.
Fresh Unicorn2.1.4 x86 VMs use a declared GDT/FS head at7d010000 with linear page0
unmapped. Observe segment-derived addresses, bytes and actual invalid-memory
faults, stopping each faulted VM. This corrects synthetic reference addressing;
it is not Windows/host CPU/TEB behavior, control-pointer corruption, protection
bypass, a full caller or Native comparison. LIB_WAR_PREPARATION_ERRORS_FS.md
defines the finite environment check. Keep all original and historical bytes.
"""
import argparse,datetime,hashlib,json,struct
from pathlib import Path
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE,UC_HOOK_MEM_INVALID,UcError
from unicorn.x86_const import *
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

FS_HEAD=0x7d010000
GDT=0x7d000000

def descriptor(base):
 limit=0xfffff
 return struct.pack('<Q',(limit&0xffff)|((base&0xffff)<<16)|(((base>>16)&255)<<32)|(0x93<<40)|(((limit>>16)&15)<<48)|(0xc<<52)|(((base>>24)&255)<<56))

def install_fs(uc):
 for p in (GDT,FS_HEAD):
  assert all(p+0x1000<=a or p>b for a,b,_ in uc.mem_regions())
  uc.mem_map(p,0x1000)
 raw=bytes(24)+descriptor(FS_HEAD);uc.mem_write(GDT,raw)
 uc.reg_write(UC_X86_REG_GDTR,(0,GDT,len(raw)-1,0));uc.reg_write(UC_X86_REG_FS,0x18)
 assert uc.reg_read(UC_X86_REG_FS_BASE)==FS_HEAD
 return dict(gdtAddress=GDT,gdtBytes=raw.hex(),gdtr=list(uc.reg_read(UC_X86_REG_GDTR)),fs=uc.reg_read(UC_X86_REG_FS),fsBase=uc.reg_read(UC_X86_REG_FS_BASE))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert hashlib.sha256(raw).hexdigest()==EXE_SHA256;pe=PE(raw);decoder=Cs(CS_ARCH_X86,CS_MODE_32)
 def decode(start,end):
  offset=pe.offset(start-pe.base);return list(decoder.disasm(raw[offset:offset+end-start],start))
 fs=[i for i in decode(0x41bc90,0x41bcd0) if 'fs:' in i.op_str]
 assert len(fs)==2
 probes=[('fsLoad',fs[0]),('fsStore',fs[1]),('nullRead',decode(0x40c116,0x40c118)[0]),('nullWrite',decode(0x43d2fd,0x43d2ff)[0])]
 cases=[]
 for name,insn in probes:
  u=Uc(UC_ARCH_X86,UC_MODE_32);u.mem_map(0x400000,0x50000);u.mem_write(insn.address,bytes(insn.bytes));setup=install_fs(u)
  before=struct.pack('<I',0x12345678);u.mem_write(FS_HEAD,before);accesses=[];invalid=[]
  def record(uc,access,address,size,value,data):accesses.append(dict(access=access,address=address,size=size,value=value))
  def fault(uc,access,address,size,value,data):invalid.append(dict(access=access,address=address,size=size,value=value,pc=uc.reg_read(UC_X86_REG_EIP)));return False
  u.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,record);u.hook_add(UC_HOOK_MEM_INVALID,fault)
  u.reg_write(UC_X86_REG_EAX,0 if name=='nullWrite' else 0x12345678);u.reg_write(UC_X86_REG_ECX,0)
  error=None
  try:u.emu_start(insn.address,0,count=1)
  except UcError as e:error=dict(message=str(e),repr=repr(e),errno=e.errno)
  after=bytes(u.mem_read(FS_HEAD,4));pc=u.reg_read(UC_X86_REG_EIP)
  assert all(start>0 for start,_,_ in u.mem_regions()) and after==before
  if name.startswith('fs'):
   assert error is None and not invalid and len(accesses)==1 and accesses[0]['address']==FS_HEAD and pc==insn.address+len(insn.bytes)
   if name=='fsLoad':assert u.reg_read(UC_X86_REG_EAX)==0x12345678
  else:assert error and len(invalid)==1 and invalid[0]['address']==0 and pc==insn.address
  cases.append(dict(name=name,pc=insn.address,bytes=insn.bytes.hex(),instruction=insn.mnemonic+' '+insn.op_str,setup=setup,accesses=accesses,invalidAccesses=invalid,error=error,endPC=pc,eax=u.reg_read(UC_X86_REG_EAX),headBefore=before.hex(),headAfter=after.hex(),regions=list(u.mem_regions())))
 doc=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),exeSHA256=EXE_SHA256,cases=cases,originalInstructionsExecuted=4,sourceCallersExecuted=0,nativeCompared=False,windowsVerified=False)
 with a.output.open('x') as f:json.dump(doc,f,indent=2);f.write('\n')
 print(dict(cases=len(cases),fsAccesses=2,nullFaults=2,headPreserved=True))

if __name__=='__main__':main()
