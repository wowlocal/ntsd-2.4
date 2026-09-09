#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover original43e9db..43ea95 application service-key scan and store order.

The pinned NTSD2.4 EXE executes under Unicorn2.1.4 with declared acquired
keyboard bytes, sequence0..3, diagnostic0/1 and mode0..2. This prefix has no
helper/import calls. Observe actual key reads, stores and normal slice exit,
and verify all remaining globals/keyboard bytes are unchanged. No pointer,
security-structure, fault or device stimulus. This is not whole43e9a0, an own
match, Windows, actual input acquisition or a timed/application integration.
"""
import hashlib,itertools,json,struct
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_CODE,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_EDI,UC_X86_REG_ESI,UC_X86_REG_EDX,UC_X86_REG_ECX,UC_X86_REG_ESP,UC_X86_REG_FPCW
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE

START,STOP,SP,GLOBAL,END,KEYS=0x43e9db,0x43ea95,0x1000f000,0x44d000,0x4593a8,0x455378
FIELDS=(0x4593a4,0x450bec,0x4593a0)
REGS=(UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_EBP,UC_X86_REG_EDI,UC_X86_REG_ESP)
def digest(b):return hashlib.sha256(b).hexdigest()


class ServiceKeys:
    def __init__(self):
        raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(raw)==EXE_SHA256;pe=PE(raw)
        self.uc=uc=Uc(UC_ARCH_X86,UC_MODE_32);uc.mem_map(0x400000,0x100000);uc.mem_map(0x10000000,0x10000)
        for s in pe.sections:
            if s['name']!='.rsrc':uc.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.original=bytes(uc.mem_read(GLOBAL,END-GLOBAL));self.running=False;self.all_pcs=set()
        uc.hook_add(UC_HOOK_CODE,self.code)
        uc.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=GLOBAL,end=END-1)
        uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=KEYS,end=KEYS+299)
    def u32(self,p):return struct.unpack('<I',self.uc.mem_read(p,4))[0]
    def code(self,uc,pc,size,data):
        if pc==STOP:self.finished=True;uc.emu_stop();return
        assert START<=pc<STOP,hex(pc);self.pcs.add(pc);self.all_pcs.add(pc)
    def read(self,uc,access,address,size,value,data):
        assert self.running and size==1;self.reads.append(address-KEYS)
    def write(self,uc,access,address,size,value,data):
        assert self.running and address in FIELDS and size==4
        self.writes.append(dict(address=address,value=value&0xffffffff))
    def run(self,index,before,pressed,chain=None,step=None):
        assert len(before)==3 and 0<=before[0]<=3 and before[1] in (0,1) and before[2] in (0,1,2)
        self.uc.mem_write(GLOBAL,self.original)
        for address,value in zip(FIELDS,before):self.uc.mem_write(address,struct.pack('<I',value))
        keyboard=bytes(100 if key in pressed else 117 for key in range(300));self.uc.mem_write(KEYS,keyboard)
        original=bytes(self.uc.mem_read(GLOBAL,END-GLOBAL));self.pcs=set();self.reads=[];self.writes=[];self.finished=False
        for register in REGS:self.uc.reg_write(register,0x11223344)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        self.running=True
        try:self.uc.emu_start(START,0,count=10000)
        finally:self.running=False
        assert self.finished and self.uc.reg_read(UC_X86_REG_ESP)==SP and self.uc.reg_read(UC_X86_REG_FPCW)==0x23f
        after=[self.u32(a) for a in FIELDS];registers=[self.uc.reg_read(r) for r in REGS]
        assert registers==[after[0],0x11223364,250,after[1],0,1,2,SP]
        rebuilt=bytearray(original)
        for w in self.writes:rebuilt[w['address']-GLOBAL:w['address']-GLOBAL+4]=struct.pack('<I',w['value'])
        observed=bytes(self.uc.mem_read(GLOBAL,END-GLOBAL));assert rebuilt==observed and bytes(self.uc.mem_read(KEYS,300))==keyboard
        assert self.reads==list(range(250))+([112,113,114] if after[1] else [])
        return dict(index=index,before=before,pressed=sorted(pressed),after=after,chain=chain,step=step,
            reads=self.reads,writes=self.writes,instructions=sorted(self.pcs),registers=registers,
            globalsBeforeSHA256=digest(original),globalsAfterSHA256=digest(observed),keyboardUnchangedSHA256=digest(keyboard),fpcw=0x23f,end=dict(pc=STOP,sp=SP))


def main():
    vm=ServiceKeys();cases=[]
    for sequence,diagnostics,mode,mask in itertools.product(range(4),range(2),range(3),range(64)):
        pressed={key for bit,key in enumerate((65,66,67,112,113,114)) if mask>>bit&1}
        cases.append(vm.run(len(cases),[sequence,diagnostics,mode],pressed))
    for key,sequence,diagnostics in itertools.product(range(300),range(4),range(2)):
        cases.append(vm.run(len(cases),[sequence,diagnostics,1],{key}))
    chains={
        'held-and-released':[[],[65],[65],[],[66],[66],[],[67],[67],[],[112],[113],[114],[112,113,114],[]],
        'interrupted-scan':[[65],[70],[66],[67],[65,66,67],[65,66,67],[]],
        'scan-end':[[249],[250],[299],[65,250],[66,299],[67,250]],
    }
    for label,steps in chains.items():
        state=[0,0,0]
        for step,pressed in enumerate(steps):
            case=vm.run(len(cases),state,set(pressed),label,step);cases.append(case);state=case['after']
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,cases=cases,instructions=sorted(vm.all_pcs),stopExcluded=STOP,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'),sort_keys=True)+'\n').encode();path=ROOT/'build/original/application-service-keys.json';path.write_bytes(raw)
    report=dict(scope=__doc__,corpus=path.name,exeSHA256=EXE_SHA256,bytes=len(raw),sha256=digest(raw),cases=len(cases),instructions=len(vm.all_pcs),
        stores=sum(len(c['writes']) for c in cases),reads=sum(len(c['reads']) for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/application-service-keys.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
