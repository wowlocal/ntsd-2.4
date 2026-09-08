#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real41c581..41c5e5 directly after verified first loading, then real419a60
through ret12 under keyboard/joystick/packing/dispatch stimuli. AI4094b0 and
non-character406ba0 are explicit no-effect call boundaries in dispatch probes;
the natural first-loading continuation has no such active tail slots.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_initial_loading import InitialLoading, transport, WORLD
from oracle_catalog_sounds import pack, REGISTERS
from oracle_state import STACK, STOP, ACTOR_SIZE
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_ESP


class LocalInput(InitialLoading):
    def __init__(self,control=False,**loading_options):
        super().__init__(control,**loading_options)
        self.input_running=False
        for pc in (0x419A60,0x419DC5,0x4094B0,0x406BA0):self.uc.hook_add(UC_HOOK_CODE,self.input_checkpoint,begin=pc,end=pc)
    def input_checkpoint(self,uc,address,size,data):
        if not self.input_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address==0x419A60:
            assert self.input_call is None and uc.reg_read(UC_X86_REG_ECX)==self.world_address
            self.input_call=dict(entrySP=sp,returnAddress=self.u32(sp),arguments=[self.u32(sp+i) for i in (4,8,12)],saved=[uc.reg_read(r) for r in REGISTERS])
        elif address==0x419DC5:
            self.before_dispatch=self.snapshot()
        else:
            slot=self.u32(sp+4);assert 10<=slot<400 and uc.reg_read(UC_X86_REG_ECX)==self.world_address
            kind='characterAI' if address==0x4094B0 else 'objectInput'
            arguments=[slot,self.u32(sp+8)] if kind=='characterAI' else [slot]
            self.dispatch.append(dict(kind=kind,arguments=arguments,world=uc.reg_read(UC_X86_REG_ECX),caller=self.u32(sp)))
            self.ret(0x98765432,8 if kind=='characterAI' else 4)
    def snapshot(self):
        def compact(r):return {k:v for k,v in self.record(r).items() if k!='initial'}
        return dict(world=compact(self.world),actors=[compact(r) for r in self.pool],globals=self.globals())
    def step(self,label,stimulus=None,parent=False,paused=0,phase=0,mode=0,commands=None):
        stimulus=json.loads(json.dumps(stimulus or dict(globals=[],actors=[],world=[],bindings=[])))
        for item in stimulus['globals']:self.uc.mem_write(item['address'],bytes.fromhex(item['bytes']))
        for item in stimulus['world']:self.write_host(self.world_address+item['offset'],bytes.fromhex(item['bytes']))
        for item in stimulus['actors']:self.write_host(self.pool[item['slot']]['address']+item['offset'],bytes.fromhex(item['bytes']))
        for item in stimulus['bindings']:
            target=self.pool[item['slot']]['address'];self.write_host(target+0x368,struct.pack('<I',self.object_addresses[item['object']]))
            self.write_host(target+0x70,struct.pack('<I',item['frame']))
        self.dispatch=[];self.input_call=None;self.before_dispatch=None
        natural=commands is None
        if not natural:self.uc.mem_write(self.commands_address,bytes(commands))
        before_commands=list(self.uc.mem_read(self.commands_address,10))
        if parent:
            if not natural:
                self.uc.reg_write(UC_X86_REG_ESP,self.body_sp);self.uc.reg_write(UC_X86_REG_EBX,self.world_address)
                self.uc.reg_write(UC_X86_REG_EDI,paused)
            start,stop=0x41C581,0x41C5E5
        else:
            sp=STACK+0xD000;self.uc.mem_write(sp,struct.pack('<IIII',STOP,phase&0xFFFFFFFF,mode&0xFFFFFFFF,self.commands_address))
            for reg,value in zip(REGISTERS,(0x11111111,0x22222222,0x33333333,0x44444444)):self.uc.reg_write(reg,value)
            self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,self.world_address)
            start,stop=0x419A60,STOP
        self.input_running=True;self.phase='input'
        try:self.execute(start,stop)
        finally:self.input_running=False
        after_sp=self.uc.reg_read(UC_X86_REG_ESP)
        if self.input_call:
            assert after_sp==self.input_call['entrySP']+16
            assert [self.uc.reg_read(r) for r in REGISTERS]==self.input_call['saved']
            assert self.input_call['returnAddress']==stop
        else:assert parent and paused!=0 and after_sp==self.body_sp
        assert not self.reads_before_writes,sorted(self.reads_before_writes)[:15]
        return dict(label=label,stimulus=stimulus,parent=parent,natural=natural,paused=paused,phase=phase&0xFFFFFFFF,mode=mode&0xFFFFFFFF,
                    commandsBefore=before_commands,commandsAfter=list(self.uc.mem_read(self.commands_address,10)),call=self.input_call,
                    beforeDispatch=self.before_dispatch,dispatch=self.dispatch,after=self.snapshot(),stackAfter=after_sp,endPC=stop)
    def capture_inputs(self):
        parent=super().capture();suffix='-control' if self.control else '';parents={}
        for key,doc in zip(('initial-loading','initial-loading-catalog','initial-loading-sounds'),parent):
            report=json.loads((ROOT/'docs/evidence'/f'initial-loading{suffix}.json').read_bytes())[key]
            raw=(ROOT/'build/original'/report['corpus']).read_bytes()
            from oracle_wave_loader import digest
            actual=(json.dumps(doc,separators=(',',':'))+'\n').encode()
            if actual!=raw:
                (ROOT/'build/original'/f'local-input-parent-diff-{key}{suffix}.json').write_bytes(actual)
            assert digest(raw)==report['sha256'] and actual==raw,key
            parents[key]=dict(fixture=report['fixture'],sha256=report['fixtureSHA256'])
        del parent
        self.body_sp=self.uc.reg_read(UC_X86_REG_ESP);self.commands_address=self.body_sp+0x434
        cases=[self.step('natural-first-input',parent=True,paused=int(self.control))]
        print('Verified parent reproduced; natural input continuation reached41c5e5',flush=True)
        def inputs(mask,joy=False,phase=0,record=1,network=1,playback=0,statuses=None,pressed=100):
            g=[];actors=[]
            def word(a,v):g.append(dict(address=a,bytes=struct.pack('<I',v&0xFFFFFFFF).hex()))
            word(0x450B80,record);word(0x450B84,playback);word(0x450B90,phase^1);word(0x451160,0x87654321)
            g.append(dict(address=0x44F1AF,bytes=bytes([network]).hex()))
            g.append(dict(address=0x44D040,bytes=bytes([0x55]*21).hex()))
            g.append(dict(address=0x455378,bytes=bytes([117]*300).hex()))
            for seat,status in enumerate(statuses or [1,2,3,4,1,2,3,4]):word(0x450B4C+4*seat,status)
            for controller in range(1,5):
                config=0x44FB20+controller*80;word(config,controller if joy else 0)
                held=(mask+controller-1)%128
                for button in range(7):
                    key=controller*32+button;word(config+4+button*4,key)
                    g.append(dict(address=0x455378+key,bytes=bytes([pressed if held&(1<<button) else 117]).hex()))
                raw=bytearray(48)
                for button,offset in enumerate([0,1,3,2,4+7,4+2,4+15]):raw[offset]=(0x80+button) if held&(1<<button) else 0
                g.append(dict(address=0x453FF0+(controller-1)*48,bytes=raw.hex()))
                for offset,button in [(0x20,7),(0x24,2),(0x28,15)]:word(config+offset,button)
            for slot in range(8):actors.append(dict(slot=slot,offset=0xC6,bytes=bytes((slot*29+i*11)&255 for i in range(14)).hex()))
            return dict(globals=g,actors=actors,world=[],bindings=[])
        for joy in (False,True):
            for mask in range(128):
                s=inputs(mask,joy);cases.append(self.step(f'{"joystick" if joy else "keyboard"}-{mask}',s,phase=0,mode=17,commands=[0x41]*10))
        for i,phase in enumerate((0,1,2,0xFFFFFFFF,0x80000000)):
            for network in (0,1,127,128,255):
                s=inputs(0x7F,phase=phase,record=0 if i%2==0 else -1,network=network,statuses=[-1,0,1,2,3,4,5,0x7FFFFFFF])
                s['world']=[dict(offset=4,bytes=bytes(8).hex())] # Local input ignores activity in0..7.
                cases.append(self.step(f'phase-status-network-{phase}-{network}',s,phase=phase,mode=-17,commands=[0x81]*10))
        for value in (0,1,99,100,101,117,128,255):
            cases.append(self.step(f'keyboard-value-{value}',inputs(127,pressed=value),commands=[0]*10))
        for device in (-1,-2147483648):
            s=inputs(127)
            s['globals'].append(dict(address=0x44FB70,bytes=struct.pack('<i',device).hex()))
            cases.append(self.step(f'negative-device-{device}',s,commands=[0]*10))
        for playback in (1,-1):
            cases.append(self.step(f'playback-local-skip-{playback}',inputs(127,playback=playback),commands=[0x33]*10))
        for paused in (0,1,-1):
            s=inputs(127);s['globals'] += [dict(address=0x450B90,bytes='00000000'),dict(address=0x451160,bytes='03000000')]
            cases.append(self.step(f'parent-template-pause-{paused}',s,parent=True,paused=paused,commands=[0]*10))
        # Bind only real loaded objects/frames. AI bodies remain declared boundaries.
        for positive in (False,True):
            s=inputs(127);s['world']=[dict(offset=4,bytes=bytes([0x80]*400).hex())]
            for slot in range(10,400):
                ordinal=(slot-10)%len(self.object_addresses);a=self.object_addresses[ordinal];frame=0
                if positive and self.u32(a+0x6F8)!=0:
                    frame=next((f for f in range(400) if 0<self.u32(a+0x7A4+f*0x178+0x30)<0x80000000),0)
                s['bindings'].append(dict(slot=slot,object=ordinal,frame=frame))
            for phase,playback in ((0,0),(1,0),(1,1)):
                s['globals']=[v for v in s['globals'] if v['address']!=0x450B84]+[dict(address=0x450B84,bytes=struct.pack('<I',playback).hex())]
                cases.append(self.step(f'dispatch-{positive}-{phase}-{playback}',s,phase=phase,mode=-17,commands=[0]*10))
        doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,parents=parents,worldAddress=self.world_address,objectAddresses=self.object_addresses,
                 actorAddresses=[r['address'] for r in self.pool],template=list(self.uc.mem_read(0x4493C8,21)),commandsAddress=self.commands_address,
                 bodySP=self.body_sp,cases=cases)
        return transport(doc,self.blobs)


def accept():
    from oracle_wave_loader import digest
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        report_path=ROOT/'docs/evidence'/f'local-input{suffix}.json';report=json.loads(report_path.read_bytes())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256'];doc=json.loads(raw)
        temporary=ROOT/'build/original'/f'local-input{suffix}-check.json';temporary.write_text(pack(doc))
        fixture_root=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixture_root/doc['parents'][key]['fixture']) for key in ('initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--local-input',str(temporary),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixture_root/('original-'+report['corpus']);data=temporary.read_bytes()
        report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((report_path,report,fixture,data))
    for report_path,report,fixture,data in pending:
        fixture.write_bytes(data);report_path.write_text(json.dumps(report,indent=2)+'\n')


def main():
    from oracle_wave_loader import digest
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');args=p.parse_args()
    if args.accept:accept();return
    vm=LocalInput(args.control);doc=vm.capture_inputs();suffix='-control' if args.control else ''
    path=ROOT/'build/original'/f'local-input{suffix}.json';path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(doc['cases']),nativeComparison='pending')
    (ROOT/'docs/evidence'/f'local-input{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(doc['cases']),'local input cases',flush=True)


if __name__=='__main__':main()
