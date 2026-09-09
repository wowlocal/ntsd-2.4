#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh initialized GAMEPLAY_NOTICES -> whole result-recording caller.

No result flags, recording bytes or stack values are injected. Audit rootSP64
from its actual round initialization on both paths. Enabled controlled writer
branches have separate whole-caller evidence; this capture follows own flags.
No returned tick, app-window, Windows or device claim.
"""
import argparse
import json
from oracle_result_stack import ResultStack, BODY_SP, WORD
from oracle_gameplay_notices import initialized, FRAME_KINDS
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, digest, capture_startup, transport
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

START, END = 0x421cdc, 0x422944


class GameplayResultRecording(ResultStack):
    def result_active(self):
        return getattr(self,'gameplay_running',False) and self.gameplay_label=='result-recording'

    def imported(self,uc,pc,size,data):
        if not self.result_active():return super().imported(uc,pc,size,data)
        raise AssertionError(('Unexpected own result import',hex(pc)))

    def checkpoint(self,uc,pc,size,data):
        if not self.result_active():return super().checkpoint(uc,pc,size,data)

    def gameplay_code(self,uc,pc,size,data):
        if not self.result_active():return super().gameplay_code(uc,pc,size,data)
        self.gameplay_instructions.add(pc)
        if pc==self.gameplay_stop:
            assert not self.gameplay_pending
            self.gameplay_finished=True;uc.emu_stop();return
        assert START<=pc<0x422218,('Own result reached an unbound helper/continuation',hex(pc))

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('gameplay-notices'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_NOTICES reproduced; continuing own result recording',flush=True)
        assert self.body_sp==BODY_SP
        starts=[i for i,e in enumerate(self.result_stack_accesses) if e['pc']==0x41d7d7 and e['sp']==BODY_SP and e['write']]
        assert starts
        audit_start=starts[-1]
        before_word=self.u32(WORD)
        def heap():return [dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu():return [dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
        before_heap,before_menu=heap(),menu()
        cw,sw,tag=[self.uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)]
        self.uc.hook_add(UC_HOOK_CODE,self.early.observe_fpu,begin=START,end=START);initialized.CHECKPOINTS.add(START)
        section=self.gameplay_step('result-recording',START,END)
        section['before'].update(frameHeap=before_heap,menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(),menuBitmaps=menu())
        section['resultRecording']=dict(stageDefeatedBefore=before_word,stageDefeatedAfter=self.u32(WORD),
            allStackAccesses=self.result_stack_accesses,fromLastRoundInitialization=self.result_stack_accesses[audit_start:],
            fpcw=cw,fpswBefore=sw,fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW),
            fptagBefore=tag,fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG))
        assert cw==self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and not self.early.fpu_pending
        return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
            parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),fpu=self.early.audit(),worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else ''
    doc=capture_startup(args.control,vm_type=GameplayResultRecording,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:
            vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/('gameplay-result-recording'+suffix+'.json');path.write_bytes(raw)
    c=doc['cases'][0]
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],
        helpers=len(c['helpers']),instructions=len(c['instructions']),end=c['end'],readsBeforeWrites=c['readsBeforeWrites'],
        stackAccesses=c['resultRecording']['fromLastRoundInitialization'],fpuCheckpoints=len(doc['fpu']['checkpoints']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
