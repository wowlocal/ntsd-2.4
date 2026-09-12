#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Additional whole library-transform aliases and actual unmapped-write stops.

The controlled allocation layout is explicit research input, not Windows heap
provenance. Exercise live aliased Actor ownership and later particle construction
without injecting expected bytes. Separate source-fault trials leave the page
beyond the last recovered Actor allocation unmapped, observe the real DLL7b4
write failure and retain prior Object mutation. No host process or original
file is modified. Faults are not successful returns or native equivalence.
"""
import itertools,json,struct
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_lib_transforms import LibTransforms,case,IDS,STATES,HEADERS,HEADER,d,b,POOL,WORLD,BODY_SP,BASE,LIB_SHA256,digest
from oracle_postdraw_slot_prefix import PostDrawSlotPrefix
from unicorn import UC_HOOK_MEM_WRITE_UNMAPPED,UC_MEM_WRITE,UcError,UC_ERR_WRITE_UNMAPPED
from unicorn.x86_const import UC_X86_REG_EIP,UC_X86_REG_EAX,UC_X86_REG_EDX,UC_X86_REG_ESP,UC_X86_REG_EDI

def probes():
    for slot,parent,state,next_state in itertools.product((0,50,399),(0,49,50,398,399),(4002,4050),(3,9996)):
        item=case('library-alias',(slot,parent,state,next_state),slot=slot,aliases=[[slot,parent]],frames=[[0,307,*d(8,state)],[1,307,*d(8,next_state)]])
        item['actors']=[[parent,[d(0x70,307),d(0x88,1),d(0x318,123)]]]
        yield item
    for slot,state,activity in itertools.product((0,399),(4002,4050),(0,128,255)):
        yield case('library-activity',(slot,state,activity),slot=slot,active=[[slot,activity]],actor=[d(0x70,307)],frames=[[0,307,*d(8,state)]])

class UnmappedTransform(LibTransforms):
    def __init__(self):
        super().__init__();self.invalid=[];self.uc.hook_add(UC_HOOK_MEM_WRITE_UNMAPPED,self.unmapped)
    def unmapped(self,u,access,address,size,value,data):
        self.invalid.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,size=size,value=value&0xffffffff));return False
    def access(self,u,access,address,size,value,data):
        if self.running and access==UC_MEM_WRITE and u.reg_read(UC_X86_REG_EIP)==BASE+0x1112 and address==POOL+399*0x500+0x7b4:
            # Do not perform a host read of absent backing before the actual
            # emulated write can reach its own unmapped-memory boundary.
            return PostDrawSlotPrefix.access(self,u,access,address,size,value,data)
        return super().access(u,access,address,size,value,data)
    def execute(self):
        self.extended_writes=[];self.uc.mem_unmap((POOL+400*0x500)&~4095,4096)
        return PostDrawSlotPrefix.execute(self)

def main():
    vm=LibTransforms();cases=[vm.probe(c,i) for i,c in enumerate(probes())];faults=[]
    for count,state in ((4,4050),(4,4998),(0,4050),(-1,4050)):
        fault=UnmappedTransform();item=case('unmapped',(count,state),slot=399,count=count,actor=[d(0x70,307)],frames=[[0,307,*d(8,state)]])
        try:fault.probe(item,0)
        except UcError as e:
            assert e.errno==UC_ERR_WRITE_UNMAPPED and len(fault.invalid)==1
            event=fault.invalid[0];assert event['pc']==BASE+0x1112 and event['address']==POOL+399*0x500+0x7b4 and event['size']==4
            actor=POOL+399*0x500;pointer=fault.u32(actor+0x368);assert pointer==0x50040000 if count==4 and state==4050 else pointer==0x50000000
            assert event['value']==(actor if count==4 and state==4050 else max(count,0))
            faults.append(dict(input=item,error=str(e),errno=e.errno,event=event,actorObjectAfter=pointer,frameAfter=fault.u32(actor+0x70),sp=fault.uc.reg_read(UC_X86_REG_ESP),edi=fault.uc.reg_read(UC_X86_REG_EDI),instructions=sorted(fault.instructions),nativeCompared=False))
        else:raise AssertionError('Expected actual source unmapped write')
    doc=dict(exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,scope=__doc__,installation=vm.installation,fpcw=0x27f,header=HEADER,headerPatches=HEADERS,ids=IDS,states=STATES,cases=cases,faults=faults,instructions=sorted(vm.instructions),poolAddress=POOL,actorStride=0x500,actorSize=0x420,tailInitial='a5',tailCount=0x1000,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();out=ROOT/'build/original/lib-transform-boundaries.json';assert not out.exists();out.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=out.name,bytes=len(raw),sha256=digest(raw),cases=len(cases),sourceFaults=len(faults),events=sum(len(c['events']) for c in cases),extendedWrites=sum(len(c['extendedWrites']) for c in cases),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-transform-boundaries.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
