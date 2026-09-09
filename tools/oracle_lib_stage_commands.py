#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole library-enabled4214d5..421a15 commands on declared game storage.

Execute the actual bundled DLL installer with declared relocation/OS responses,
then the installed command3 hook and all original command/recovery/cleanup
instructions, constructors, RNG, conversions and music helper. Inputs retain
the established four-Object/400-Actor/BG boundary and explicitCW027f. The extra
459ff8 word is supplied here; the separate whole preparation study produces it.
No natural initialized match, Windows device, or whole-library equivalence.
"""
import itertools,json,struct
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_postdraw_commands import PostDrawCommands,probes,case,IDS,STATES,HEADERS,BACKGROUNDS,HEADER,d,b
from oracle_world_control import BODY_SP
from lib_runtime_loader import install_library,BASE
from oracle_lib_initialization import LIB_SHA256,digest
from unicorn import UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP

class LibStageCommands(PostDrawCommands):
    def __init__(self):
        super().__init__();self.installation=install_library(self.uc);self.requested_accesses=[]
        self.uc.hook_add(UC_HOOK_MEM_READ,self.requested_access,begin=0x459ff8,end=0x459ffb)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.requested_access,begin=0x459ff8,end=0x459ffb)
    def requested_access(self,u,access,address,size,value,data):
        if self.running:self.requested_accesses.append(dict(pc=u.reg_read(UC_X86_REG_EIP),access=access,address=address,size=size,value=self.u32(address)))
    def code(self,u,pc,size,data):
        if self.running and BASE+0x1a9a<=pc<=BASE+0x1b15:self.instructions.add(pc);return
        return super().code(u,pc,size,data)
    def execute(self):
        self.requested_accesses=[];self.uc.mem_write(0x459ff8,struct.pack('<i',self.item.get('requestedID',0)))
        super().execute()
        assert self.u32(0x459ff8)==(self.item.get('requestedID',0)&0xffffffff)
    def probe(self,item,index):
        result=super().probe(item,index);result.update(requestedID=item.get('requestedID',0),requestedReads=self.requested_accesses)
        return result

def additional():
    patterns=[(100,122,123,300),(122,122,122,122),(-1,-1,-2**31,2**31-1),(0,0,1,200)]
    for requested,count,ids in itertools.product((-2**31,-1,0,1,100,122,123,199,200,300,2**31-1),(-1,0,1,2,3,4),patterns):
        yield case('library-selection',(requested,count,*ids),requestedID=requested,count=count,headers=[[i,*d(0x6f4,n)] for i,n in enumerate(ids)],globals=[d(0x450bb8,3)])
    for free_count,retained,alias,sse2,requested in itertools.product((0,1,2,4),(0,77,399),(0,1,2),(0,1),(122,300)):
        free=list(range(50,50+free_count));active=[[0,255]]+[[i,1] for i in range(50,400) if i not in free]
        yield case('library-pool',(free_count,retained,alias,sse2,requested),requestedID=requested,retained=retained,active=active,sse2=sse2,
            aliases=[[50,0]] if alias==1 else [[51,50]] if alias==2 else [],headers=[[i,*d(0x6f4,requested)] for i in range(4)],
            actors=[[0,[b(0xf0+50,17),b(0xf0+51,31)]],[399,[b(0xf0+50,27)]]],globals=[d(0x450bb8,3),d(0x450bcc,2999),d(0x450c34,1233)])
    for command,requested,seed in itertools.product((1,2,3,0,-1,0x12345603),(0,122),(0,1)):
        yield case('library-command-gate',(command,requested,seed),requestedID=requested,globals=[d(0x450bb8,command),d(0x450c34,seed)])

def main():
    vm=LibStageCommands();cases=[]
    for i,item in enumerate(itertools.chain(probes(),additional())):
        cases.append(vm.probe(item,i))
        if (i+1)%500==0:print('LIB COMMANDS',i+1,flush=True)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,installation=vm.installation,fpcw=0x27f,header=HEADER,headerPatches=HEADERS,ids=IDS,states=STATES,backgrounds=BACKGROUNDS,cases=cases,instructions=sorted(vm.instructions),nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();p=ROOT/'build/original/lib-stage-commands.json';assert not p.exists();p.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=p.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),events=sum(len(c['events']) for c in cases),requestedReads=sum(len(c['requestedReads']) for c in cases),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-stage-commands.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
