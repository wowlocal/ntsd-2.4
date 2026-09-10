#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole43e8e0 game art setup and401250 in pinned NTSD2.4/Unicorn2.1.4.

Execute actual query/clear/debug control flow to recover live surface reads,
retained ordinary32/100-byte locals and signed results. COM output/HRESULTs,
valid surface-reference changes and debug results are declared API boundaries;
no Windows/device/full-dispatcher or initialized-stack provenance claim. No
control/protective storage corruption. Atomic completed cases preserve evidence.
"""
import argparse,itertools,json,os
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_ESP,UC_X86_REG_EIP,UC_X86_REG_EAX,UC_X86_REG_FPCW
from oracle_application_dispatch_prefix import DispatchPrefix,GLOBAL,SIZE,SP,STOP,COM,SURFACE,VTABLE,REGISTERS,digest,signed
from import_ntsd import ROOT,EXE_SHA256
QUERY,DEBUG=COM+16,COM+32
Q,C,STACK=SP-32,SP-144,SP-256

class ArtSetup(DispatchPrefix):
    def __init__(self):
        super().__init__();self.put(VTABLE+0x54,QUERY);self.put(0x447080,DEBUG)
        self.union=set();self.previous=None
    def written(self,u,access,p,n,value,data):
        if not self.active:return
        assert STACK<=p<p+n<=SP+16,(hex(p),n,hex(u.reg_read(UC_X86_REG_EIP)))
        self.stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,bytes=list((value&((1<<(n*8))-1)).to_bytes(n,'little')),adapter=False))
        if Q<=p<p+n<=Q+32:self.qmask[p-Q:p-Q+n]=b'\1'*n
        if C<=p<p+n<=C+100:self.cmask[p-C:p-C+n]=b'\1'*n
    def apiwrite(self,p,b):
        self.uc.mem_write(p,bytes(b));self.stores.append(dict(pc=self.uc.reg_read(UC_X86_REG_EIP),address=p,bytes=list(b),adapter=True))
        if Q<=p<p+len(b)<=Q+32:self.qmask[p-Q:p-Q+len(b)]=b'\1'*len(b)
    def event(self,kind,**kw):
        self.events.append(dict(kind=kind,globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),storeCount=len(self.stores),**kw))
    def code(self,u,pc,n,data):
        if not self.active:return
        if pc==STOP:self.finished=True;u.emu_stop();return
        sp=u.reg_read(UC_X86_REG_ESP);s=self.spec
        if pc==QUERY:
            args=[self.u32(sp+4+i*4) for i in range(2)];assert args==[self.u32(0x455634),Q]
            self.event('query',target=args[0],bytes=list(u.mem_read(Q,32)),defined=[bool(x) for x in self.qmask],response=s['queryResult'])
            for w in s['queryWrites']:self.apiwrite(Q+w['offset'],w['bytes'])
            if s['queryTarget'] is not None:self.apiwrite(0x455608,s['queryTarget'].to_bytes(4,'little'))
            self.ret(s['queryResult'],8);return
        if pc==COM:
            args=[self.u32(sp+4+i*4) for i in range(6)];assert args==[self.u32(0x455608),0,0,0,0x1000400,C]
            self.event('clear',target=args[0],flags=args[4],bytes=list(u.mem_read(C,100)),defined=[bool(x) for x in self.cmask],response=s['clearResult'])
            if s['clearTarget'] is not None:self.apiwrite(0x455608,s['clearTarget'].to_bytes(4,'little'))
            self.ret(s['clearResult'],24);return
        if pc==DEBUG:
            p=self.u32(sp+4);b=bytearray();a=p
            while u.mem_read(a,1)!=b'\0':b.extend(u.mem_read(a,1));a+=1
            self.event('debug',address=p,bytes=list(b),response=s['debugResult']);self.ret(s['debugResult'],4);return
        assert 0x43e8e0<=pc<=0x43e934 or 0x401250<=pc<=0x401281,hex(pc)
        self.pcs.add(pc);self.union.add(pc)
    def run(self,s):
        self.active=False;self.spec=s
        if not s['continued']:
            self.begin('clear');self.uc.mem_write(GLOBAL,self.template)
            self.put(0x455634,s['querySurface']);self.put(0x455608,s['initialTarget'])
            self.uc.mem_write(Q,bytes(s['queryBacking']));self.uc.mem_write(C,bytes(s['clearBacking']))
            self.qmask=bytearray(32);self.cmask=bytearray(100)
        else:
            assert self.previous is not None
            # New direct invocation uses its own previous local/global bytes.
            self.uc.reg_write(UC_X86_REG_ESP,SP);self.put(SP,STOP)
        self.events=[];self.stores=[];self.pcs=set();self.finished=False
        before=dict(globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),stack=self.blob(self.uc.mem_read(STACK,272)),
            query=list(self.uc.mem_read(Q,32)),queryMask=list(self.qmask),clear=list(self.uc.mem_read(C,100)),clearMask=list(self.cmask))
        self.execute(0x43e8e0)
        assert self.uc.reg_read(UC_X86_REG_ESP)==SP+4
        assert [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        after=dict(globals=self.blob(self.uc.mem_read(GLOBAL,SIZE)),stack=self.blob(self.uc.mem_read(STACK,272)),
            query=list(self.uc.mem_read(Q,32)),queryMask=list(self.qmask),clear=list(self.uc.mem_read(C,100)),clearMask=list(self.cmask),
            result=signed(self.uc.reg_read(UC_X86_REG_EAX)),sp=SP+4,pc=STOP,fpcw=self.uc.reg_read(UC_X86_REG_FPCW))
        self.previous=after
        return dict(spec=s,before=before,after=after,events=self.events,stores=self.stores,instructions=sorted(self.pcs))

def specifications():
    hrs=[-2**31,-1,0,1,2**31-1]
    for i,(q,c,output,pattern) in enumerate(itertools.product(hrs,hrs,range(3),range(3))):
        backing=lambda n:[0]*n if pattern==0 else [165]*n if pattern==1 else list(range(n))
        writes=[] if output==0 else [dict(offset=4,bytes=list(range(8 if output==1 else 28)))]
        yield dict(index=i,continued=False,querySurface=SURFACE+16*(i%3),initialTarget=SURFACE+16*((i+1)%3),
            queryBacking=backing(32),clearBacking=backing(100),queryWrites=writes,queryResult=q,clearResult=c,debugResult=hrs[i%5],
            queryTarget=None if output==0 else SURFACE+16*((i+2)%3),clearTarget=None if pattern==0 else SURFACE+16*(i%3))
    for j in range(6):
        yield dict(index=225+j,continued=j>0,querySurface=SURFACE,initialTarget=SURFACE+16,queryBacking=[90]*32,clearBacking=[60]*100,
            queryWrites=[] if j%2 else [dict(offset=4+j,bytes=[j+1]*8)],queryResult=hrs[j%5],clearResult=hrs[(j+2)%5],debugResult=hrs[(j+3)%5],
            queryTarget=SURFACE+16*(j%3),clearTarget=SURFACE+16*((j+1)%3))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args()
    path=Path(a.output);parts=path.with_suffix('.parts');parts.mkdir();vm=ArtSetup();cases=[]
    for s in itertools.islice(specifications(),a.limit):
        try:c=vm.run(s)
        except Exception as e:
            path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=s,events=vm.events,stores=vm.stores,instructions=sorted(vm.pcs),blobs=vm.blobs)))
            raise
        cases.append(c);out=parts/f'{s["index"]:04d}.json';tmp=out.with_suffix('.tmp');tmp.write_text(json.dumps(dict(case=c,blobs=vm.blobs),sort_keys=True,separators=(',',':'))+'\n');os.replace(tmp,out)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,globalAddress=GLOBAL,globalSize=SIZE,globalTemplate=vm.blob(vm.template),stackAddress=STACK,
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.union),nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    print(json.dumps(dict(cases=len(cases),bytes=len(raw),sha256=digest(raw),instructions=len(vm.union),blobs=len(vm.blobs))))
if __name__=='__main__':main()
