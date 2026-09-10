#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute whole NTSD402d70 exit and retained client-to-exit compatibility calls.

Pinned EXE/lib installer and actual VC80 memset on Unicorn2.1.4. Trace literal,
address bytes, strlen, sendto and cleanup through original cookie checks/returns.
Platform results are declared; no real socket, external address, control-field
corruption or manufactured memory fault. NETWORK_EXIT_PLAN.md defines limits.
"""
import argparse,json,os,struct
from pathlib import Path
from oracle_network_client import Client,BASE,COUNT,spec as client_spec
from oracle_lib_initialization import SP,STACK,STOP,REGISTERS,LIB_SHA256,digest
from oracle_crt import DLL_SHA256
from import_ntsd import ROOT,EXE_SHA256
from unicorn.x86_const import *
FRAME=SP-0x104
HELPERS={0x402d70:'exit',0x4450b2:'cookieCheck'}

class NetworkExit(Client):
    def __init__(self):self.exit_active=False;super().__init__()
    def record(self,a,b,origin):
        if not self.exit_active:return super().record(a,b,origin)
        b=bytes(b)
        if BASE<=a<a+len(b)<=BASE+COUNT:region='globals';o=a-BASE;mask=self.gm
        elif FRAME<=a<a+len(b)<=FRAME+256:region='local';o=a-FRAME;mask=self.lm
        else:raise AssertionError(('Exit storage write',hex(a),len(b)))
        mask[o:o+len(b)]=b'\1'*len(b);self.writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=a,bytes=b.hex(),origin=origin,region=region))
        if not self.pending_memset:self.actions.append(dict(kind='store',region=region,offset=o,bytes=list(b)))
    def changed(self,u,access,a,n,value,data):
        if not self.exit_active:return super().changed(u,access,a,n,value,data)
        if not self.capturing:return
        if BASE<=a<a+n<=BASE+COUNT or FRAME<=a<a+n<=FRAME+256:self.record(a,(value&((1<<(8*n))-1)).to_bytes(n,'little'),'CPU')
        elif not STACK<=a<a+n<=STACK+0x10000:raise AssertionError(('Unexpected exit write',hex(a),hex(u.reg_read(UC_X86_REG_EIP))))
    def read(self,u,access,a,n,value,data):
        if not self.exit_active:return super().read(u,access,a,n,value,data)
        if self.capturing and (FRAME<=a<a+n<=FRAME+256 or 0x44f1b0<=a<a+n<=0x44f1b8 or 0x44f208<=a<a+n<=0x44f20c):self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=a,bytes=bytes(u.mem_read(a,n)).hex()))
    def code(self,u,pc,size,data):
        if not self.exit_active:return super().code(u,pc,size,data)
        if not self.capturing:return
        sp=u.reg_read(UC_X86_REG_ESP)
        if self.pending_memset and pc==self.pending_memset['returnPC']:
            m=self.pending_memset;assert sp==m['sp']+4 and u.reg_read(UC_X86_REG_EAX)==FRAME and bytes(u.mem_read(FRAME,256))==bytes(256)
            self.actions.append(dict(kind='store',region='local',offset=0,bytes=[0]*256));self.memsets.append(m);self.pending_memset=None
        for item in list(reversed(self.pending_helpers)):
            if item['returnPC']==pc and sp==item['sp']+4:self.returns.append(dict(**item,eax=u.reg_read(UC_X86_REG_EAX)));self.pending_helpers.remove(item)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in HELPERS:self.pending_helpers.append(dict(address=pc,kind=HELPERS[pc],sp=sp,returnPC=self.u32(sp)))
        if pc==0x4450b2:
            c=dict(value=u.reg_read(UC_X86_REG_ECX),expected=self.u32(0x44eea4));assert c['value']==c['expected'];self.cookies.append(c)
        if pc==self.memset:
            a,v,n=[self.u32(sp+i) for i in (4,8,12)];assert (a,v,n)==(FRAME,0,256);self.pending_memset=dict(address=a,value=v,count=n,sp=sp,returnPC=self.u32(sp))
        if pc in (0x402e7b,0x402eb6):self.return_pc=pc
        if pc not in self.boundaries:
            assert 0x402d70<=pc<=0x402eb6 or pc in (0x43f3ba,0x43f3b4,0x43f3c0,0x4450a0,0x4450b2,0x4450b8,0x4450ba) or self.crt.base<=pc<self.crt.base+0x100000,('Unexpected exit PC',hex(pc))
            self.instructions_case[pc]=bytes(u.mem_read(pc,size)).hex();return
        _,name=self.boundaries[pc];arg=lambda i:self.u32(sp+4+4*i);s=self.spec
        if name=='ordinal:20':
            assert arg(1)==FRAME and arg(5)==16;payload=bytes(u.mem_read(arg(1),arg(2)));target=bytes(u.mem_read(arg(4),16));r=s.get('sendResult',len(payload))
            self.request('sendTo',[arg(0),arg(2),arg(3),arg(5)],payload+target,result=r);self.ret(r,24)
        elif name=='ordinal:3':r=s.get('closeResult',-1);self.request('closeSocket',[arg(0)],result=r);self.ret(r,4)
        elif name=='ordinal:116':r=s.get('cleanupResult',0);self.request('cleanup',result=r);self.ret(r)
        elif name=='MessageBoxA':r=s.get('messageResult',1);self.request('message',[arg(0),arg(3)],self.string(arg(1))+b'\0'+self.string(arg(2))+b'\0',result=r);self.ret(r,16)
        else:raise AssertionError(('Unexpected exit API',name,hex(pc)))
    def call_exit(self,spec,index):
        self.spec=spec;self.new_blobs=[]
        if not spec.get('retain'):
            self.u.mem_write(BASE,self.initial)
            for a,v in [(0x44f1b4,spec.get('listener',0x34560001)),(0x44f1b0,spec.get('active',1)),(0x44f46c,0x34560003),(0x44f208,spec.get('address',0x0100007f))]:self.put(a,v)
            self.u.mem_write(0x44f58c,bytes(spec.get('sockaddr',[(i*13+7)&255 for i in range(16)])))
        self.u.mem_write(STACK,bytes((i*spec.get('seed',17)+0xa5)&255 for i in range(0x10000)));self.put(SP,STOP);self.u.reg_write(UC_X86_REG_ESP,SP)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.reg_write(UC_X86_REG_FPCW,0x23f);self.u.reg_write(UC_X86_REG_EFLAGS,2)
        self.events=[];self.actions=[];self.writes=[];self.reads=[];self.cookies=[];self.pending_helpers=[];self.returns=[];self.instructions_case={};self.pending_memset=None;self.memsets=[];self.gm=bytearray(COUNT);self.lm=bytearray(256);self.finished=False;self.return_pc=None
        before=self.blob(self.u.mem_read(BASE,COUNT));local_before=self.blob(self.u.mem_read(FRAME,256));self.exit_active=True;self.capturing=True
        try:self.u.emu_start(0x402d70,0,count=200000)
        finally:self.capturing=False;self.exit_active=False
        assert self.finished and not self.pending_helpers and self.pending_memset is None and self.u.reg_read(UC_X86_REG_ESP)==SP+4
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677] and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert self.images_before==[bytes(self.u.mem_read(a,n)) for a,n in ((0x400000,0x4d000),(0x10000000,0x5000),(self.crt.base,0x100000))]
        return dict(index=index,spec=spec,before=before,after=self.blob(self.u.mem_read(BASE,COUNT)),localBefore=local_before,localAfter=self.blob(self.u.mem_read(FRAME,256)),globalWritten=self.blob(self.gm),localWritten=self.blob(self.lm),frame=FRAME,actions=self.actions,events=self.events,writes=self.writes,reads=self.reads,memsets=self.memsets,cookies=self.cookies,helpers=self.returns,instructions=[dict(address=a,bytes=v) for a,v in sorted(self.instructions_case.items())],result=self.u.reg_read(UC_X86_REG_EAX),returnPC=self.return_pc,sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW))

def specs():
    yield dict(label='default')
    for listener in (0,1,0xffffffff):
        for active in (0,1,0xffffffff):yield dict(label='gates',listener=listener,active=active)
    for r in (-1,0,1,19,0x7fffffff):yield dict(label='send-status',sendResult=r)
    for field in ('closeResult','cleanupResult'):
        for r in (-1,0,1,19,0x7fffffff):yield dict(label=field,**{field:r})
    for r in (-1,0,1,0x7fffffff):yield dict(label='message-status',sendResult=-1,messageResult=r)
    for i in range(4):
        for byte in (0,1,0x7f,0x80,0xff):yield dict(label='address-byte',address=(0x55555555&~(255<<(8*i)))|byte<<(8*i))
    for x in (0,0xff):yield dict(label='sockaddr',sockaddr=[x]*16)
    yield dict(label='own-failure',sendResult=-1)
    yield dict(label='own-retry',retain=True)
    yield dict(label='own-repeat',retain=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir();vm=NetworkExit();cases=[];parents=[]
    def save(s):
        try:c=vm.call_exit(s,len(cases))
        except Exception as e:
            path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,writes=vm.writes),indent=2)+'\n');raise
        cases.append(c)
        for key in vm.new_blobs:(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();target=parts/('%06d.json'%c['index']);tmp=target.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,target)
        checkpoint=path.with_suffix('.incomplete.json');tmp=checkpoint.with_suffix('.tmp');tmp.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(tmp,checkpoint)
    for s in specs():
        if a.limit is not None and len(cases)>=a.limit:break
        save(s)
    if a.limit is None:
        parents.append(Client.call(vm,client_spec('own-client-before-exit'),0))
        # Retain every parent blob atomically before continuing its actual state.
        for key in vm.new_blobs:(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
        save(dict(label='own-client-exit',retain=True,parentClient=0));save(dict(label='own-client-repeat',retain=True))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,parent=vm.parent,clientParents=parents,cases=cases,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw);report=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),clientParents=len(parents),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()));path.with_suffix('.report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
