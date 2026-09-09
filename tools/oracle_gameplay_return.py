#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh initialized own result layout -> output -> match and dispatcher ret4.

Pinned EXE/VC80, one Unicorn CPU and the entire original startup/menu/catalog/
selection/first gameplay chain. Reproduce every accepted parent before continuing
422994 with its own globals, font resources, live sound queues and retained frame.
Memory/register/FPU tracing recovers output order, queue ownership and the actual
422ab8 and428805 returns. Newly bound COM method responses use already created
buffer objects; no game globals, saved stack words or flags are injected. No
control pointer/cookie damage, Windows/device/pixel or full-match claim.
"""
import argparse
import json
import struct
from collections import Counter
from oracle_gameplay_result_layout import GameplayResultLayout, initialized, FRAME_KINDS, BODY_SP
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_front_menu_resources import GLOBAL, GLOBAL_SIZE, ENTRY_SP, SOURCE
from oracle_front_screen_body import BAPI
from oracle_front_screen_prelude import PAPI
from oracle_state import STOP
from oracle_crt import PTD
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP,
    UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

START, API = 0x422994, 0x33006000
HELPERS={0x41b130:(2,8),0x4028a0:(1,0),0x43e940:(1,0),0x419e60:(0,0),0x401a30:(1,4),
         0x402810:(2,0),0x401f30:(1,0),0x401290:(6,0),0x423940:(7,0),0x423a70:(5,0),
         0x43f010:(6,24),0x43ef70:(6,0),0x4450b2:(0,0)}
STAGES=(0x41b130,0x4028a0,0x43e940,0x419e60)
METHODS={0x40:2,0x3c:2,0x48:1,0x34:2,0x30:4}
FPU_POINTS=(START,*STAGES,0x422a95,0x424746,0x4287de)
signed=lambda v:(v+0x80000000)%0x100000000-0x80000000


class GameplayReturn(GameplayResultLayout):
    def output_active(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='gameplay-return'
    def drawing_active(self):return self.output_active() or super().drawing_active()
    def imported(self,uc,pc,size,data):
        if not self.output_active():return super().imported(uc,pc,size,data)
    def checkpoint(self,uc,pc,size,data):
        if not self.output_active():return super().checkpoint(uc,pc,size,data)

    def cycle_step(self,label,pressed=None,selection=False,gameplay=False):
        if not gameplay:return super().cycle_step(label,pressed,selection,gameplay)
        self.own_entry_observations=[]
        def observe(uc,pc,size,data):
            sp=uc.reg_read(UC_X86_REG_ESP)
            self.own_entry_observations.append(dict(pc=pc,sp=sp,returnPC=self.u32(sp),argument=self.u32(sp+4),
                saved=[uc.reg_read(r) for r in REGISTERS],seh=self.u32(0)))
        hooks=[self.uc.hook_add(UC_HOOK_CODE,observe,begin=pc,end=pc) for pc in (0x4246b0,0x41bc90)]
        try:return super().cycle_step(label,pressed,selection,gameplay)
        finally:
            for hook in hooks:self.uc.hook_del(hook)

    def output_write(self,uc,access,p,size,value,data):
        if not self.output_active():return
        pc=uc.reg_read(UC_X86_REG_EIP);assert size in (1,2,4)
        value&=(1<<(8*size))-1
        self.output_writes.append(dict(pc=pc,address=p,size=size,value=value))
        if 0x41b130<=pc<0x41b387:self.drawing_event('labelWrite',[p,size,value])
        elif pc==0x423a49:
            assert size==1 and value==0;self.drawing_event('stringWrite',[p-self.output_text,0])
        elif pc in (0x419e9f,0x419f7f):
            assert size==4 and value==0;self.drawing_event('queueWrite',[p,0])
        elif pc==0x424746:
            assert p==0x457580 and size==4 and value==0;self.drawing_event('dispatcherWrite',[p,0])
        else:assert 0x402810<=pc<0x402a60,hex(pc)

    def gameplay_code(self,uc,pc,size,data):
        if not self.output_active():return super().gameplay_code(uc,pc,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
            h=self.gameplay_pending.pop()
            assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
            h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
            if h['entry']==0x43f010:self.drawing_bitmap=None
            elif h['entry']==0x7817775d:
                raw=self.cstr(h['arguments'][0]);assert len(raw)==h['result']
                self.drawing_events.append(dict(kind='format',arguments=[len(raw)],strings=[list(self.cstr(h['arguments'][1])),list(raw)]))
        if self.drawing_clip and pc==self.drawing_clip['returnPC']:
            h=self.drawing_clip;self.drawing_clip=None
            self.drawing_event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
        if pc in (0x422a95,0x424746,0x4287de,STOP):
            self.output_returns.append(dict(pc=pc,sp=sp,saved=[uc.reg_read(r) for r in REGISTERS],seh=self.u32(0)))
        if pc==STOP:
            assert not self.gameplay_pending and self.drawing_clip is None and self.drawing_bitmap is None
            self.gameplay_finished=True;uc.emu_stop();return
        if pc in self.output_methods:
            offset,count=self.output_methods[pc];assert arg(0) in self.output_buffers
            self.drawing_event('method',[arg(0),offset,*[arg(n) for n in range(1,count)]]);self.ret(0,4*count);return
        gdi=self.early.gdi
        if pc in gdi.presentation_imports:gdi.presentation_imported(uc,pc,size,data);return
        if pc in (BAPI+0x100,BAPI+0x110):gdi.com('getDC' if pc==BAPI+0x100 else 'releaseDC');return
        if pc==PAPI:
            if self.u32(sp)==0x43e975:gdi.com('blit');return
            assert arg(0)==self.u32(0x455608) and arg(5)==0
            self.drawing_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
                destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
            result=self.drawing_blits%2;self.drawing_blits+=1;self.ret(result,24);return
        if pc==0x78132db2:self.ret(PTD);return
        # Other CRT imports retain their declared adapters, not original-PC counts.
        if STOP+0x6000<=pc<STOP+0x8000:return
        self.gameplay_instructions.add(pc)
        if pc in STAGES:self.drawing_event('stage',[pc])
        if pc in HELPERS or pc==0x7817775d:
            count,pop=HELPERS[pc] if pc in HELPERS else (3 if b'%' in self.cstr(arg(1)) else 2,0)
            self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,this=uc.reg_read(UC_X86_REG_ECX),
                arguments=[arg(n) for n in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
        if pc==0x423940:
            self.output_text=arg(0);assert self.output_text==0x450c38
            self.drawing_events.append(dict(kind='fontPass',arguments=[arg(n) for n in range(1,7)],strings=[list(self.cstr(arg(0)))]))
        elif pc==0x43f010:
            pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer in self.drawing_regions
            self.drawing_bitmap=pointer;self.drawing_event('draw',[pointer,*[arg(n) for n in range(6)]])
        elif pc==0x43ef70:
            src=[arg(n) for n in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
            self.drawing_clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        elif pc==0x401a30:self.drawing_event('play',[uc.reg_read(UC_X86_REG_ECX),arg(0)])
        assert any(a<=pc<=b for a,b in [(START,0x4229c7),(0x422a95,0x422ab8),(0x424746,0x424750),(0x4287de,0x428805),
            (0x41b130,0x41b384),(0x401290,0x4012fe),(0x401f30,0x401fff),(0x402810,0x402a5f),(0x43e940,0x43e99e),
            (0x419e60,0x41a043),(0x401a30,0x401a6f),(0x423940,0x423afa),(0x43ef70,0x43f2fe),(0x4450b2,0x4450ba),
            (0x78130000,0x7822ffff)]),hex(pc)

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('gameplay-result-layout'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert report['nativeCompared'] and len(raw)==report['bytes'] and digest(raw)==report['sha256']
        assert json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_RESULT_LAYOUT reproduced; retaining caller through output and both returns',flush=True)
        self.position(START);assert self.body_sp==BODY_SP
        assert len(self.own_entry_observations)==2
        outer,inner=self.own_entry_observations
        assert outer['pc']==0x4246b0 and outer['sp']==ENTRY_SP and outer['returnPC']==STOP and outer['seh']==0x12345678
        assert inner['pc']==0x41bc90 and inner['returnPC']==0x424746
        assert self.u32(0x44eecc)!=0
        self.output_buffers={self.u32(base+4*n) for count,base in ((400,0x452948),(80,0x451db0),(5,0x45560c)) for n in range(count)}-{0}
        tables={self.u32(buffer) for buffer in self.output_buffers};assert tables
        self.uc.mem_map(API,0x1000)
        self.output_methods={API+16*n:(offset,count) for n,(offset,count) in enumerate(METHODS.items())}
        bindings=[]
        for endpoint,(offset,count) in self.output_methods.items():
            for table in sorted(tables):
                bindings.append(dict(table=table,offset=offset,before=self.u32(table+offset),after=endpoint,argumentCount=count))
                self.put(table+offset,endpoint)
        self.drawing_events=[];self.drawing_bitmap=None;self.drawing_clip=None;self.drawing_blits=0;self.output_text=0x450c38
        self.output_writes=[];self.output_returns=[]
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.output_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        p=dict(targetSurface=self.u32(0x455608),methodResult=0,queryResult=0,audioGetResult=0,audioSetResult=0,
            queriedAudio=self.music_tokens[4],audioVolume=-1234,dcResult=0,dc=0x12345678,postResult=0)
        self.early.gdi.presentation_input=p;self.early.gdi.presentation_events=self.drawing_events
        for pc in FPU_POINTS:self.uc.hook_add(UC_HOOK_CODE,self.early.observe_fpu,begin=pc,end=pc)
        initialized.CHECKPOINTS.update(FPU_POINTS)
        def snapshot():
            value=self.launch_state()
            value['frameHeap']=[dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
            value['menuBitmaps']=[dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
            return value
        before=snapshot();assert before==old['cases'][0]['after']
        cw,sw,tag=[self.uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)]
        self.gameplay_label='gameplay-return';self.gameplay_stop=STOP;self.gameplay_finished=False;self.gameplay_pending=[]
        self.gameplay_helpers=[];self.gameplay_checkpoints=[];self.gameplay_instructions=set()
        previous_reads=self.reads_before_writes;assert not previous_reads;self.reads_before_writes=set()
        self.phase='gameplay-return';self.gameplay_running=True
        try:
            self.uc.emu_start(START,0,count=2_000_000)
            assert self.gameplay_finished and self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8
            assert [self.uc.reg_read(r) for r in REGISTERS]==outer['saved'] and self.u32(0)==outer['seh']
        except Exception:
            print('OWN RETURN FAILURE',hex(self.uc.reg_read(UC_X86_REG_EIP)),self.gameplay_pending,self.drawing_events[-5:],flush=True);raise
        finally:
            reads=sorted(self.reads_before_writes);self.reads_before_writes=previous_reads;self.gameplay_running=False
        assert cw==self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and not self.early.fpu_pending
        after=snapshot()
        section=dict(label='gameplay-return',before=before,after=after,helpers=self.gameplay_helpers,checkpoints=[],
            instructions=sorted(self.gameplay_instructions),readsBeforeWrites=reads,end=self.position(STOP),
            gameplayReturn=dict(input=p,events=self.drawing_events,writes=self.output_writes,methodBindings=bindings,
                loadedSoundBuffers=sorted(self.output_buffers),entryObservations=self.own_entry_observations,returnObservations=self.output_returns,
                resourceSurfaces={str(self.u32(g)):self.u32(self.u32(g)) for g in (0x44faf4,0x44f888,0x44fcbc)},drawResults=[0,1],
                fpcw=cw,fpswBefore=sw,fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW),fptagBefore=tag,fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG)))
        return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
            parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),fpu=self.early.audit(),worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else '';name='gameplay-return'+suffix
    prerequisite=json.loads((ROOT/'docs/evidence'/('gameplay-result-layout'+suffix+'.json')).read_bytes())
    assert prerequisite['nativeCompared']
    doc=capture_startup(args.control,vm_type=GameplayReturn,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:
            vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/(name+'.json');path.write_bytes(raw)
    c=doc['cases'][0];n=c['gameplayReturn']
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],
        helpers=len(c['helpers']),instructions=len(c['instructions']),events=dict(Counter(e['kind'] for e in n['events'])),end=c['end'],
        readsBeforeWrites=c['readsBeforeWrites'],fpuCheckpoints=len(doc['fpu']['checkpoints']),returnObservations=n['returnObservations'],
        nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
