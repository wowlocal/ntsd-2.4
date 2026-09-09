#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Sixteen successive own initialized match/dispatcher calls with neutral keys.

Pinned original EXE/VC80 on the same Unicorn2.1.4 CPU as the complete accepted
startup/menu/catalog/selection/first-return parent. Retain game allocations,
World/Actor aliases, RNG, replay memory, source CPU and enabled sound. The own
300 keyboard bytes remain117 from the original launch reset; no gameplay flags
or unknown stack words are supplied. Only the established outer caller ABI and
COM/GDI responses are declared. Read/write/FPU/return observations recover
cross-call update order, scratch lifetimes and ownership. Newly reached AI or
object-input children stop before their old controlled no-effect adapters.
No Windows/device/latency, outer43e9a0-loop or full-match claim.
"""
import argparse
import copy
import json
import os
from collections import Counter
from datetime import datetime, timezone
from oracle_gameplay_return import GameplayReturn, initialized, FRAME_KINDS, BODY_SP
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_front_menu_resources import GLOBAL, GLOBAL_SIZE, ENTRY_SP
from oracle_gameplay_lifecycle import SCRATCH
from oracle_state import STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

STAGES=[('control',0x41e339,0x41e634),('physics',0x41e634,0x41eed1),
    ('depth-attachments',0x41eed1,0x41eed8),('contacts',0x41eed8,0x41eefb),('hits-items',0x41eefb,0x41f2ac),
    ('cpoint-actions',0x41f2ac,0x41f2b3),('cpoint-placement',0x41f2b3,0x41f2b8),
    ('cpoint-cleanup',0x41f2b8,0x41f47d),('cpoint-attachments',0x41f47d,0x41f484),
    ('camera-background',0x41f484,0x41f496),('world-drawing',0x41f496,0x41f4ac),
    ('post-draw-impulses',0x41f4ac,0x41f550),('post-draw-lifecycle',0x41f550,0x4214d5),
    ('post-draw-commands',0x4214d5,0x421a15),('world-hud',0x421a15,0x421a2d),
    ('post-hud-notices',0x421a2d,0x421cdc),('result-recording',0x421cdc,0x422944),
    ('result-layout',0x422944,0x422994)]


def encoded(value):return json.dumps(value,separators=(',',':'),sort_keys=True).encode()


class ContinuousGameplay(GameplayReturn):
    def continuous(self):return getattr(self,'continuous_active',False)

    def input_checkpoint(self,uc,pc,size,data):
        if self.continuous() and self.input_running and pc in (0x4094b0,0x406ba0):
            raise AssertionError(('Unrecovered actual own input child; adapter not invoked',hex(pc),hex(self.u32(uc.reg_read(UC_X86_REG_ESP)))))
        return super().input_checkpoint(uc,pc,size,data)

    def component_snapshot(self,value):
        result={}
        for name,item in value.items():
            key=digest(encoded(item))
            if key not in self.continuous_components:self.continuous_components[key]=item
            result[name]=key
        return result

    def launch_state(self):
        value=super().launch_state()
        if not self.continuous():return value
        value['menuBitmaps']=[dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
        return self.component_snapshot(value)

    def full_state(self):
        value=super().launch_state()
        value['frameHeap']=[dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size'])))
            for a in self.allocations if a['caller'] in FRAME_KINDS]
        value['menuBitmaps']=[dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
        return value

    def continuous_code(self,uc,pc,size,data):
        if not self.continuous():return
        # This observer runs after the inherited execution/stop/API hooks.
        # Keep the inventory labelled as observed addresses; helper-boundary
        # adapters at an original address are not per-instruction CPU evidence.
        if 0x400000<=pc<0x500000 or 0x78130000<=pc<0x78230000:self.continuous_pcs.add(pc)

    def continuous_global(self,uc,access,address,size,value,data):
        if not self.continuous():return
        assert size in (1,2,4,8)
        self.continuous_writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=address,size=size,
            value=value&((1<<(size*8))-1)))

    def continuous_stack(self,uc,access,address,size,value,data):
        if not self.continuous():return
        self.continuous_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),sp=uc.reg_read(UC_X86_REG_ESP),
            address=address,size=size,write=access==UC_MEM_WRITE,phase=self.phase,
            bytesBefore=bytes(uc.mem_read(address,size)).hex(),reportedValue=value if access==UC_MEM_WRITE else None))

    def run_stage(self,label,start,stop):
        self.camera_events=[];self.camera_fill_inputs=[];self.camera_clip=None;self.camera_bitmap=None;self.camera_blits=0
        self.drawing_events=[];self.drawing_fill_inputs=[];self.drawing_clip=None;self.drawing_bitmap=None;self.drawing_blits=0
        self.impulses_events=[];self.lifecycle_events=[];self.lifecycle_scratch_accesses=[]
        self.commands_events=[];self.commands_scratch_accesses=[];self.hud_argument_accesses=[]
        self.notice_accesses=[];self.notice_written=bytearray(0x158);self.notice_fill_inputs=[];self.layout_accesses=[]
        self.camera_target=self.u32(BODY_SP+0x68)
        self.drawing_target=self.u32(0x455608) if label=='world-hud' else self.u32(BODY_SP+0x68)
        self.hud_argument=self.u32(BODY_SP+0x68)
        gdi=self.early.gdi
        gdi.presentation_input=copy.deepcopy(self.continuous_output_input)
        gdi.presentation_events=self.impulses_events if label=='post-draw-impulses' else self.drawing_events
        scratch=[self.u32(BODY_SP+offset) for offset in SCRATCH]
        stage_word=self.u32(BODY_SP+0x64);spawn=self.u32(BODY_SP+0x34)
        fp_before=[self.uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)]
        section=self.gameplay_step(label,start,stop)
        event_lists=dict(camera=self.camera_events,drawing=self.drawing_events,impulses=self.impulses_events,
            lifecycle=self.lifecycle_events,commands=self.commands_events)
        section['events']={key:events for key,events in event_lists.items() if events}
        section['boundary']=dict(fpuBefore=fp_before,
            fpuAfter=[self.uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)],
            stageDefeatedBefore=stage_word,stageDefeatedAfter=self.u32(BODY_SP+0x64),
            scratchBefore=scratch,scratchAfter=[self.u32(BODY_SP+offset) for offset in SCRATCH],
            spawnBefore=spawn,spawnAfter=self.u32(BODY_SP+0x34),indicatorTarget=self.u32(BODY_SP+0x68),
            cameraFillInputs=self.camera_fill_inputs,noticeFillInputs=self.notice_fill_inputs)
        return section

    def run_output(self):
        before=self.launch_state();self.drawing_events=[];self.drawing_bitmap=None;self.drawing_clip=None;self.drawing_blits=0
        self.output_text=0x450c38;self.output_writes=[];self.output_returns=[]
        self.early.gdi.presentation_input=copy.deepcopy(self.continuous_output_input)
        self.early.gdi.presentation_events=self.drawing_events
        self.gameplay_label='gameplay-return';self.gameplay_stop=STOP;self.gameplay_finished=False;self.gameplay_pending=[]
        self.gameplay_helpers=[];self.gameplay_checkpoints=[];self.gameplay_instructions=set()
        previous_reads=self.reads_before_writes;assert not previous_reads;self.reads_before_writes=set()
        self.phase='gameplay-return';self.gameplay_running=True
        try:
            self.uc.emu_start(0x422994,0,count=2_000_000)
            assert self.gameplay_finished and self.uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP+8
            outer=self.own_entry_observations[0]
            assert [self.uc.reg_read(r) for r in REGISTERS]==outer['saved'] and self.u32(0)==outer['seh']
        finally:
            reads=sorted(self.reads_before_writes);self.reads_before_writes=previous_reads;self.gameplay_running=False
        return dict(label='gameplay-return',before=before,after=self.launch_state(),helpers=self.gameplay_helpers,
            checkpoints=[],instructions=sorted(self.gameplay_instructions),readsBeforeWrites=reads,end=self.position(STOP),
            events=self.drawing_events,writes=self.output_writes,entryObservations=self.own_entry_observations,returnObservations=self.output_returns)

    def document(self):
        # Component manifests deduplicate complete arrays, without dropping
        # any record, byte/mask reference or unchanged ownership entry.
        return transport(dict(format='continuous-gameplay-components-v1',exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,
            scope=__doc__,control=self.control,parent=self.continuous_parent,worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,
            platform=self.continuous_platform,initial=self.continuous_initial,
            cases=self.continuous_cases,components=self.continuous_components,fpu=copy.deepcopy(self.early.audit())),
            {**self.early.blobs,**self.blobs})

    def checkpoint_file(self):
        raw=encoded(self.document())+b'\n';path=ROOT/'build/research'/('continuous-gameplay'+('-control' if self.control else '')+'-partial.json')
        temporary=path.with_suffix('.json.tmp');temporary.write_bytes(raw);os.replace(temporary,path)
        proof=dict(bytes=len(raw),sha256=digest(raw),completeReturnedCalls=len(self.continuous_cases),
            nativeCompared=False,updatedUTC=datetime.now(timezone.utc).isoformat())
        path.with_suffix('.checkpoint.json').write_text(json.dumps(proof,indent=2)+'\n')
        assert digest(path.read_bytes())==proof['sha256']

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('gameplay-return'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert report['nativeCompared'] and len(raw)==report['bytes'] and digest(raw)==report['sha256']
        assert json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        assert self.position(STOP)==dict(pc=STOP,sp=ENTRY_SP+8)
        assert self.full_state()==old['cases'][0]['after']
        print('Entire accepted GAMEPLAY_RETURN reproduced; continuing sixteen actual calls without game-state injection',flush=True)
        self.continuous_components={};self.continuous_cases=[]
        self.continuous_parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        self.continuous_output_input=copy.deepcopy(old['cases'][0]['gameplayReturn']['input'])
        self.continuous_platform={k:old['cases'][0]['gameplayReturn'][k] for k in ('input','methodBindings','loadedSoundBuffers','resourceSurfaces','drawResults')}
        self.continuous_initial=self.component_snapshot(self.full_state())
        self.continuous_active=True
        self.uc.hook_add(UC_HOOK_CODE,self.continuous_code)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.continuous_global,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        for lo,hi in ((0x34,0x74),(0x44c,0x5c4)):
            self.uc.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,self.continuous_stack,begin=BODY_SP+lo,end=BODY_SP+hi-1)
        self.continuous_pcs=set();self.continuous_writes=[];self.continuous_accesses=[]
        self.checkpoint_file()
        try:
            for index in range(16):
                self.continuous_pcs=set();self.continuous_writes=[];self.continuous_accesses=[]
                keys=bytes(self.uc.mem_read(0x455378,300));assert keys==b'u'*300
                before=self.continuous_initial if not self.continuous_cases else self.continuous_cases[-1]['after']
                fpu_start=len(self.early.fpu_checkpoints)
                cycle=self.cycle_step(f'neutral-{index+1:02d}',gameplay=True)
                assert cycle['stimulus']==[] and not cycle['local']['dispatch']
                stages=[self.run_stage(*stage) for stage in STAGES]
                output=self.run_output();after=self.component_snapshot(self.full_state())
                case=dict(index=index+1,before=before,cycle=cycle,stages=stages,output=output,after=after,
                    keyboardBefore=list(keys),keyboardAfter=list(self.uc.mem_read(0x455378,300)),
                    fpuStart=fpu_start,fpuEnd=len(self.early.fpu_checkpoints),
                    globalsWrites=self.continuous_writes,stackAccesses=self.continuous_accesses,
                    observedOriginalAddressPCs=sorted(self.continuous_pcs),end=self.position(STOP))
                self.continuous_cases.append(case);self.checkpoint_file()
                print('CONTINUOUS RETURN',index+1,'phase',self.u32(0x450b90),'tick',self.u32(0x450b80),
                    'stages',len(stages),'output events',len(output['events']),'CW',hex(self.uc.reg_read(UC_X86_REG_FPCW)),flush=True)
        except Exception as error:
            failure=dict(error=repr(error),pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),
                completeReturnedCalls=len(self.continuous_cases),phase=self.phase,helpers=getattr(self,'gameplay_pending',[]),
                sourceStackAccesses=self.continuous_accesses[-30:],sourceGlobalWrites=self.continuous_writes[-30:],
                updatedUTC=datetime.now(timezone.utc).isoformat(),nativeCompared=False)
            (ROOT/'build/research'/('continuous-gameplay'+suffix+'-failure.json')).write_text(json.dumps(failure,indent=2)+'\n')
            raise
        finally:self.continuous_active=False
        return self.document()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else '';name='continuous-gameplay'+suffix
    doc=capture_startup(args.control,vm_type=ContinuousGameplay,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:
            vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=encoded(doc)+b'\n';path=ROOT/'build/original'/(name+'.json');path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),
        parent=doc['parent'],returnedCalls=len(doc['cases']),components=len(doc['components']),blobs=len(doc['blobs']),
        fpuCheckpoints=len(doc['fpu']['checkpoints']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
