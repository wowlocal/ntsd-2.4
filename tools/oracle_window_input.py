#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute original whole keyboard/mouse/joystick WndProc returns for NTSD.

Pinned EXE/lib.dll, Unicorn2.1.4 and a fresh accepted installer parent. Actual
text/cleanup children execute; Win32/COM/free results and allocation backing
are declared boundaries, not Windows/device/host-heap behavior. A retained
ordinary key stream traces a terminating NUL overwriting its own length field;
no control-pointer/security mutation or manufactured memory fault. Unknown
storage/faults remain explicit failures. See WINDOW_INPUT_PLAN.md.
"""
import argparse,base64,json,os,struct,zlib
from pathlib import Path
from oracle_lib_initialization import LibInitialization,SP,STOP,STACK,REGISTERS,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_WRITE
from unicorn.x86_const import *

BASE,COUNT=0x44d000,0xb440
LOCAL,LOCAL_COUNT=0x458440,0x140
POINTERS=0x4588a8
COM,RELEASE,REPLAY=0x31000000,STOP+0x6000,0x32000000
MESSAGES={0x100,0x101,0x200,0x201,0x202,0x203,0x204,0x205,0x3a0,0x3a1,0x3b5,0x3b6,0x3b7,0x3b8}
HELPERS={0x43b3d0:('windowInput',16),0x4031d0:('textInput',4),0x4019b0:('soundRelease',0),0x401d30:('musicRelease',0),0x43d2a0:('replayRelease',0),0x43d280:('bufferRelease',0),0x4462e0:('textInitializer',0),0x4031b0:('textConstructor',0)}


class WindowInput(LibInitialization):
    def __init__(self):
        self.capturing=False;super().__init__(0);self.parent=super().run()
        self.initial=bytes(self.u.mem_read(BASE,COUNT));self.local_initial=bytes(self.u.mem_read(LOCAL,LOCAL_COUNT))
        self.u.mem_map(COM,0x100000);self.u.mem_map(REPLAY,0x10000)
        self.handles=[]
        for i in range(490):
            a=COM+0x100+i*0x100;self.put(a,a+0x10);self.put(a+0x18,RELEASE);self.handles.append(a)
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.changed)
        self.code_before=bytes(self.u.mem_read(0x400000,0x4d000));self.lib_before=bytes(self.u.mem_read(0x10000000,0x5000))
        self.blobs={};self.new_blobs=[];self.last=None
    def blob(self,raw):
        raw=bytes(raw);h=digest(raw)
        if h not in self.blobs:
            self.blobs[h]=dict(count=len(raw),deflate=base64.b64encode(zlib.compress(raw,9)).decode());self.new_blobs.append(h)
        return h
    def changed(self,u,access,address,n,value,data):
        if not self.capturing:return
        if STACK<=address<STACK+0x10000:return
        found=False
        for base,count,mask in self.regions:
            if base<=address and address+n<=base+count:
                mask[address-base:address-base+n]=b'\1'*n;found=True
        assert found,('writeOutsideDeclaredStorage',hex(u.reg_read(UC_X86_REG_EIP)),hex(address),n)
        payload=(value&((1<<(8*n))-1)).to_bytes(n,'little')
        self.stores.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,bytes=payload.hex()))
        self.actions.append(dict(kind='store',address=address,bytes=list(payload)))
    def request(self,kind,arguments=(),strings=()):
        result=self.spec.get({'windowDefault':'defaultResult','message':'messageResult'}.get(kind,'methodResult'),0)
        self.calls.append(dict(kind=kind,arguments=list(arguments),strings=[list(s) for s in strings],result=result))
        self.actions.append(dict(kind='request',event=self.calls[-1]))
        return result
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        for item in list(reversed(self.pending_helpers)):
            if item['returnPC']==pc and sp==item['sp']+4+item['pop']:
                self.returns.append(dict(**item,eax=u.reg_read(UC_X86_REG_EAX)));self.pending_helpers.remove(item)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in HELPERS:
            name,pop=HELPERS[pc];self.pending_helpers.append(dict(address=pc,kind=name,sp=sp,returnPC=self.u32(sp),pop=pop))
        if pc not in self.boundaries and pc!=RELEASE:
            allowed=(0x43b3d0<=pc<=0x43bc40 or 0x4031b0<=pc<=0x40325e or 0x4019b0<=pc<=0x401a26 or 0x401d30<=pc<=0x401d90 or 0x43d280<=pc<=0x43d2b7 or pc in (0x4462e0,0x4462e5))
            assert allowed,('unexpectedGameChild',hex(pc))
            self.instructions_case[pc]=bytes(u.mem_read(pc,size)).hex();return
        arg=lambda i:self.u32(sp+4+i*4)
        if pc==RELEASE:
            target=arg(0);assert target in self.handles;self.ret(self.request('method',[target,8]),4);return
        _,name=self.boundaries[pc]
        if name=='DefWindowProcA':self.ret(self.request('windowDefault',[arg(i) for i in range(4)]),16)
        elif name=='MessageBoxA':self.ret(self.request('message',[arg(0),arg(3)],[self.string(arg(1)),self.string(arg(2))]),16)
        elif name=='PostMessageA':self.ret(self.request('postMessage',[arg(i) for i in range(4)]),16)
        elif name=='free':
            pointer=arg(0);item=next(a for a in self.allocations_case if a['address']==pointer);assert item['live'];item['live']=False
            self.ret(self.request('free',[pointer]))
        else:raise RuntimeError(('unsupportedWindowInputAPI',name,hex(pc),hex(self.u32(sp))))
    def snapshot(self):
        return dict(globals=self.blob(self.u.mem_read(BASE,COUNT)),local=self.blob(self.u.mem_read(LOCAL,LOCAL_COUNT)),
                    pointers=self.blob(self.u.mem_read(POINTERS,8)),allocations=[dict(**a,bytes=self.blob(self.u.mem_read(a['address'],a['count']))) for a in self.allocations_case])
    def call(self,spec,index):
        self.new_blobs=[]
        self.spec=spec;entry=0x4462e0 if spec.get('constructor') else 0x43b3d0
        if entry==0x43b3d0:assert spec['message'] in MESSAGES and (spec['message'] not in (0x100,0x101) or 0<=spec['key']<=255)
        if not spec.get('retain'):
            self.u.mem_write(BASE,self.initial);self.u.mem_write(LOCAL,self.local_initial);self.put(POINTERS,0);self.put(POINTERS+4,0);self.allocations_case=[]
            for a,v in [(0x44eecc,0),(0x458438,0),(0x45843c,0),(0x44f04c,0),(0x44f048,0),(0x44f044,0),(0x44f040,0),(0x4546f4,0x72000002)]:self.put(a,v)
            for i in range(300):self.u.mem_write(0x455378+i,bytes([(i*spec.get('seed',0)+17)&255]))
            for i in range(LOCAL_COUNT):self.u.mem_write(LOCAL+i,bytes([(i*spec.get('seed',0)+0xa5)&255]))
            for a,v in [(LOCAL,spec.get('active',0)),(LOCAL+0x130,spec.get('length',0)),(LOCAL+0x134,spec.get('total',0)),(0x45857c,spec.get('first',0)),(0x458578,spec.get('second',0))]:self.put(a,v)
            for j,a in enumerate((0x453fd8,0x454008)):
                bounds=spec.get('bounds',[0,0,65535,65535])
                for i,v in enumerate(bounds):self.put(a+4*i,v)
                for i in range(8):self.u.mem_write(a+24+i,bytes([spec.get('buttons',0xa5)]))
            if spec.get('shutdown'):
                cat,builtin=spec.get('sounds',[2,2]);self.put(0x44eecc,self.handles[0]);self.put(0x458438,cat);self.put(0x45843c,builtin)
                for i in range(max(cat,0)):self.put(0x452948+4*i,self.handles[i+1])
                for i in range(max(builtin,0)):self.put(0x451db0+4*i,self.handles[401+i])
                for i,a in enumerate((0x44f04c,0x44f048,0x44f044,0x44f040)):self.put(a,self.handles[481+i] if spec.get('music',True) else 0)
                for i,n in enumerate(spec.get('replays',[64,128])):
                    if n:
                        pointer=REPLAY+0x1000*(i+1);self.put(POINTERS+4*i,pointer);self.u.mem_write(pointer,bytes([0x40+i])*n);self.allocations_case.append(dict(address=pointer,count=n,live=True))
        for change in spec.get('stimulus',[]):self.put(change[0],change[1])
        self.u.mem_write(STACK,b'\xa5'*0x10000)
        args=[STOP] if entry==0x4462e0 else [STOP,spec.get('window',0x72000001),spec['message'],spec.get('key',0),spec.get('lParam',0)]
        self.u.mem_write(SP,struct.pack('<'+'I'*len(args),*[x&0xffffffff for x in args]));self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_FPCW,0x23f)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.regions=[(BASE,COUNT,bytearray(COUNT)),(LOCAL,LOCAL_COUNT,bytearray(LOCAL_COUNT)),(POINTERS,8,bytearray(8))]
        self.stores=[];self.calls=[];self.actions=[];self.pending_helpers=[];self.returns=[];self.instructions_case={};before=self.snapshot();self.finished=False;self.capturing=True
        try:self.u.emu_start(entry,0,count=200000)
        finally:self.capturing=False
        assert self.finished and not self.pending_helpers and self.u.reg_read(UC_X86_REG_ESP)==SP+len(args)*4
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_before and bytes(self.u.mem_read(0x10000000,0x5000))==self.lib_before
        return dict(index=index,spec=spec,before=before,after=self.snapshot(),writes=self.stores,
                    writeMasks=[self.blob(mask) for _,_,mask in self.regions],events=self.calls,actions=self.actions,helpers=self.returns,
                    instructions=[dict(address=a,bytes=b) for a,b in sorted(self.instructions_case.items())],
                    result=self.u.reg_read(UC_X86_REG_EAX),sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW))


def specifications():
    for key in range(256):
        yield dict(label='key-down',message=0x100,key=key,seed=7,defaultResult=-1234567)
        yield dict(label='key-up',message=0x101,key=key,seed=11,defaultResult=0x12345678)
        for length in (0,5,298,299):yield dict(label='text-key',message=0x100,key=key,active=1,length=length,total=0x7ffffffe,seed=13)
    for which,sequence in [('first',[0x4c,0x46,0x32,0xbe,0x4e,0x45,0x54]),('second',[0x48,0x45,0x52,0x4f,0x46,0x49,0x47,0x48,0x54,0x45,0x52,0xbe,0x43,0x4f,0x4d])]:
        for state,key in enumerate(sequence):
            for value in dict.fromkeys([key,sequence[max(0,state-1)],0x41]):yield dict(label=which+'-state',message=0x100,key=value,**{which:state})
    for message in range(0x200,0x206):
        for lparam in (0,0xffffffff,0x80007fff,0xffff0000):yield dict(label='mouse',message=message,key=0xaabbccdd,lParam=lparam,defaultResult=-1,seed=19)
    for message in (0x3b5,0x3b6,0x3b7,0x3b8):
        for bits in range(16):
            for old in (0,1,0x75,0xa5):yield dict(label='joystick-buttons',message=message,key=bits|0xaabb0000,buttons=old,defaultResult=-123)
    for message in (0x3a0,0x3a1):
        for bounds in ([0,0,65535,65535],[10,20,110,220],[110,220,10,20],[-1,-1,1,1],[0x7fffffff,0x7fffffff,-0x80000000,-0x80000000]):
            xs={0,1,16383,16384,32767,49151,49152,65535}
            def signed(v):return (v+2**31)%2**32-2**31
            for i in (0,1):
                for value in (signed(bounds[i]*3+bounds[i+2]),signed(bounds[i]+bounds[i+2]*3)):
                    q=abs(value)//4*(-1 if value<0 else 1)
                    for n in (q-1,q,q+1):
                        if 0<=n<=65535:xs.add(n)
            for x in sorted(xs):
                for y in sorted(xs):yield dict(label='joystick-position',message=message,key=0xaabbccdd,lParam=x|(y<<16),bounds=bounds,buttons=0xa5,seed=23)
    for answer in (0,1,6,7,-1):
        for method in (0,-1,0x7fffffff):
            for cat,builtin in ((0,0),(2,2),(400,80)):
                yield dict(label='escape-cleanup',message=0x100,key=27,messageResult=answer,methodResult=method,shutdown=True,sounds=[cat,builtin])
    for replay in ([0,0],[64,0],[0,128]):yield dict(label='escape-replay-presence',message=0x100,key=27,messageResult=6,shutdown=True,music=False,replays=replay)
    # Actual text constructor, then declared activation, then own ordinary keys.
    yield dict(label='own-text-constructor',constructor=True,seed=17)
    for i in range(360):yield dict(label='own-text-key',message=0x100,key=0x42,retain=True,stimulus=[[LOCAL,1]] if i==0 else [])
    for key in (8,8,13):yield dict(label='own-text-backspace-return',message=0x100,key=key,retain=True)
    for name,sequence in [('first',[0x4c,0x46,0x32,0xbe,0x4e,0x45,0x54]),('second',[0x48,0x45,0x52,0x4f,0x46,0x49,0x47,0x48,0x54,0x45,0x52,0xbe,0x43,0x4f,0x4d])]:
        yield dict(label='own-'+name+'-constructor',constructor=True,seed=0)
        for key in sequence:yield dict(label='own-'+name+'-sequence',message=0x100,key=key,retain=True)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists()
    vm=WindowInput();cases=[];checkpoint=path.with_suffix('.incomplete.json')
    assert not checkpoint.exists(),'Review terminal job and immutable checkpoint before any resume'
    parts=path.with_suffix('.parts');parts.mkdir();(parts/'blobs').mkdir()
    for spec in specifications():
        if a.limit is not None and len(cases)>=a.limit:break
        try:cases.append(vm.call(spec,len(cases)))
        except Exception as e:
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(error=repr(e),spec=spec,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.calls,writes=vm.stores),indent=2)+'\n');raise
        # Atomic per-case/immutable blob journal avoids rewriting the entire
        # growing corpus after every ordinary input event.
        for h in vm.new_blobs:
            target=parts/'blobs'/(h+'.json');assert not target.exists()
            target.write_text(json.dumps(vm.blobs[h],sort_keys=True,separators=(',',':'))+'\n')
        case_raw=(json.dumps(cases[-1],sort_keys=True,separators=(',',':'))+'\n').encode()
        case_file=parts/('%06d.json'%cases[-1]['index']);assert not case_file.exists()
        case_tmp=case_file.with_suffix('.tmp');case_tmp.write_bytes(case_raw);os.replace(case_tmp,case_file)
        raw=(json.dumps(dict(scope=__doc__,incomplete=True,completed=len(cases),parts=str(parts.relative_to(ROOT)),lastCaseSHA256=digest(case_raw)),sort_keys=True,separators=(',',':'))+'\n').encode()
        tmp=checkpoint.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,checkpoint)
        if len(cases)%100==0:print('Completed',len(cases),'checkpointBytes',len(raw),flush=True)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,cases=cases,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    print(json.dumps(dict(path=str(path),sha256=digest(raw),bytes=len(raw),cases=len(cases),blobs=len(vm.blobs),events=sum(len(c['events']) for c in cases)),indent=2))
if __name__=='__main__':main()
