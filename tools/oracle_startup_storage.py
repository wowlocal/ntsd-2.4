#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Compare the game's three static constructors via original CRT _initterm.

Whole fresh EXE-entry/lib.dll installation is reproduced first. Then a DECLARED
call of _initterm(4472c8,4472d4) executes three original table callbacks and real
memset on controlled458440..458c94 storage. This does NOT continue the stopped
CRT process-attach chain or execute its preceding argv/NLS initialization.
Pinned EXE/lib/MSVCR80, Unicorn2.1.4, original-file CRT data and CW037f; no host
Windows/heap/ABI claim. Full before/after bytes, masks, stores, callback order and
returns are retained. See docs/research/CRT_STARTUP_PLAN.md.
"""
import argparse,json,struct
from oracle_lib_initialization import LibInitialization,SP,STOP,LIB_SHA256,digest
from oracle_crt import prepare,DLL_SHA256
from oracle_crt_startup import exports
from import_ntsd import ROOT,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
BASE,COUNT=0x458440,0x854
CALLBACKS=[0x4462e0,0x4462f0,0x446300]

class StartupStorage:
    def __init__(self):
        self.vm=vm=LibInitialization(0);self.parent=vm.run();assert len(self.parent['patches'])==13
        self.u=u=vm.u;raw=prepare().read_bytes();pe=PE(raw);u.mem_map(pe.base,0x100000)
        for s in pe.sections:u.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.exports=exports(pe);vm.put(0x447160,self.exports['memset'])
        self.table=bytes(u.mem_read(0x4472c8,12));assert list(struct.unpack('<3I',self.table))==CALLBACKS
        self.loader=bytes(u.mem_read(BASE,COUNT));self.active=False
        u.hook_add(UC_HOOK_CODE,self.code);u.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=BASE,end=BASE+COUNT-1)
        self.code_before=bytes(u.mem_read(0x400000,0x4d000));self.dll_before=bytes(u.mem_read(0x10000000,0x5000))
    def code(self,u,pc,size,data):
        if not self.active:return
        self.instructions[pc]=bytes(u.mem_read(pc,size)).hex()
        if pc in CALLBACKS:self.entries.append(pc)
        if pc==0x78131742:self.returns.append(dict(initializer=self.entries[-1],eax=u.reg_read(UC_X86_REG_EAX),sp=u.reg_read(UC_X86_REG_ESP)))
    def write(self,u,access,address,size,value,data):
        if not self.active:return
        assert BASE<=address<address+size<=BASE+COUNT
        self.mask[address-BASE:address-BASE+size]=b'\1'*size
        self.writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,size=size,bytes=(value&((1<<(8*size))-1)).to_bytes(size,'little').hex()))
    def call(self,index,before,defined,label):
        u=self.u;u.mem_write(BASE,before);self.mask=bytearray(COUNT);self.writes=[];self.entries=[];self.returns=[];self.instructions={}
        u.mem_write(SP,struct.pack('<3I',STOP,0x4472c8,0x4472d4));u.reg_write(UC_X86_REG_ESP,SP)
        u.reg_write(UC_X86_REG_FPCW,0x37f);saved=[u.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)]
        self.active=True
        try:u.emu_start(self.exports['_initterm'],STOP,count=100000)
        finally:self.active=False
        assert u.reg_read(UC_X86_REG_EIP)==STOP and u.reg_read(UC_X86_REG_ESP)==SP+4 and self.entries==CALLBACKS and len(self.returns)==3
        assert saved==[u.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)]
        assert bytes(u.mem_read(0x400000,0x4d000))==self.code_before and bytes(u.mem_read(0x10000000,0x5000))==self.dll_before
        after=bytes(u.mem_read(BASE,COUNT));rebuilt=bytearray(before)
        for w in self.writes:rebuilt[w['address']-BASE:w['address']-BASE+w['size']]=bytes.fromhex(w['bytes'])
        assert after==rebuilt
        return dict(index=index,label=label,before=list(before),beforeDefined=list(defined),after=list(after),writeMask=list(self.mask),afterDefined=[bool(a or b) for a,b in zip(defined,self.mask)],writes=self.writes,entries=self.entries,returns=self.returns,
            instructions=[dict(address=a,bytes=b) for a,b in sorted(self.instructions.items())],fpcw=u.reg_read(UC_X86_REG_FPCW),sp=u.reg_read(UC_X86_REG_ESP))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',default='build/original/startup-storage.json');a=p.parse_args();path=ROOT/a.output;assert not path.exists()
    vm=StartupStorage();cases=[];last=None
    for index in range(12):
        if index==0:before=vm.loader;defined=[True]*COUNT;label='declared-loader-bytes'
        elif index in (9,10,11):before=bytes(last['after']);defined=last['afterDefined'];label='retained-own-constructor-result'
        else:
            before=bytes([0xa5 if index==1 else 0xff if index==2 else (i*index*37+index*19)&255 for i in range(COUNT)])
            defined=[False if index in (1,2) else (i+index)%3==0 for i in range(COUNT)];label='controlled-data-backing'
        last=vm.call(index,before,defined,label);cases.append(last)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,base=BASE,count=COUNT,table=vm.table.hex(),parent=vm.parent,cases=cases,retainedChain=[8,9,10,11],nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    print(json.dumps(dict(path=str(path.relative_to(ROOT)),bytes=len(raw),sha256=digest(raw),cases=len(cases),writes=sum(len(c['writes']) for c in cases),writeBytes=sum(sum(c['writeMask']) for c in cases),instructions=len({i['address'] for c in cases for i in c['instructions']})),indent=2))
if __name__=='__main__':main()
