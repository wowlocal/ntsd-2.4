#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole library-enabled preparation, then its own command3 consumer.

Restore the pinned complete loaded catalog and run original World/bootstrap.
Actual relocated DLL installation precedes whole42d1ff..42d6ed preparations.
Each own resulting state then enters whole4214d5..421a15 at a declared fresh
caller ABI. No intervening gameplay tick is skipped under a full-tick claim:
this is an explicit controlled producer/consumer join, not an initialized app.
Menu/RNG/music, optional BG perspective and command-word stimuli are declared.
The library's459ff8 word starts from an explicit retained boundary value; later
consumers use the actual previous producer output, never expected-state bytes.
"""
import argparse,json,struct
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_match_preparation import MatchPreparation,run_scenarios,digest,CATALOG,BG_BASE,BG_SIZE,WORLD,GLOBAL,DEVICE,STACK,ACTOR_SIZE
from oracle_postdraw_commands import CALLS,REGS
from lib_runtime_loader import install_library,BASE
from oracle_lib_initialization import LIB_SHA256
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE,UC_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_ECX,UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG

class LibMatchPreparation(MatchPreparation):
    def __init__(self,capture,pattern):
        self.command_active=False;self.installing=False;self.instructions=set();self.library_accesses=[];self.extra=None;self.undefined_perspective_reads=[]
        super().__init__(capture,pattern)
        self.active=False;self.installing=True
        self.installation=install_library(self.uc)
        self.installing=False;self.active=True
        self.initial_requested=0x12345678;self.put(0x459ff8,self.initial_requested)
        for hook in (UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE):self.uc.hook_add(hook,self.library_access,begin=0x459ff8,end=0x459ffb)
        self.uc.hook_add(UC_HOOK_CODE,self.command_code)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.scratch_access,begin=STACK+0xe034,end=STACK+0xe037)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.scratch_access,begin=STACK+0xe034,end=STACK+0xe037)
        self.uc.reg_write(UC_X86_REG_FPCW,0x27f)
    def track_read(self,u,access,address,size,value,data):
        if address==CATALOG+BG_BASE+99*BG_SIZE+0xc and size==4 and BASE+0x1b2e<=u.reg_read(UC_X86_REG_EIP)<=BASE+0x1b5c:
            assert not any(self.catalog['mask'][BG_BASE+99*BG_SIZE+0xc:BG_BASE+99*BG_SIZE+0x10])
            self.undefined_perspective_reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,size=size,value=self.u32(address)))
            return
        super().track_read(u,access,address,size,value,data)
    def library_access(self,u,access,address,size,value,data):
        if self.active:self.library_accesses.append(dict(pc=u.reg_read(UC_X86_REG_EIP),write=access==UC_MEM_WRITE,address=address,size=size,value=value&0xffffffff if access==UC_MEM_WRITE else self.u32(address)))
    def scratch_access(self,u,access,address,size,value,data):
        if self.command_active:self.scratch.append(dict(pc=u.reg_read(UC_X86_REG_EIP),write=access==UC_MEM_WRITE,address=address,size=size,value=value&0xffffffff if access==UC_MEM_WRITE else self.u32(address)))
    def allowed_code(self,u,pc,size,data):
        if not self.active:return
        if self.command_active:
            if pc==0x421a15:return
            assert any(a<=pc<=b for a,b in [(0x4214d5,0x421a0f),(0x4061d0,0x4064cc),(0x417170,0x4171bc),(0x4450a0,0x44517a),(0x402000,0x402011),(BASE+0x1a9a,BASE+0x1b15)]),hex(pc)
        elif BASE+0x1b1b<=pc<=BASE+0x1b5c:pass
        else:super().allowed_code(u,pc,size,data)
        if not (0x30000000<=pc<0x30001000):self.instructions.add(pc)
    def observe(self,u,pc,size,data):
        if not self.command_active and not self.installing:super().observe(u,pc,size,data)
    def snapshot(self):
        item=super().snapshot();item['requestedID']=struct.unpack('<i',self.uc.mem_read(0x459ff8,4))[0];return item
    def before_preparation(self,mode):
        if self.extra is not None:
            perspective,flag=self.extra
            self.stimulus(CATALOG+BG_BASE+0xc,struct.pack('<i',perspective))
            self.stimulus(0x450bb8,struct.pack('<I',flag))
    def command_code(self,u,pc,size,data):
        if not self.command_active or pc==0x4450a0:return
        sp=u.reg_read(UC_X86_REG_ESP)
        while self.command_pending and pc==self.command_pending[-1]['returnPC']:
            h=self.command_pending.pop();assert sp==h['sp']+4+h['pop'] and h['saved']==[u.reg_read(r) for r in REGS],h
            self.command_helpers+=1
            if h['entry']==0x417170:self.command_events.append(dict(kind='random',arguments=h['args']+[u.reg_read(UC_X86_REG_EAX)]))
        if pc==0x421a15:
            assert not self.command_pending;self.command_finished=True;u.emu_stop();return
        if pc in CALLS:
            count,pop=CALLS[pc];self.command_pending.append(dict(entry=pc,sp=sp,pop=pop,returnPC=self.u32(sp),args=[self.u32(sp+4+4*i) for i in range(count)],saved=[u.reg_read(r) for r in REGS]))
            if pc==0x4061d0:self.command_events.append(dict(kind='reconstruct',arguments=[self.u32(STACK+0xe034)]))
    def commands(self):
        sp=STACK+0xe000;self.uc.mem_write(sp,b'\xa5'*0x800)
        for r,v in zip(REGS,[WORLD,0x22334455,0x33445566,0x44556677]):self.uc.reg_write(r,v)
        self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_FPCW,0x27f);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.command_pending=[];self.command_events=[];self.command_helpers=0;self.scratch=[];self.command_finished=False
        self.command_active=True
        try:self.uc.emu_start(0x4214d5,0,count=2000000)
        finally:self.command_active=False
        assert self.command_finished and self.uc.reg_read(UC_X86_REG_ESP)==sp and not self.reads_before_writes
        writes=[x for x in self.scratch if x['write']]
        assert not self.scratch or writes and self.scratch[0]['write'],self.scratch
        return dict(after=self.snapshot(),events=self.command_events,helpers=self.command_helpers,retainedAfter=self.u32(sp+0x34) if writes else None,scratch=self.scratch)
    def scenario(self,*args,**kwargs):
        self.library_accesses=[]
        item=super().scenario(*args,**kwargs)
        item['commands']=self.commands();item['libraryAccesses']=self.library_accesses
        return item

def main():
    p=argparse.ArgumentParser();p.add_argument('--ramp',action='store_true');a=p.parse_args()
    provenance=next(c for c in json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_bytes())['corpora'] if c['corpus']=='loaded-catalog.json')
    raw=(ROOT/'build/original'/provenance['corpus']).read_bytes();assert digest(raw)==provenance['corpusSHA256']
    vm=LibMatchPreparation(json.loads(raw),None if a.ramp else 0xa5);del raw
    staged=vm.bootstrap();cases=run_scenarios(vm)
    by_path={o['path']:o['index'] for o in vm.object_inputs};naruto=by_path['chars\\naruto.dat']
    for i,(perspective,flag,status) in enumerate([(122,0,1),(122,0,11),(300,0,1),(-1,0,1),(0x7fffffff,0,1),(-0x80000000,0,11),(100,0x12345678,1),(122,0,0),(0,0,1),(0,0,11)]):
        vm.extra=(perspective,flag)
        cases.append(vm.scenario('library-boundary-'+str(i),0,0,[(status,naruto,0)]+[(0,0,0)]*7))
    vm.verify_immutable()
    doc=dict(exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,scope=__doc__,installation=vm.installation,initialRequestedID=vm.initial_requested,fpcw=0x27f,uninitializedPerspective=dict(background=99,bytes='a5a5a5a5',provenance='untouched pinned catalog allocator backing; loader mask remains zero'),undefinedPerspectiveReads=vm.undefined_perspective_reads,
        loadedCatalog=provenance['corpus'],loadedCatalogSHA256=provenance['corpusSHA256'],loadedFixtureSHA256=provenance['fixtureSHA256'],
        catalogAddress=CATALOG,worldAddress=WORLD,actorAddresses=vm.actor_addresses,objects=vm.object_inputs,objectAddresses=vm.object_addresses,
        bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]],surfaceAddress=DEVICE,globalAddress=GLOBAL,globalInitial=vm.blob(vm.global_initial),randomSource=vm.random_source,
        pattern='ramp' if a.ramp else 'a5',selector=2,staged=staged,cases=cases,assets=list(vm.asset_inputs.values()),readsBeforeWrites=sorted(vm.reads_before_writes),blobs=vm.blobs,instructions=sorted(vm.instructions),nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();name='lib-match-preparation'+('-ramp' if a.ramp else '')+'.json';out=ROOT/'build/original'/name;assert not out.exists();out.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,scope=__doc__,corpus=name,sha256=digest(raw),bytes=len(raw),cases=len(cases),instructions=len(vm.instructions),libraryAccesses=sum(len(c['libraryAccesses']) for c in cases),commandEvents=dict(Counter(e['kind'] for c in cases for e in c['commands']['events'])),commandHelpers=sum(c['commands']['helpers'] for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/name).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
