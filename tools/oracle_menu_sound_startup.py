#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover controlled original menu sound startup43d08e..43d100/whole401970.

Pinned EXE/five WAVs, Unicorn2.1.4, retained MMIO/COM/allocator/copy adapters.
Actual game instructions recover device checks, five loads, full globals/write
order, live request state, PCM/masks/ownership and caller stack cleanup. Not an
initialized WinMain/CRT/lib chain, Windows sound DLL, device or app test. Failed
CreateSoundBuffer stops at the retained40187a boundary before unsafe continuation;
no control corruption or null allocation experiment. See MENU_SOUND_STARTUP_PLAN.
"""
import argparse, json, os, struct
from pathlib import Path
from oracle_wave_loader import WaveLoader, platform, data_size, digest, DEVICE, VTABLE, ALLOC, FIRST, SECOND, GLOBAL, GLOBAL_SIZE
from oracle_state import STACK, STOP
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import *

ENTRY, END, SP = 0x43d08e, 0x43d100, STACK+0xf000
PATHS = ['data\\m_join.wav','data\\m_ok.wav','data\\m_cancel.wav','data\\m_pass.wav','data\\m_end.wav']
SAVED = [(UC_X86_REG_EBX,0x11111111),(UC_X86_REG_EBP,0x22222222),(UC_X86_REG_ESI,0x33333333),(UC_X86_REG_EDI,0x44444444)]
HELPERS = {0x401970:0,0x4014e0:4}

class MenuSoundStartup(WaveLoader):
    def __init__(self):
        super().__init__()
        self.put(0x447010,STOP+0x500);self.put(VTABLE+0x18,STOP+0x510)
        self.uc.hook_add(UC_HOOK_CODE,self.device_api,begin=STOP+0x500,end=STOP+0x510)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.global_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        self.initial_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        self.image=bytes(self.uc.mem_read(0x400000,0x4d000))
        self.source_files={p:(DEFAULT_SOURCE/p.replace('\\','/')).read_bytes() for p in PATHS}
        self.all_pcs={}
    def state(self):return self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
    def write_record(self,address,raw,origin):
        off=address-GLOBAL;assert 0<=off<off+len(raw)<=GLOBAL_SIZE
        self.global_mask[off:off+len(raw)]=b'\1'*len(raw)
        self.stores.append(dict(pc=self.uc.reg_read(UC_X86_REG_EIP),address=address,bytes=raw.hex(),origin=origin,eventIndex=len(self.ordered)))
    def global_write(self,u,access,address,n,value,data):
        if self.running:self.write_record(address,(value&((1<<(8*n))-1)).to_bytes(n,'little'),'CPU')
    def record_event(self,kind,args=(),strings=(),wave=None):
        self.ordered.append(dict(event=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],wave=wave),globals=self.state()))
    def event(self,kind,args=(),strings=()):
        e=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]);self.events.append(e)
        self.record_event('wave',wave=e)
    def device_api(self,u,pc,n,data):
        sp=u.reg_read(UC_X86_REG_ESP);args=lambda count:[self.u32(sp+4+i*4) for i in range(count)]
        if pc==STOP+0x500:
            words=args(3);assert words==[0,0x44eecc,0];self.record_event('deviceCreate',words)
            output=self.spec['device']['createdDevice']
            if output is not None:
                self.put(words[1],output);self.write_record(words[1],struct.pack('<I',output),'API')
            self.ret(self.spec['device']['createResult'],12)
        else:
            words=args(3);assert words==[self.u32(0x44eecc),self.u32(0x4546f4),1]
            self.record_event('cooperativeLevel',words);self.ret(self.spec['device']['cooperativeResult'],12)
    def imported(self,u,pc,n,data):
        if self.imports[pc]=='message' and self.current is None:
            sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
            self.record_event('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(self.spec['device']['messageResult'],16)
        else:super().imported(u,pc,n,data)
    def allowed(self,u,pc,n,data):
        if not self.running:return
        sp=u.reg_read(UC_X86_REG_ESP)
        for h in list(reversed(self.pending)):
            if pc==h['returnPC'] and sp==h['sp']+4+HELPERS[h['entry']]:
                saved=[u.reg_read(r) for r,_ in SAVED];assert saved==h['saved']
                self.returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX),returnSP=sp));self.pending.remove(h)
                if h['entry']==0x4014e0:self.finish_wave('returned',u.reg_read(UC_X86_REG_EAX))
        if pc==END:return # unexecuted stop; only the completed child return
        if pc==0x40187a and self.current is not None and self.p['createResult']!=0:
            self.finish_wave('invalidCreateContinuation',None);u.emu_stop();return
        if pc in HELPERS:
            self.pending.append(dict(entry=pc,sp=sp,returnPC=self.u32(sp),saved=[u.reg_read(r) for r,_ in SAVED]))
            if pc==0x4014e0:self.begin_wave(sp)
        boundary=pc in (0x4450ac,0x4450a6,0x4450c2) or STOP<=pc<STOP+0x1000
        if not boundary:
            assert (ENTRY<=pc<END or 0x401970<=pc<=0x4019a8 or 0x4014e0<=pc<=0x40195e
                    or 0x4450b2<=pc<=0x4450ba or pc==0x43f384),hex(pc)
            raw=bytes(u.mem_read(pc,n)).hex();self.pcs[pc]=raw;self.all_pcs[pc]=raw
    def begin_wave(self,sp):
        index=len(self.loads);assert index<5
        self.wave_entry_sp=sp;destination=self.uc.reg_read(UC_X86_REG_ECX)
        self.path=self.cstr(self.u32(sp+4));assert self.path.decode()==PATHS[index] and destination==0x45560c+4*index
        self.raw=self.source_files[PATHS[index]]
        changes=dict(self.spec.get('waves',{}).get(str(index),{}))
        if changes.pop('shortData',False):changes['dataReadResult']=data_size(self.raw)-1
        self.p=platform(self.raw,index,destination=destination,device=self.u32(0x44eecc),ramp=self.spec['ramp'],**changes)
        assert data_size(self.raw)<0x5f000
        self.allocation=ALLOC+index*0x60000
        self.p['firstPointer']=FIRST+index*0x60000
        if self.p['secondPointer']:self.p['secondPointer']=SECOND+index*0x60000
        self.put(self.p['buffer'],VTABLE)
        self.current=dict(label=PATHS[index],path=list(self.path),file=self.blob(self.raw),input=self.p,
                          entrySP=sp,outputBefore=self.u32(destination),beforeGlobals=self.state())
        self.regions={};self.events=[];self.device_format=self.descriptor=None;self.descents=self.reads=self.locks=0
        self.region('first',self.p['firstPointer'],self.p['firstCount'])
        if self.p['secondPointer']:self.region('second',self.p['secondPointer'],self.p['secondCount'])
        self.record_event('load',[destination],[self.path])
    def crt(self,u,pc,n,data):
        sp=u.reg_read(UC_X86_REG_ESP);a=self.allocation
        if pc==0x4450ac:
            count=self.u32(sp+4);assert self.u32(sp)==0x401763
            self.event('allocate',[count]);self.region('temporary',a,count);self.ret(a)
        elif pc==0x4450a6:
            assert self.u32(sp+4)==a and self.regions['temporary']['live']
            self.regions['temporary']['live']=False;self.event('free');self.ret()
        else:
            dest,source,count=[self.u32(sp+i) for i in (4,8,12)]
            assert self.regions['temporary']['live'] and a<=source<=source+count<=a+self.regions['temporary']['count']
            assert dest in (self.p['firstPointer'],self.p['secondPointer'])
            part=0 if dest==self.p['firstPointer'] else 1
            self.event('copy',[part,source-a,count]);self.host_write(dest,bytes(u.mem_read(source,count)));self.ret(dest)
    def finish_wave(self,exit_kind,returned):
        storage=[dict(kind=name,address=r['address'],bytes=self.blob(self.uc.mem_read(r['address'],r['count'])),
                      live=r['live']) for name,r in self.regions.items()]
        self.current.update(outputAfter=self.u32(self.p['destination']),afterGlobals=self.state(),
            temporary=self.record('temporary'),temporaryLive=self.regions.get('temporary',{}).get('live',False),
            first=self.record('first'),second=self.record('second'),format=self.device_format,descriptor=self.descriptor,
            events=self.events,exit=exit_kind,returned=returned,stackAfter=self.uc.reg_read(UC_X86_REG_ESP),storage=storage)
        self.loads.append(self.current);self.current=None
    def run_case(self,spec):
        self.spec=spec;self.ordered=[];self.loads=[];self.current=None;self.pending=[];self.returns=[];self.pcs={};self.stores=[]
        self.uc.mem_write(GLOBAL,self.initial_globals)
        for a,v in [(0x44eecc,0x12345678),(0x4546f4,spec['window'])]+[(0x45560c+4*i,0x87654000+i) for i in range(5)]:self.put(a,v)
        self.uc.mem_write(SP-0x1000,bytes(i%256 for i in range(0x1040)) if spec['ramp'] else b'\xa5'*0x1040)
        # Actual pending memset arguments from43d078..43d084; their producer
        # is static here. No earlier WinMain/private stack bytes are imported.
        self.uc.mem_write(SP,struct.pack('<III',0x455378,0x75,0x100))
        self.uc.reg_write(UC_X86_REG_ESP,SP)
        for reg,value in SAVED:self.uc.reg_write(reg,value)
        self.uc.reg_write(UC_X86_REG_FPCW,0x37f)
        self.stack_mask=bytearray(0x10000);self.global_mask=bytearray(GLOBAL_SIZE)
        before=self.state();self.before_bytes=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.running=True
        try:
            self.uc.emu_start(ENTRY,END,count=1_000_000)
            if self.uc.reg_read(UC_X86_REG_EIP)==END:self.allowed(self.uc,END,0,None)
        finally:self.running=False
        pc=self.uc.reg_read(UC_X86_REG_EIP);invalid=pc==0x40187a
        assert pc==END or invalid,hex(pc)
        assert self.current is None
        if not invalid:
            assert len(self.loads)==5 and not self.pending
            assert self.uc.reg_read(UC_X86_REG_ESP)==SP+12
            assert [self.uc.reg_read(r) for r,_ in SAVED]==[v for _,v in SAVED]
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x37f
        assert bytes(self.uc.mem_read(0x400000,0x4d000))==self.image
        for load in self.loads:
            for region in load['storage']:
                # Later loads use disjoint adapter regions, including after a
                # leaked temporary. Preserve every earlier byte to segment end.
                assert digest(self.uc.mem_read(region['address'],self.blobs[region['bytes']]['count']))==region['bytes']
        after=self.state();after_bytes=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        assert all(v or after_bytes[i]==self.before_bytes[i] for i,v in enumerate(self.global_mask))
        return dict(spec=spec,beforeGlobals=before,afterGlobals=after,globalMask=self.blob(self.global_mask),stores=self.stores,
            events=self.ordered,loads=self.loads,helperReturns=self.returns,instructions={hex(a):b for a,b in sorted(self.pcs.items())},
            exit='invalidCreateContinuation' if invalid else 'segmentEnd',endPC=pc,stackAfter=self.uc.reg_read(UC_X86_REG_ESP),
            controlWord=0x37f,savedRegisters=[self.uc.reg_read(r) for r,_ in SAVED])

def specifications():
    cases=[]
    def add(label,ramp=False,create=0,coop=0,waves=None):
        cases.append(dict(label=label,ramp=ramp,window=0x23450002 if not ramp else 0,
            device=dict(createResult=create,createdDevice=DEVICE if create==0 else None,cooperativeResult=coop,messageResult=-1),waves=waves or {}))
    for ramp in [False,True]:
        for create in [0,1,-1,-2147467259]:
            for coop in ([0,1,-2147467259] if create==0 else [0]):add(f'device-{int(ramp)}-{create}-{coop}',ramp,create,coop)
        variations=[('open',dict(stream=0)),('riff',dict(descendResults=[1,0,0])),('format-chunk',dict(descendResults=[0,-1,0])),
            ('format-read',dict(formatReadResult=17)),('ascend',dict(ascendResult=-1)),('data-chunk',dict(descendResults=[0,0,1])),
            ('short-data',dict(shortData=True)),('failed-data',dict(dataReadResult=-1)),
            ('lost',dict(lockResults=[0x88780096,0x88780096])),('lock-error',dict(lockResults=[0x80004005,0]))]
        for index in range(5):
            for label,change in variations:add(f'{label}-{index}-{int(ramp)}',ramp,waves={str(index):change})
        for index in range(5):add(f'create-rejection-{index}-{int(ramp)}',ramp,waves={str(index):dict(createResult=-1 if ramp else 1)})
    return cases

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--limit',type=int);args=ap.parse_args()
    assert not args.output.exists();parts=args.output.with_suffix('.parts');assert not parts.exists();parts.mkdir(parents=True)
    producer=Path(__file__).read_bytes();args.output.with_name(args.output.stem+'-source.py').write_bytes(producer)
    vm=MenuSoundStartup();cases=[]
    for spec in specifications()[:args.limit]:
        c=vm.run_case(spec);cases.append(c)
        part=parts/f'{len(cases):04d}.json';payload=(json.dumps(dict(case=c,blobs=vm.blobs),separators=(',',':'))+'\n').encode()
        temp=part.with_suffix('.tmp');temp.write_bytes(payload);os.replace(temp,part)
        print(len(cases),spec['label'],c['exit'],len(c['events']),flush=True)
    doc=dict(exeSHA256=EXE_SHA256,producerSHA256=digest(producer),adapterSHA256=digest((ROOT/'tools/oracle_wave_loader.py').read_bytes()),scope=__doc__,
        dependencies={name:digest((ROOT/'tools'/name).read_bytes()) for name in ['oracle_wave_loader.py','oracle_state.py','inspect_original.py','import_ntsd.py']},
        sources=[dict(path=p,sha256=digest(raw),count=len(raw)) for p,raw in vm.source_files.items()],
        cases=cases,blobs=vm.blobs,instructions={hex(a):b for a,b in sorted(vm.all_pcs.items())})
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();temp=args.output.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,args.output)
    print('completed',len(cases),len(raw),digest(raw),flush=True)
if __name__=='__main__':main()
