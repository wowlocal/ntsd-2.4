#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Audit actual rootSP+64 accesses on an unchanged initialized gameplay chain.

Retain the complete pinned GAMEPLAY_NOTICES result. No stack word is supplied
or rewritten. This proves only the selected own path, not all caller branches.
"""
import argparse
import json
from oracle_gameplay_notices import GameplayNotices, initialized, capture_startup, ROOT, digest
from unicorn import UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_ESP

BODY_SP, WORD = 0x1000e9bc, 0x1000ea20


class ResultStack(GameplayNotices):
    instances=[]
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        self.result_stack_accesses=[]
        self.uc.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,self.result_stack_access,begin=WORD,end=WORD+3)
        self.instances.append(self)

    def result_stack_access(self,uc,access,address,size,value,data):
        self.result_stack_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),sp=uc.reg_read(UC_X86_REG_ESP),
            address=address,size=size,write=access==UC_MEM_WRITE,beforeWord=self.u32(WORD),
            reportedValue=value if access==UC_MEM_WRITE else None,phase=getattr(self,'phase',None)))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');args=parser.parse_args()
    suffix='-control' if args.control else ''
    doc=capture_startup(args.control,vm_type=ResultStack,early_type=initialized.InitializedEarlyMenus,
        after=lambda vm,parent:vm.capture_screen(parent,after_first=lambda vm,first:vm.capture_return(first,
            after_cycle=lambda vm,cycle:vm.capture_character(cycle))))
    evidence=json.loads((ROOT/'docs/evidence'/('gameplay-notices'+suffix+'.json')).read_bytes())
    raw=(ROOT/'build/original'/evidence['corpus']).read_bytes()
    assert len(raw)==evidence['bytes'] and digest(raw)==evidence['sha256']
    assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/evidence['fixture']).read_bytes())==evidence['fixtureSHA256']
    assert json.loads(json.dumps(doc))==json.loads(raw),'Complete pinned own parent changed'
    vm=ResultStack.instances[-1];events=vm.result_stack_accesses
    starts=[i for i,e in enumerate(events) if e['pc']==0x41d7d7 and e['sp']==BODY_SP and e['write']]
    assert starts,'Own round producer did not execute'
    own=events[starts[-1]:]
    report=dict(scope=__doc__,control=args.control,parent=evidence['fixture'],parentSHA256=evidence['fixtureSHA256'],
        completeParentReproduced=True,bodySP=BODY_SP,address=WORD,allAccesses=events,fromLastRoundInitialization=own,
        finalWord=vm.u32(WORD),end=dict(pc=vm.uc.reg_read(UC_X86_REG_EIP),sp=vm.uc.reg_read(UC_X86_REG_ESP)))
    path=ROOT/'build/research'/('result-stack'+suffix+'.json');path.write_text(json.dumps(report,indent=2)+'\n')
    print('RESULT STACK',len(events),'total accesses;',len(own),'since last round initialization;',
          sum(e['write'] for e in own),'writes; final',report['finalWord'],'end',report['end'],flush=True)


if __name__=='__main__':main()
