#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover input initialization43bf10 within whole43d078..43d100 and own callbacks.

Pinned original EXE/five WAVs, Unicorn2.1.4, controlled WinMM/DirectSound and
memory-copy boundaries. Actual instructions recover retained joystick/key bytes,
calibration/order/stack provenance, all menu WAV children and subsequent joystick
WndProc consumers. No real Windows device, full CRT/WinMain, lib installation or
app claim. Ordinary caps failure can expose unknown caller backing: preserve the
source return, separately reject native unknown reads; no corruption/fault stimulus.
See INPUT_STARTUP_PLAN.md. Reference execution is development tooling only.
"""
import argparse,json,os,struct
from pathlib import Path
from oracle_menu_sound_startup import MenuSoundStartup,SP,SAVED,END,PATHS
from oracle_wave_loader import GLOBAL,GLOBAL_SIZE,digest
from oracle_state import STACK,STOP
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ
from unicorn.x86_const import *

ENTRY=0x43d078
class InputStartup(MenuSoundStartup):
    def __init__(self):
        self.callback_running=False;self.joy_frame=None
        super().__init__();self.joy_imports={}
        names={0x447234:'numberDevices',0x447240:'position',0x447244:'threshold',0x447248:'capture',0x44724c:'capabilities'}
        for i,(iat,name) in enumerate(names.items()):
            pc=STOP+0x600+i*16;self.put(iat,pc);self.joy_imports[pc]=name
        exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes()
        iat=next(int(x['iatVA'],16) for x in PE(exe).imports() if x['name']=='DefWindowProcA');self.put(iat,STOP+0x680)
        self.uc.hook_add(UC_HOOK_CODE,self.joy_api,begin=STOP+0x600,end=STOP+0x680)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.read_caps)
        self.image=bytes(self.uc.mem_read(0x400000,0x4d000))
    def read_caps(self,u,access,address,n,value,data):
        if not self.running or self.joy_frame is None or self.callback_running:return
        a=self.joy_frame['caps'];o=address-a
        if 0<=o<o+n<=404:
            known=all(self.stack_mask[address-STACK:address-STACK+n])
            self.caps_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),offset=o,count=n,known=known,bytes=bytes(u.mem_read(address,n)).hex()))
            if not known and self.own_boundary is None:
                self.own_boundary=dict(pc=u.reg_read(UC_X86_REG_EIP),eventCount=len(self.ordered),storeCount=len(self.stores),globals=self.state(),offset=o,count=n)
    def memset(self,u,pc,n,data):
        sp=u.reg_read(UC_X86_REG_ESP);a,v,count=[self.u32(sp+i) for i in (4,8,12)]
        assert (a==0x455378 and v==117 and count==256) or (self.joy_frame and a==self.joy_frame['info'] and v==0 and count==52)
        raw=bytes([v])*count;self.host_write(a,raw)
        if a==0x455378:self.write_record(a,raw,'memset')
        self.ret(a)
    def joy_api(self,u,pc,n,data):
        sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
        if pc==STOP+0x680:
            assert self.callback_running;args=[arg(i) for i in range(4)]
            self.record_event('windowDefault',args);self.ret(-123,16);return
        name=self.joy_imports[pc];j=self.spec['joysticks'];information=None;address=None
        if name=='numberDevices':args=[];response=dict(result=j['count'],writes=[]);pop=0
        else:
            id=arg(1) if name=='capture' else arg(0);assert id in (0,1)
            response=j['devices'][id][name]
            if name=='position':
                address=arg(1);assert address==self.joy_frame['info'];information=list(u.mem_read(address,52));args=[id];pop=8
            elif name=='threshold':args=[id,arg(1)];pop=8;assert args[1]==100
            elif name=='capture':args=[arg(i) for i in range(4)];pop=16;assert args==[self.u32(0x4546f4),id,25,1]
            else:address=arg(1);assert address==self.joy_frame['caps'] and arg(2)==404;args=[id,404];pop=12
        self.record_event(name,args,[] if information is None else [bytes(information)])
        item=dict(request=dict(kind=name,arguments=args,information=information),response=response,globals=self.state())
        self.joy_requests.append(item)
        for write in response['writes']:
            assert address is not None;off=write['offset'];payload=bytes(write['bytes']);limit=52 if name=='position' else 404
            assert 0<=off<=off+len(payload)<=limit;self.host_write(address+off,payload)
        if name=='capabilities':
            self.caps_states.append(dict(id=id,bytes=self.blob(u.mem_read(address,404)),defined=self.blob(self.stack_mask[address-STACK:address-STACK+404])))
        self.ret(response['result'],pop)
    def allowed(self,u,pc,n,data):
        if not self.running:return
        if self.callback_running:
            if pc==STOP:return
            if pc==STOP+0x680:return
            assert 0x43b3d0<=pc<=0x43bc3e,hex(pc)
            value=bytes(u.mem_read(pc,n)).hex();self.pcs[pc]=value;self.all_pcs[pc]=value;return
        if pc==0x43bf10:
            sp=u.reg_read(UC_X86_REG_ESP);self.joy_frame=dict(sp=sp,info=sp-0x1cc,caps=sp-0x198)
        if pc==0x43d08e:
            assert self.joy_frame and u.reg_read(UC_X86_REG_ESP)==self.joy_frame['sp']+4
            self.joy_return=dict(eax=u.reg_read(UC_X86_REG_EAX),sp=u.reg_read(UC_X86_REG_ESP),globals=self.state(),saved=[u.reg_read(r) for r,_ in SAVED])
            assert self.joy_return['saved']==[v for _,v in SAVED]
            self.joy_frame=None
        if pc in self.joy_imports or pc==0x4450a0:return
        if ENTRY<=pc<0x43d08e or 0x43bf10<=pc<=0x43c0ba:
            value=bytes(u.mem_read(pc,n)).hex();self.pcs[pc]=value;self.all_pcs[pc]=value;return
        super().allowed(u,pc,n,data)
    def run_case(self,spec):
        self.spec=spec;self.ordered=[];self.loads=[];self.current=None;self.pending=[];self.returns=[];self.pcs={};self.stores=[]
        self.joy_requests=[];self.caps_states=[];self.caps_reads=[];self.own_boundary=None;self.joy_return=None;self.joy_frame=None
        self.uc.mem_write(GLOBAL,self.initial_globals)
        for a,v in [(0x44eecc,0x12345678),(0x4546f4,spec['window'])]+[(0x45560c+4*i,0x87654000+i) for i in range(5)]:self.put(a,v)
        self.uc.mem_write(0x453fd0,bytes((i*17+spec['seed'])&255 for i in range(192)))
        self.uc.mem_write(0x455378,bytes((i*19+spec['seed'])&255 for i in range(300)))
        self.uc.mem_write(SP-0x1000,bytes(i%256 for i in range(0x1040)) if spec['ramp'] else b'\xa5'*0x1040)
        # New caller starts12 bytes above the retained sound-study entry. It
        # executes all three pushes itself; no pending arguments are imported.
        self.uc.reg_write(UC_X86_REG_ESP,SP+12)
        for reg,value in SAVED:self.uc.reg_write(reg,value)
        self.uc.reg_write(UC_X86_REG_FPCW,0x37f);self.stack_mask=bytearray(0x10000);self.global_mask=bytearray(GLOBAL_SIZE)
        before=self.state();self.running=True
        try:
            self.uc.emu_start(ENTRY,END,count=1_000_000)
            if self.uc.reg_read(UC_X86_REG_EIP)==END:super().allowed(self.uc,END,0,None)
        finally:self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==END and self.uc.reg_read(UC_X86_REG_ESP)==SP+12
        assert len(self.loads)==5 and not self.pending and self.joy_return
        assert [self.uc.reg_read(r) for r,_ in SAVED]==[v for _,v in SAVED]
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f and bytes(self.uc.mem_read(0x400000,0x4d000))==self.image
        for load in self.loads:
            for r in load['storage']:assert digest(self.uc.mem_read(r['address'],self.blobs[r['bytes']]['count']))==r['bytes']
        result=dict(spec=spec,beforeGlobals=before,afterGlobals=self.state(),globalMask=self.blob(self.global_mask),stores=self.stores,
            events=self.ordered,loads=self.loads,helperReturns=self.returns,joystickReturn=self.joy_return,joyRequests=self.joy_requests,
            capsStates=self.caps_states,capsReads=self.caps_reads,ownBoundary=self.own_boundary,
            instructions={hex(a):b for a,b in sorted(self.pcs.items())},endPC=END,stackAfter=SP+12,controlWord=0x37f)
        result['callbacks']=[]
        if spec.get('callbacks') and self.own_boundary is None:
            bounds=[[self.u32(base+4*i) for i in range(4)] for base in [0x453fd8,0x454008]]
            for message in callback_specs(spec['window'],bounds):result['callbacks'].append(self.callback(message))
        return result
    def callback(self,message):
        self.ordered=[];self.stores=[];self.pcs={};self.global_mask=bytearray(GLOBAL_SIZE)
        before=self.state();self.uc.mem_write(SP,struct.pack('<5I',STOP,message['window'],message['message'],message['wParam'],message['lParam']))
        self.uc.reg_write(UC_X86_REG_ESP,SP)
        for r,v in SAVED:self.uc.reg_write(r,v)
        self.callback_running=True;self.running=True
        try:self.uc.emu_start(0x43b3d0,STOP,count=100000)
        finally:self.callback_running=False;self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+20
        assert [self.uc.reg_read(r) for r,_ in SAVED]==[v for _,v in SAVED]
        return dict(message=message,beforeGlobals=before,afterGlobals=self.state(),globalMask=self.blob(self.global_mask),stores=self.stores,events=self.ordered,
            instructions={hex(a):b for a,b in sorted(self.pcs.items())},returned=self.uc.reg_read(UC_X86_REG_EAX),stackAfter=SP+20)

def response(result=0,writes=None):return dict(result=result&0xffffffff,writes=writes or [])
def device(bounds,seed=0,pos=0,caps=0,caps_output=True):
    info=bytes((i*7+seed)&255 for i in range(44))
    raw=bytearray((i*13+seed)&255 for i in range(404))
    struct.pack_into('<4I',raw,36,*[v&0xffffffff for v in bounds])
    return dict(position=response(pos,[dict(offset=8,bytes=list(info))] if pos!=167 else []),threshold=response(-1),capture=response(-1),
        capabilities=response(caps,[dict(offset=0,bytes=list(raw))] if caps_output else []))
def specifications():
    result=[]
    def add(label,devices,count=2,ramp=False,audio=True,waves=None,callbacks=False):
        result.append(dict(label=label,seed=23 if ramp else 0xa5,ramp=ramp,window=0x23450002,joysticks=dict(count=count,devices=devices),
            device=dict(createResult=0 if audio else -1,createdDevice=0x24000020 if audio else None,cooperativeResult=-1,messageResult=-1),waves=waves or {},callbacks=callbacks))
    ranges=[[0,65535,0,65535],[10,110,20,220],[110,10,220,20],[0xffffffff,1,0xffffffff,1],
            [0x7fffffff,0x7fffffff,0x80000000,0x80000000],[0,0,1,2]]
    for ramp in [False,True]:
        add('no-device-'+str(ramp),[device(ranges[0]),device(ranges[1])],count=0,ramp=ramp)
        for first in [0,1,167,165]:
            for second in [0,167,165]:add(f'positions-{ramp}-{first}-{second}',[device(ranges[0],pos=first),device(ranges[1],pos=second)],count=1,ramp=ramp,callbacks=first==0 and second==0)
        for i,bounds in enumerate(ranges):add(f'bounds-{ramp}-{i}',[device(bounds,17),device(list(reversed(bounds)),31)],ramp=ramp,callbacks=True)
        add('retained-caps-'+str(ramp),[device(ranges[1]),device(ranges[2],caps=165,caps_output=False)],ramp=ramp,callbacks=True)
        add('unknown-first-caps-'+str(ramp),[device(ranges[1],caps=165,caps_output=False),device(ranges[2])],ramp=ramp)
        add('unknown-second-only-'+str(ramp),[device(ranges[1],pos=167),device(ranges[2],caps=165,caps_output=False)],ramp=ramp)
        add('failed-caps-output-'+str(ramp),[device(ranges[1],caps=165),device(ranges[2],caps=1)],ramp=ramp,callbacks=True)
        add('audio-disabled-'+str(ramp),[device(ranges[0]),device(ranges[1])],ramp=ramp,audio=False)
        for i in range(5):add(f'missing-wave-{ramp}-{i}',[device(ranges[0]),device(ranges[1])],ramp=ramp,waves={str(i):dict(stream=0)})
    return result
def callback_specs(window,bounds):
    signed=lambda n:(n+2**31)%2**32-2**31
    quarter=lambda n:abs(signed(n))//4*(-1 if signed(n)<0 else 1)
    for index,msg in enumerate([0x3a0,0x3a1]):
        left,top,right,bottom=bounds[index]
        coordinates={(0,0),(1,1),(25,50),(26,51),(50,100),(75,150),(76,151),(16383,16384),(49151,49152),(65535,65535)}
        for x in [quarter(3*left+right),quarter(left+3*right)]:
            for y in [quarter(3*top+bottom),quarter(top+3*bottom)]:
                for dx in [-1,0,1]:
                    for dy in [-1,0,1]:
                        if 0<=x+dx<=65535 and 0<=y+dy<=65535:coordinates.add((x+dx,y+dy))
        for x,y in sorted(coordinates):
            yield dict(window=window,message=msg,wParam=0xaabbccdd,lParam=x|(y<<16))
    for msg in [0x3b5,0x3b6,0x3b7,0x3b8]:
        for bits in [0,1,2,4,8,15]:yield dict(window=window,message=msg,wParam=bits|0xaabb0000,lParam=0)

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--limit',type=int);a=ap.parse_args();assert not a.output.exists()
    parts=a.output.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
    producer=Path(__file__).read_bytes();a.output.with_name(a.output.stem+'-source.py').write_bytes(producer);vm=InputStartup();cases=[]
    for s in specifications()[:a.limit]:
        c=vm.run_case(s);cases.append(c);part=parts/f'{len(cases):04d}.json';tmp=part.with_suffix('.tmp')
        tmp.write_text(json.dumps(dict(case=c,blobs=vm.blobs),separators=(',',':'))+'\n');os.replace(tmp,part)
        print(len(cases),s['label'],'unknown' if c['ownBoundary'] else 'supported',len(c['callbacks']),flush=True)
    d=dict(exeSHA256=EXE_SHA256,producerSHA256=digest(producer),scope=__doc__,
        dependencies={n:digest((ROOT/'tools'/n).read_bytes()) for n in ['oracle_menu_sound_startup.py','oracle_wave_loader.py','oracle_state.py','inspect_original.py','import_ntsd.py']},
        sources=[dict(path=p,sha256=digest(raw),count=len(raw)) for p,raw in vm.source_files.items()],cases=cases,blobs=vm.blobs,
        instructions={hex(a):b for a,b in sorted(vm.all_pcs.items())})
    raw=(json.dumps(d,separators=(',',':'))+'\n').encode();tmp=a.output.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,a.output)
    print('completed',len(cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
