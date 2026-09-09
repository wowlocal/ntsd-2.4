#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh initialized result-recording parent -> whole result-layout continuation.

The original recorder chose422944. Continue from that own state without flags,
stack words or recording injection. Trace actual access to the retained target
and formatting region; unavailable native backing must remain unavailable when
unused. Pinned EXE/VC80 research on one emulated CPU, not a returned tick, real
platform drawing, device output or Windows execution.
"""
import argparse
import json
from oracle_gameplay_result_recording import GameplayResultRecording, initialized, FRAME_KINDS, BODY_SP, WORD
from oracle_gameplay_entry import ROOT, EXE_SHA256, DLL_SHA256, WORLD, digest, capture_startup, transport
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

START, END = 0x422944, 0x422994


class GameplayResultLayout(GameplayResultRecording):
    def layout_active(self):return getattr(self,'gameplay_running',False) and self.gameplay_label=='result-layout'

    def imported(self,uc,pc,size,data):
        if not self.layout_active():return super().imported(uc,pc,size,data)
        raise AssertionError(('Unexpected own layout import',hex(pc)))

    def checkpoint(self,uc,pc,size,data):
        if not self.layout_active():return super().checkpoint(uc,pc,size,data)

    def gameplay_code(self,uc,pc,size,data):
        if not self.layout_active():return super().gameplay_code(uc,pc,size,data)
        self.gameplay_instructions.add(pc)
        if pc==self.gameplay_stop:
            assert not self.gameplay_pending
            self.gameplay_finished=True;uc.emu_stop();return
        assert START<=pc<END,('Own layout reached an unbound helper',hex(pc))

    def layout_access(self,uc,access,p,size,value,data):
        if self.layout_active():self.layout_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),offset=p-BODY_SP,size=size,write=access==UC_MEM_WRITE))

    def capture_character(self,parent):
        old=super().capture_character(parent);suffix='-control' if self.control else ''
        report=json.loads((ROOT/'docs/evidence'/('gameplay-result-recording'+suffix+'.json')).read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and json.loads(raw)==json.loads(json.dumps(old))
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes())==report['fixtureSHA256']
        print('Entire pinned GAMEPLAY_RESULT_RECORDING reproduced; continuing own result layout',flush=True)
        assert self.body_sp==BODY_SP
        def heap():return [dict(address=a['address'],kind=FRAME_KINDS[a['caller']],storage=self.record(self.region(a['address'],a['size']))) for a in self.allocations if a['caller'] in FRAME_KINDS]
        def menu():return [dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps]
        before_heap,before_menu=heap(),menu();before_word=self.u32(WORD)
        cw,sw,tag=[self.uc.reg_read(r) for r in (UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG)]
        self.layout_accesses=[]
        self.uc.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,self.layout_access,begin=BODY_SP+0x34,end=BODY_SP+0x6b)
        self.uc.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,self.layout_access,begin=BODY_SP+0x44c,end=BODY_SP+0x5c3)
        self.uc.hook_add(UC_HOOK_CODE,self.early.observe_fpu,begin=START,end=START);initialized.CHECKPOINTS.add(START)
        section=self.gameplay_step('result-layout',START,END)
        section['before'].update(frameHeap=before_heap,menuBitmaps=before_menu)
        section['after'].update(frameHeap=heap(),menuBitmaps=menu())
        section['resultLayout']=dict(continuation=START,stageDefeatedBefore=before_word,stageDefeatedAfter=self.u32(WORD),
            localAccesses=self.layout_accesses,fpcw=cw,fpswBefore=sw,fpswAfter=self.uc.reg_read(UC_X86_REG_FPSW),
            fptagBefore=tag,fptagAfter=self.uc.reg_read(UC_X86_REG_FPTAG))
        assert cw==self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and not self.early.fpu_pending
        return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
            parent=dict(fixture=report['fixture'],sha256=report['fixtureSHA256']),fpu=self.early.audit(),worldAddress=WORLD,
            actorAddresses=[r['address'] for r in self.pool],objectAddresses=self.object_addresses,cases=[section]),{**self.early.blobs,**self.blobs})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else ''
    doc=capture_startup(args.control,vm_type=GameplayResultLayout,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:
            vm.capture_return(first,after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/('gameplay-result-layout'+suffix+'.json');path.write_bytes(raw)
    c=doc['cases'][0]
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),parent=doc['parent'],
        helpers=len(c['helpers']),instructions=len(c['instructions']),end=c['end'],readsBeforeWrites=c['readsBeforeWrites'],
        localAccesses=c['resultLayout']['localAccesses'],fpuCheckpoints=len(doc['fpu']['checkpoints']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/path.name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
