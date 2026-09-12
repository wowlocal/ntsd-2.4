#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "capstone==5.0.7"]
# ///
"""Seven NTSD instructions check separate FS plus flat32-bit stack/data.
Pinned EXE supplies every opcode. Fresh Unicorn2.1.4 VMs use explicit flat
CS/DS/ES/SS and FS base7d010000; page0 is unmapped. Trace successful stack/data/FS
addresses and two actual NULL faults, without resuming faults or modifying
source/protection bytes. This corrects synthetic harness segment setup, not
Windows/host/device behavior. LIB_WAR_PREPARATION_ERRORS_FS_STACK.md defines
the finite extension after the preserved first caller's push failure.
"""
import argparse,datetime,hashlib,json,struct
from pathlib import Path
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE,UC_HOOK_MEM_INVALID,UcError
from unicorn.x86_const import *
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256
from probe_war_fs_environment import FS_HEAD,GDT,descriptor

def install_fs(uc):
 for p in (GDT,FS_HEAD):
  assert all(p+0x1000<=a or p>b for a,b,_ in uc.mem_regions());uc.mem_map(p,0x1000)
 code=bytearray(descriptor(0));code[5]=0x9b
 raw=bytes(8)+bytes(code)+descriptor(0)+descriptor(FS_HEAD);uc.mem_write(GDT,raw)
 uc.reg_write(UC_X86_REG_GDTR,(0,GDT,len(raw)-1,0))
 for reg,value in [(UC_X86_REG_CS,8),(UC_X86_REG_DS,0x10),(UC_X86_REG_ES,0x10),(UC_X86_REG_SS,0x10),(UC_X86_REG_FS,0x18)]:uc.reg_write(reg,value)
 assert uc.reg_read(UC_X86_REG_FS_BASE)==FS_HEAD
 return dict(gdtAddress=GDT,gdtBytes=raw.hex(),gdtr=list(uc.reg_read(UC_X86_REG_GDTR)),cs=uc.reg_read(UC_X86_REG_CS),ds=uc.reg_read(UC_X86_REG_DS),es=uc.reg_read(UC_X86_REG_ES),ss=uc.reg_read(UC_X86_REG_SS),fs=uc.reg_read(UC_X86_REG_FS),fsBase=uc.reg_read(UC_X86_REG_FS_BASE))

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert hashlib.sha256(raw).hexdigest()==EXE_SHA256;pe=PE(raw);decoder=Cs(CS_ARCH_X86,CS_MODE_32)
 def decode(start,end):
  offset=pe.offset(start-pe.base);return list(decoder.disasm(raw[offset:offset+end-start],start))
 fs=[i for i in decode(0x41bc90,0x41bcd0) if 'fs:' in i.op_str];assert len(fs)==2
 probes=[('fsLoad',fs[0]),('fsStore',fs[1]),('nullRead',decode(0x40c116,0x40c118)[0]),('nullWrite',decode(0x43d2fd,0x43d2ff)[0]),
  ('stackPush',decode(0x41bc90,0x41bc91)[0]),('flatRead',decode(0x40c116,0x40c118)[0]),('flatWrite',decode(0x43d2fd,0x43d2ff)[0])]
 cases=[];stack=0x10000000;sp=stack+0xf000;data=stack+0x100
 for name,insn in probes:
  u=Uc(UC_ARCH_X86,UC_MODE_32);u.mem_map(0x400000,0x50000);u.mem_map(stack,0x10000);u.mem_write(insn.address,bytes(insn.bytes));setup=install_fs(u)
  head=struct.pack('<I',0x12345678);u.mem_write(FS_HEAD,head);u.mem_write(data,head);accesses=[];invalid=[]
  def record(uc,access,address,size,value,opaque):accesses.append(dict(access=access,address=address,size=size,value=value))
  def fault(uc,access,address,size,value,opaque):invalid.append(dict(access=access,address=address,size=size,value=value,pc=uc.reg_read(UC_X86_REG_EIP)));return False
  u.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,record);u.hook_add(UC_HOOK_MEM_INVALID,fault)
  u.reg_write(UC_X86_REG_EAX,data if name=='flatWrite' else 0 if name=='nullWrite' else 0x12345678)
  u.reg_write(UC_X86_REG_ECX,data if name=='flatRead' else 0xabcdef01 if name=='flatWrite' else 0)
  u.reg_write(UC_X86_REG_EBP,0x11223344);u.reg_write(UC_X86_REG_ESP,sp)
  error=None
  try:u.emu_start(insn.address,0,count=1)
  except UcError as e:error=dict(message=str(e),repr=repr(e),errno=e.errno)
  after=bytes(u.mem_read(FS_HEAD,4));pc=u.reg_read(UC_X86_REG_EIP)
  assert all(start>0 for start,_,_ in u.mem_regions()) and after==head
  if name.startswith('null'):assert error and len(invalid)==1 and invalid[0]['address']==0 and pc==insn.address
  else:
   expected=FS_HEAD if name.startswith('fs') else sp-4 if name=='stackPush' else data
   assert error is None and not invalid and len(accesses)==1 and accesses[0]['address']==expected and pc==insn.address+len(insn.bytes)
   if name in ('fsLoad','flatRead'):assert u.reg_read(UC_X86_REG_EAX)==0x12345678
   if name=='stackPush':assert u.reg_read(UC_X86_REG_ESP)==sp-4 and bytes(u.mem_read(sp-4,4))==struct.pack('<I',0x11223344)
   if name=='flatWrite':assert bytes(u.mem_read(data,4))==struct.pack('<I',0xabcdef01)
  cases.append(dict(name=name,pc=insn.address,bytes=insn.bytes.hex(),instruction=insn.mnemonic+' '+insn.op_str,setup=setup,accesses=accesses,invalidAccesses=invalid,error=error,endPC=pc,eax=u.reg_read(UC_X86_REG_EAX),esp=u.reg_read(UC_X86_REG_ESP),headBefore=head.hex(),headAfter=after.hex(),regions=list(u.mem_regions())))
 with a.output.open('x') as f:json.dump(dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),exeSHA256=EXE_SHA256,cases=cases,originalInstructionsExecuted=7,sourceCallersExecuted=0,nativeCompared=False,windowsVerified=False),f,indent=2);f.write('\n')
 print(dict(cases=7,fsAccesses=2,nullFaults=2,flatDataAccesses=2,stackPushes=1))

if __name__=='__main__':main()
