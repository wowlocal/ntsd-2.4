#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute whole original43bec0 window/DirectDraw initialization after lib install.

Pinned EXE/lib.dll, Unicorn2.1.4; controlled Win32/COM results and helper-entry
scratch, not Windows callbacks, devices or an initialized WinMain/CRT chain.
All original children execute; no success stub replaces window/surface helpers.
Preserve full globals/masks, descriptor bytes/writes, ordered requests, allocations
and actual returns, including ignored failures. Only original callback pointers
and declared COM adapters are used; no control/security corruption stimulus.
See docs/research/WINDOW_INITIALIZATION_PLAN.md. Development tooling only.
"""
import argparse,json,struct,os
from pathlib import Path
from collections import Counter
from oracle_lib_initialization import LibInitialization,SP,STOP,STACK,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,COUNT=0x44d000,0xb440
COM=0x31000000
HELPERS={0x43bec0:'wrapper',0x43bdd0:'display',0x401b00:'windowed',0x401bf0:'fullscreen',0x401000:'directDraw',0x401090:'swapSurfaces',0x401110:'plainSurfaces',0x4011d0:'clipperSetup',0x401300:'fullConfigure',0x43e8e0:'clearSetup',0x401250:'clear'}
FRAMES={0x401b00:('windowClass',40),0x401bf0:('windowClass',40),0x401090:('surfaceDescription',108),0x401110:('surfaceDescription',108),0x43e8e0:('pixelFormat',32),0x401250:('fillEffects',100)}
METHODS={'draw':{0x10:('createClipper',4),0x18:('createSurface',4),0x50:('cooperativeLevel',3),0x54:('displayMode',4)},'surface':{8:('release',1),0x14:('blt',6),0x30:('attachedSurface',3),0x54:('pixelFormat',2),0x70:('setClipper',2)},'clipper':{8:('release',1),0x20:('clipperWindow',3)}}

class WindowInitialization(LibInitialization):
    def __init__(self):
        self.capturing=False;super().__init__(0);self.parent=super().run()
        self.initial_globals=bytes(self.u.mem_read(BASE,COUNT));self.u.mem_map(COM,0x100000);self.com_methods={}
        for family,items in METHODS.items():
            for offset,(name,n) in items.items():
                pc=STOP+0x6000+len(self.com_methods)*16;self.com_methods[pc]=(family,name,n)
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.observe_write);self.u.hook_add(UC_HOOK_MEM_READ,self.observe_read,begin=SP+8,end=SP+11)
        self.code_image=bytes(self.u.mem_read(0x400000,0x4d000));self.library=bytes(self.u.mem_read(0x10000000,0x5000))
    def observe_read(self,u,access,address,n,value,data):
        if self.capturing:self.show_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,count=n))
    def allocate(self,family):
        a=COM+0x1000*(len(self.objects)+1);v=a+0x100;self.put(a,v)
        for offset,(name,n) in METHODS[family].items():self.put(v+offset,next(pc for pc,item in self.com_methods.items() if item==(family,name,n)))
        self.objects.append(dict(address=a,family=family,releases=[]));return a
    def output(self,address,value):
        self.put(address,value)
        if BASE<=address<BASE+COUNT:self.record_write(address,4,struct.pack('<I',value),origin='API')
    def record_write(self,address,n,payload,origin='CPU'):
        o=address-BASE;assert 0<=o<o+n<=COUNT;self.mask[o:o+n]=b'\1'*n;self.global_writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=address,bytes=payload.hex(),origin=origin))
    def observe_write(self,u,access,address,n,value,data):
        if not self.capturing:return
        payload=(value&((1<<(8*n))-1)).to_bytes(n,'little')
        if BASE<=address<BASE+COUNT:self.record_write(address,n,payload)
        for f in self.frames:
            if f['address']<=address and address+n<=f['address']+f['count']:f['mask'][address-f['address']:address-f['address']+n]=b'\1'*n
    def request(self,kind,words=(),structure=None,strings=()):
        r=dict(kind=kind,words=list(words),strings=[list(s) for s in strings])
        if structure is not None:
            address,n=structure;frame=next(f for f in reversed(self.frames) if f['address']==address and f['count']==n)
            r.update(bytes=list(self.u.mem_read(address,n)),defined=[bool(x) for x in frame['mask']])
        self.counts[kind]+=1;key=kind+'#'+str(self.counts[kind]);response=dict(result=self.spec.get('results',{}).get(key,1 if kind in ('registerClass','updateWindow','showWindow') else 0))
        event=dict(key=key,request=r,response=response,returnPC=self.u32(self.u.reg_read(UC_X86_REG_ESP)))
        self.events.append(event);return response
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        for h in list(reversed(self.pending_helpers)):
            if h['returnPC']==pc and sp==h['sp']+4:
                self.helper_returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX)));self.pending_helpers.remove(h)
                self.frames=[f for f in self.frames if f['sp']!=h['sp']]
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in HELPERS:self.pending_helpers.append(dict(address=pc,kind=HELPERS[pc],sp=sp,returnPC=self.u32(sp)))
        if pc in FRAMES:
            kind,n=FRAMES[pc];f=dict(kind=kind,address=sp-n,count=n,sp=sp,mask=bytearray(n));self.frames.append(f)
            self.backings.append(dict(kind=kind,entry=pc,address=sp-n,bytes=list(u.mem_read(sp-n,n))))
        if pc not in self.boundaries and pc not in self.com_methods:self.case_instructions[pc]=bytes(u.mem_read(pc,size)).hex();return
        arg=lambda i:self.u32(sp+4+4*i)
        if pc in self.com_methods:
            family,name,n=self.com_methods[pc];args=[arg(i) for i in range(n)];target=next(o for o in self.objects if o['address']==args[0]);assert target['family']==family
            if name=='createSurface':response=self.request(name,[args[0],args[2],args[3]],(args[1],108))
            elif name=='attachedSurface':
                assert bytes(u.mem_read(args[1],4))==b'\4\0\0\0';response=self.request(name,[args[0],4,args[2]])
            elif name=='pixelFormat':response=self.request(name,[args[0]],(args[1],32))
            elif name=='blt':response=self.request(name,args[:5],(args[5],100))
            else:response=self.request(name,args)
            result=response['result']
            if name in ('createSurface','attachedSurface','createClipper') and result>=0:
                pointer=self.allocate('clipper' if name=='createClipper' else 'surface');self.output(args[2],pointer);response['output']=pointer
            if name=='pixelFormat' and result>=0:
                payload=struct.pack('<8I',32,0x20,0,8,0,0,0,0);u.mem_write(args[1],payload);response['bytes']=list(payload)
            if name=='release':target['releases'].append(dict(key=self.events[-1]['key'],result=result&0xffffffff))
            self.ret(result,n*4);return
        _,name=self.boundaries[pc]
        if name=='GetSystemMetrics':
            response=self.request('metric',[arg(0)]);i=self.counts['metric']-1;values=self.spec.get('metrics',[4,4,4,23] if self.spec.get('mode',0)==0 else [1080,1920]);response['result']=values[i];self.ret(response['result'],4)
        elif name in ('LoadIconA','LoadCursorA'):
            kind='icon' if name=='LoadIconA' else 'cursor';response=self.request(kind,[arg(0),arg(1)]);response['result']=self.spec.get('results',{}).get(kind+'#1',0x72000001 if kind=='icon' else 0x72000002);self.ret(response['result'],8)
        elif name=='RegisterClassA':response=self.request('registerClass',structure=(arg(0),40));self.ret(response['result'],4)
        elif name=='CreateWindowExA':
            words=[arg(i) for i in range(12)];response=self.request('createWindow',words,strings=[self.string(words[1]),self.string(words[2])]);response['result']=self.spec.get('results',{}).get('createWindow#1',0x73000001);self.ret(response['result'],48)
        elif name in ('UpdateWindow','ShowWindow'):
            n=1 if name=='UpdateWindow' else 2;response=self.request('updateWindow' if n==1 else 'showWindow',[arg(i) for i in range(n)]);self.ret(response['result'],n*4)
        elif name=='DirectDrawCreate':
            args=[arg(i) for i in range(3)];response=self.request('directDrawCreate',args)
            if response['result']>=0:response['output']=self.allocate('draw');self.output(args[1],response['output'])
            self.ret(response['result'],12)
        elif name=='OutputDebugStringA':response=self.request('debug',strings=[self.string(arg(0))]);self.ret(response['result'],4)
        else:raise RuntimeError(('Unsupported window API',name,hex(pc),hex(self.u32(sp))))
    def call(self,spec):
        self.spec=spec;self.show_reads=[];self.objects=[];self.events=[];self.counts=Counter();self.frames=[];self.backings=[];self.pending_helpers=[];self.helper_returns=[];self.case_instructions={};self.mask=bytearray(COUNT);self.global_writes=[]
        self.u.mem_write(BASE,self.initial_globals)
        for address,value in [(0x458430,spec.get('mode',0)),(0x44d78c,spec.get('width',794)),(0x44d790,spec.get('height',550)),(0x453e0c,spec.get('pixelFlag',0)),(0x458348,spec.get('oldDisplay',0x11223344))]:self.put(address,value)
        self.u.mem_write(STACK,bytes((i*spec.get('scratchSeed',0)+0xa5)&255 for i in range(0x10000)))
        self.u.mem_write(SP,struct.pack('<3I',STOP,spec.get('instance',0x400000),spec.get('show',10)&0xffffffff));self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_FPCW,0x37f)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip((UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI),saved):self.u.reg_write(r,v)
        before=bytes(self.u.mem_read(BASE,COUNT));self.capturing=True;self.finished=False
        try:self.u.emu_start(0x43bec0,0,count=200000)
        finally:self.capturing=False
        assert self.finished and self.u.reg_read(UC_X86_REG_ESP)==SP+4 and not self.frames and not self.pending_helpers
        assert [self.u.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)]==saved
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_image and bytes(self.u.mem_read(0x10000000,0x5000))==self.library
        after=bytes(self.u.mem_read(BASE,COUNT));rebuilt=bytearray(before)
        for w in self.global_writes:o=w['address']-BASE;payload=bytes.fromhex(w['bytes']);rebuilt[o:o+len(payload)]=payload
        assert bytes(rebuilt)==after
        return dict(spec=spec,before=list(before),after=list(after),written=list(self.mask),writes=self.global_writes,backings=self.backings,events=self.events,objects=self.objects,helpers=self.helper_returns,instructions=[dict(address=a,bytes=b) for a,b in sorted(self.case_instructions.items())],showReads=self.show_reads,result=self.u.reg_read(UC_X86_REG_EAX),fpcw=self.u.reg_read(UC_X86_REG_FPCW),sp=self.u.reg_read(UC_X86_REG_ESP))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);a=p.parse_args();path=ROOT/a.output;assert not path.exists()
    vm=WindowInitialization();cases=[];seen={}
    checkpoint=path.with_suffix('.incomplete.json')
    if checkpoint.exists():
        saved=json.loads(checkpoint.read_bytes());assert saved['incomplete'] is True
        cases=saved['cases']
        for c in cases:seen[json.dumps({k:v for k,v in c['spec'].items() if k!='label'},sort_keys=True)]=c
        print('Resuming',len(cases),'immutable controlled returns',digest(checkpoint.read_bytes()),flush=True)
    def capture(spec):
        key=json.dumps({k:v for k,v in spec.items() if k!='label'},sort_keys=True)
        if key in seen:return seen[key]
        try:c=vm.call(spec)
        except Exception as e:
            failure=dict(spec=spec,error=repr(e),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,backings=vm.backings,completed=len(cases))
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(failure,indent=2)+'\n');raise
        c['index']=len(cases);cases.append(c);seen[key]=c
        if True:
            raw=(json.dumps(dict(scope=__doc__,incomplete=True,cases=cases),sort_keys=True,separators=(',',':'))+'\n').encode();tmp=checkpoint.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,checkpoint)
            if len(cases)%25==0:print('Completed',len(cases),'checkpoint',digest(raw),flush=True)
        return c
    contexts=[(0,{}),(1,{}),(1,{'createSurface#1':-1}),(1,{'attachedSurface#1':-1}),(1,{'createSurface#1':-1,'createSurface#2':-1}),(1,{'createSurface#1':-1,'attachedSurface#1':-1}),(1,{'attachedSurface#1':-1,'createSurface#2':-1}),(1,{'attachedSurface#1':-1,'attachedSurface#2':-1})]
    tested={'directDrawCreate','cooperativeLevel','displayMode','createSurface','attachedSurface','createClipper','clipperWindow','pixelFormat','blt','setClipper'}
    for group,(mode,results) in enumerate(contexts):
        base=dict(label=f'path-{group}',mode=mode,results=results);c=capture(base)
        for event in c['events']:
            key=event['key'];kind=event['request']['kind']
            if key in results:continue
            values=[-1,-2147467259,1] if kind in tested else [0] if kind in ('icon','cursor','registerClass','createWindow','updateWindow','showWindow') else []
            for value in values:capture(dict(label=f'path-{group}-{key}-{value}',mode=mode,results={**results,key:value}))
    for mode in (0,1,-1,2):
        for width,height,metrics in [(794,550,[2,3,7,19] if mode==0 else [768,1024]),(0,0,[-1,-2,-3,-4] if mode==0 else [0,0]),(2147483647,2147483647,[1,2147483647,1,1] if mode==0 else [2147483647,-2147483648]),(-1,-2147483648,[2147483647,-1,1,-1] if mode==0 else [-1,1])]:
            for flag in (0,1,-1):capture(dict(label='dimensions-metrics-pixel-flag',mode=mode,width=width,height=height,metrics=metrics,pixelFlag=flag,scratchSeed=17))
    for mode in (0,1):
        for show in (0,1,5,10,-1,2147483647,-2147483648):capture(dict(label='unused-show',mode=mode,show=show,scratchSeed=31,instance=0x74000001))
    assert all(c['result']==1 and not c['showReads'] for c in cases)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,cases=cases,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    report=dict(corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),events=sum(len(c['events']) for c in cases),helpers=sum(len(c['helpers']) for c in cases),instructions=len({i['address'] for c in cases for i in c['instructions']}),sourceSHA256=digest(Path(__file__).read_bytes()),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/window-initialization.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
