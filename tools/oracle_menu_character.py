#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute NTSD whole422f60 character decoder for network-menu compatibility.

Pinned EXE and actual lib installer on Unicorn2.1.4. Trace Shift reads, declared
GetKeyState outputs and request order, AL/full EAX and real saved-register return.
The caller sign-extends AL. No Windows keyboard/device polling or control-field
corruption. Full globals stay immutable. See MENU_CHARACTER_PLAN.md.
"""
import argparse,base64,json,os,struct
from pathlib import Path
from oracle_lib_initialization import LibInitialization,SP,STACK,STOP,REGISTERS,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import *
BASE,COUNT,SHIFT=0x44d000,0xb440,0x455388

class MenuCharacter(LibInitialization):
    def __init__(self):
        self.capturing=False;super().__init__(0);self.parent=super().run();self.initial=bytes(self.u.mem_read(BASE,COUNT));self.images_before={name:bytes(self.u.mem_read(pe.base,n)) for name,(pe,n) in self.images.items()};self.blobs={};self.all_pcs={};self.new_blobs=[]
        self.u.hook_add(UC_HOOK_MEM_READ,self.read);self.u.hook_add(UC_HOOK_MEM_WRITE,self.changed)
    def blob(self,b):
        b=bytes(b);key=digest(b)
        if key not in self.blobs:self.blobs[key]=dict(count=len(b),base64=base64.b64encode(b).decode());self.new_blobs.append(key)
        return key
    def read(self,u,access,a,n,value,data):
        if self.capturing and BASE<=a<a+n<=BASE+COUNT:
            assert a==SHIFT and n==1;self.events.append(dict(kind='shift',pc=u.reg_read(UC_X86_REG_EIP),value=u.mem_read(a,1)[0]))
    def changed(self,u,access,a,n,value,data):
        if self.capturing:assert STACK<=a<a+n<=STACK+0x10000,('Unexpected character write',hex(a),hex(u.reg_read(UC_X86_REG_EIP)))
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in self.boundaries:
            _,name=self.boundaries[pc];sp=u.reg_read(UC_X86_REG_ESP);assert name=='GetKeyState' and self.u32(sp+4)==20
            assert self.calls<len(self.spec['caps']);value=self.spec['caps'][self.calls];self.calls+=1;self.events.append(dict(kind='keyState',argument=20,result=value,returnPC=self.u32(sp)));self.ret(value,4);return
        assert 0x422f60<=pc<=0x423222,('Character PC',hex(pc));self.pcs.add(pc);self.all_pcs[pc]=bytes(u.mem_read(pc,size)).hex()
    def call(self,spec,index):
        self.spec=spec;self.new_blobs=[];self.u.mem_write(BASE,self.initial);self.u.mem_write(SHIFT,bytes([spec['shift']]));before=self.blob(self.u.mem_read(BASE,COUNT));self.events=[];self.pcs=set();self.calls=0;self.finished=False
        self.u.mem_write(STACK,b'\xa5'*0x10000);self.put(SP,STOP);self.put(SP+4,spec['key']);self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_EAX,spec.get('eax',0x12345678));self.u.reg_write(UC_X86_REG_EFLAGS,2);self.u.reg_write(UC_X86_REG_FPCW,0x23f)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGISTERS,saved):self.u.reg_write(r,v)
        self.capturing=True
        try:self.u.emu_start(0x422f60,0,count=10000)
        finally:self.capturing=False
        assert self.finished and self.u.reg_read(UC_X86_REG_ESP)==SP+4 and [self.u.reg_read(r) for r in REGISTERS]==saved and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        after=self.blob(self.u.mem_read(BASE,COUNT));assert after==before
        for name,(pe,n) in self.images.items():
            if name=='NTSD 2.4.exe':assert bytes(self.u.mem_read(pe.base,BASE-pe.base))==self.images_before[name][:BASE-pe.base]
            else:assert bytes(self.u.mem_read(pe.base,n))==self.images_before[name]
        eax=self.u.reg_read(UC_X86_REG_EAX)
        return dict(index=index,spec=spec,before=before,after=after,events=self.events,instructions=sorted(self.pcs),result=eax&255,eax=eax,sp=SP+4,saved=saved,fpcw=0x23f)

def specs():
    shifts=(0,0x63,0x64,0x65,0xff);caps=(0xffff8000,0xffffffff,0,1,2,0x7fff)
    for key in range(300):
        for shift in shifts:
            for value in caps:yield dict(label='caller-domain',key=key,shift=shift,caps=[value,value])
    for key in range(65,91):
        for first in caps:
            for second in caps:yield dict(label='successive-caps',key=key,shift=100,caps=[first,second])
    for shift in range(256):
        for key in (65,49):yield dict(label='every-shift-byte',key=key,shift=shift,caps=[1,0])
    for key in (300,301,0x7fffffff,0x80000000,0xffffffff,0x10020,0x10041,0x10060):
        for shift in shifts:yield dict(label='unsigned-range',key=key,shift=shift,caps=[1,0])
    for caps_pair in ([0x12340000,0x56780001],[0xabcd0001,0x12340000],[0x12348000,0x56787fff],[0xabcdef01,0x7654ffff]):
        yield dict(label='api-high-word',key=65,shift=100,caps=list(caps_pair),eax=0xfedcba98)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir();vm=MenuCharacter();cases=[]
    for s in specs():
        if a.limit is not None and len(cases)>=a.limit:break
        try:c=vm.call(s,len(cases))
        except Exception as e:
            path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events),indent=2)+'\n');raise
        cases.append(c)
        for key in vm.new_blobs:(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();target=parts/('%06d.json'%c['index']);temp=target.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,target)
        checkpoint=path.with_suffix('.incomplete.json');temp=checkpoint.with_suffix('.tmp');temp.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(temp,checkpoint)
        if len(cases)%1000==0:print('Completed',len(cases),flush=True)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,initialGlobals=vm.blob(vm.initial),globalWritten=vm.blob(bytes(COUNT)),cases=cases,blobs=vm.blobs,instructions=[dict(address=a,bytes=v) for a,v in sorted(vm.all_pcs.items())],limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    # Final metadata blobs are retained separately from already atomic cases.
    for key in (doc['initialGlobals'],doc['globalWritten']):(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw);report=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()));path.with_suffix('.report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
