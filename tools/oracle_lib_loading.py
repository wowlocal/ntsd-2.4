#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole4242e0 loading with installed library label/text and real helper bodies.

Pinned NTSD EXE/lib.dll/VC80 on Unicorn2.1.4. Actual relocated DLL installer,
then controlled whole loading calls retain timer/phase/DC/click state and
compare globals, resources, actual bitmap/clip/fill/text/audio/overlay/present
and43d230 message-pump order. COM/GDI/clocks/Sleep/ShellExecute/message APIs
are declared requests; no URL, window message or host device operation occurs.
Fill backing is the actual100-byte helper-entry input with92 untouched bytes,
not recovered initialized application stack provenance. See LIB_LOADING_PLAN.
No runtime DLL, code patching in Native, Windows/app/full-match claim.
"""
import json,itertools,struct
from collections import Counter
from oracle_gameplay_output import GameplayOutput,COM,CTABLE,CAPI,QUEUES
from oracle_bitmap_font import BITMAP,TARGET,VTABLE,API,SP,GLOBAL,GLOBAL_SIZE,SIZE,REGS,FONTS
from oracle_bitmap_drawing import digest,signed
from oracle_state import ROOT,STOP,STACK,EXE_SHA256
from oracle_playback_information import SPRINTF
from oracle_crt import DLL_SHA256
from lib_runtime_loader import install_library,BASE
from oracle_lib_initialization import LIB_SHA256
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *

LAPI=STOP+0x9000
PANEL,CALLER_TEXT=BITMAP+0x2000,COM+0x4900
EXTRA={0x415160:0,0x43d230:0}
class LoadingProgress(GameplayOutput):
    def __init__(self):
        super().__init__();self.installation=install_library(self.uc)
        pe=PE((DEFAULT_SOURCE/'lib.dll').read_bytes())
        self.library_api={0x36010000+16*n:i['name'] for n,i in enumerate(pe.imports())}
        self.loading_api={LAPI+16*n:name for n,name in enumerate(('timeGetTime','Sleep','ShellExecuteA','PeekMessageA','GetMessageA','TranslateMessage','DispatchMessageA'))}
        for iat,name in [(0x447250,'timeGetTime'),(0x447098,'Sleep'),(0x4471b8,'ShellExecuteA'),(0x447204,'PeekMessageA'),(0x447208,'GetMessageA'),(0x4471c0,'TranslateMessage'),(0x447210,'DispatchMessageA')]:
            self.put(iat,next(p for p,n in self.loading_api.items() if n==name))
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.library_write,begin=BASE,end=BASE+0x4fff)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.caller_read,begin=CALLER_TEXT,end=CALLER_TEXT+99)
        self.allocation_before=[bytes(self.uc.mem_read(a['address'],a['count'])) for a in self.installation['allocations']]
    def caller_read(self,u,access,p,size,value,data):
        if self.running:self.unread_caller.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,size=size))
    def read(self,u,access,p,size,value,data):
        if self.running and u.reg_read(UC_X86_REG_EIP)==0x4243d4:
            assert p==PANEL and size==4
            self.event('panelRead',[p,self.u32(p)]);return
        return super().read(u,access,p,size,value,data)
    def library_write(self,u,access,p,size,value,data):
        if not self.running:return
        assert p==BASE+0x306e and size==4
        self.library_writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,size=size,value=value&0xffffffff))
    def global_write(self,u,access,p,size,value,data):
        if not self.running:return
        assert GLOBAL<=p<p+size<=GLOBAL+GLOBAL_SIZE and size in (1,2,4)
        self.global_writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=p,size=size,value=value&((1<<(size*8))-1)))
        self.global_written[p-GLOBAL:p-GLOBAL+size]=b'\1'*size
    def cstring(self,p):
        if GLOBAL<=p<GLOBAL+GLOBAL_SIZE:return super().cstring(p)
        if STACK<=p<STACK+0x10000:return super().cstring(p)
        assert 0x400000<=p<0x44d000 or BASE<=p<BASE+0x5000,hex(p)
        raw=bytes(self.uc.mem_read(p,200));end=raw.find(b'\0');assert end>=0;return raw[:end]
    def code(self,u,pc,size,data):
        if not self.running:return
        own=(0x4242e0<=pc<0x4246ae or 0x415160<=pc<=0x4151c2 or 0x43d230<=pc<=0x43d276 or BASE<=pc<BASE+0x5000
             or pc in self.loading_api or pc in self.library_api or pc==API and self.u32(u.reg_read(UC_X86_REG_ESP)+24)!=0)
        if not own:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.pending and pc==self.pending[-1]['returnPC']:
            h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[u.reg_read(r) for r in REGS],h
            h['returnSP']=sp;self.helpers.append(h)
            if h['entry']==0x43f010:self.bitmap=None
        if pc in self.library_api:
            name=self.library_api[pc]
            if name in ('SetBkMode','SetTextColor'):
                self.event('setBackgroundMode' if name=='SetBkMode' else 'setTextColor',[arg(0),arg(1)]);self.ret(self.input['methodResult'],8)
            elif name=='lstrlenA':
                raw=self.cstring(arg(0));self.event('stringLength',[],[raw]);self.ret(len(raw),4)
            elif name=='TextOutA':self.event('textOut',[arg(0),arg(1),arg(2),arg(4)],[bytes(u.mem_read(arg(3),arg(4)))]);self.ret(self.input['methodResult'],20)
            else:raise AssertionError(name)
            return
        if pc in self.loading_api:
            name=self.loading_api[pc]
            if name=='timeGetTime':
                assert self.clock_index<len(self.times),(self.spec,self.clock_index)
                value=self.times[self.clock_index];self.clock_index+=1;self.event('timeGetTime',[value]);self.ret(value)
            elif name=='Sleep':self.event('sleep',[arg(0)]);self.ret(0,4)
            elif name=='ShellExecuteA':
                self.event('shell',[arg(0),arg(3),arg(4),arg(5)],[self.cstring(arg(1)),self.cstring(arg(2))]);self.ret(self.spec.get('shellResult',33),24)
            else:
                self.message_calls.append(dict(name=name,sp=sp,returnPC=self.u32(sp),pointer=arg(0)))
                if name in ('PeekMessageA','GetMessageA'):
                    count=5 if name=='PeekMessageA' else 4
                    assert [arg(n) for n in range(1,count)]==[0]*(count-1)
                    result=self.spec.get('peek' if count==5 else 'get',0)
                    if result:self.uc.mem_write(arg(0),self.message_input)
                    self.event(name,[result&0xffffffff,*[arg(n) for n in range(1,count)]], [self.message_input] if result else [])
                    self.ret(result,count*4)
                else:
                    raw=bytes(u.mem_read(arg(0),28));assert raw==self.message_input
                    self.event(name,[],[raw]);self.ret(self.spec.get('messageResult',-1),4)
            return
        if pc==API:
            assert arg(0)==TARGET and arg(2)==0 and arg(3)==0 and arg(4)==0x1000400
            raw=bytes(u.mem_read(arg(5),100));defined=[True if n<4 or 80<=n<84 else False for n in range(100)]
            self.event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',u.mem_read(arg(1),16))),flags=arg(4),effects=list(raw),defined=defined))
            self.ret(self.input['methodResult'],24);return
        self.instructions.add(pc);self.case_instructions.add(pc)
        if pc in EXTRA:self.pending.append(dict(entry=pc,sp=sp,pop=EXTRA[pc],returnPC=self.u32(sp),saved=[u.reg_read(r) for r in REGS]))
        if pc==0x415160:
            self.fill_backing.append(bytes(u.mem_read(sp-100,100)).hex());self.event('fillCall',[arg(n) for n in range(5)])
        if pc==BASE+0x1236:
            self.label_entries.append(dict(sp=sp,phase=signed(u.reg_read(UC_X86_REG_EDX)),esi=u.reg_read(UC_X86_REG_ESI),callerSP=SP,stackArguments=[self.u32(SP+4),self.u32(SP+8)]))
        if BASE<=pc<BASE+0x5000:
            assert BASE+0x1236<=pc<=BASE+0x1309 or pc in (BASE+0x1c7e,BASE+0x1c84,BASE+0x1c8a,BASE+0x1c90),hex(pc)
    def probe(self,spec):
        self.running=False;self.spec=spec;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.methods=0;self.case_instructions=set()
        self.global_writes=[];self.global_written=bytearray(GLOBAL_SIZE);self.label_reads=[];self.text_pointer=0x450c38
        self.input=dict(targetSurface=TARGET,methodResult=-2147467259,queryResult=0,audioGetResult=0,audioSetResult=-1,
            queriedAudio=COM+16*483,audioVolume=-1234,dcResult=0,dc=0x76543210,postResult=0)
        self.input.update(spec.get('input',{}));self.results=spec.get('results',[-2147467259,0,-1,1])
        self.uc.mem_write(GLOBAL,self.initial_globals);self.put(TARGET,VTABLE);self.put(VTABLE+0x14,API)
        self.bitmap_masks=[];bitmaps=[]
        for n in range(3):
            raw=bytearray(b'\xa5'*SIZE);mask=bytearray(b'\1'*SIZE)
            struct.pack_into('<4I',raw,0,TARGET+0x100+16*n,32+n*8,48+n*16,spec.get('count',500)&0xffffffff)
            if n==1 and spec.get('panel',1)==0:struct.pack_into('<I',raw,0,0)
            for k in range(500):
                for offset,value in ((0x10,k*3),(0x7e0,k*5),(0xfb0,8+n),(0x1780,16+n)):struct.pack_into('<i',raw,offset+4*k,value)
            for index,offset,size in spec.get('undefinedBitmap',[]):
                if index==n:mask[offset:offset+size]=bytes(size)
            self.uc.mem_write(BITMAP+n*0x2000-16,b'\x96'*16+bytes(raw)+b'\x69'*16)
            self.bitmap_masks.append(mask);bitmaps.append(dict(bytes=self.blob(raw),defined=self.blob(mask)))
        for n,p in enumerate(FONTS):self.put(p,BITMAP+n*0x2000)
        defaults={0x455608:TARGET,0x44d78c:800,0x44d790:600,0x451160:0,0x450b84:0,0x450c30:1,0x450b94:0,
            0x44d000:50,0x44f190:0,0x450b70:0,0x450b6c:0,0x450bfc:0,0x458348:3,0x44eecc:COM+16*480,
            0x455634:COM+16*481,0x453e0c:COM+16*482,0x44f040:COM+16*484}
        defaults.update({p:COM+16*(485+n) for n,p in enumerate(range(0x45560c,0x455620,4))})
        defaults.update({int(k,0):v for k,v in spec.get('globals',{}).items()})
        for p,v in defaults.items():self.put(p,v)
        self.uc.mem_write(0x4553f2,bytes(spec.get('keys',[0x75,0x75])))
        self.uc.mem_write(0x453ccc,struct.pack('<4i',-7,20,807,563))
        for p,text in ((0x450c38,b'retained '),(0x44fd98,bytes.fromhex(spec.get('name',b'Naruto-Sasuke.lfr'.hex())))):
            assert len(text)<200;self.uc.mem_write(p,text+b'\0')
        for group,(count,pending,first,second,buffers) in enumerate(QUEUES):
            for n in range(count):
                self.put(pending+4*n,0);self.put(first+4*n,70);self.put(second+4*n,30);self.put(buffers+4*n,COM+16*(n+(400 if group else 0)))
        for group,n,flag,right,left in spec.get('slots',[[0,6,1,70,30],[1,2,1,20,80]]):
            count,pending,first,second,buffers=QUEUES[group];assert 0<=n<count
            self.put(pending+4*n,flag);self.put(first+4*n,right);self.put(second+4*n,left)
        for p,n in ((0x45118c,0),(0x451188,1),(0x451170,2)):self.put(p,BITMAP+n*0x2000)
        self.put(0x4511c0,spec.get('previousTime',100));self.put(0x4511bc,spec.get('phase',0))
        self.put(0x458420,PANEL if spec.get('panel',1) is not None else 0)
        self.put(0x4546f0,spec.get('x',0));self.put(0x453cdc,spec.get('y',0))
        self.put(0x457580,spec.get('held',0));self.put(0x4511b8,spec.get('previousHeld',0))
        for n,raw in enumerate(spec.get('links',['?']*8)):
            text=raw.encode('latin1');assert len(text)<100 and b'\0' not in text
            self.uc.mem_write(0x4546f8+100*n,text+b'\0')
        for p,v in spec.get('retain',{}).items():self.put(int(p,0),v)
        self.put(BASE+0x306e,spec.get('retainedDC',0))
        self.times=list(spec.get('times',[134,134]));self.clock_index=0;self.fill_backing=[];self.library_writes=[];self.label_entries=[];self.message_calls=[]
        self.message_input=bytes.fromhex(spec.get('message','00112233445566778899aabbccddeeff102132435465768798a9bacb'))
        assert len(self.message_input)==28
        self.uc.mem_write(CALLER_TEXT,b'caller file.dat\0');self.unread_caller=[]
        before=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));resources=bytes(self.uc.mem_read(COM&~0xfff,0x5000))
        library_before=bytes(self.uc.mem_read(BASE,0x5000));panel_before=bytes(self.uc.mem_read(PANEL,4))
        self.uc.mem_write(SP-0x3000,b'\xa5'*0x3800);self.put(SP,STOP);self.put(SP+4,CALLER_TEXT);self.put(SP+8,TARGET)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.running=True
        try:self.uc.emu_start(0x4242e0,0,count=2_000_000)
        except Exception:
            print('SOURCE FAILURE',spec['label'],hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-4:],flush=True);raise
        finally:self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4
        assert saved==[self.uc.reg_read(r) for r in REGS] and self.clock_index==len(self.times)
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        assert bytes(self.uc.mem_read(COM&~0xfff,0x4800))==resources[:0x4800]
        assert bytes(self.uc.mem_read(PANEL,4))==panel_before and not self.unread_caller
        for n,b in enumerate(bitmaps):assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
        for a,raw in zip(self.installation['allocations'],self.allocation_before):assert bytes(self.uc.mem_read(a['address'],a['count']))==raw
        library_after=bytes(self.uc.mem_read(BASE,0x5000));rebuilt=bytearray(library_before)
        for w in self.library_writes:struct.pack_into('<I',rebuilt,w['address']-BASE,w['value'])
        assert bytes(rebuilt)==library_after
        return dict(spec=spec,input=self.input,globals=self.blob(before),globalsAfter=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
            written=self.blob(self.global_written),writes=self.global_writes,bitmaps=bitmaps,events=self.events,blits=self.blits,methods=self.methods,
            libraryBefore=self.blob(library_before),libraryAfter=self.blob(library_after),libraryWrites=self.library_writes,
            fillBacking=self.fill_backing,labelEntries=self.label_entries,messageCalls=self.message_calls,
            helpers=self.helpers,instructions=sorted(self.case_instructions),abi=dict(entrySP=SP,returnSP=SP+4,saved=saved,returnPC=STOP,fpcw=0x23f,tag=0xffff,sw=0))

def probes():
    yield dict(label='ordinary')
    for phase in [*range(-12,12),-2147483648,2147483647]:yield dict(label=f'phase-{phase}',phase=phase)
    for previous,times in [(0,[100,100,100]),(0,[100,134,134]),(100,[100,100]),(100,[133,133]),(100,[134,134]),(100,[200,200]),(100,[201,201,250]),(100,[134,100]),(100,[133,129]),(100,[133,128]),(100,[133,132]),(100,[133,134]),(100,[133,0x80000085]),(0xfffffff0,[17,17]),(0xfffffff0,[18,18]),(0xfffffffe,[100,100,150])]:
        yield dict(label=f'time-{previous}-{times}',previousTime=previous,times=times)
    for panel in [None,0,1]:
        for links in [['?']*8,['http://example.invalid/'+str(i) for i in range(8)],['?']*7+['tail']]:
            yield dict(label=f'panel-{panel}-{links[0]}-{links[-1]}',panel=panel,links=links)
    for slot in range(8):
        x=1+198*(slot%4);y=142+194*(slot//4);links=['?']*8;links[slot]=f'http://example.invalid/{slot}'
        for px,py in [(x,y+1),(x+1,y),(x+1,y+1),(x+197,y+193),(x+198,y+1),(2147483647,y+1),(x+1,y+194)]:
            yield dict(label=f'hover-{slot}-{px}-{py}',links=links,x=px,y=py,held=1)
        for held,previous in [(0,0),(1,0),(2,0),(1,1),(-1,0)]:yield dict(label=f'click-{slot}-{held}-{previous}',links=links,x=x+1,y=y+1,held=held,previousHeld=previous)
    for x,y in itertools.product([-2147483648,0,1,146,147,775,776,2147483647],[534,535,536,2147483647]):yield dict(label=f'bottom-{x}-{y}',x=x,y=y,held=1)
    for peek,get in itertools.product([0,1],[-1,0,1]):yield dict(label=f'message-{peek}-{get}',peek=peek,get=get)
    for notice,timer,block in itertools.product([-1,0,1,2,3,4],[-1,239,240,241,2147483647],[0,1]):
        yield dict(label=f'overlay-{notice}-{timer}-{block}',globals={'0x450b70':notice,'0x450b6c':timer,'0x450bfc':block,'0x44f190':2})
    for level,keys in itertools.product([-2147483648,-1,0,50,100,101,2147483647],[[0x75,0x75],[0x64,0x75],[0x75,0x64],[0x64,0x64]]):yield dict(label=f'volume-{level}-{keys}',keys=keys,globals={'0x44d000':level,'0x44f190':1})
    for key,value in itertools.product(['queryResult','audioGetResult','audioSetResult','dcResult','methodResult'],[-2147467259,-1,0,1]):
        yield dict(label=f'response-{key}-{value}',keys=[0x75,0x64],input={key:value},x=1,y=535,held=1,peek=1,get=1)
    for mode,sound in itertools.product([-1,0,1,2,3,4],[0,1,2]):
        g={'0x458348':mode,'0x44eecc':0 if sound==0 else COM+16*480}
        if sound==1:g['0x455610']=0
        yield dict(label=f'present-sound-{mode}-{sound}',globals=g,x=1,y=535,held=1)
    for i in range(6):yield dict(label=f'retained-{i}',chain=True,times=[134+i*34,134+i*34],phase=0,x=1,y=535,held=1,input={'dcResult':-1 if i%2 else 0})

def main():
    out=ROOT/'build/original/lib-loading.json';assert not out.exists(),'Never overwrite completed source evidence'
    vm=LoadingProgress();cases=[];retained={};dc=0
    for spec in probes():
        if spec.get('chain'):spec.update(retain=retained,retainedDC=dc)
        print('START',len(cases)+1,spec['label'],flush=True);c=vm.probe(spec);cases.append(c)
        if spec.get('chain'):
            retained={hex(p):vm.u32(p) for p in (0x4511c0,0x4511bc,0x4511b8,0x457580)};dc=vm.u32(BASE+0x306e)
        if len(cases)%20==0:
            partial=out.with_name('lib-loading-incomplete.json');temp=partial.with_suffix('.tmp')
            checkpoint=(json.dumps(dict(incomplete=True,cases=cases,blobs=vm.blobs),separators=(',',':'))+'\n').encode()
            temp.write_bytes(checkpoint);temp.replace(partial);partial.with_suffix('.sha256').write_text(digest(checkpoint)+'\n')
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,blobEncoding='zlib',installation=vm.installation,
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions),nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();out.write_bytes(raw)
    report=dict(scope=__doc__,corpus=out.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),helpers=sum(len(c['helpers']) for c in cases),
        events=dict(Counter(e['kind'] for c in cases for e in c['events'])),instructions=len(vm.instructions),blobs=len(vm.blobs),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-loading.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
