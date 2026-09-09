#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Own pause, single-step and resume after the complete sixteen-call parent.

Pinned NTSD2.4 EXE/VC80 on the retained initialized Unicorn2.1.4 CPU. Only
acquired F1/F2 keyboard bytes are supplied; no pause flags, caller stack words,
World/Actor state or replay bytes are injected. Execute input/round, direct
paused background/world/HUD/PAUSE rendering, common output and both returns.
Memory, helper, register and FPU observers recover ownership and call order.
COM/GDI responses remain declared boundaries. Newly encountered unknown game
children stop explicitly. No whole playback prologue, outer timing, native
device, Windows or complete-match claim. Native comparison is a separate step.
"""
import argparse
import copy
import json
import os
import struct
from datetime import datetime, timezone
from oracle_continuous_gameplay import ContinuousGameplay, STAGES, encoded, initialized, BODY_SP
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_front_menu_resources import ENTRY_SP, SOURCE
from oracle_front_screen_prelude import PAPI
from oracle_state import STOP
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDI,
    UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

SCHEDULE=[dict(index=i+1,keys=([0x4553e8] if i in (0,10) else [0x4553e9] if i==4 else [])) for i in range(14)]
PAUSED_STOPS={0x41d74d:'background',0x41d762:'drawing',0x41d76a:'hud',0x41d78b:'pauseBitmap',0x422994:'indicators'}
HELPERS={0x41a250:(1,4),0x41a050:(1,4),0x41a5a0:(3,12),0x41ae60:(1,4),
    0x40de30:(3,12),0x40be70:(7,28),0x40bf30:(1,4),0x43f010:(6,24),0x43ef70:(6,0),
    0x43f310:(7,28),0x415160:(5,0),0x4450d0:(0,0),0x4450b2:(0,0)}
signed=lambda n:(n+0x80000000)%0x100000000-0x80000000


class PausedGameplay(ContinuousGameplay):
    def pausing(self):return getattr(self,'pause_sequence',False)
    def pause_rendering(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='paused-rendering'
    def drawing_active(self):return self.pause_rendering() or super().drawing_active()

    def imported(self,uc,pc,size,data):
        if not self.pause_rendering():return super().imported(uc,pc,size,data)

    def checkpoint(self,uc,pc,size,data):
        if not self.pause_rendering():return super().checkpoint(uc,pc,size,data)

    def checkpoint_file(self):
        suffix='-control' if self.control else ''
        name='paused-gameplay'+suffix+('-partial' if self.pausing() else '-parent-partial')
        doc=self.pause_document() if self.pausing() else super().document()
        raw=encoded(doc)+b'\n';path=ROOT/'build/research'/(name+'.json');temporary=path.with_suffix('.json.tmp')
        temporary.write_bytes(raw);os.replace(temporary,path)
        proof=dict(bytes=len(raw),sha256=digest(raw),completeReturnedCalls=len(self.continuous_cases),
            nativeCompared=False,updatedUTC=datetime.now(timezone.utc).isoformat())
        path.with_suffix('.checkpoint.json').write_text(json.dumps(proof,indent=2)+'\n')
        assert digest(path.read_bytes())==proof['sha256']

    def cycle_step(self,label,pressed=None,selection=False,gameplay=False):
        if not self.pausing():return super().cycle_step(label,pressed,selection,gameplay)
        assert pressed is None and not selection and gameplay
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.u32(WORLD)==2
        before=self.control_snapshot();retained=self.early.snapshot()
        assert self.u32(0)==0x12345678
        assert [self.uc.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677]
        self.own_entry_observations=[]
        def entry(uc,pc,size,data):
            sp=uc.reg_read(UC_X86_REG_ESP)
            self.own_entry_observations.append(dict(pc=pc,sp=sp,returnPC=self.u32(sp),argument=self.u32(sp+4),
                saved=[uc.reg_read(r) for r in REGISTERS],seh=self.u32(0)))
        hooks=[self.uc.hook_add(UC_HOOK_CODE,entry,begin=pc,end=pc) for pc in (0x4246b0,0x41bc90)]
        self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE)
        self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
        self.cycle_prefix=True;self.cycle_end=False;self.phase='cycle-prefix'
        try:self.uc.emu_start(0x4246b0,0,count=10000);assert self.cycle_end
        finally:
            self.cycle_prefix=False
            for hook in hooks:self.uc.hook_del(hook)
        self.body_sp=self.uc.reg_read(UC_X86_REG_ESP);assert self.body_sp==BODY_SP
        self.commands_address=BODY_SP+0x434
        paused=self.u32(BODY_SP+0x38);assert paused in (0,1)
        assert self.u32(0x44d05c)==0 and self.u32(0x450b84)==0
        prefix=dict(after=self.control_snapshot(),paused=paused,phase=self.u32(0x450b90),
            commands=list(self.uc.mem_read(self.commands_address,10)),playback=list(self.uc.mem_read(BODY_SP+0x440,10)),end=self.position(0x41c581))
        local=self.step(label+' local',parent=True,paused=paused);assert not local['dispatch']
        control=self.control_step(label+' control',paused=paused,inherited=True)
        replay=self.replay_step(label+' replay',paused=paused,inherited=True)
        outcome=self.round_step(label+' round',paused=paused,inherited=True)
        assert outcome['continuation'] in ('gameplay','pausedRendering')
        return dict(label=label,stimulus=[],before=before,earlyBefore=retained,prefix=prefix,local=local,
            inputControl=control,replay=replay,round=outcome,after=self.control_snapshot(),earlyAfter=self.early.snapshot(),end=self.position(outcome['endPC']))

    def gameplay_code(self,uc,pc,size,data):
        if not self.pause_rendering():return super().gameplay_code(uc,pc,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.gameplay_pending and pc==self.gameplay_pending[-1]['returnPC']:
            h=self.gameplay_pending.pop()
            assert sp==h['entrySP']+4+h['pop'] and h['saved']==[uc.reg_read(r) for r in REGISTERS],h
            h.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.gameplay_helpers.append(h)
            if h['entry'] in (0x43f010,0x43f310):self.drawing_bitmap=None
        if self.drawing_clip and pc==self.drawing_clip['returnPC']:
            h=self.drawing_clip;self.drawing_clip=None
            self.drawing_event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],
                visible=uc.reg_read(UC_X86_REG_EAX)==1))
        if pc in PAUSED_STOPS:
            assert not self.gameplay_pending and self.drawing_clip is None and self.drawing_bitmap is None
            self.pause_checkpoints.append(dict(stage=PAUSED_STOPS[pc],pc=pc,state=self.launch_state(),
                events=self.drawing_events[self.pause_event_offset:],registers=[uc.reg_read(r) for r in REGISTERS],
                fpu=[uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)]))
            self.pause_event_offset=len(self.drawing_events)
        if pc==0x422994:self.gameplay_finished=True;uc.emu_stop();return
        if pc==PAPI:
            if arg(4)==0x1000400:
                assert arg(0)==self.u32(0x455608) and arg(2)==arg(3)==0 and arg(5)!=0
                self.drawing_event('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),
                    flags=arg(4),effects=list(uc.mem_read(arg(5),100)),defined=[i<4 or 0x50<=i<0x54 for i in range(100)]))
                result=0
            else:
                assert arg(0) in (self.drawing_target,self.u32(0x455608)) and arg(5)==0
                self.drawing_event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),
                    source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),
                    flags=arg(4),effects=None))
                result=self.drawing_blits%2;self.drawing_blits+=1
            self.ret(result,24);return
        self.gameplay_instructions.add(pc)
        if pc in HELPERS:
            count,pop=HELPERS[pc]
            self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=pop,
                this=uc.reg_read(UC_X86_REG_ECX),arguments=[arg(n) for n in range(count)],saved=[uc.reg_read(r) for r in REGISTERS]))
        if pc in (0x43f010,0x43f310):
            pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer in self.drawing_bitmap_tokens
            self.drawing_bitmap=pointer
            self.drawing_event('draw' if pc==0x43f010 else 'rectangle',
                [self.drawing_bitmap_tokens[pointer],*[arg(n) for n in range(6 if pc==0x43f010 else 7)]])
        elif pc==0x43ef70:
            src=[arg(n) for n in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
            self.drawing_clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        elif pc==0x415160:self.pause_fill_inputs.append(bytes(uc.mem_read(sp-0x64,100)).hex())
        assert any(a<=pc<=b for a,b in ((0x41d73b,0x41d799),(0x41a050,0x41a590),(0x41a5a0,0x41b12d),
            (0x40de30,0x40e160),(0x40be70,0x40bfa8),(0x43ef70,0x43f37a),(0x415160,0x4151c2),
            (0x4450d0,0x44517a),(0x4450b2,0x4450ba),(0x422952,0x42298f))),('Unrecovered paused helper',hex(pc))

    def render_pause(self):
        self.drawing_events=[];self.drawing_bitmap=None;self.drawing_clip=None;self.drawing_blits=0
        self.drawing_target=self.u32(BODY_SP+0x68)
        self.pause_checkpoints=[];self.pause_fill_inputs=[];self.pause_event_offset=0
        section=self.gameplay_step('paused-rendering',0x41d73b,0x422994)
        assert [c['stage'] for c in self.pause_checkpoints]==list(PAUSED_STOPS.values())
        section.update(checkpoints=self.pause_checkpoints,events=self.drawing_events,fillInputs=self.pause_fill_inputs,
            target=self.drawing_target,drawResults=[0,1],fillResult=0)
        return section

    def acquire_pause_keys(self,step):
        before=bytes(self.uc.mem_read(0x455378,300));changes=[]
        for address in (0x4553e8,0x4553e9):
            value=100 if address in step['keys'] else 117
            if before[address-0x455378]!=value:
                self.uc.mem_write(address,bytes([value]));changes.append(dict(address=address,bytes=bytes([value]).hex()))
        after=bytes(self.uc.mem_read(0x455378,300))
        assert after==bytes(100 if 0x455378+n in step['keys'] else 117 for n in range(300))
        return dict(plan=step,before=list(before),after=list(after),changes=changes)

    def pause_document(self):
        return transport(dict(format='paused-gameplay-components-v1',exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,
            scope=__doc__,control=self.control,parent=self.continuous_parent,worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,platform=self.continuous_platform,
            initial=self.continuous_initial,schedule=SCHEDULE,cases=self.continuous_cases,
            components=self.continuous_components,fpu=copy.deepcopy(self.early.audit())),{**self.early.blobs,**self.blobs})

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('continuous-gameplay'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert report['nativeCompared'] and len(raw)==report['bytes'] and digest(raw)==report['sha256']
        assert json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        print('Complete accepted16-call parent reproduced; beginning own pause/step/resume keys',flush=True)
        self.pause_sequence=True;self.continuous_active=True
        self.continuous_components={};self.continuous_cases=[]
        self.continuous_parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        self.continuous_initial=self.component_snapshot(self.full_state());self.checkpoint_file()
        for pc in (0x41d73b,*PAUSED_STOPS):
            if pc not in initialized.CHECKPOINTS:
                self.uc.hook_add(UC_HOOK_CODE,self.early.observe_fpu,begin=pc,end=pc)
                initialized.CHECKPOINTS.add(pc)
        try:
            for step in SCHEDULE:
                self.continuous_pcs=set();self.continuous_writes=[];self.continuous_accesses=[]
                before=self.continuous_initial if not self.continuous_cases else self.continuous_cases[-1]['after']
                acquisition=self.acquire_pause_keys(step);fpu_start=len(self.early.fpu_checkpoints)
                cycle=self.cycle_step('pause-key-'+str(step['index']),gameplay=True)
                paused=cycle['round']['continuation']=='pausedRendering'
                rendering=self.render_pause() if paused else None
                stages=[] if paused else [self.run_stage(*s) for s in STAGES]
                output=self.run_output();after=self.component_snapshot(self.full_state())
                self.continuous_cases.append(dict(index=step['index'],before=before,acquisition=acquisition,cycle=cycle,
                    paused=paused,rendering=rendering,stages=stages,output=output,after=after,
                    keyboardAfter=list(self.uc.mem_read(0x455378,300)),fpuStart=fpu_start,fpuEnd=len(self.early.fpu_checkpoints),
                    globalsWrites=self.continuous_writes,stackAccesses=self.continuous_accesses,
                    observedOriginalAddressPCs=sorted(self.continuous_pcs),end=self.position(STOP)))
                self.checkpoint_file()
                print('PAUSE RETURN',step['index'],'paused',paused,'phase',self.u32(0x450b90),
                    'replayTick',self.u32(0x450b8c),'elapsed',self.u32(0x450bbc),flush=True)
        except Exception as error:
            failure=dict(error=repr(error),pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),
                completeReturnedCalls=len(self.continuous_cases),phase=self.phase,helpers=getattr(self,'gameplay_pending',[]),
                sourceStackAccesses=self.continuous_accesses[-30:],sourceGlobalWrites=self.continuous_writes[-30:],
                nativeCompared=False,updatedUTC=datetime.now(timezone.utc).isoformat())
            (ROOT/'build/research'/('paused-gameplay'+suffix+'-failure.json')).write_text(json.dumps(failure,indent=2)+'\n')
            raise
        finally:self.continuous_active=False
        return self.pause_document()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');a=p.parse_args()
    suffix='-control' if a.control else '';name='paused-gameplay'+suffix
    doc=capture_startup(a.control,vm_type=PausedGameplay,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:
            vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=encoded(doc)+b'\n';path=ROOT/'build/original'/(name+'.json');temporary=path.with_suffix('.json.tmp')
    temporary.write_bytes(raw);os.replace(temporary,path)
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),
        parent=doc['parent'],returnedCalls=len(doc['cases']),pausedCalls=sum(c['paused'] for c in doc['cases']),
        components=len(doc['components']),blobs=len(doc['blobs']),fpuCheckpoints=len(doc['fpu']['checkpoints']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
