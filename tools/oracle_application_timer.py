#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover the original application pacing decision, whole43d157..43d1ef.

Execute the pinned game EXE under Unicorn2.1.4. Declared clock responses,
dispatcher43e9a0 result, surface recovery43e890 and Sleep are external call
boundaries; their bodies are NOT executed by this study. Actual instructions
recover repeated time reads, unsigned33/3/100 thresholds, baseline wrapping,
negative-dispatch recovery order and signed/capped sleep. Compare ordered
requests and baseline to Native; this is not an own match, Windows/device
timing, message handling or the whole outer loop. No memory-fault probes.
"""
import hashlib,itertools,json,struct
from pathlib import Path
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_EDI,UC_X86_REG_ESI,UC_X86_REG_ESP,UC_X86_REG_EIP,UC_X86_REG_FPCW
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE

START,STOP,SP,CLOCK,SLEEP=0x43d157,0x43d1ef,0x1000f000,0x30001000,0x30001020
def digest(b):return hashlib.sha256(b).hexdigest()
def signed(x):return (x+2**31)%2**32-2**31


class Timer:
    def __init__(self):
        raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(raw)==EXE_SHA256;pe=PE(raw)
        self.uc=uc=Uc(UC_ARCH_X86,UC_MODE_32)
        for p,n in ((0x400000,0x100000),(0x10000000,0x10000),(0x30001000,0x1000)):uc.mem_map(p,n)
        for s in pe.sections:
            if s['name']!='.rsrc':uc.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        uc.hook_add(UC_HOOK_CODE,self.code);self.all_pcs=set()
    def u32(self,p):return struct.unpack('<I',self.uc.mem_read(p,4))[0]
    def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
    def ret(self,value,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xffffffff)
        self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp));self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop)
    def code(self,uc,pc,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if pc==STOP:self.finished=True;uc.emu_stop();return
        if pc==CLOCK:
            value=self.times[len(self.reads)];self.reads.append(value);self.events.append(dict(kind='time',arguments=[value]));self.ret(value);return
        if pc==0x43e9a0:
            self.events.append(dict(kind='dispatch',arguments=[self.u32(sp+4),self.result&0xffffffff]));self.ret(self.result);return
        if pc==0x43e890:
            self.events.append(dict(kind='recoverSurface',arguments=[]));self.ret(0);return
        if pc==SLEEP:
            self.events.append(dict(kind='sleep',arguments=[self.u32(sp+4)]));self.ret(0,pop=4);return
        assert START<=pc<STOP,hex(pc);self.pcs.add(pc);self.all_pcs.add(pc)
    def run(self,index,speed,baseline,delay,step,result):
        self.times=[(baseline+delay+n*step)&0xffffffff for n in range(4)];self.result=result
        self.pcs=set();self.events=[];self.reads=[];self.finished=False
        target=0x28002020 if index%2 else 0
        self.put(0x44d02c,speed);self.put(0x451dac,target)
        self.uc.mem_write(SP-128,b'\xa5'*256)
        for reg,value in ((UC_X86_REG_ESP,SP),(UC_X86_REG_ESI,baseline),(UC_X86_REG_EDI,CLOCK),(UC_X86_REG_EBX,SLEEP),(UC_X86_REG_EBP,0x22334455),(UC_X86_REG_FPCW,0x23f)):self.uc.reg_write(reg,value)
        before=bytes(self.uc.mem_read(0x44d000,0xf000))
        self.uc.emu_start(START,0,count=1000)
        assert self.finished and self.uc.reg_read(UC_X86_REG_ESP)==SP
        assert self.uc.reg_read(UC_X86_REG_EDI)==CLOCK and self.uc.reg_read(UC_X86_REG_EBX)==SLEEP and self.uc.reg_read(UC_X86_REG_EBP)==0x22334455
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and bytes(self.uc.mem_read(0x44d000,0xf000))==before
        return dict(index=index,speed=speed,baselineBefore=baseline,clockResponses=self.times,dispatchResult=result,target=target,
            baselineAfter=self.uc.reg_read(UC_X86_REG_ESI),events=self.events,instructions=sorted(self.pcs),end=dict(pc=STOP,sp=SP),globalsUnchangedSHA256=digest(before),fpcw=0x23f)


def main():
    vm=Timer();cases=[]
    space=itertools.product((0,1,-1),(0,0xfffffff0,0x7ffffff0),(0,1,2,3,4,32,33,34,99,100,101,102,0x7fffffff,0x80000000,0xfffffff0),(0,1,5,33,101),(0,1,-1))
    for index,values in enumerate(space):cases.append(vm.run(index,*values))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,cases=cases,instructions=sorted(vm.all_pcs),boundaryPCs=[CLOCK,SLEEP,0x43e9a0,0x43e890],stopExcluded=STOP,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'),sort_keys=True)+'\n').encode();path=ROOT/'build/original/application-timer.json';path.write_bytes(raw)
    report=dict(scope=__doc__,corpus=path.name,exeSHA256=EXE_SHA256,sha256=digest(raw),bytes=len(raw),cases=len(cases),instructions=len(vm.all_pcs),events=sum(len(c['events']) for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/application-timer.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
