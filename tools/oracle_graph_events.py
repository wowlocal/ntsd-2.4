#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute NTSD's original graph creation and whole message400 event callbacks.

Pinned EXE/lib.dll and Unicorn2.1.4, complete installer parent. Actual401c90 and
401e90 execute; COM/Win32 outputs, interface tokens, finite event queues and
helper-entry backing are declared adapters. Trace real aligned locals, partial
API writes, retained parameters and FLDZ/FSTPQ seek bytes. No actual Windows,
audio device, codec/thread/reentrancy or host release is inferred; no control/
security mutation or manufactured null-interface fault. GRAPH_EVENTS_PLAN.md.
"""
import argparse,base64,copy,json,os,struct
from pathlib import Path
from oracle_lib_initialization import LibInitialization,SP,STOP,STACK,REGISTERS,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,COUNT=0x44d000,0xb440
COM=0x31000000
ABORT=0x80004004
HELPERS={0x43b3d0:('callback',16),0x401e90:('drain',0),0x401c90:('initializeGraph',0)}
FAMILIES={'graph':{0:('query',3)},'control':{},'event':{0x20:('getEvent',5),0x30:('method',4),0x34:('method',4),0x38:('method',2)},'position':{0x20:('method',3)}}

class GraphEvents(LibInitialization):
    def __init__(self):
        self.capturing=False;super().__init__(0);self.parent=super().run()
        self.initial=bytes(self.u.mem_read(BASE,COUNT));self.u.mem_map(COM,0x10000);self.methods={};self.tokens={}
        for j,(family,methods) in enumerate(FAMILIES.items()):
            token=COM+(j+1)*0x1000;v=token+0x100;self.tokens[family]=token;self.put(token,v)
            for offset,(kind,n) in methods.items():
                pc=STOP+0x6000+len(self.methods)*16;self.methods[pc]=(family,offset,kind,n);self.put(v+offset,pc)
        self.code_before=bytes(self.u.mem_read(0x400000,0x4d000));self.lib_before=bytes(self.u.mem_read(0x10000000,0x5000))
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.changed);self.u.hook_add(UC_HOOK_MEM_READ,self.read)
        self.blobs={};self.new_blobs=[]
    def blob(self,b):
        b=bytes(b);h=digest(b)
        if h not in self.blobs:self.blobs[h]=dict(count=len(b),base64=base64.b64encode(b).decode());self.new_blobs.append(h)
        return h
    def fpu(self):return dict(control=self.u.reg_read(UC_X86_REG_FPCW),status=self.u.reg_read(UC_X86_REG_FPSW),tag=self.u.reg_read(UC_X86_REG_FPTAG))
    def record(self,address,b,origin):
        b=bytes(b)
        if BASE<=address and address+len(b)<=BASE+COUNT:region='globals';o=address-BASE;self.global_mask[o:o+len(b)]=b'\1'*len(b)
        elif self.frame is not None and self.frame<=address and address+len(b)<=self.frame+64:region='local';o=address-self.frame;self.local_mask[o:o+len(b)]=b'\1'*len(b)
        else:raise AssertionError(('Unexpected graph write',hex(address),len(b)))
        self.writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=address,bytes=b.hex(),origin=origin,region=region))
        self.actions.append(dict(kind='store',region=region,offset=o,bytes=list(b),origin=origin))
    def changed(self,u,access,address,n,value,data):
        if not self.capturing:return
        if BASE<=address<BASE+COUNT or self.frame is not None and self.frame<=address<self.frame+64:self.record(address,(value&((1<<(8*n))-1)).to_bytes(n,'little'),'CPU')
        elif not STACK<=address<STACK+0x10000:raise AssertionError(('Graph store outside declared data',hex(address)))
    def read(self,u,access,address,n,value,data):
        if self.capturing and self.frame is not None and self.frame<=address and address+n<=self.frame+64:
            self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),offset=address-self.frame,count=n,bytes=bytes(u.mem_read(address,n)).hex()))
    def output(self,address,value):self.put(address,value);self.record(address,struct.pack('<I',value&0xffffffff),'API')
    def request(self,kind,arguments=(),strings=(),response=None):
        e=dict(kind=kind,arguments=list(arguments),strings=[list(s) for s in strings],response=response or dict(result=0));self.events.append(e);self.actions.append(dict(kind='request',event=e));return e
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        for h in list(reversed(self.pending_helpers)):
            if h['returnPC']==pc and sp==h['sp']+4+h['pop']:
                self.returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX),fpu=self.fpu()));self.pending_helpers.remove(h)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in HELPERS:
            kind,pop=HELPERS[pc];self.pending_helpers.append(dict(address=pc,kind=kind,sp=sp,pop=pop,returnPC=self.u32(sp)))
        if pc==0x401e90:
            self.frame=((sp-4)&~63)-64;self.local_before=self.blob(u.mem_read(self.frame,64));self.entry_fpu=self.fpu()
        if pc not in self.boundaries and pc not in self.methods:
            assert 0x43b3d0<=pc<=0x43bc40 or 0x401e90<=pc<=0x401f20 or 0x401c90<=pc<=0x401d26,('Unexpected graph child',hex(pc))
            self.instructions_case[pc]=bytes(u.mem_read(pc,size)).hex();return
        arg=lambda i:self.u32(sp+4+i*4)
        if pc in self.methods:
            family,offset,kind,n=self.methods[pc];assert arg(0)==self.tokens[family]
            if kind=='query':
                guid=bytes(u.mem_read(arg(1),16));target={0xb1:'control',0xb6:'event',0xb2:'position'}[guid[0]];pointer=self.tokens[target]
                r=dict(result=self.spec.get('queryResult',0),pointer=pointer);self.request('queryInterface',[arg(0)],[guid],r);self.output(arg(2),pointer);self.ret(r['result'],n*4);return
            if kind=='getEvent':
                assert [arg(i) for i in range(1,5)]==[self.frame+0x34,self.frame+0x3c,self.frame+0x38,0]
                assert self.queue_index<len(self.spec['queue']),'Declared queue exhausted without E_ABORT'
                r=copy.deepcopy(self.spec['queue'][self.queue_index]);self.queue_index+=1
                self.request('getEvent',[arg(0),offset,0],response=r)
                for key,address in [('code',arg(1)),('first',arg(2)),('second',arg(3))]:
                    if key in r:self.output(address,r[key])
                self.ret(r['result'],n*4);return
            args=[arg(0),offset]+[arg(i) for i in range(1,n)];result=self.spec.get('methodResult',0)
            self.request('method',args,response=dict(result=result))
            if family=='position':
                self.seeks.append(dict(pc=pc,returnPC=self.u32(sp),bytes=bytes(u.mem_read(sp+8,8)).hex(),fpu=self.fpu()));assert args[2:]==[0,0]
            self.ret(result,n*4);return
        _,name=self.boundaries[pc]
        if name=='CoCreateInstance':
            args=[arg(i) for i in range(5)];assert args==[0x44a2a4,0,1,0x44a254,0x44f040]
            result=self.spec.get('createResult',0);r=dict(result=result)
            if self.spec.get('createWrite',True):r['pointer']=self.tokens['graph']
            self.request('createInstance',args,response=r)
            if 'pointer' in r:self.output(args[4],r['pointer'])
            self.ret(result,20)
        elif name=='DefWindowProcA':
            result=self.spec.get('defaultResult',-123);self.request('windowDefault',[arg(i) for i in range(4)],response=dict(result=result));self.ret(result,16)
        else:raise AssertionError(('Unsupported graph API',name,hex(pc)))
    def call(self,spec,index):
        self.spec=spec;self.new_blobs=[]
        if not spec.get('retain'):
            self.u.mem_write(BASE,self.initial)
            for a,f in [(0x44f040,'graph'),(0x44f044,'control'),(0x44f048,'event'),(0x44f04c,'position')]:self.put(a,0 if spec.get('emptyGraph') else self.tokens[f])
            self.put(0x4546f4,0x73000001)
        self.u.mem_write(STACK,bytes((i*spec.get('seed',17)+0xa5)&255 for i in range(0x10000)))
        initialize=spec.get('initialize',False);args=[STOP] if initialize else [STOP,spec.get('window',0x73000001),0x400,spec.get('wParam',0xaabbccdd),spec.get('lParam',0x11223344)]
        self.u.mem_write(SP,struct.pack('<'+'I'*len(args),*args));self.u.reg_write(UC_X86_REG_ESP,SP)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.reg_write(UC_X86_REG_FPCW,0x23f);self.u.reg_write(UC_X86_REG_FPSW,0);self.u.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.events=[];self.actions=[];self.writes=[];self.reads=[];self.seeks=[];self.pending_helpers=[];self.returns=[];self.instructions_case={};self.frame=None;self.local_before=None;self.entry_fpu=None;self.queue_index=0;self.global_mask=bytearray(COUNT);self.local_mask=bytearray(64);self.finished=False
        before=self.blob(self.u.mem_read(BASE,COUNT));self.capturing=True
        try:self.u.emu_start(0x401c90 if initialize else 0x43b3d0,0,count=200000)
        finally:self.capturing=False
        assert self.finished and not self.pending_helpers and self.u.reg_read(UC_X86_REG_ESP)==SP+(4 if initialize else 20)
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert self.fpu()==dict(control=0x23f,status=0,tag=0xffff)
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_before and bytes(self.u.mem_read(0x10000000,0x5000))==self.lib_before
        if not initialize:assert self.queue_index==len(spec['queue'])
        return dict(index=index,spec=spec,before=before,after=self.blob(self.u.mem_read(BASE,COUNT)),globalWritten=self.blob(self.global_mask),localBefore=self.local_before,localAfter=self.blob(self.u.mem_read(self.frame,64)) if self.frame else None,localWritten=self.blob(self.local_mask),frame=self.frame,entryFPU=self.entry_fpu,exitFPU=self.fpu(),actions=self.actions,events=self.events,writes=self.writes,reads=self.reads,seeks=self.seeks,helpers=self.returns,instructions=[dict(address=a,bytes=b) for a,b in sorted(self.instructions_case.items())],result=self.u.reg_read(UC_X86_REG_EAX),sp=self.u.reg_read(UC_X86_REG_ESP))

def specs():
    abort=dict(result=ABORT-2**32)
    for seed in (0,17,31):
        yield dict(label='empty',seed=seed,queue=[abort])
        yield dict(label='terminal-output',seed=seed,queue=[dict(abort,code=1,first=0x7fffffff,second=0x80000000)])
    for status in (0,1,-1,-2147467259,-2147483648,2147483647):
        for code in (0,1,2,3,0xffffffff,0x80000000,0x7fffffff):
            for mask in range(8):
                r=dict(result=status)
                for bit,key,value in [(1,'code',code),(2,'first',0x80000000|code),(4,'second',0xffffffff-code)]:
                    if mask&bit:r[key]=value
                yield dict(label='event-outputs',queue=[r,abort],methodResult=-1,seed=17)
    for method in (0,1,-1,-2147467259):
        for count in (1,2,17,64):
            queue=[dict(result=0,code=1 if i%2==0 else 2,first=i,second=0xffffffff-i) for i in range(count)]+[abort]
            yield dict(label='multi-event',queue=queue,methodResult=method,seed=31)
    for mask in range(8):
        r=dict(result=-1)
        for bit,key,value in [(1,'code',2),(2,'first',0x12345678),(4,'second',0x87654321)]:
            if mask&bit:r[key]=value
        yield dict(label='retained-parameters',queue=[dict(result=0,code=1,first=17,second=21),r,abort],methodResult=1)
    for result in (-1,0,1):yield dict(label='graph-initialize',initialize=True,createResult=result,queryResult=-1,methodResult=-1)
    yield dict(label='own-graph-initialize',initialize=True,emptyGraph=True)
    for code in (1,2,1,0,1):yield dict(label='own-notification',retain=True,queue=[dict(result=0,code=code,first=17,second=21),abort])

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir();vm=GraphEvents();cases=[]
    for spec in specs():
        if a.limit is not None and len(cases)>=a.limit:break
        try:c=vm.call(spec,len(cases))
        except Exception as e:
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(error=repr(e),spec=spec,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,actions=vm.actions,frame=vm.frame,fpu=vm.fpu()),indent=2)+'\n');raise
        cases.append(c)
        for h in vm.new_blobs:(parts/'blobs'/(h+'.json')).write_text(json.dumps(vm.blobs[h],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();target=parts/('%06d.json'%c['index']);tmp=target.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,target)
        checkpoint=path.with_suffix('.incomplete.json');tmp=checkpoint.with_suffix('.tmp');tmp.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(tmp,checkpoint)
        if len(cases)%50==0:print('Completed',len(cases),flush=True)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,tokens=vm.tokens,cases=cases,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    r=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()));path.with_suffix('.report.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2),flush=True)
if __name__=='__main__':main()
