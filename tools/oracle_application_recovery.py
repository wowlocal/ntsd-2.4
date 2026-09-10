#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole game surface recovery43e890 with actual restore/recreate children.
Pinned NTSD2.4 EXE/lib.dll, Unicorn2.1.4 and accepted installer parent. Observe
original control flow, globals/stack/lifetimes and ordinary resource failures.
COM/Win32 responses and helper-local backings are declared, not Windows devices,
reentrant callbacks or own WinMain. A null back-surface read after failed creation
is preserved as an ordinary source fault, separate from successful native matches.
No control/protective storage corruption or protection bypass. Research-only.
"""
import argparse,copy,itertools,json,os,struct
from collections import Counter
from pathlib import Path
from unicorn import UC_HOOK_MEM_INVALID,UcError
from unicorn.x86_const import *
from oracle_window_lifecycle import WindowLifecycle,METHOD_SET,POINTERS,EXTRA_HELPERS
from oracle_window_initialization import WindowInitialization,BASE,COUNT,COM
from oracle_lib_initialization import SP,STOP,STACK,REGISTERS,LIB_SHA256,digest
from import_ntsd import ROOT,EXE_SHA256
METHOD_SET['surface'][0x6c]=('restore',1)
RECOVERY_HELPERS={0x43e890:'recovery',0x43e860:'restoreSurfaces'}
STACK_BASE,STACK_COUNT=SP-512,576

class ApplicationRecovery(WindowLifecycle):
    def __init__(self):
        super().__init__();self.u.hook_add(UC_HOOK_MEM_INVALID,self.invalid)
    def invalid(self,u,access,address,n,value,data):
        self.faults.append(dict(access=access,address=address,count=n,value=value,pc=u.reg_read(UC_X86_REG_EIP)));return False
    def observe_write(self,u,access,address,n,value,data):
        if self.capturing and STACK_BASE<=address<address+n<=STACK_BASE+STACK_COUNT:
            self.stack_writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,bytes=((value&((1<<(8*n))-1)).to_bytes(n,'little')).hex(),origin='CPU'))
        return super().observe_write(u,access,address,n,value,data)
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        for h in list(reversed(self.recovery_pending)):
            if h['returnPC']==pc and sp==h['sp']+4:
                self.recovery_returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX)));self.recovery_pending.remove(h)
        if pc in RECOVERY_HELPERS:self.recovery_pending.append(dict(address=pc,kind=RECOVERY_HELPERS[pc],sp=sp,returnPC=self.u32(sp)))
        if 0x43e860<=pc<=0x43e8d4:
            for h in list(reversed(self.pending_helpers)):
                if h['returnPC']==pc and sp==h['sp']+4:
                    self.helper_returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX)));self.pending_helpers.remove(h)
                    self.frames=[f for f in self.frames if f['sp']!=h['sp']]
            for h in list(reversed(self.extra_pending)):
                if h['returnPC']==pc and sp==h['sp']+4+h['pop']:
                    self.extra_returns.append(dict(**h,eax=u.reg_read(UC_X86_REG_EAX)));self.extra_pending.remove(h)
            self.case_instructions[pc]=bytes(u.mem_read(pc,size)).hex();return
        query=pc in self.com_methods and self.com_methods[pc][1]=='pixelFormat'
        if query:address=self.u32(sp+8)
        result=super().code(u,pc,size,data)
        if query and 'bytes' in self.events[-1]['response']:
            self.stack_writes.append(dict(pc=pc,address=address,bytes=bytes(self.events[-1]['response']['bytes']).hex(),origin='API'))
        return result
    def run_case(self,spec,index):
        self.spec=spec;self.new_blobs=[]
        if not spec.get('retain'):
            self.objects=[];self.allocations=[];self.u.mem_write(BASE,self.initial_globals)
            for a,v in [(POINTERS,0),(POINTERS+4,0),(0x458430,spec.get('mode',0)),(0x458434,spec.get('changing',0)),(0x44d794,1),(0x4554c0,0x400000),(0x44d78c,794),(0x44d790,550),(0x4546f4,spec.get('oldWindow',0x73000011)),(0x455634,0),(0x455608,0),(0x457578,0)]:self.put(a,v)
            for bit,a,f in [(1,0x457578,'draw'),(2,0x455608,'surface'),(4,0x455634,'surface')]:
                if spec.get('resources',0 if spec.get('initialize') else 7)&bit:self.put(a,self.allocate(f))
            self.u.mem_write(STACK,bytes((i*spec.get('scratchSeed',17)+0xa5)&255 for i in range(0x10000)))
        self.events=[];self.actions=[];self.counts=Counter();self.frames=[];self.backings=[];self.pending_helpers=[];self.helper_returns=[];self.extra_pending=[];self.extra_returns=[];self.case_instructions={};self.mask=bytearray(COUNT);self.global_writes=[];self.pointer_mask=bytearray(8);self.pointer_writes=[];self.show_reads=[]
        self.stack_writes=[];self.faults=[];self.recovery_pending=[];self.recovery_returns=[]
        initialize=spec.get('initialize',False);entry=0x43bec0 if initialize else 0x43e890
        args=[STOP,0x400000,10] if initialize else [STOP]
        self.u.mem_write(SP,struct.pack('<'+'I'*len(args),*args));self.u.reg_write(UC_X86_REG_ESP,SP);self.u.reg_write(UC_X86_REG_FPCW,0x23f)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGISTERS,saved):self.u.reg_write(r,v)
        before=self.snapshot();stack_before=self.blob(self.u.mem_read(STACK_BASE,STACK_COUNT));self.finished=False;self.capturing=True;error=None
        try:self.u.emu_start(entry,0,count=200000)
        except UcError as e:
            error=str(e);assert spec.get('allowNullBackFault') and self.u.reg_read(UC_X86_REG_EIP)==0x43e876 and self.u.reg_read(UC_X86_REG_EAX)==0 and self.faults[-1]['address']==0,(error,self.faults)
        finally:self.capturing=False
        if error is None:
            assert self.finished and not self.pending_helpers and not self.extra_pending and not self.frames and not self.recovery_pending
            assert self.u.reg_read(UC_X86_REG_ESP)==SP+4
        assert [self.u.reg_read(r) for r in REGISTERS]==saved and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_image and bytes(self.u.mem_read(0x10000000,0x5000))==self.library
        return dict(index=index,spec=spec,before=before,after=self.snapshot(),writeMasks=[self.blob(self.mask),self.blob(self.pointer_mask)],writes=self.global_writes+self.pointer_writes,actions=self.actions,events=self.events,backings=self.backings,helpers=self.helper_returns+self.extra_returns+self.recovery_returns,instructions=[dict(address=a,bytes=b) for a,b in sorted(self.case_instructions.items())],result=self.u.reg_read(UC_X86_REG_EAX),sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW),stackBefore=stack_before,stackAfter=self.blob(self.u.mem_read(STACK_BASE,STACK_COUNT)),stackWrites=self.stack_writes,faults=self.faults,error=error,completed=error is None)

def specs():
    signed=lambda x:(x+2**31)%2**32-2**31
    back=[-2**31,-1,signed(0x8876024b),signed(0x8876024c),signed(0x8876024d),0,1,2**31-1]
    for mode,resources in itertools.product((0,1),(2,3,6,7)):
        for first,last in itertools.product(([-2**31,-1,0,1,2**31-1] if resources&4 else [0]),back):
            results={'restore#1':first,'restore#2':last} if resources&4 else {'restore#1':last}
            yield dict(label='restore-result-boundaries',mode=mode,resources=resources,results=results)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');parts.mkdir();(parts/'blobs').mkdir();vm=ApplicationRecovery();cases=[]
    def capture(spec):
        if a.limit is not None and len(cases)>=a.limit:return None
        try:c=vm.run_case(spec,len(cases))
        except Exception as e:
            path.with_suffix('.failure.json').write_text(json.dumps(dict(error=repr(e),spec=spec,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,actions=vm.actions,faults=vm.faults),indent=2)+'\n');raise
        cases.append(c)
        for k in vm.new_blobs:(parts/'blobs'/(k+'.json')).write_text(json.dumps(vm.blobs[k],separators=(',',':'))+'\n')
        out=parts/f'{c["index"]:04d}.json';temp=out.with_suffix('.tmp');temp.write_text(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n');os.replace(temp,out)
        if len(cases)%50==0:print('completed',len(cases),flush=True)
        return c
    for s in specs():capture(s)
    contexts=[(0,{}),(1,{}),(1,{'createSurface#1':-1}),(1,{'attachedSurface#1':-1,'attachedSurface#2':-1})]
    for mode,errors in contexts:
        base=dict(label='recreation-api-errors',mode=mode,results={'restore#2':-1,**errors});c=capture(base)
        if c:
            for e in c['events']:
                kind=e['request']['kind'];key=e['key']
                if key in base['results'] or kind in ('restore','metric','debug'):continue
                for value in ([0] if kind in ('icon','cursor','registerClass','createWindow','updateWindow','destroyWindow','showWindow') else [-1,1]):
                    capture(dict(base,results={**base['results'],key:value}))
    if a.limit is None:
        for mode in (0,1):
            capture(dict(label='own-display-initialize',initialize=True,mode=mode,scratchSeed=0))
            for results in ({},{'restore#1':-1},{'restore#2':-2005532084},{'restore#2':-1},{'restore#2':-1,'release#1':-1,'showWindow#1':-1},{}):
                capture(dict(label='own-display-recovery',retain=True,results=results))
        capture(dict(label='own-failed-create-initialize',initialize=True,mode=0))
        capture(dict(label='own-failed-create-recovery',retain=True,results={'restore#2':-1,'createWindow#1':0}))
        capture(dict(label='own-null-back-after-failed-create',retain=True,allowNullBackFault=True))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,parent=vm.parent,initialGlobals=vm.blob(vm.initial_globals),cases=cases,blobs=vm.blobs,limited=a.limit is not None,stackAddress=STACK_BASE,stackCount=STACK_COUNT,nativeCompared=False,windowsVerified=False)
    for k,b in vm.blobs.items():
        out=parts/'blobs'/(k+'.json')
        if not out.exists():out.write_text(json.dumps(b,separators=(',',':'))+'\n')
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw);print(json.dumps(dict(cases=len(cases),whole=sum(c['completed'] for c in cases),bytes=len(raw),sha256=digest(raw),blobs=len(vm.blobs))))
if __name__=='__main__':main()
