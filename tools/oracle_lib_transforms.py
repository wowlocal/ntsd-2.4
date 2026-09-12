#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole library-enabled slot prefix and observed Actor+7b4 writes.

The pinned bundled DLL executes its actual installer in a development-only
Unicorn VM. Whole41f550..41fb0b includes original transformation, particles,
resources and scheduler children; only established platform/memset boundaries
remain supplied. The controlled Actor pool has500hex spacing, not a recovered
Windows heap layout. Its7b4 write can affect the next owned Actor's2b4 word;
the last Actor targets separately declared research backing beyond the pool.
Capture those actual writes and complete state without extending Actor size or
substituting expected state. This is not native or Windows equivalence by itself.
"""
import itertools,json,struct
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_postdraw_slot_prefix import PostDrawSlotPrefix,probes,case,IDS,STATES,HEADERS,HEADER,d,b
from oracle_world_control import POOL,WORLD,BODY_SP
from lib_runtime_loader import install_library,BASE
from oracle_lib_initialization import LIB_SHA256,digest
from unicorn import UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EDX,UC_X86_REG_EIP

class LibTransforms(PostDrawSlotPrefix):
    def __init__(self):
        super().__init__();self.installation=install_library(self.uc);self.extended_writes=[]
    def code(self,u,pc,size,data):
        if self.running and BASE+0x109d<=pc<=BASE+0x111f:self.instructions.add(pc);return
        super().code(u,pc,size,data)
    def access(self,u,access,address,size,value,data):
        if self.running and access==UC_MEM_WRITE and u.reg_read(UC_X86_REG_EIP)==BASE+0x1112:
            actor=u.reg_read(UC_X86_REG_EDX);assert address==actor+0x7b4 and size==4
            index,offset=divmod(actor-POOL,0x500);assert 0<=index<400 and offset==0
            self.extended_writes.append(dict(pc=BASE+0x1112,actor=index,address=address,before=bytes(u.mem_read(address,4)).hex(),value=value&0xffffffff))
        super().access(u,access,address,size,value,data)
    def execute(self):
        self.extended_writes=[];self.uc.mem_write(POOL+400*0x500,b'\xa5'*0x1000)
        super().execute()
    def probe(self,item,index):
        result=super().probe(item,index);tail=bytes(self.uc.mem_read(POOL+400*0x500,0x1000))
        rebuilt=bytearray(b'\xa5'*0x1000)
        for w in self.extended_writes:
            if w['actor']==399:rebuilt[0x2b4:0x2b8]=w['value'].to_bytes(4,'little')
        assert tail==rebuilt
        result.update(extendedWrites=self.extended_writes,tailSHA256=digest(tail));return result

def additional():
    for state,kind,count,freeze,slot in itertools.product((3999,4000,4002,4050,4217,4218,4998,4999,5000,7999,8000,8999,9000),(-1,0,3),(-1,0,1,2,4),(0,1),(0,399)):
        yield case('library-transform',(state,kind,count,freeze,slot),slot=slot,count=count,actor=[d(0x70,307),d(0xb4,freeze),d(0x318,123)],headers=[[0,*d(0x6f8,kind)]],frames=[[0,307,*d(8,state)]])
    for state in (4000,4002,4050,4217,4218,4998):
        yield case('library-duplicate',(state,),actor=[d(0x70,307)],headers=[[i,*d(0x6f4,state-4000)] for i in range(4)],frames=[[0,307,*d(8,state)]])
    yield case('library-after-9995',(0,),actor=[d(0x70,300)],frames=[[1,0,*d(8,4002)]])
    for next_state in (9996,14,1700,4002):
        yield case('library-retained-frame',(next_state,),actor=[d(0x70,307),d(0x88,1)],frames=[[0,307,*d(8,4050)],[1,307,*d(8,next_state)]])

def main():
    vm=LibTransforms();cases=[]
    for i,item in enumerate(itertools.chain(probes(),additional())):
        cases.append(vm.probe(item,i))
        if (i+1)%500==0:print('LIB TRANSFORMS',i+1,flush=True)
    doc=dict(exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,scope=__doc__,installation=vm.installation,fpcw=0x27f,header=HEADER,headerPatches=HEADERS,ids=IDS,states=STATES,cases=cases,instructions=sorted(vm.instructions),poolAddress=POOL,actorStride=0x500,actorSize=0x420,tailInitial='a5',tailCount=0x1000,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();p=ROOT/'build/original/lib-transforms.json';assert not p.exists();p.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,scope=__doc__,corpus=p.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),helpers=sum(c['helpers'] for c in cases),events=sum(len(c['events']) for c in cases),extendedWrites=sum(len(c['extendedWrites']) for c in cases),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-transforms.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
