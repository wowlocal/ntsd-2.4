#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute the original game's whole419e60 and401a30 sound consumers.

Controlled global queues and COM buffer words; numeric COM HRESULTs are supplied.
Instruction/global-write tracing recovers pending-flag ownership, signed wrapped
pan/volume and enabled playback order for the native macOS port. No audio device,
Windows, initialized own tick or arbitrary COM reentrancy is claimed.
"""
import argparse
import base64
import itertools
import json
import struct
import zlib
from collections import Counter
from oracle_state import Constructors,ROOT,STACK,STOP,EXE_SHA256
from oracle_bitmap_drawing import digest
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import (UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,
    UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)

GLOBAL,SIZE,SP=0x44d000,0xb440,STACK+0xf000
BUFFER,VTABLE,API=0x23000020,0x23003000,STOP+0x100
QUEUES=((400,0x457588,0x452170,0x457bc8,0x452948),(80,0x453e10,0x4554c8,0x4527e8,0x451db0))
REGS=(UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)
METHODS={0x40:2,0x3c:2,0x48:1,0x34:2,0x30:4}
PLAY_WORD=0x450c34


class QueuedSound(Constructors):
    def __init__(self):
        self.running=False;super().__init__()
        self.uc.mem_map(BUFFER&~0xfff,0x5000)
        self.uc.hook_add(UC_HOOK_CODE,self.code)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.global_write,begin=GLOBAL,end=GLOBAL+SIZE-1)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.resource_read,begin=BUFFER&~0xfff,end=(BUFFER&~0xfff)+0x4fff)
        self.initial=bytes(self.uc.mem_read(GLOBAL,SIZE));self.blobs={};self.instructions=set()
        for i in range(480):self.put(BUFFER+16*i,VTABLE)
        self.apis={API+16*i:(offset,count) for i,(offset,count) in enumerate(METHODS.items())}
        for p,(offset,_) in self.apis.items():self.put(VTABLE+offset,p)
        self.resources=bytes(self.uc.mem_read(BUFFER&~0xfff,0x5000))

    def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
    def event(self,kind,args):self.events.append(dict(kind=kind,arguments=args))
    def blob(self,raw):
        value=bytes(raw);key=digest(value)
        if key not in self.blobs:self.blobs[key]=dict(count=len(value),deflate=base64.b64encode(zlib.compress(value,9)).decode())
        return key
    def written(self,*args):
        if self.running:raise AssertionError('Unexpected sound write to constructor arena')
    def memset(self,*args):raise AssertionError('Unexpected sound memset')
    def resource_read(self,uc,access,p,size,value,data):
        if not self.running:return
        assert size==4 and (p in [VTABLE+o for o in METHODS] or BUFFER<=p<BUFFER+480*16 and (p-BUFFER)%16==0)
        self.resource_reads.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=p,value=self.u32(p)))
    def global_write(self,uc,access,p,size,value,data):
        if not self.running:return
        pc=uc.reg_read(UC_X86_REG_EIP);assert size==4 and value==0 and pc in (0x419e9f,0x419f7f)
        assert any(start<=p<start+4*count and (p-start)%4==0 for count,start,_,_,_ in QUEUES)
        self.written_mask[p-GLOBAL:p-GLOBAL+4]=b'\1'*4
        self.writes.append(dict(pc=pc,address=p,size=size,value=0));self.event('queueWrite',[p,0])
    def code(self,uc,pc,size,data):
        if not self.running:return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.pending and pc==self.pending[-1]['returnPC']:
            h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[uc.reg_read(r) for r in REGS]
            h['returnSP']=sp;self.helpers.append(h)
        if pc==STOP:assert not self.pending;uc.emu_stop();return
        if pc in self.apis:
            offset,count=self.apis[pc];buffer=arg(0)
            assert BUFFER<=buffer<BUFFER+480*16 and (buffer-BUFFER)%16==0
            self.event('method',[buffer,offset,*[arg(i) for i in range(1,count)]])
            result=self.results[self.methods%len(self.results)];self.methods+=1
            uc.reg_write(UC_X86_REG_EAX,result&0xffffffff);uc.reg_write(UC_X86_REG_ESP,sp+4+4*count);uc.reg_write(UC_X86_REG_EIP,self.u32(sp));return
        assert 0x419e60<=pc<0x41a044 or 0x401a30<=pc<0x401a72,hex(pc)
        self.instructions.add(pc);self.case_pcs.add(pc)
        if pc in (0x419e60,0x401a30):
            self.pending.append(dict(entry=pc,sp=sp,pop=4 if pc==0x401a30 else 0,returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
        if pc==0x401a30:self.event('play',[uc.reg_read(UC_X86_REG_ECX),arg(0)])

    def probe(self,spec):
        self.running=False;self.events=[];self.writes=[];self.written_mask=bytearray(SIZE);self.resource_reads=[]
        self.methods=0;self.pending=[];self.helpers=[];self.case_pcs=set();self.results=spec.get('results',[-2147467259,0,-1,1])
        self.uc.mem_write(GLOBAL,self.initial)
        for group,(count,pending,first,second,buffers) in enumerate(QUEUES):
            for n in range(count):
                self.put(pending+4*n,0);self.put(first+4*n,70);self.put(second+4*n,30)
                self.put(buffers+4*n,BUFFER+16*(n+(400 if group else 0)))
        for group,index,flag,left,right in spec.get('slots',[]):
            count,pending,first,second,_=QUEUES[group];assert 0<=index<count
            self.put(pending+4*index,flag);self.put(first+4*index,left);self.put(second+4*index,right)
        for group,index,buffer in spec.get('aliases',[]):self.put(QUEUES[group][4]+4*index,BUFFER+16*buffer)
        self.put(0x44eecc,spec.get('device',1));self.put(0x44d000,spec.get('volume',100))
        self.put(PLAY_WORD,0 if spec.get('nullBuffer') else BUFFER)
        before=bytes(self.uc.mem_read(GLOBAL,SIZE));self.uc.mem_write(SP-0x1000,b'\xa5'*0x1100);self.put(SP,STOP);self.put(SP+4,spec.get('loop',0))
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
        self.uc.reg_write(UC_X86_REG_ECX,PLAY_WORD);self.uc.reg_write(UC_X86_REG_ESP,SP)
        self.uc.reg_write(UC_X86_REG_FPCW,0x23f);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        entry=spec.get('entry',0x419e60);self.running=True;self.uc.emu_start(entry,0,count=2_000_000);self.running=False
        end=SP+(8 if entry==0x401a30 else 4)
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==end
        assert saved==[self.uc.reg_read(r) for r in REGS] and not self.pending
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        assert bytes(self.uc.mem_read(BUFFER&~0xfff,0x5000))==self.resources
        return dict(spec=spec,before=self.blob(before),after=self.blob(self.uc.mem_read(GLOBAL,SIZE)),written=self.blob(self.written_mask),
            writes=self.writes,events=self.events,methods=self.methods,resourceReads=self.resource_reads,helpers=self.helpers,instructions=sorted(self.case_pcs),end=dict(pc=STOP,sp=end))


def probes():
    for group,count in ((0,400),(1,80)):
        for index in range(count):yield dict(label=f'slot-{group}-{index}',slots=[[group,index,1,index%101,100-index%101]])
    values=(-2147483648,-1431656,-1431655,-101,-100,-1,0,1,49,50,99,100,101,1431655,1431656,2147483647)
    for group,(left,right),volume in itertools.product(range(2),list(dict.fromkeys([(v,1) for v in values]+[(1,v) for v in values])),(-2147483648,-1,0,1,99,100,2147483647)):
        yield dict(label=f'numeric-{group}-{left}-{right}-{volume}',slots=[[group,0,1,left,right]],volume=volume)
    for group,flag,device in itertools.product(range(2),(-2147483648,-1,0,1,2,2147483647),(0,1,0xffffffff)):
        yield dict(label=f'gate-{group}-{flag}-{device}',slots=[[group,0,flag,70,30]],device=device)
    yield dict(label='all-queues',slots=[[g,n,1,70,30] for g,count in ((0,400),(1,80)) for n in range(count)])
    yield dict(label='buffer-aliases',slots=[[0,0,1,70,30],[0,399,2,20,80],[1,0,1,40,60],[1,79,1,50,50]],aliases=[[0,399,0],[1,0,0],[1,79,0]])
    for loop,device,null in itertools.product((0,1,2,0xffffffff),(0,1),(False,True)):
        yield dict(label=f'play-{loop}-{device}-{null}',entry=0x401a30,loop=loop,device=device,nullBuffer=null)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);args=parser.parse_args()
    vm=QueuedSound();cases=[]
    for spec in list(probes())[:args.limit]:
        cases.append(vm.probe(spec))
        if len(cases)%100==0:print('QUEUED SOUND',len(cases),'cases',sum(c['methods'] for c in cases),'methods',flush=True)
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x23f,blobEncoding='zlib',bufferBase=BUFFER,playWord=PLAY_WORD,cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/queued-sound.json';path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),instructions=len(vm.instructions),
        events=dict(Counter(e['kind'] for c in cases for e in c['events'])),helpers=sum(len(c['helpers']) for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/queued-sound.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
