#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Forty-eight active-key calls after the complete own sixteen-call parent.

The pinned NTSD2.4 EXE/VC80 execute on the retained initialized Unicorn2.1.4
CPU. The complete startup/menu/catalog/launch/neutral parent is reproduced;
only acquired keyboard transitions from live own control bindings are supplied.
Recover movement, attacks, guard/jump, replay packet changes and ordered output
with actual helpers, normal returns and memory/FPU/scratch observations. Full
Object/inline Frame records and weapon-string owners are additionally captured
at new whole-call returns. Unknown AI/object children remain explicit stops,
not no-effect adapters. COM/GDI responses remain declared research boundaries.
Constructor memset uses its existing declared adapter exactly once; its bytes
and ABI are recorded separately, and its hooked thunk is not executed EXE code.
No actual input device, Windows, outer clock pacing, app or full-match claim.
"""
# Post-capture fidelity finding: the actual PE entry loads bundled lib.dll,
# which patches game routines. This producer retains the pristine EXE/VC80
# control domain and its original serialized scope text so source bytes remain
# reproducible. It does not load those patches. See ACTIVE_GAMEPLAY_CAPTURE.md
# and application-initialization-work.json; do not relabel this as the complete
# DLL-enabled application. This comment was added only after both jobs exited0.
import argparse
import copy
import json
import os
from datetime import datetime, timezone
from oracle_continuous_gameplay import ContinuousGameplay, STAGES, encoded, initialized, BODY_SP
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, REGISTERS, digest, capture_startup, transport
from oracle_objects import OBJECT_SIZE
from oracle_state import STOP
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW

BUTTONS=['up','down','left','right','attack','jump','defend']
SEGMENTS=[('approach',16,['left'],['right']),('moving-attacks',8,['left','attack'],['right','attack']),
    ('release',4,[],[]),('guard-and-attack',8,['defend'],['attack']),
    ('jump',4,['jump'],['jump']),('depth-movement',4,['up'],['down']),('release-final',4,[],[])]
SCHEDULE=[dict(index=index+1,segment=label,buttons=[a,b]) for index,(label,a,b) in enumerate(
    (label,a,b) for label,count,a,b in SEGMENTS for _ in range(count))]
EFFECT_STAGES={'control','physics','depth-attachments','contacts','hits-items','cpoint-actions','cpoint-placement','cpoint-cleanup','cpoint-attachments'}


def save_atomic(path,doc,count):
    raw=encoded(doc)+b'\n';tmp=path.with_suffix('.json.tmp');tmp.write_bytes(raw);os.replace(tmp,path)
    proof=dict(bytes=len(raw),sha256=digest(raw),completeReturnedCalls=count,nativeCompared=False,updatedUTC=datetime.now(timezone.utc).isoformat())
    path.with_suffix('.checkpoint.json').write_text(json.dumps(proof,indent=2)+'\n');assert digest(path.read_bytes())==proof['sha256']


class ActiveGameplay(ContinuousGameplay):
    def active_trajectory(self):return getattr(self,'active_gameplay',False)

    def memset(self,uc,pc,size,data):
        observed=self.active_trajectory() and getattr(self,'gameplay_running',False) and self.gameplay_label in {s[0] for s in STAGES}
        if observed:
            sp=uc.reg_read(UC_X86_REG_ESP);destination,value,count=[self.u32(sp+n) for n in (4,8,12)]
            item=dict(kind='memset',entryPC=pc,entrySP=sp,returnPC=self.u32(sp),arguments=[destination,value,count],
                savedBefore=[uc.reg_read(r) for r in REGISTERS],before=self.blob(uc.mem_read(destination,count)))
        super().memset(uc,pc,size,data)
        if observed:
            item.update(returnSP=uc.reg_read(UC_X86_REG_ESP),actualReturnPC=uc.reg_read(UC_X86_REG_EIP),result=uc.reg_read(UC_X86_REG_EAX),
                savedAfter=[uc.reg_read(r) for r in REGISTERS],after=self.blob(uc.mem_read(destination,count)))
            assert item['returnSP']==sp+4 and item['actualReturnPC']==item['returnPC'] and item['result']==destination
            assert item['savedAfter']==item['savedBefore'] and bytes(uc.mem_read(destination,count))==bytes([value&255])*count
            self.active_boundaries.append(item)

    def full_state(self):
        value=super().full_state()
        if self.active_trajectory():
            value['objects']=[dict(address=p,storage=self.record(self.region(p,OBJECT_SIZE))) for p in self.object_addresses]
            pointers=sorted({self.u32(p+o) for p in self.object_addresses for o in (0x98,0x9c,0xa0)}-{0})
            value['objectStrings']=[dict(address=p,storage=self.record(self.region(p,1))) for p in pointers]
        return value

    def checkpoint_file(self):
        suffix='-control' if self.control else ''
        name='active-gameplay'+suffix+('-partial' if self.active_trajectory() else '-parent-partial')+'.json'
        doc=self.active_document() if self.active_trajectory() else super().document()
        save_atomic(ROOT/'build/research'/name,doc,len(self.continuous_cases))

    def effect_context(self,uc,pc,sp):
        return dict(pc=pc,sp=sp,this=uc.reg_read(UC_X86_REG_ECX),registers=[uc.reg_read(r) for r in REGISTERS],
            root3c=self.u32(BODY_SP+0x3c),parents=[{k:h[k] for k in ('entry','entrySP','returnPC','this','arguments')} for h in self.gameplay_pending])

    def gameplay_code(self,uc,pc,size,data):
        if self.active_trajectory() and getattr(self,'gameplay_running',False) and pc==0x4450a0:
            # The inherited constructor memset adapter already ran before this
            # observer. Exclude its thunk from actual instruction coverage, as
            # the accepted controlled lifecycle harness does. Do not run it twice.
            assert self.active_boundaries and self.active_boundaries[-1]['actualReturnPC']==uc.reg_read(UC_X86_REG_EIP)
            assert self.active_boundaries[-1]['returnSP']==uc.reg_read(UC_X86_REG_ESP)
            return
        enabled=self.active_trajectory() and getattr(self,'gameplay_running',False) and self.gameplay_label in EFFECT_STAGES
        if enabled:
            sp=uc.reg_read(UC_X86_REG_ESP)
            while self.active_random and pc==self.active_random[-1]['returnPC']:
                item=self.active_random.pop();assert sp==item['entrySP']+4
                self.active_effects.append(dict(kind='random',arguments=item['arguments']+[uc.reg_read(UC_X86_REG_EAX)],context=item['context']))
            if pc in (0x417170,0x416fb0,0x417090,0x4061d0):
                context=self.effect_context(uc,pc,sp)
                if pc==0x417170:
                    self.active_random.append(dict(entrySP=sp,returnPC=self.u32(sp),arguments=[self.u32(sp+4),self.u32(sp+8)],context=context))
                elif pc in (0x416fb0,0x417090):
                    self.active_effects.append(dict(kind='catalogSound' if pc==0x416fb0 else 'builtinSound',arguments=[self.u32(sp+4),self.u32(sp+8)],context=context))
                else:
                    this=uc.reg_read(UC_X86_REG_ECX);created=[r['address'] for r in self.pool].index(this)
                    self.active_effects.append(dict(kind='reconstruct',arguments=[created],context=context))
            # The accepted control/physics entry observer did not include its
            # enabled sound helpers. Execute their actual instructions, keeping
            # their complete cdecl helper ABI in the same pending/return stack.
            if self.gameplay_label in ('control','physics') and 0x416fb0<=pc<0x417170:
                self.gameplay_instructions.add(pc)
                if pc in (0x416fb0,0x417090):
                    self.gameplay_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),pop=0,
                        this=uc.reg_read(UC_X86_REG_ECX),arguments=[self.u32(sp+4),self.u32(sp+8)],saved=[uc.reg_read(r) for r in REGISTERS]))
                return
        return super().gameplay_code(uc,pc,size,data)

    def run_stage(self,label,start,stop):
        if self.active_trajectory():self.active_effects=[];self.active_random=[];self.active_boundaries=[]
        section=super().run_stage(label,start,stop)
        if self.active_trajectory():
            assert not self.active_random;section['effects']=self.active_effects;section['boundaries']=self.active_boundaries
        return section

    def acquire_active_keys(self,step):
        desired=set();bindings=[]
        for seat,names in enumerate(step['buttons']):
            status=self.u32(0x450b4c+seat*4);assert 1<=status<=4
            config=0x44fb20+status*80;assert self.u32(config)==0
            keys=[self.u32(config+4+4*i) for i in range(7)];assert all(k<300 for k in keys)
            bindings.append(dict(seat=seat,status=status,config=config,device=0,keys=keys))
            desired.update(keys[BUTTONS.index(name)] for name in names)
        changes=[]
        before=bytes(self.uc.mem_read(0x455378,300))
        for key in sorted(self.active_pressed|desired):
            value=100 if key in desired else 117
            if before[key]!=value:
                self.uc.mem_write(0x455378+key,bytes([value]));changes.append(dict(key=key,address=0x455378+key,before=before[key],after=value))
        self.active_pressed=desired
        acquired=bytes(self.uc.mem_read(0x455378,300))
        assert acquired==bytes(100 if n in desired else 117 for n in range(300))
        return dict(plan=step,bindings=bindings,changes=changes,before=list(before),after=list(acquired))

    def active_document(self):
        return transport(dict(format='active-gameplay-components-v1',exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,
            scope=__doc__,control=self.control,parent=self.continuous_parent,worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,
            platform=self.continuous_platform,initial=self.continuous_initial,schedule=SCHEDULE,
            cases=self.continuous_cases,components=self.continuous_components,fpu=copy.deepcopy(self.early.audit())),{**self.early.blobs,**self.blobs})

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('continuous-gameplay'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert report['nativeCompared'] and len(raw)==report['bytes'] and digest(raw)==report['sha256']
        assert json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        print('Entire accepted CONTINUOUS_GAMEPLAY parent reproduced; beginning48 active-key calls',flush=True)
        self.active_gameplay=True;self.continuous_active=True
        self.continuous_components={};self.continuous_cases=[];self.active_pressed=set()
        self.continuous_parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        self.continuous_initial=self.component_snapshot(self.full_state());self.checkpoint_file()
        prefix_path=ROOT/'build/research/active-gameplay-attempt2'/('active-gameplay'+suffix+'-partial.json')
        prefix=json.loads(prefix_path.read_bytes()) if prefix_path.exists() else None
        if prefix:
            proof=json.loads(prefix_path.with_suffix('.checkpoint.json').read_bytes())
            assert digest(prefix_path.read_bytes())==proof['sha256'] and proof['completeReturnedCalls']==16
            assert self.continuous_initial==prefix['initial']
        try:
            for step in SCHEDULE:
                self.continuous_pcs=set();self.continuous_writes=[];self.continuous_accesses=[]
                before=self.continuous_initial if not self.continuous_cases else self.continuous_cases[-1]['after']
                fpu_start=len(self.early.fpu_checkpoints);acquisition=self.acquire_active_keys(step)
                # No original instruction runs during this acquisition. Retain
                # the complete last heap/Object records while replacing the
                # freshly observed globals/pool/resource snapshot fields.
                acquired={**before,**self.launch_state()}
                cycle=self.cycle_step('active-'+str(step['index']).zfill(2),gameplay=True)
                assert cycle['stimulus']==[] and not cycle['local']['dispatch']
                stages=[self.run_stage(*stage) for stage in STAGES];output=self.run_output()
                after=self.component_snapshot(self.full_state())
                case=dict(index=step['index'],before=before,acquired=acquired,acquisition=acquisition,cycle=cycle,stages=stages,output=output,after=after,
                    keyboardBefore=acquisition['after'],keyboardAfter=list(self.uc.mem_read(0x455378,300)),
                    fpuStart=fpu_start,fpuEnd=len(self.early.fpu_checkpoints),globalsWrites=self.continuous_writes,
                    stackAccesses=self.continuous_accesses,observedOriginalAddressPCs=sorted(self.continuous_pcs),end=self.position(STOP))
                # Persist every actual whole return before verification, so a
                # comparison failure retains its complete observed state too.
                self.continuous_cases.append(case);self.checkpoint_file()
                if prefix and step['index']<=len(prefix['cases']):
                    prior=copy.deepcopy(case)
                    for section in prior['stages']:assert section.pop('boundaries')==[]
                    # Live undefined-read entries are tuples; JSON decodes
                    # arrays as lists. Compare the exact canonical transport
                    # bytes, preserving every value and ordering constraint.
                    assert encoded(prior)==encoded(prefix['cases'][step['index']-1]),'Retained whole active prefix changed'
                print('ACTIVE RETURN',step['index'],step['segment'],'phase',self.u32(0x450b90),'tick',self.u32(0x450b8c),
                    'recording',self.u32(0x450b80),'actors',[(self.u32(r['address']+0x70),self.u32(r['address']+0x2fc)) for r in self.pool[:2]],
                    'CW',hex(self.uc.reg_read(UC_X86_REG_FPCW)),flush=True)
        except Exception as error:
            failure=dict(error=repr(error),pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP),
                completedReturnedCalls=len(self.continuous_cases),plan=step,phase=self.phase,helpers=getattr(self,'gameplay_pending',[]),
                effects=getattr(self,'active_effects',[]),sourceStackAccesses=self.continuous_accesses[-30:],sourceGlobalWrites=self.continuous_writes[-30:],
                boundaries=getattr(self,'active_boundaries',[]),
                updatedUTC=datetime.now(timezone.utc).isoformat(),nativeCompared=False)
            (ROOT/'build/research'/('active-gameplay'+suffix+'-failure.json')).write_text(json.dumps(failure,indent=2)+'\n');raise
        finally:self.active_gameplay=False;self.continuous_active=False
        return self.active_document()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else '';name='active-gameplay'+suffix
    doc=capture_startup(args.control,vm_type=ActiveGameplay,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=encoded(doc)+b'\n';path=ROOT/'build/original'/(name+'.json');path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),
        parent=doc['parent'],returnedCalls=len(doc['cases']),components=len(doc['components']),blobs=len(doc['blobs']),
        fpuCheckpoints=len(doc['fpu']['checkpoints']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
