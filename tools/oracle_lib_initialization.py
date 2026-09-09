#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute bundled lib.dll installation on the pinned game image.

The original NTSD EXE entry calls LoadLibraryA before CRT startup. This
research-only source VM runs that entry and the actual bundled DLL entry on
one CPU. Windows clock, loader, VirtualAlloc, VirtualProtect and RtlMoveMemory
responses are declared adapters. Exact patch bytes, copy requests and full
image digests establish which game behaviors must be ported natively; this
is neither Windows loader verification nor native hook-behavior equivalence.
No original file is modified, and the native application must not load a DLL.
"""
import argparse,hashlib,json,struct
from pathlib import Path
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW)

LIB_SHA256='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
STACK,SP,STOP,API,DLL_RETURN=0x20000000,0x2000f000,0x30000000,0x30001000,0x30000100
REGISTERS=(UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)
digest=lambda b:hashlib.sha256(b).hexdigest()

class LibInitialization:
    def __init__(self,index,reason=None):
        self.index=index;self.reason=reason;self.u=Uc(UC_ARCH_X86,UC_MODE_32);self.boundaries={};self.images={};self.instructions=set();self.instruction_bytes={};self.events=[];self.patches=[];self.writes=[];self.allocations=[];self.active=False;self.pending=None;self.protections={}
        for name,sha in [('NTSD 2.4.exe',EXE_SHA256),('lib.dll',LIB_SHA256)]:
            raw=read_bytes(DEFAULT_SOURCE/name);assert digest(raw)==sha;pe=PE(raw);size=(max(s['rva']+max(s['fileSize'],s['virtualSize']) for s in pe.sections)+4095)&~4095
            self.u.mem_map(pe.base,size);self.u.mem_write(pe.base,raw[:pe.sections[0]['fileOffset']])
            for s in pe.sections:self.u.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
            self.images[name]=(pe,size)
            for item in pe.imports():
                address=API+16*len(self.boundaries);self.boundaries[address]=(name,item['name']);self.put(int(item['iatVA'],16),address)
        self.u.mem_map(STACK,0x10000);self.u.mem_map(STOP,0x10000)
        self.u.mem_write(STACK,b'\xa5'*0x10000);self.put(SP,STOP);self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_FPCW,0x37f)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.hook_add(UC_HOOK_CODE,self.code);self.u.hook_add(UC_HOOK_MEM_WRITE,self.written)
        self.before={name:bytes(self.u.mem_read(pe.base,size)) for name,(pe,size) in self.images.items()}
        if reason is not None:
            self.put(SP+4,0x10000000);self.put(SP+8,reason);self.put(SP+12,0)
    def u32(self,a):return int.from_bytes(self.u.mem_read(a,4),'little')
    def put(self,a,v):self.u.mem_write(a,struct.pack('<I',v&0xffffffff))
    def string(self,a):
        b=bytearray()
        for _ in range(4096):
            v=self.u.mem_read(a+len(b),1)[0]
            if not v:return bytes(b)
            b.append(v)
        raise ValueError('Unterminated source string')
    def ret(self,value,pop=0):
        sp=self.u.reg_read(UC_X86_REG_ESP);self.u.reg_write(UC_X86_REG_EAX,value&0xffffffff);self.u.reg_write(UC_X86_REG_EIP,self.u32(sp));self.u.reg_write(UC_X86_REG_ESP,sp+4+pop)
    def written(self,u,access,address,size,value,data):
        if self.active and not STACK<=address<STACK+0x10000:
            self.writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,size=size,value=value&((1<<(8*size))-1)))
    def code(self,u,pc,size,data):
        if pc==(0x445565 if self.reason is None else STOP):self.finished=True;u.emu_stop();return
        sp=u.reg_read(UC_X86_REG_ESP)
        if pc==DLL_RETURN:
            assert self.pending is not None and sp==self.pending['sp']
            self.pending['result']=u.reg_read(UC_X86_REG_EAX)
            self.events.append(dict(kind='dllReturn',**self.pending));assert self.pending['result']!=0
            self.pending=None;self.ret(0x10000000,4);return
        if pc not in self.boundaries:
            self.instructions.add(pc);self.instruction_bytes[pc]=bytes(u.mem_read(pc,size)).hex();return
        image,name=self.boundaries[pc];arg=lambda i:self.u32(sp+4+4*i)
        event=dict(kind=name,image=image,returnPC=self.u32(sp));self.events.append(event)
        if name=='GetSystemTimeAsFileTime':
            value=0x0123456789abcdef+self.index;event.update(arguments=[arg(0)],value=value);u.mem_write(arg(0),value.to_bytes(8,'little'));self.ret(0,4)
        elif name in ('GetCurrentProcessId','GetCurrentThreadId','GetTickCount'):
            value={'GetCurrentProcessId':0x1234,'GetCurrentThreadId':0x5678,'GetTickCount':0x11223344}[name]+self.index;event['result']=value;self.ret(value)
        elif name=='QueryPerformanceCounter':
            value=0x55667788+self.index;event.update(arguments=[arg(0)],value=value,result=1);u.mem_write(arg(0),value.to_bytes(8,'little'));self.ret(1,4)
        elif name=='LoadLibraryA':
            assert self.pending is None and self.string(arg(0))==b'lib.dll';event.update(path='lib.dll',module=0x10000000)
            self.pending=dict(sp=sp,entry=0x10001b62,module=0x10000000,reason=1,reserved=0)
            frame=sp-16
            for i,v in enumerate((DLL_RETURN,0x10000000,1,0)):self.put(frame+4*i,v)
            u.reg_write(UC_X86_REG_ESP,frame);u.reg_write(UC_X86_REG_EIP,0x10001b62)
        elif name=='VirtualAlloc':
            arguments=[arg(i) for i in range(4)];assert arguments in ([0,4000,0x1000,4],[0,20000,0x1000,4])
            address=0x24000000+self.index*0x100000+len(self.allocations)*0x10000;extent=(arguments[1]+4095)&~4095
            u.mem_map(address,extent);self.allocations.append(dict(address=address,count=arguments[1],mapped=extent,initialSHA256=digest(bytes(extent))))
            event.update(arguments=arguments,result=address);self.ret(address,16)
        elif name=='VirtualProtect':
            arguments=[arg(i) for i in range(4)];address,count,protection,output=arguments;assert 0x400000<=address<address+count<0x446000 and count in (2,5) and protection in (0x20,0x40)
            page=address&~4095;old=self.protections.get(page,0x20);self.protections[page]=protection;self.put(output,old)
            event.update(arguments=arguments,oldProtection=old,result=1);self.ret(1,16)
        elif name=='RtlMoveMemory':
            dst,src,count=[arg(i) for i in range(3)];assert 0x400000<=dst<dst+count<0x446000 and 0x10003000<=src<src+count<=0x100030a1
            before=bytes(u.mem_read(dst,count));payload=bytes(u.mem_read(src,count));u.mem_write(dst,payload)
            patch=dict(address=dst,source=src,count=count,before=before.hex(),after=payload.hex(),returnPC=self.u32(sp));self.patches.append(patch);event.update(patch);self.ret(dst,12)
        else:raise RuntimeError((name,hex(pc),hex(self.u32(sp))))
    def run(self):
        self.active=True;self.finished=False
        try:self.u.emu_start(0x445560 if self.reason is None else 0x10001b62,0,count=100000)
        finally:self.active=False
        assert self.finished and self.pending is None
        expected_sp=SP if self.reason is None else SP+16;assert self.u.reg_read(UC_X86_REG_ESP)==expected_sp
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        images=[]
        for name,(pe,size) in self.images.items():
            before=self.before[name];after=bytes(self.u.mem_read(pe.base,size));changes=[];start=None
            for i,(a,b) in enumerate(zip(before,after)):
                if a!=b and start is None:start=i
                if a==b and start is not None:changes.append(dict(address=pe.base+start,before=before[start:i].hex(),after=after[start:i].hex()));start=None
            if start is not None:changes.append(dict(address=pe.base+start,before=before[start:].hex(),after=after[start:].hex()))
            images.append(dict(name=name,base=pe.base,count=size,beforeSHA256=digest(before),afterSHA256=digest(after),changes=changes))
        return dict(index=self.index,reason=self.reason,scope='whole EXE entry445560..445565' if self.reason is None else 'direct DLL entry with declared notification reason',events=self.events,patches=self.patches,allocations=self.allocations,writes=self.writes,images=images,
            instructions=[dict(address=a,bytes=self.instruction_bytes[a]) for a in sorted(self.instructions)],end=dict(pc=self.u.reg_read(UC_X86_REG_EIP),sp=expected_sp,eax=self.u.reg_read(UC_X86_REG_EAX),fpcw=self.u.reg_read(UC_X86_REG_FPCW)))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',default='build/original/lib-initialization.json');a=p.parse_args();path=ROOT/a.output;assert not path.exists(),path
    cases=[LibInitialization(i).run() for i in range(3)]+[LibInitialization(3+i,reason).run() for i,reason in enumerate((0,1,2,3))]
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,sourceEnvironment='Unicorn2.1.4; DLL preferred base10000000, synthetic stack20000000, declared successful loader/VirtualAlloc/VirtualProtect/memory-copy boundaries',cases=cases,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=path.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),wholeEntryCases=3,notificationControls=4,patchesPerAttach=len(cases[0]['patches']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-initialization.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
