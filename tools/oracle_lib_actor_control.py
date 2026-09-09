#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole NTSD413080 control with the actual bundled41408b library hook.

The pinned EXE/lib.dll run their whole accepted entry/installer on Unicorn2.1.4.
The retained CPU then executes7168 whole controlled Actor control calls with
declared Actor/Object/Frame/global inputs, CW023f or037f, actual input/RNG/sound
helpers and normal returns. Installer OS responses and constructor memset are
declared research boundaries. Observe full Actor bytes/masks/stores, complete
Object/global hashes, ordered events, helper ABIs and live hook/FPU provenance.
No expected game snapshot, code/helper success stub, control-pointer corruption
or protection bypass is used. This is not full CRT/game initialization, natural
reachability of every synthetic input, Windows/device or a native comparison.
"""
import base64
import itertools
import json
import os
import struct
import traceback
import zlib
from collections import Counter
from datetime import datetime, timezone
from oracle_actor_control import ActorControl, HEADER, STATES, GLOBAL_BASE, GLOBAL_SIZE, held, q
from oracle_actor_input import OBJECT, REGS, d, b, f
from oracle_state import AREA, ACTOR_SIZE, STOP
from oracle_lib_initialization import LibInitialization, ROOT, EXE_SHA256, LIB_SHA256, digest, STACK
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX,
    UC_X86_REG_EDX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EBP, UC_X86_REG_EIP,
    UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG,
    UC_X86_REG_FP0, UC_X86_REG_FP1, UC_X86_REG_FP2, UC_X86_REG_FP3,
    UC_X86_REG_FP4, UC_X86_REG_FP5, UC_X86_REG_FP6, UC_X86_REG_FP7)

FP = (UC_X86_REG_FP0,UC_X86_REG_FP1,UC_X86_REG_FP2,UC_X86_REG_FP3,
      UC_X86_REG_FP4,UC_X86_REG_FP5,UC_X86_REG_FP6,UC_X86_REG_FP7)
VX = (-float.fromhex('0x1.fffffffffffffp1023'),-1.,-float.fromhex('0x0.0000000000001p-1022'),
      -0.,0.,float.fromhex('0x0.0000000000001p-1022'),1.,float.fromhex('0x1.fffffffffffffp1023'))


class Installation(LibInitialization):
    observing_installation = True
    def code(self, u, pc, size, data):
        if self.observing_installation:
            return super().code(u,pc,size,data)


class LibActorControl(ActorControl):
    def __init__(self):
        installer = Installation(0)
        self.installation = installer.run()
        installer.observing_installation = False
        packed = (ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json').read_bytes()
        assert digest(packed) == '3697e7d6c40c78fd1ae026f658c28654a4ed825bde24c087df7ad51242f0584c'
        wrapper = json.loads(packed)
        raw = zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert len(raw) == wrapper['count'] and digest(raw) == wrapper['sha256']
        assert self.installation == json.loads(raw)['cases'][0]
        self.uc = installer.u
        self.running = False
        self.instructions = set()
        self.uc.mem_map(AREA,0x4000)
        self.uc.mem_map(OBJECT,0x40000)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=AREA,end=AREA+0x3fff)
        self.uc.hook_add(UC_HOOK_CODE,self.memset,begin=0x4450a0,end=0x4450a0)
        self.uc.hook_add(UC_HOOK_CODE,self.code)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=AREA,end=AREA+0x3fff)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.global_write,begin=GLOBAL_BASE,end=GLOBAL_BASE+GLOBAL_SIZE-1)
        self.templates = {fill:self.constructor(fill,offset) for fill,offset in [('a5',0x100),('ramp',0x1400)]}

    def constructor(self, fill, displacement):
        initial = bytes([0xa5])*ACTOR_SIZE if fill == 'a5' else bytes(i&255 for i in range(ACTOR_SIZE))
        self.target = AREA+displacement
        self.size = ACTOR_SIZE
        self.mask = [False]*ACTOR_SIZE
        self.writes = []
        self.uc.mem_write(self.target-16,b'\x96'*16+initial+b'\x69'*16)
        sp = STACK+0xf000
        self.uc.mem_write(sp,struct.pack('<I',STOP))
        self.uc.reg_write(UC_X86_REG_ESP,sp)
        self.uc.reg_write(UC_X86_REG_ECX,self.target)
        self.uc.emu_start(0x4061d0,STOP,count=100000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP and self.uc.reg_read(UC_X86_REG_ESP) == sp+4
        assert bytes(self.uc.mem_read(self.target-16,16)) == b'\x96'*16
        assert bytes(self.uc.mem_read(self.target+ACTOR_SIZE,16)) == b'\x69'*16
        return dict(address=hex(self.target),bytes=bytes(self.uc.mem_read(self.target,ACTOR_SIZE)).hex(),defined=self.mask.copy(),writes=self.writes.copy())

    def call(self, entry, args=(), stop=STOP, pop=0):
        assert stop == STOP
        sp = STACK+0xf000
        saved = [0x11223344,0x22334455,0x33445566,0x44556677]
        self.uc.mem_write(sp,struct.pack('<'+'I'*(len(args)+1),STOP,*args))
        self.uc.reg_write(UC_X86_REG_ESP,sp)
        self.uc.reg_write(UC_X86_REG_ECX,self.target)
        for register,value in zip(REGS,saved):self.uc.reg_write(register,value)
        self.until = stop
        self.running = True
        try:self.uc.emu_start(entry,0,count=30000)
        finally:self.running = False
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP and self.uc.reg_read(UC_X86_REG_ESP) == sp+4+pop
        assert [self.uc.reg_read(r) for r in REGS] == saved
        return self.uc.reg_read(UC_X86_REG_EAX)

    def fpu(self):
        u = self.uc
        return dict(cw=u.reg_read(UC_X86_REG_FPCW),sw=u.reg_read(UC_X86_REG_FPSW),tag=u.reg_read(UC_X86_REG_FPTAG),
                    registers=[list(u.reg_read(r)) for r in FP])

    def context(self, pc):
        u = self.uc
        return dict(pc=pc,sp=u.reg_read(UC_X86_REG_ESP),eax=u.reg_read(UC_X86_REG_EAX),
            ecx=u.reg_read(UC_X86_REG_ECX),edx=u.reg_read(UC_X86_REG_EDX),ebx=u.reg_read(UC_X86_REG_EBX),
            esi=u.reg_read(UC_X86_REG_ESI),edi=u.reg_read(UC_X86_REG_EDI),ebp=u.reg_read(UC_X86_REG_EBP),
            frame=self.u32(self.target+0x70),facing=self.uc.mem_read(self.target+0x80,1)[0],fpu=self.fpu())

    def global_write(self, u, access, address, size, value, data):
        if self.running:
            assert GLOBAL_BASE <= address < address+size <= GLOBAL_BASE+GLOBAL_SIZE
            self.global_writes.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=address,size=size,value=value&((1<<(8*size))-1)))

    def code(self, u, pc, size, data):
        if not self.running:return
        sp = u.reg_read(UC_X86_REG_ESP)
        if self.pending and pc == self.pending[-1]['returnPC']:
            h = self.pending[-1]
            self.helper_returns.append(dict(**h,actualSP=sp,result=u.reg_read(UC_X86_REG_EAX),actualSaved=[u.reg_read(r) for r in REGS]))
        if pc in (0x41408b,0x414099,0x414243,0x10001178):
            self.checkpoints.append(self.context(pc))
        if pc == 0x41408b:
            assert u.reg_read(UC_X86_REG_EDI) == 0
            assert u.reg_read(UC_X86_REG_ESI) == self.target and u.reg_read(UC_X86_REG_ECX) == OBJECT
            assert u.reg_read(UC_X86_REG_EDX) == self.u32(self.target+0x70)*0x178
            fp = self.fpu();top = (fp['sw']>>11)&7
            assert fp['registers'][top] == [0x8000000000000000,0x3fff] and fp['registers'][(top+1)&7] == [0,0],fp
        if 0x10001125 <= pc <= 0x100011b8:
            while self.pending and pc == self.pending[-1]['returnPC']:
                h = self.pending.pop()
                assert h['entry'] == 0x10001178 and sp == h['sp']+4 and [u.reg_read(r) for r in REGS] == h['saved']
            self.instructions.add(pc)
            if pc == 0x10001178:
                self.pending.append(dict(entry=pc,sp=sp,pop=0,returnPC=self.u32(sp),args=[],saved=[u.reg_read(r) for r in REGS]))
            return
        return super().code(u,pc,size,data)

    def execute(self, item):
        self.uc.reg_write(UC_X86_REG_FPCW,item['fpcw'])
        self.uc.reg_write(UC_X86_REG_FPSW,0)
        self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.start_fpu = self.fpu()
        super().execute(item)
        self.end_fpu = self.fpu()
        assert self.end_fpu['cw'] == item['fpcw'] and self.end_fpu['tag'] == 0xffff and (self.end_fpu['sw']>>11)&7 == 0

    def probe(self, item, index):
        self.instructions = set()
        self.global_writes = []
        self.helper_returns = []
        self.checkpoints = []
        result = super().probe(item,index)
        result.update(writes=self.writes,globalWrites=self.global_writes,helperReturns=self.helper_returns,
            checkpoints=self.checkpoints,instructions=sorted(self.instructions),fpuBefore=self.start_fpu,fpuAfter=self.end_fpu,
            objectSHA256=digest(bytes(self.uc.mem_read(OBJECT,0x40000))),end=dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP)))
        assert sum(c['pc']==0x41408b for c in self.checkpoints) == 1
        return result


def probes():
    for state,number,facing,left,right,vx in itertools.product((85,86),(0,41,216,217),(0,1,2,255),(0,1,2,255),(0,1,2,255),VX):
        yield dict(group='new-states',actor=[d(0x70,number),b(0x80,facing),b(0xcf,left),b(0xd0,right),q(0x40,vx)],frames=[f(number,8,state)],fpcw=0x23f)
    for state,number,facing,left,right,vx in itertools.product((3,5,84,87),(0,41,216,217),(0,1),(0,1),(0,1),(-1.,0.,1.)):
        yield dict(group='routing',actor=[d(0x70,number),b(0x80,facing),b(0xcf,left),b(0xd0,right),q(0x40,vx)],frames=[f(number,8,state)],fpcw=0x23f)
    for number,mask,state in itertools.product((0,5,9,12,16,212,215,182,188),range(128),(85,86)):
        yield dict(group='same-call-transitions',actor=[d(0x70,number),d(0x14,-1 if number>=180 else 0),q(0x40,-1.5),*held(mask)],
            frames=[f(n,8,state) for n in range(400) if n != number],fpcw=0x23f)
    for state,vx,dx,dy,facing in itertools.product((85,86),VX,(-10,0,10,501),(-1,0,1),(0,1)):
        yield dict(group='later-frame-velocity',actor=[d(0x70,41),b(0x80,facing),q(0x40,vx),q(0x48,3.5)],
            frames=[f(41,8,state),f(41,0x14,dx),f(41,0x18,dy),f(42,0x14,-dx),f(42,0x18,-dy)],fpcw=0x37f)


def save(path, doc):
    raw = (json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode()
    tmp = path.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,path)
    return raw


def main():
    output = ROOT/'build/original/lib-actor-control.json'
    assert not output.exists(),output
    cases = [];vm = None;item = None
    doc = dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,header=HEADER,states=STATES,cases=cases,
               nativeCompared=False,windowsVerified=False)
    try:
        vm = LibActorControl();doc.update(installation=vm.installation,templates=vm.templates)
        for index,stimulus in enumerate(probes()):
            item = dict(stimulus,label=stimulus['group']+'-'+str(index+1))
            cases.append(vm.probe(item,index))
            if len(cases)%256 == 0:
                save(ROOT/'build/research/lib-actor-control-partial.json',doc)
                print('LIB ACTOR CONTROL',len(cases),flush=True)
        assert len(cases) == 7168
    except Exception as error:
        save(ROOT/'build/research/lib-actor-control-partial.json',doc)
        failure = dict(error=repr(error),traceback=traceback.format_exc(),updatedUTC=datetime.now(timezone.utc).isoformat(),completedCases=len(cases),input=item)
        if vm is not None:failure.update(pc=vm.uc.reg_read(UC_X86_REG_EIP),sp=vm.uc.reg_read(UC_X86_REG_ESP),checkpoints=getattr(vm,'checkpoints',[]))
        save(ROOT/'build/research/lib-actor-control-failure.json',failure)
        raise
    doc['instructions'] = sorted({pc for c in cases for pc in c['instructions']})
    raw = save(output,doc)
    report = dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=output.name,bytes=len(raw),sha256=digest(raw),
        cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),actualEXEPCs=sum(0x400000<=pc<0x500000 for pc in doc['instructions']),
        actualDLLPCs=sum(0x10000000<=pc<0x10005000 for pc in doc['instructions']),nativeCompared=False,windowsVerified=False)
    save(ROOT/'build/research/lib-actor-control.json',report)
    print(json.dumps(report,indent=2),flush=True)


if __name__ == '__main__':main()
