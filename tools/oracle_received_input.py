#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real4198f0/4197a0 and41d469 input caller after reproduced initial loading
and natural local input. Primary first continuation also executes41c5e5's phase1
jump. Phase0 network/hotkeys, playback checksum and recording remain outside.
Direct probes supply packets, pause, globals and Actor/seat inputs explicitly.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_local_input import LocalInput
from oracle_initial_loading import InitialLoading, transport, WORLD
from oracle_catalog_sounds import pack, REGISTERS
from oracle_wave_loader import digest
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_ESP


class ReceivedInput(LocalInput):
    def __init__(self,control=False):
        super().__init__(control);self.received_running=False;self.received_pending=None
        for pc in (0x4198F0,0x4197A0,0x419A50,0x4198E9):
            self.uc.hook_add(UC_HOOK_CODE,self.received_checkpoint,begin=pc,end=pc)

    def received_checkpoint(self,uc,address,size,data):
        if not self.received_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address in (0x4198F0,0x4197A0):
            assert self.received_pending is None and uc.reg_read(UC_X86_REG_ECX)==WORLD
            kind='remote' if address==0x4198F0 else 'playback';count=3 if kind=='remote' else 2
            self.received_pending=dict(kind=kind,entrySP=sp,returnAddress=self.u32(sp),arguments=[self.u32(sp+4+i*4) for i in range(count)],
                                       saved=[uc.reg_read(r) for r in REGISTERS])
        else:
            call=self.received_pending;assert call is not None
            assert address==(0x419A50 if call['kind']=='remote' else 0x4198E9)
            assert sp==call['entrySP'] and [uc.reg_read(r) for r in REGISTERS]==call['saved']
            call.update(returnSP=sp+4+len(call['arguments'])*4,after=self.snapshot(),commands=list(uc.mem_read(self.commands_address,10)))
            self.received_calls.append(call);self.received_pending=None

    def receive_step(self,label,kind,stimulus=None,phase=0,paused=0,inherited=False):
        stimulus=json.loads(json.dumps(stimulus or dict(globals=[],actors=[],world=[],seats=[])))
        for write in stimulus['globals']:self.uc.mem_write(write['address'],bytes.fromhex(write['bytes']))
        for write in stimulus['actors']:self.write_host(self.pool[write['slot']]['address']+write['offset'],bytes.fromhex(write['bytes']))
        for write in stimulus['world']:self.write_host(WORLD+write['offset'],bytes.fromhex(write['bytes']))
        for seat,index in enumerate(stimulus['seats']):self.write_host(WORLD+0x194+seat*4,struct.pack('<I',self.pool[index]['address']))
        if not inherited:
            # Include both command-buffer padding areas in the unchanged witness.
            self.uc.mem_write(self.body_sp+0x430,bytes((i*19+0x81)&255 for i in range(28)))
            value=int(label.rsplit('-',1)[-1])&255
            self.uc.mem_write(self.body_sp+0x440,bytes((value+i*53)&255 for i in range(10)))
        before=list(self.uc.mem_read(self.body_sp+0x430,28))
        self.received_calls=[];self.received_pending=None
        continuous=inherited and not self.control
        if kind=='caller':
            if not continuous:
                self.uc.reg_write(UC_X86_REG_ESP,self.body_sp);self.uc.reg_write(UC_X86_REG_EBX,WORLD)
                self.put(self.body_sp+0x38,paused)
            start=0x41C5E5 if continuous else 0x41D469
            stop=0x41D4B7 if paused==0 and self.u32(0x450B84)!=0 else 0x41D5DB
        else:
            sp=STACK+0xD000;args=[0x44F198,phase&0xFFFFFFFF,self.commands_address] if kind=='remote' else [self.body_sp+0x440,phase&0xFFFFFFFF]
            self.uc.mem_write(sp,struct.pack('<'+'I'*(len(args)+1),STOP,*args))
            for reg,value in zip(REGISTERS,(0x11111111,0x22222222,0x33333333,0x44444444)):self.uc.reg_write(reg,value)
            self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
            start=0x4198F0 if kind=='remote' else 0x4197A0;stop=STOP
        self.received_running=True;self.phase='received-input'
        try:self.execute(start,stop)
        finally:self.received_running=False
        assert self.received_pending is None and not self.reads_before_writes
        after_sp=self.uc.reg_read(UC_X86_REG_ESP)
        assert after_sp==(self.body_sp if kind=='caller' else self.received_calls[-1]['returnSP'])
        if kind=='caller' and stop==0x41D5DB:assert self.uc.reg_read(UC_X86_REG_ESI)==self.u32(0x44D020)
        for call in self.received_calls:
            assert call['returnAddress']==(0x41D495 if call['kind']=='remote' else 0x41D4B7) if kind=='caller' else call['returnAddress']==STOP
        return dict(label=label,kind=kind,stimulus=stimulus,phase=phase&0xFFFFFFFF,paused=paused,inherited=inherited,continuous=continuous,
                    stackBefore=before,stackAfter=list(self.uc.mem_read(self.body_sp+0x430,28)),calls=self.received_calls,
                    after=self.snapshot(),entryPC=start,endPC=stop,stackPointerAfter=after_sp)

    def capture_received(self):
        parents={};suffix='-control' if self.control else ''
        # Re-execute the whole original first-loading chain before continuation.
        for key,doc in zip(('initial-loading','initial-loading-catalog','initial-loading-sounds'),InitialLoading.capture(self)):
            report=json.loads((ROOT/'docs/evidence'/f'initial-loading{suffix}.json').read_bytes())[key]
            raw=(ROOT/'build/original'/report['corpus']).read_bytes()
            assert digest(raw)==report['sha256'] and (json.dumps(doc,separators=(',',':'))+'\n').encode()==raw,key
            parents[key]=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        self.body_sp=self.uc.reg_read(UC_X86_REG_ESP);self.commands_address=self.body_sp+0x434
        natural=self.step('natural-first-input',parent=True,paused=int(self.control))
        report=json.loads((ROOT/'docs/evidence'/f'local-input{suffix}.json').read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'];old=json.loads(raw)
        assert transport(dict(case=natural),self.blobs)==transport(dict(case=old['cases'][0]),old['blobs'])
        parents['local-input']=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        del raw,old
        cases=[self.receive_step('inherited-caller-0','caller',paused=int(self.control),inherited=True)]
        print('First loading and natural local input reproduced; received-input continuation captured',flush=True)

        def inputs(value,phase=0,record=1,playback=0,statuses=None,seats=None):
            g=[]
            def word(a,v):g.append(dict(address=a,bytes=struct.pack('<I',v&0xFFFFFFFF).hex()))
            word(0x450B90,phase);word(0x450B80,record);word(0x450B84,playback)
            for seat,status in enumerate(statuses if statuses is not None else [-1]*8):word(0x450B4C+seat*4,status)
            g.append(dict(address=0x44F198,bytes=bytes((value+i*29)&255 for i in range(21)).hex()))
            actors=[dict(slot=i,offset=0xC6,bytes=bytes((i*29+j*11+value)&255 for j in range(14)).hex()) for i in [*range(20),399]]
            return dict(globals=g,actors=actors,world=[dict(offset=4,bytes=bytes([0,1,2,127,128,255,0,0]*50).hex())],seats=seats or list(range(8)))

        for kind in ('remote','playback'):
            for value in range(256):
                cases.append(self.receive_step(f'{kind}-byte-{value}',kind,inputs(value,phase=1,playback=-1),phase=0))
        statuses=[-2147483648,-2,-1,0,1,4,5,2147483647]
        for kind in ('remote','playback','caller'):
            for phase in (0,1,2,0xFFFFFFFF,0x80000000):
                for record in (0,1,-1):
                    for playback in (0,1,-1):
                        value=len(cases)%256;rotated=statuses[value%8:]+statuses[:value%8]
                        s=inputs(value,phase=phase if kind=='caller' else phase^1,record=record,playback=playback,statuses=rotated)
                        cases.append(self.receive_step(f'{kind}-phase-{phase}-record-{record}-playback-{playback}-{value}',kind,s,phase=phase))
            for shift in range(8):
                s=inputs(255,statuses=statuses[shift:]+statuses[:shift])
                cases.append(self.receive_step(f'{kind}-status-rotation-{shift}',kind,s))
            for phase in (0,1):
                for seats in ([0]*8,[0,0,1,1,399,399,3,3],list(reversed(range(8))),[399,9,8,10,11,12,13,14]):
                    value=len(cases)%256
                    s=inputs(value,phase=phase,playback=1,seats=seats)
                    cases.append(self.receive_step(f'{kind}-seat-alias-{phase}-{value}',kind,s,phase=phase))
        for paused in (1,-1):
            for phase in (0,1,2,0xFFFFFFFF,0x80000000):
                for playback in (0,1,-1):
                    value=len(cases)%256
                    cases.append(self.receive_step(f'caller-paused-{paused}-{phase}-{playback}-{value}','caller',inputs(value,phase=phase,playback=playback),paused=paused))
        doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,parents=parents,worldAddress=WORLD,
                 objectAddresses=self.object_addresses,actorAddresses=[r['address'] for r in self.pool],bodySP=self.body_sp,cases=cases)
        return transport(doc,self.blobs)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        report_path=ROOT/'docs/evidence'/f'received-input{suffix}.json';report=json.loads(report_path.read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'];doc=json.loads(raw)
        temporary=ROOT/'build/original'/f'received-input{suffix}-check.json';temporary.write_text(pack(doc))
        root=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(root/doc['parents'][key]['fixture']) for key in ('local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--received-input',str(temporary),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=root/('original-'+report['corpus']);data=temporary.read_bytes()
        report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((report_path,report,fixture,data))
    for report_path,report,fixture,data in pending:
        fixture.write_bytes(data);report_path.write_text(json.dumps(report,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');args=p.parse_args()
    if args.accept:accept();return
    vm=ReceivedInput(args.control);doc=vm.capture_received();suffix='-control' if args.control else ''
    path=ROOT/'build/original'/f'received-input{suffix}.json';path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(doc['cases']),
                remoteCalls=sum(call['kind']=='remote' for case in doc['cases'] for call in case['calls']),
                playbackCalls=sum(call['kind']=='playback' for case in doc['cases'] for call in case['calls']),nativeComparison='pending')
    (ROOT/'docs/evidence'/f'received-input{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(doc['cases']),'received input cases',flush=True)


if __name__=='__main__':main()
