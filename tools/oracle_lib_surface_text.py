#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Compare the actual lib.dll replacement reached through patched401290.

First execute the whole original EXE entry and bundled DLL installation on
one controlled CPU. Then call patched401290 with declared surface/text/GDI
responses and retained DLL DC state. The actual DLL body and import thunks
execute; COM/GDI raster and lstrlenA are explicit platform boundaries.
No native whole initialized application or Windows rendering is claimed.
"""
import itertools,json,random
from import_ntsd import ROOT,EXE_SHA256
from oracle_lib_initialization import LibInitialization,LIB_SHA256,SP,STOP,REGISTERS,digest
from unicorn.x86_const import UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_EAX,UC_X86_REG_FPCW

SURFACE,VTABLE,TEXT=0x28000020,0x28001000,0x28002000
GETDC,RELEASE=STOP+0x7000,STOP+0x7010

class LibText(LibInitialization):
    def __init__(self):
        super().__init__(0);self.installation=super().run();self.text_active=False
        self.u.mem_map(0x28000000,0x10000)
        for i in range(3):self.put(SURFACE+16*i,VTABLE)
        self.put(VTABLE+0x44,GETDC);self.put(VTABLE+0x68,RELEASE)
        self.boundaries[GETDC]=('controlled surface','getDC');self.boundaries[RELEASE]=('controlled surface','releaseDC')
    def code(self,u,pc,size,data):
        if not getattr(self,'text_active',False):return super().code(u,pc,size,data)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc not in self.boundaries:
            assert pc==0x401290 or 0x10001298<=pc<=0x10001309 or pc in (0x10001c7e,0x10001c84,0x10001c8a,0x10001c90),hex(pc)
            self.instructions.add(pc);self.instruction_bytes[pc]=bytes(u.mem_read(pc,size)).hex();return
        _,name=self.boundaries[pc];sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
        if name=='getDC':
            assert arg(0)==self.target;self.events.append(dict(kind='getDC',arguments=[arg(0)],strings=[]));self.put(arg(1),self.dc);self.ret(self.dc_result,8)
        elif name=='releaseDC':
            self.events.append(dict(kind=name,arguments=[arg(0),arg(1)],strings=[]));self.ret(self.response,8)
        elif name in ('SetBkMode','SetTextColor'):
            kind='setBackgroundMode' if name=='SetBkMode' else 'setTextColor';self.events.append(dict(kind=kind,arguments=[arg(0),arg(1)],strings=[]));self.ret(self.response,8)
        elif name=='lstrlenA':
            text=self.string(arg(0));self.events.append(dict(kind='stringLength',arguments=[],strings=[list(text)]));self.ret(len(text),4)
        elif name=='TextOutA':
            text=bytes(u.mem_read(arg(3),arg(4)));self.events.append(dict(kind='textOut',arguments=[arg(0),arg(1),arg(2),arg(4)],strings=[list(text)]));self.ret(self.response,20)
        else:raise AssertionError(name)
    def call(self,index,target,raw,background,color,x,y,dc_result,dc,response,retained):
        self.text_active=True;self.active=False;self.target=target;self.dc_result=dc_result;self.dc=dc;self.response=response
        self.put(0x1000306e,retained);self.u.mem_write(TEXT,raw);before=bytes(self.u.mem_read(0x10003000,161))
        self.u.mem_write(SP-0x100,b'\xa5'*0x200);self.put(SP,STOP)
        arguments=[target,TEXT,background,color,x&0xffffffff,y&0xffffffff]
        for i,v in enumerate(arguments):self.put(SP+4+4*i,v)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.reg_write(UC_X86_REG_ESP,SP);self.instructions=set();self.instruction_bytes={};self.events=[];self.writes=[];self.finished=False;self.active=True
        try:self.u.emu_start(0x401290,0,count=10000)
        finally:self.active=False;self.text_active=False
        assert self.finished and self.u.reg_read(UC_X86_REG_ESP)==SP+4
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert [self.u32(SP+4+i*4) for i in range(6)]==[dc,*arguments[1:]]
        assert bytes(self.u.mem_read(TEXT,len(raw)))==raw and self.u.reg_read(UC_X86_REG_FPCW)==0x37f
        after=bytes(self.u.mem_read(0x10003000,161));result=self.u.reg_read(UC_X86_REG_EAX);result=result if result<2**31 else result-2**32
        return dict(index=index,target=target,input=list(raw),text=list(raw.split(b'\0')[0]),background=background,color=color,x=x,y=y,dcResult=dc_result,dc=dc,gdiResponse=response,retainedDC=retained,retainedDCAfter=self.u32(0x1000306e),before=list(before),after=list(after),events=self.events,writes=self.writes,result=result,
            instructions=[dict(address=a,bytes=self.instruction_bytes[a]) for a in sorted(self.instructions)],end=dict(pc=STOP,sp=SP+4,fpcw=0x37f))

def main():
    vm=LibText();cases=[];strings=[b'\0',b'Loading files\0',b'abc\0ignored',b'\x80\xff\0',bytes(range(1,256))+b'\0',b'x'*4095+b'\0']
    for target,text,result,response in itertools.product((SURFACE,SURFACE+16,SURFACE+32),strings,(-2**31,-1,0,1,2**31-1),(-1,0,1)):
        i=len(cases);cases.append(vm.call(i,target,text,(i*9876543)&0xffffffff,(i*1234567)&0xffffffff,(-2**31,-1,0,1,2**31-1)[i%5],(-2**31,0,2**31-1)[i%3],result,(0,0x12345678,0xffffffff)[i%3],response,(0,0xa5a5a5a5,0xffffffff)[i%3]))
    # Every subsequent call retains the previous source DC; native must do the same.
    retained=vm.u32(0x1000306e);chain=[]
    for i,result in enumerate((0,-1,1,-2**31,2**31-1,0)):
        c=vm.call(len(cases),SURFACE,b'retained\0',7,8,i,-i,result,0x77889900+i,-1,retained);retained=c['retainedDCAfter'];chain.append(c['index']);cases.append(c)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,installation=vm.installation,cases=cases,retainedChain=chain,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();p=ROOT/'build/original/lib-surface-text.json';assert not p.exists();p.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=p.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),sourceEvents=sum(len(c['events']) for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-surface-text.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
