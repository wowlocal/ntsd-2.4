#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real43dc50/43db40, command prefix41bdce..41be8b and checksum/recording
41d4b7/41d5db..41d714 after freshly reproduced full loading/local/control.
Linked probes continue prefix->local->control->received->replay tail on the
same World/CPU/stack. Playback buffers/settings, keys, flags and OS responses
are declared inputs; earlier playback camera/startup/file IO, AI and later
pause/menu/gameplay are not replaced or claimed here.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import ROOT, EXE_SHA256
from oracle_input_control import InputControl, BUFFERS, signed, div, platform
from oracle_initial_loading import transport, WORLD
from oracle_catalog_sounds import pack, REGISTERS
from oracle_wave_loader import digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESI, UC_X86_REG_ESP


class ReplayTick(InputControl):
    def __init__(self,control=False):
        super().__init__(control);self.replay_running=False;self.replay_part=None
        for pc in (0x41BE8B,0x41C5E5,0x41D714):self.uc.hook_add(UC_HOOK_CODE,self.control_boundary,begin=pc,end=pc)
        for pc in (0x43DC50,0x43DB40,0x43DD56,0x43DC47,0x41D54E,0x41D6AC):
            self.uc.hook_add(UC_HOOK_CODE,self.replay_hook,begin=pc,end=pc)

    def replay_event(self,kind,args=(),data=(),response=None):
        self.replay_events.append(dict(kind=kind,arguments=list(args),data=[list(x) for x in data],response=response))

    def control_helper(self,uc,address,size,data):
        if self.replay_running and self.replay_part=='finish' and address in (0x431C70,0x43DF00):
            self.replay_event('inputReset' if address==0x431C70 else 'restorePlayback');return
        super().control_helper(uc,address,size,data)

    def control_imported(self,uc,address,size,data):
        if self.replay_running and self.replay_part=='finish':
            assert self.control_imports[address]=='message'
            sp=uc.reg_read(UC_X86_REG_ESP);args=[self.u32(sp+4+i*4) for i in range(4)]
            self.messages[str(args[1])]=list(self.cstr(args[1]));self.replay_event('message',args,response=self.control_platform['messageResult'])
            self.ret(self.control_platform['messageResult'],16)
        else:super().control_imported(uc,address,size,data)

    def input_checkpoint(self,uc,address,size,data):
        if not self.replay_running:return super().input_checkpoint(uc,address,size,data)
        if address==0x419A60:
            sp=uc.reg_read(UC_X86_REG_ESP);assert self.local_call is None and uc.reg_read(UC_X86_REG_ECX)==WORLD
            self.local_call=dict(entrySP=sp,returnAddress=self.u32(sp),arguments=[self.u32(sp+i) for i in (4,8,12)],saved=[uc.reg_read(r) for r in REGISTERS])
        elif address!=0x419DC5:raise AssertionError('Replay chain reached an unimplemented AI/object body')

    def replay_hook(self,uc,address,size,data):
        if not self.replay_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address in (0x43DC50,0x43DB40):
            assert self.replay_pending is None
            self.replay_pending=dict(entry=address,entrySP=sp,returnAddress=self.u32(sp),argument=self.u32(sp+4),saved=[uc.reg_read(r) for r in REGISTERS])
            read=address==0x43DC50
            self.replay_event('readPacket' if read else 'writePacket',[self.u32(0x450B8C),self.u32(0x4588AC if read else 0x4588A8)],
                              [] if read else [uc.mem_read(self.u32(sp+4),10)])
        elif address in (0x43DD56,0x43DC47):
            c=self.replay_pending;assert c and sp==c['entrySP'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
            c['returnSP']=sp+4;self.replay_calls.append(c);self.replay_pending=None
        elif address==0x41D54E:
            pointer=uc.reg_read(UC_X86_REG_EDX);offset=(0x14B8+4*uc.reg_read(UC_X86_REG_ECX))&0xFFFFFFFF
            self.replay_event('readChecksum',[pointer,offset,uc.reg_read(UC_X86_REG_EAX),self.u32((pointer+offset)&0xFFFFFFFF)])
        elif address==0x41D6AC:
            self.replay_event('writeChecksum',[uc.reg_read(UC_X86_REG_ECX),(0x14B8+4*uc.reg_read(UC_X86_REG_EDI))&0xFFFFFFFF,uc.reg_read(UC_X86_REG_EAX)])

    def replay_step(self,label,s=None,kind='finish',entry='recording',paused=0,inherited=False):
        s=json.loads(json.dumps(s or dict(globals=[],actors=[],world=[],seats=[],saved=None,pointers=None,buffers=[],live=None,commands=None,playback=None)))
        for v in s['globals']:self.uc.mem_write(v['address'],bytes.fromhex(v['bytes']))
        for v in s['actors']:self.write_host(self.pool[v['slot']]['address']+v['offset'],bytes.fromhex(v['bytes']))
        for v in s['world']:self.write_host(WORLD+v['offset'],bytes.fromhex(v['bytes']))
        for seat,slot in enumerate(s['seats']):self.write_host(WORLD+0x194+seat*4,struct.pack('<I',self.pool[slot]['address']))
        if s['saved'] is not None:self.uc.mem_write(0x458588,bytes(s['saved']))
        if s['pointers'] is not None:self.uc.mem_write(0x4588A8,struct.pack('<II',*s['pointers']))
        if s['live'] is not None:
            for m,live in zip(self.replay_memory,s['live']):m['live']=live
        for v in s['buffers']:self.uc.mem_write(BUFFERS[v['index']]+v['offset'],bytes.fromhex(v['bytes']))
        if not inherited:
            for reg,value in [(UC_X86_REG_ESP,self.body_sp),(UC_X86_REG_EBX,WORLD),(UC_X86_REG_EDI,paused&0xFFFFFFFF),(UC_X86_REG_ESI,self.u32(0x44D020))]:self.uc.reg_write(reg,value)
            self.put(self.body_sp+0x38,paused);self.put(self.body_sp+0x44,0x99887766)
            self.uc.mem_write(self.body_sp+0x430,bytes([0xA5]*28))
            self.uc.mem_write(self.commands_address,bytes(s['commands']));self.uc.mem_write(self.body_sp+0x440,bytes(s['playback']))
        self.replay_events=[];self.replay_calls=[];self.replay_pending=None;self.local_call=None
        self.control_platform=platform();self.control_platform['messageResult']=-1 if self.control else 1
        before=list(self.uc.mem_read(self.body_sp+0x430,28));scratch=self.u32(self.body_sp+0x44)
        self.replay_running=self.control_running=True;self.phase='replay-tick'
        prefix=None;control=None
        try:
            if kind in ('prefix','chain'):
                self.replay_part='prefix';self.execute(0x41BDCE,0x41BE8B)
                prefix=dict(state=self.control_snapshot(),stack=list(self.uc.mem_read(self.body_sp+0x430,28)))
            if kind=='chain':
                assert self.u32(0x44D05C)==0
                self.execute(0x41BE8B,0x41C5E5)
                if self.local_call:
                    c=self.local_call;assert self.uc.reg_read(UC_X86_REG_ESP)==c['entrySP']+16 and c['saved']==[self.uc.reg_read(r) for r in REGISTERS]
                else:assert paused!=0
                self.replay_part='control'
                control=self.control_step(label+' control',paused=paused,inherited=True)
                self.control_running=True
                entry='playbackChecksum' if control['endPC']==0x41D4B7 else 'recording'
            if kind!='prefix':
                self.replay_part='finish';self.execute(0x41D4B7 if entry=='playbackChecksum' else 0x41D5DB,0x41D714)
            assert self.replay_pending is None and not self.reads_before_writes
            assert self.uc.reg_read(UC_X86_REG_ESP)==self.body_sp
        except Exception:
            print('REPLAY FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.replay_events[-5:],flush=True);raise
        finally:self.replay_running=self.control_running=False;self.replay_part=None
        return dict(label=label,kind=kind,entry=entry,paused=paused,inherited=inherited,stimulus=s,stackBefore=before,
                    stackAfter=list(self.uc.mem_read(self.body_sp+0x430,28)),scratchBefore=scratch,scratchAfter=self.u32(self.body_sp+0x44),
                    prefix=prefix,control=control,events=self.replay_events,calls=self.replay_calls,localCall=self.local_call,
                    messageResult=self.control_platform['messageResult'],menuRegister=self.uc.reg_read(UC_X86_REG_ESI),after=self.control_snapshot(),
                    endPC=self.uc.reg_read(UC_X86_REG_EIP))

    def capture_replay(self):
        parents,initial,natural=self.capture_parent_control();suffix='-control' if self.control else ''
        r=json.loads((ROOT/'docs/evidence'/f'input-control{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];old=json.loads(raw)
        assert parents==old['parents']
        assert transport(dict(initialContext=initial,case=natural),self.blobs)==transport(dict(initialContext=old['initialContext'],case=old['cases'][0]),old['blobs'])
        parents['input-control']=dict(fixture=r['fixture'],sha256=r['fixtureSHA256'])
        initial=self.control_snapshot();del old,raw
        cases=[self.replay_step('natural-first-replay-tail',paused=int(self.control),inherited=True)]
        print('Pinned first input-control case reproduced; natural replay tail reached41d714',flush=True)

        def inputs(tick=0,record=1,playback=1,menu=0,restore=1,phase=0,fault=False,activity=None,seats=None,weights=None,alias=False,packet=None):
            vals={0x450B8C:tick,0x450B80:record,0x450B84:playback,0x450B88:restore,0x44D020:menu,0x451160:0,
                  0x450B90:phase,0x450BDC:173,0x458428:0,0x45842C:1,0x450C28:0,0x44D02C:1}
            g=[dict(address=a,bytes=struct.pack('<I',v&0xFFFFFFFF).hex()) for a,v in vals.items()]
            g += [dict(address=0x455378,bytes=bytes([117]*300).hex()),dict(address=0x44F1AF,bytes='00'),dict(address=0x44F198,bytes=bytes([0xA3]*22).hex())]
            for i in range(8):g.append(dict(address=0x450B4C+i*4,bytes=struct.pack('<i',-1).hex()))
            weights=weights or [101+i for i in range(400)];table=seats or list(range(20));active=activity if activity is not None else [1]*20+[0]*380
            actors=[dict(slot=i,offset=0x2FC,bytes=struct.pack('<i',weights[i]).hex()) for i in set([*range(20),*table])]
            actors += [dict(slot=i,offset=0xC6,bytes=bytes((i*17+j*11)&255 for j in range(14)).hex()) for i in set([*range(20),*table])]
            saved=bytearray([0xA5]*0x320)
            for offset,value in [(0,b'replay-description'),(0x1F8,b'replay-label'),(0x260,b'replay-arena')]:saved[offset:offset+len(value)+1]=value+b'\0'
            saved[0x1F4]=0x80 if self.control else 0xFF
            for i in range(8):
                value=f'Replay{i}'.encode()+b'\0';saved[0x2C8+i*11:0x2C8+i*11+len(value)]=value
            buffers=[dict(index=1,offset=0x630BB8,bytes=struct.pack('<ii',-17,2147483647).hex())]
            packet=packet or [0xE1,0x81,0x41,0x21,0x11,9,5,3,0,0]
            offset=(0x2B38+10*tick)&0xFFFFFFFF
            if offset+10<=0x630E18:buffers.append(dict(index=1,offset=offset,bytes=bytes(packet).hex()))
            total=0
            for i in range(20):
                if active[i]==1:total=signed(total+weights[table[i]])
            offset=(0x14B8+4*div(tick,150))&0xFFFFFFFF
            if offset+4<=0x630E18:buffers.append(dict(index=1,offset=offset,bytes=struct.pack('<I',(total&0xFFFFFFFF)^(0x80000000 if fault else 0)).hex()))
            return dict(globals=g,actors=actors,world=[dict(offset=4,bytes=bytes(active).hex())],seats=table,saved=list(saved),pointers=[BUFFERS[1] if alias else BUFFERS[0],BUFFERS[1]],
                        buffers=buffers,live=[True,True],commands=[0x31+i for i in range(10)],playback=[0xE1-i for i in range(10)])

        for playback in (0,1,-1):
            for paused in (0,1,-1):
                for tick in (0,1,149,150,647999,648000,-1,-1106,-2147483648):
                    cases.append(self.replay_step(f'prefix-{playback}-{paused}-{tick}',inputs(tick=tick,playback=playback),kind='prefix',paused=paused))
        for entry in ('recording','playbackChecksum'):
            for record in (0,1,-1):
                for playback in (0,1,-1):
                    for paused in (0,1,-1):
                        for tick in (0,1,149,150,151,299,300,647998,647999,648000,-1,-150):
                            cases.append(self.replay_step(f'finish-{entry}-{record}-{playback}-{paused}-{tick}',inputs(tick,record,playback),entry=entry,paused=paused))
        print('Prefix gates and recording/playback/paused counter matrix captured',flush=True)
        for menu in (-1,0,1,10,2147483647):
            for restore in (0,1,-1):
                for playback in (0,1,-1):
                    cases.append(self.replay_step(f'checksum-error-{menu}-{restore}-{playback}',inputs(menu=menu,restore=restore,playback=playback,fault=True),entry='playbackChecksum'))
        for tick in (-2147483648,-2147483647,647999,648000,2147483646,2147483647):
            s=inputs(tick=tick,record=0,playback=0);s['pointers']=[0,0];s['buffers']=[]
            cases.append(self.replay_step(f'counter-only-{tick}',s))
        for i in range(24):
            seats=([399]*20 if i%3==0 else list(reversed(range(20))) if i%3==1 else list(range(19))+[0])
            active=([0]*400 if i%4==0 else [2,128,255,1]*100 if i%4==1 else [1]*400 if i%4==2 else [0]*20+[1]*380)
            weights=([2147483647]*400 if i%2 else [-2147483648,-257,0,2147483647]*100)
            cases.append(self.replay_step(f'checksum-seats-activity-wrap-{i}',inputs(tick=150,seats=seats,activity=active,weights=weights,fault=i%2==0),entry='playbackChecksum'))
        for tick in (215850,216000,216150,647850,647999,648000,648001,-1106,-150,-1,-2147483648):
            s=inputs(tick=tick,alias=True)
            cases.append(self.replay_step(f'overlap-write-{tick}',s))
            s=inputs(tick=0,record=0,alias=True);s['buffers']=[]
            cases.append(self.replay_step(f'overlap-read-zero-{tick}',s,kind='prefix'))
        for value in range(256):
            s=inputs(tick=[0,149,150,647999][value%4],phase=value%2,activity=[1]*8+[0]*392,packet=[(value+i*17)&255 for i in range(8)]+[0,0])
            cases.append(self.replay_step(f'packet-source-chain-{value}',s,kind='chain'))
        for phase in (0,1,-1):
            for paused in (0,1,-1):
                for replay in (0,1,-1):
                    s=inputs(tick=150,phase=phase,playback=replay,activity=[1]*8+[0]*392,packet=[0xFF]*8+[0xF4,3],alias=True)
                    cases.append(self.replay_step(f'commands-chain-{phase}-{paused}-{replay}',s,kind='chain',paused=paused))
        for i in range(24):
            s=inputs(tick=146,activity=[1]*8+[0]*392,alias=True)
            if i==0:
                for tick in range(146,170):
                    packet=[(tick+j*13)&255 for j in range(8)]+[0,0]
                    s['buffers'].append(dict(index=1,offset=0x2B38+10*tick,bytes=bytes(packet).hex()))
                s['buffers'].append(dict(index=1,offset=0x14B8+4,bytes=struct.pack('<i',sum(range(101,109))).hex()))
            else:
                # The counter, Actor state and buffers continue from execution.
                # Only the phase is supplied: the earlier phase-toggling prologue
                # is outside this prefix/continuation, not silently reproduced.
                s.update(globals=[dict(address=0x450B90,bytes=struct.pack('<i',i%2).hex())],actors=[],world=[],seats=[],saved=None,pointers=None,buffers=[],live=None)
            cases.append(self.replay_step(f'consecutive-input-replay-{i}',s,kind='chain'))
        print('Error exits, address overlap and full input/replay chains captured',flush=True)
        doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,parents=parents,worldAddress=WORLD,objectAddresses=self.object_addresses,
                 actorAddresses=[r['address'] for r in self.pool],bodySP=self.body_sp,bufferAddresses=BUFFERS,initialContext=initial,cases=cases,messages=self.messages)
        return transport(doc,self.blobs)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        path=ROOT/'docs/evidence'/f'replay-tick{suffix}.json';r=json.loads(path.read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256']
        doc=json.loads(raw);temp=ROOT/'build/original'/f'replay-tick{suffix}-check.json';temp.write_text(pack(doc));fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixtures/doc['parents'][k]['fixture']) for k in ('input-control','local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--replay-tick',str(temp),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixtures/('original-'+r['corpus']);data=temp.read_bytes();r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((path,r,fixture,data))
    for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:accept();return
    vm=ReplayTick(a.control);d=vm.capture_replay();suffix='-control' if a.control else '';path=ROOT/'build/original'/f'replay-tick{suffix}.json'
    path.write_text(json.dumps(d,separators=(',',':'))+'\n')
    counts={k:sum(e['kind']==k for c in d['cases'] for e in c['events']) for k in ('readPacket','writePacket','readChecksum','writeChecksum','message','inputReset','restorePlayback')}
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(d['cases']),events=counts,nativeComparison='pending')
    (ROOT/'docs/evidence'/f'replay-tick{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print('Captured',len(d['cases']),'replay tick cases',counts,flush=True)


if __name__=='__main__':main()
