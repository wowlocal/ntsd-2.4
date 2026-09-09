#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover two prerequisites of the original application's outer dispatcher.

Pinned NTSD2.4 EXE/Unicorn2.1.4: execute the whole43e9db..43ea95 service-key
prefix, whole401250 surface-clear helper, and explicit446300 static-World
initializer over the image's zero-filled458b00 storage. Keyboard/global inputs,
clear-local backing, COM HRESULT and the inherited constructor memset adapter
are declared boundaries. No editor/game body, whole43e9a0, CRT startup order,
initialized application, Windows raster or native equivalence is implied.
Original instruction/write observers distinguish preserved bytes from writes.
"""
import base64
import hashlib
import itertools
import json
import random
import struct
import zlib
from pathlib import Path
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP,
    UC_X86_REG_ECX, UC_X86_REG_EDX, UC_X86_REG_EDI, UC_X86_REG_ESI,
    UC_X86_REG_ESP, UC_X86_REG_EIP, UC_X86_REG_FPCW)
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE

GLOBAL, SIZE, WORLD = 0x44d000, 0xc3a8, 0x458b00
SP, STOP, COM, SURFACE, VTABLE = 0x1000f000, 0x30000000, 0x30000100, 0x28000020, 0x28001000
REGISTERS=[UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_EDI]
digest=lambda b:hashlib.sha256(b).hexdigest()
signed=lambda x:(x+2**31)%2**32-2**31


class DispatchPrefix:
    def __init__(self):
        raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(raw)==EXE_SHA256;pe=PE(raw)
        self.uc=u=Uc(UC_ARCH_X86,UC_MODE_32)
        for p,n in ((0x400000,0x100000),(0x10000000,0x10000),(0x28000000,0x2000),(STOP,0x1000)):u.mem_map(p,n)
        for section in pe.sections:
            if section['name']!='.rsrc':u.mem_write(pe.base+section['rva'],raw[section['fileOffset']:section['fileOffset']+section['fileSize']])
        self.template=bytes(u.mem_read(GLOBAL,SIZE));self.blobs={};self.active=False
        self.all_pcs={'keys':set(),'clear':set(),'world':set()}
        self.put(VTABLE+0x14,COM)
        for n in range(3):self.put(SURFACE+16*n,VTABLE)
        u.hook_add(UC_HOOK_CODE,self.code);u.hook_add(UC_HOOK_MEM_WRITE,self.written)
    def u32(self,p):return struct.unpack('<I',self.uc.mem_read(p,4))[0]
    def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
    def blob(self,b):
        raw=bytes(b);key=digest(raw)
        if key not in self.blobs:
            c=zlib.compressobj(9,wbits=-15);packed=c.compress(raw)+c.flush()
            self.blobs[key]=dict(count=len(raw),deflate=base64.b64encode(packed).decode())
        return key
    def ret(self,value,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xffffffff)
        self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def written(self,uc,access,p,n,value,data):
        if not self.active:return
        pc=uc.reg_read(UC_X86_REG_EIP)
        if GLOBAL<=p<p+n<=GLOBAL+SIZE:self.writes.append(dict(pc=pc,address=p,size=n,value=value&((1<<(8*n))-1)))
        if self.kind=='clear' and SP-100<=p<p+n<=SP:self.mask[p-(SP-100):p-(SP-100)+n]=b'\1'*n
        if self.kind=='world' and WORLD<=p<p+n<=WORLD+0x7d8:self.mask[p-WORLD:p-WORLD+n]=b'\1'*n
    def code(self,uc,pc,n,data):
        if not self.active:return
        if pc==(0x43ea95 if self.kind=='keys' else STOP):self.finished=True;uc.emu_stop();return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if pc==COM:
            assert self.kind=='clear'
            args=[self.u32(sp+4+4*i) for i in range(6)]
            assert args==[self.target,0,0,0,0x1000400,SP-100]
            self.request=dict(target=args[0],flags=args[4],effects=list(uc.mem_read(args[5],100)),defined=[bool(x) for x in self.mask])
            self.ret(self.response,24);return
        if pc==0x4450a0:
            assert self.kind=='world' and [self.u32(sp+4+4*i) for i in range(3)]==[WORLD+4,0,400]
            self.memset=dict(entry=pc,address=WORLD+4,count=400,value=0)
            uc.mem_write(WORLD+4,bytes(400));self.mask[4:404]=b'\1'*400
            self.ret(WORLD+4);return
        allowed=(0x43e9db<=pc<0x43ea95 if self.kind=='keys' else 0x401250<=pc<=0x401281 if self.kind=='clear'
            else pc in (0x446300,0x446305) or 0x419e40<=pc<=0x419e5f)
        assert allowed,(self.kind,hex(pc));self.pcs.add(pc);self.all_pcs[self.kind].add(pc)
    def begin(self,kind):
        self.active=False;self.uc.mem_write(SP-0x200,b'\xa5'*0x300)
        for reg,value in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.uc.reg_write(reg,value)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f);self.put(SP,STOP)
        self.kind=kind;self.pcs=set();self.writes=[];self.finished=False;self.mask=bytearray(100 if kind=='clear' else 0x7d8)
    def execute(self,start):
        self.active=True
        try:self.uc.emu_start(start,0,count=10000);assert self.finished
        finally:self.active=False
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f
    def keys(self,index,sequence,enabled,mode,keys):
        self.begin('keys');self.uc.mem_write(GLOBAL,self.template)
        self.put(0x4593a4,sequence);self.put(0x450bec,enabled);self.put(0x4593a0,mode)
        self.uc.mem_write(0x455378,bytes(keys));before=bytes(self.uc.mem_read(GLOBAL,SIZE));stack=bytes(self.uc.mem_read(SP-0x200,0x300))
        self.execute(0x43e9db)
        assert self.uc.reg_read(UC_X86_REG_ESP)==SP and bytes(self.uc.mem_read(SP-0x200,0x300))==stack
        return dict(index=index,sequence=sequence,enabled=enabled,mode=mode,keys=self.blob(keys),before=self.blob(before),
            after=self.blob(self.uc.mem_read(GLOBAL,SIZE)),sequenceAfter=signed(self.u32(0x4593a4)),enabledAfter=signed(self.u32(0x450bec)),
            modeAfter=signed(self.u32(0x4593a0)),writes=self.writes,instructions=sorted(self.pcs),end=dict(pc=0x43ea95,sp=SP),fpcw=0x23f)
    def clear(self,index,target,color,backing,response):
        self.begin('clear');self.target=target;self.response=response;self.request=None
        self.uc.mem_write(SP-100,bytes(backing));self.put(SP+4,target);self.put(SP+8,color)
        before=bytes(self.uc.mem_read(GLOBAL,SIZE));self.execute(0x401250)
        assert self.request is not None and not self.writes and bytes(self.uc.mem_read(GLOBAL,SIZE))==before
        assert self.uc.reg_read(UC_X86_REG_ESP)==SP+4 and [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert [self.u32(SP+4),self.u32(SP+8)]==[target,color]
        return dict(index=index,target=target,color=color,backing=list(backing),response=response,request=self.request,
            result=signed(self.uc.reg_read(UC_X86_REG_EAX)),effectsAfter=list(self.uc.mem_read(SP-100,100)),mask=list(self.mask),
            instructions=sorted(self.pcs),end=dict(pc=STOP,sp=SP+4),fpcw=0x23f)
    def world(self):
        self.begin('world');self.uc.mem_write(GLOBAL,self.template)
        before=bytes(self.uc.mem_read(WORLD,0x7d8));assert before==bytes(0x7d8)
        assert self.u32(0x4472d0)==0x446300;self.memset=None;self.execute(0x446300)
        assert self.memset is not None and self.uc.reg_read(UC_X86_REG_EAX)==WORLD and self.uc.reg_read(UC_X86_REG_ESP)==SP+4
        assert [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        return dict(address=WORLD,initializer=0x446300,pointerSlot=0x4472d0,before=self.blob(before),
            after=self.blob(self.uc.mem_read(WORLD,0x7d8)),mask=self.blob(self.mask),writes=self.writes,memset=self.memset,
            instructions=sorted(self.pcs),end=dict(pc=STOP,sp=SP+4),fpcw=0x23f)


def main():
    vm=DispatchPrefix();world=vm.world();cases=[];clears=[]
    patterns=[[],[65],[66],[67],[65,66],[65,66,67],[65,67],[64,65,66,67],[65,66,67,68],
        [112],[113],[114],[112,113,114],[65,66,67,112,113,114],[249],[250],[299]]
    for sequence,enabled,mode,pressed in itertools.product((-2**31,-1,0,1,2,3,4,2**31-1),(-1,0,1,2),(-1,0,1,2,3),patterns):
        keys=[117]*300
        for key in pressed:keys[key]=100
        cases.append(vm.keys(len(cases),sequence,enabled,mode,keys))
    for key,sequence in itertools.product(range(300),range(5)):
        keys=[117]*300;keys[key]=100;cases.append(vm.keys(len(cases),sequence,0,0,keys))
    rng=random.Random(0x43e9a0)
    for _ in range(128):
        keys=[rng.choice((0,1,99,100,101,117,127,255)) for _ in range(300)]
        cases.append(vm.keys(len(cases),rng.choice((-1,0,1,2,3,4)),signed(rng.getrandbits(32)),signed(rng.getrandbits(32)),keys))
    for target,color,pattern,response in itertools.product((SURFACE,SURFACE+16,SURFACE+32),(0,1,0x2945,0xffffff,0x7fffffff,0x80000000,0xffffffff),range(4),(-2**31,-1,0,1,2**31-1)):
        backing=bytes(100) if pattern==0 else b'\xa5'*100 if pattern==1 else bytes(range(100)) if pattern==2 else bytes(rng.getrandbits(8) for _ in range(100))
        clears.append(vm.clear(len(clears),target,color,backing,response))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,globalAddress=GLOBAL,globalSize=SIZE,ordinaryGlobalSize=0xb440,
        globalTemplate=vm.blob(vm.template),keys=cases,clears=clears,staticWorld=world,blobs=vm.blobs,
        instructions={k:sorted(v) for k,v in vm.all_pcs.items()},nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'),sort_keys=True)+'\n').encode();path=ROOT/'build/original/application-dispatch-prefix.json';path.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,corpus=path.name,bytes=len(raw),sha256=digest(raw),keyCases=len(cases),clearCalls=len(clears),
        instructions={k:len(v) for k,v in vm.all_pcs.items()},nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/application-dispatch-prefix.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
