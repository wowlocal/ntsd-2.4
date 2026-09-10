#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute original whole window-lifecycle callbacks and display recreation.

Pinned NTSD EXE/lib.dll, Unicorn2.1.4, complete installer parent. Whole43bdd0,
401ae0/401a80 and sound/music/replay children execute. Win32/COM/free results,
rectangle outputs and helper-entry backing are explicit boundaries, not actual
Windows callbacks, device/heap ownership or CRT startup. Retained own window
chains have declared message delivery; no reentrancy or control-pointer/security
corruption is manufactured. See WINDOW_LIFECYCLE_PLAN.md; development tooling.
"""
import argparse,base64,copy,json,os,struct
from pathlib import Path
from collections import Counter
from oracle_window_initialization import WindowInitialization,METHODS,BASE,COUNT,COM
from oracle_lib_initialization import SP,STOP,STACK,REGISTERS,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn.x86_const import *

POINTERS,REPLAY=0x4588a8,0x32000000
EXTRA_HELPERS={0x43b3d0:('callback',16),0x401a80:('releaseDisplay',0),0x401ae0:('destroyDisplay',0),0x4019b0:('releaseSound',0),0x401d30:('releaseMusic',0),0x43d2a0:('releaseReplays',0),0x43d280:('releaseBuffer',0)}
INPUT={0x100,0x101,0x200,0x201,0x202,0x203,0x204,0x205,0x3a0,0x3a1,0x3b5,0x3b6,0x3b7,0x3b8}
METHOD_SET=copy.deepcopy(METHODS);METHOD_SET['draw'][8]=('release',1);METHOD_SET['surface'][0x7c]=('setPalette',2);METHOD_SET['audio']={8:('release',1)}

class WindowLifecycle(WindowInitialization):
    def __init__(self):
        super().__init__();self.u.mem_map(REPLAY,0x10000)
        for family,items in METHOD_SET.items():
            for offset,(name,n) in items.items():
                if (family,name,n) not in self.com_methods.values():self.com_methods[STOP+0x6000+len(self.com_methods)*16]=(family,name,n)
        self.blobs={};self.new_blobs=[]
    def blob(self,b):
        b=bytes(b);h=digest(b)
        if h not in self.blobs:self.blobs[h]=dict(count=len(b),base64=base64.b64encode(b).decode());self.new_blobs.append(h)
        return h
    def allocate(self,family):
        a=COM+0x1000*(len(self.objects)+1);v=a+0x100;self.put(a,v)
        for offset,(name,n) in METHOD_SET[family].items():self.put(v+offset,next(pc for pc,item in self.com_methods.items() if item==(family,name,n)))
        self.objects.append(dict(address=a,family=family,releases=[]));return a
    def record_write(self,address,n,payload,origin='CPU'):
        if POINTERS<=address<POINTERS+8:
            o=address-POINTERS;assert o+n<=8;self.pointer_mask[o:o+n]=b'\1'*n
            self.pointer_writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=address,bytes=payload.hex(),origin=origin))
        else:super().record_write(address,n,payload,origin)
        self.actions.append(dict(kind='store',address=address,bytes=list(payload),origin=origin))
    def observe_write(self,u,access,address,n,value,data):
        if self.capturing and POINTERS<=address<POINTERS+8:self.record_write(address,n,(value&((1<<(8*n))-1)).to_bytes(n,'little'))
        else:super().observe_write(u,access,address,n,value,data)
    def request(self,kind,words=(),structure=None,strings=()):
        result=super().request(kind,words,structure,strings);self.actions.append(dict(kind='request',event=self.events[-1]));return result
    def api_bytes(self,address,b):
        b=bytes(b);self.u.mem_write(address,b);self.record_write(address,len(b),b,origin='API')
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        for h in list(reversed(self.extra_pending)):
            if h['returnPC']==pc and sp==h['sp']+4+h['pop']:
                self.extra_returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX)));self.extra_pending.remove(h)
        if pc in EXTRA_HELPERS:
            name,pop=EXTRA_HELPERS[pc];self.extra_pending.append(dict(address=pc,kind=name,sp=sp,pop=pop,returnPC=self.u32(sp)))
        if pc in self.boundaries:
            _,name=self.boundaries[pc];arg=lambda i:self.u32(sp+4+i*4)
            if name=='GetSystemMetrics':
                response=self.request('metric',[arg(0)]);values=self.spec.get('metricValues',{'0':1920,'1':1080,'7':4,'8':4,'4':23})
                response['result']=values[str(arg(0))];self.ret(response['result'],4);return
            if name in ('DefWindowProcA','DestroyWindow','PostQuitMessage','SetCursor','InvalidateRect'):
                kind,n={'DefWindowProcA':('windowDefault',4),'DestroyWindow':('destroyWindow',1),'PostQuitMessage':('postQuit',1),'SetCursor':('setCursor',1),'InvalidateRect':('invalidate',3)}[name]
                r=self.request(kind,[arg(i) for i in range(n)]);self.ret(r['result'],n*4);return
            if name in ('GetClientRect','ClientToScreen','SetRect'):
                kind,n={'GetClientRect':('clientRect',2),'ClientToScreen':('screenPoint',2),'SetRect':('setRect',5)}[name]
                words=[arg(i) for i in range(n)];address=words[0] if kind=='setRect' else words[1];count=8 if kind=='screenPoint' else 16
                assert address in (0x453ccc,0x453cd4)
                r=self.request(kind,words)
                self.events[-1]['request'].update(bytes=list(u.mem_read(address,count)),defined=[True]*count)
                if kind=='clientRect':values=self.spec.get('clientRect',[0,0,794,550])
                elif kind=='screenPoint':values=self.spec.get('screenPoints',[[-30,40],[764,590]])[self.counts[kind]-1]
                else:values=words[1:]
                if self.spec.get('writeRect',True):
                    r['bytes']=list(struct.pack('<'+'I'*len(values),*[v&0xffffffff for v in values]));self.api_bytes(address,r['bytes'])
                self.ret(r['result'],n*4);return
            if name=='free':
                pointer=arg(0);a=next(a for a in self.allocations if a['address']==pointer);assert a['live'];a['live']=False
                r=self.request('free',[pointer]);self.ret(r['result']);return
        if pc not in self.boundaries and pc not in self.com_methods and pc!=STOP:
            allowed=(0x43b3d0<=pc<=0x43bc40 or 0x43bdd0<=pc<=0x43bf02 or 0x401000<=pc<=0x4013ce or 0x4019b0<=pc<=0x401a26 or 0x401a80<=pc<=0x401af5 or 0x401b00<=pc<=0x401c85 or 0x401d30<=pc<=0x401d90 or 0x43d280<=pc<=0x43d2b7 or 0x43e8e0<=pc<=0x43e934 or 0x43f37e<=pc<=0x43f383)
            assert allowed,('Unexpected lifecycle child',hex(pc))
        return super().code(u,pc,size,data)
    def snapshot(self):
        return dict(globals=self.blob(self.u.mem_read(BASE,COUNT)),pointers=self.blob(self.u.mem_read(POINTERS,8)),
                    objects=copy.deepcopy(self.objects),allocations=[dict(**a,bytes=self.blob(self.u.mem_read(a['address'],a['count']))) for a in self.allocations])
    def call_lifecycle(self,spec,index):
        self.spec=spec;self.new_blobs=[]
        if not spec.get('retain'):
            self.objects=[];self.allocations=[];self.u.mem_write(BASE,self.initial_globals)
            for a,v in [(POINTERS,0),(POINTERS+4,0),(0x458430,spec.get('mode',0)),(0x458434,spec.get('changing',0)),(0x44d794,spec.get('toggle',1)),(0x4554c0,0x400000),(0x44d78c,794),(0x44d790,550),(0x4546f4,spec.get('oldWindow',0x73000011)),(0x455634,0),(0x455608,0),(0x457578,0),(0x4554c4,spec.get('palette',0x74000001)),(0x44eecc,0),(0x458438,0),(0x45843c,0),(0x44f04c,0),(0x44f048,0),(0x44f044,0),(0x44f040,0)]:self.put(a,v)
            resources=spec.get('resources',0 if spec.get('initialize') else 7)
            for bit,a,f in [(1,0x457578,'draw'),(2,0x455608,'surface'),(4,0x455634,'surface')]:
                if resources&bit:self.put(a,self.allocate(f))
            if spec.get('audio'):
                self.put(0x44eecc,self.allocate('audio'));self.put(0x458438,2);self.put(0x45843c,2)
                for a in (0x452948,0x45294c,0x451db0,0x451db4,0x44f04c,0x44f048,0x44f044,0x44f040):self.put(a,self.allocate('audio'))
            for j,n in enumerate(spec.get('replays',[])):
                if n:
                    a=REPLAY+(j+1)*0x1000;self.put(POINTERS+j*4,a);self.u.mem_write(a,bytes([0x41+j])*n);self.allocations.append(dict(address=a,count=n,live=True))
        for a,v in spec.get('stimulus',[]):self.put(a,v)
        self.events=[];self.actions=[];self.counts=Counter();self.frames=[];self.backings=[];self.pending_helpers=[];self.helper_returns=[];self.extra_pending=[];self.extra_returns=[];self.case_instructions={};self.mask=bytearray(COUNT);self.global_writes=[];self.pointer_mask=bytearray(8);self.pointer_writes=[];self.show_reads=[]
        self.u.mem_write(STACK,bytes((i*spec.get('scratchSeed',17)+0xa5)&255 for i in range(0x10000)))
        initialize=spec.get('initialize',False);entry=0x43bec0 if initialize else 0x43b3d0
        if not initialize:assert spec['message'] not in INPUT|{0x400,0x401}
        args=[STOP,0x400000,10] if initialize else [STOP,spec.get('window',0x73000011),spec['message'],spec.get('wParam',0),spec.get('lParam',0)]
        self.u.mem_write(SP,struct.pack('<'+'I'*len(args),*[v&0xffffffff for v in args]));self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_FPCW,0x23f)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGISTERS,saved):self.u.reg_write(r,v)
        before=self.snapshot();self.finished=False;self.capturing=True
        try:self.u.emu_start(entry,0,count=200000)
        finally:self.capturing=False
        assert self.finished and not self.pending_helpers and not self.extra_pending and not self.frames
        assert self.u.reg_read(UC_X86_REG_ESP)==SP+(4 if initialize else 20)
        assert [self.u.reg_read(r) for r in REGISTERS]==saved and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_image and bytes(self.u.mem_read(0x10000000,0x5000))==self.library
        return dict(index=index,spec=spec,before=before,after=self.snapshot(),writeMasks=[self.blob(self.mask),self.blob(self.pointer_mask)],writes=self.global_writes+self.pointer_writes,actions=self.actions,events=self.events,backings=self.backings,helpers=self.helper_returns+self.extra_returns,instructions=[dict(address=a,bytes=b) for a,b in sorted(self.case_instructions.items())],result=self.u.reg_read(UC_X86_REG_EAX),sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW))

def initial_specs():
    for mode in (0,1):
        for message in (3,5,0x1c,0x20,0x112):
            for word in (0,1,2,0xf100,0xf101):
                for value in (0,-1):yield dict(label='lifecycle-flags',mode=mode,message=message,wParam=word,results={'windowDefault#1':-123,'invalidate#1':value,'setCursor#1':value,'clientRect#1':value,'screenPoint#1':value,'screenPoint#2':value})
    for mode in (0,1):
        for write in (False,True):yield dict(label='move-output',mode=mode,message=3,writeRect=write,clientRect=[-100,-200,0x7fffffff,-0x80000000],screenPoints=[[-1,1],[-0x80000000,0x7fffffff]],metricValues={'0':-1,'1':-0x80000000},results={'clientRect#1':0,'screenPoint#1':0,'screenPoint#2':0,'setRect#1':0})
    for changing in (0,1,2):
        for audio in (False,True):
            for replays in ([0,0],[64,0],[0,128],[64,128]):yield dict(label='destroy-resources',message=2,changing=changing,audio=audio,replays=replays,results={'release#1':-1,'free#1':-1,'postQuit#1':-1})
    for resources in (0,7):
        for palette in (0,0x74000001):yield dict(label='query-palette',message=0x30f,resources=resources,palette=palette,results={'setPalette#1':-1,'windowDefault#1':123})
    for window in (0x73000011,0x73000012):
        for palette in (0,0x74000001):yield dict(label='palette-changed',message=0x311,wParam=window,palette=palette,results={'setPalette#1':-1,'windowDefault#1':-123})
    for message in (0,1,4,6,0x1b,0x1d,0x21,0xff,0x102,0x104,0x106,0x111,0x113,0x206,0x30e,0x310,0x312,0x3a2,0x3b4,0x3b9,0x3ff,0x402,0xffffffff):yield dict(label='default-dispatch',message=message,wParam=0xabcdef01,lParam=0xffffffff,results={'windowDefault#1':-123})
    for key in (0,13,65):
        for enabled in (0,1):yield dict(label='system-key',message=0x105,wParam=key,toggle=enabled)
    for mode in (0,1,2):
        for resources in range(8):
            for old_window in (0,0x73000011):yield dict(label='recreate-ownership',message=0x105,wParam=13,mode=mode,resources=resources,oldWindow=old_window,results={'destroyWindow#1':0,'release#1':-1,'showWindow#1':0})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir()
    vm=WindowLifecycle();cases=[];seen=set()
    def capture(spec):
        key=json.dumps(spec,sort_keys=True)
        if not spec.get('retain') and key in seen:return None
        if a.limit is not None and len(cases)>=a.limit:return None
        try:c=vm.call_lifecycle(spec,len(cases))
        except Exception as e:
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(error=repr(e),spec=spec,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,actions=vm.actions),indent=2)+'\n');raise
        seen.add(key);cases.append(c)
        for h in vm.new_blobs:(parts/'blobs'/(h+'.json')).write_text(json.dumps(vm.blobs[h],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();p=parts/('%06d.json'%c['index']);t=p.with_suffix('.tmp');t.write_bytes(raw);os.replace(t,p)
        checkpoint=path.with_suffix('.incomplete.json');t=checkpoint.with_suffix('.tmp');t.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(t,checkpoint)
        if len(cases)%50==0:print('Completed',len(cases),flush=True)
        return c
    for spec in initial_specs():capture(spec)
    for mode,results in [(0,{}),(1,{}),(0,{'createSurface#1':-1}),(0,{'createSurface#1':-1,'createSurface#2':-1}),(0,{'attachedSurface#1':-1,'attachedSurface#2':-1})]:
        base=dict(label='recreate-errors',message=0x105,wParam=13,mode=mode,results=results);c=capture(base)
        if c:
            for e in c['events']:
                if e['key'] in results:continue
                if e['request']['kind'] in ('metric','debug','release','windowDefault'):continue
                for value in ([0] if e['request']['kind'] in ('icon','cursor','registerClass','createWindow','updateWindow','showWindow','destroyWindow') else [-1,1]):capture(dict(base,results={**results,e['key']:value}))
    if a.limit is None:
        for mode in (0,1):
            capture(dict(label='own-window-initialize',initialize=True,mode=mode,scratchSeed=0))
            for message,wparam in [(3,0),(5,1),(5,0),(0x20,0),(0x30f,0),(0x105,13),(3,0),(0x105,13),(2,0)]:capture(dict(label='own-window-callback',retain=True,message=message,wParam=wparam,window=0x73000001))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,cases=cases,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    report=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()))
    path.with_suffix('.report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
