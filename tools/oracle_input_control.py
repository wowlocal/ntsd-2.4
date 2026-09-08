#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real41c5e5..41d46f phase0 control and network path, then received input,
after reproduced full initial loading/natural local input. Real hotkey, sound,
shutdown/free, input-reset and saved-playback restore helpers execute. Winsock,
COM, MessageBox, free and PostMessage results are explicit supplied boundaries.
Playback saved settings/buffers are declared inputs, not full file/startup IO.
The inherited memset boundary also performs431c70's300-byte keyboard reset.
"""
import argparse
import itertools
import json
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_local_input import LocalInput
from oracle_initial_loading import InitialLoading, transport, WORLD
from oracle_catalog_sounds import pack, REGISTERS
from oracle_wave_loader import VTABLE, DEVICE, digest
from oracle_replay_initialization import SIZE
from oracle_state import STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDX, UC_X86_REG_EIP, UC_X86_REG_ESI, UC_X86_REG_ESP

API=0x30002000
BUFFERS=[0x2A000020,0x2B000020]
KEYS=[0x455471,0x455470,0x4553E8,0x4553E9,0x4553EA,0x4553EB,0x4553EC,0x4553ED,0x4553EE,0x4553EF,0x4553F0]
HELPERS=[0x416C70,0x416CA0,0x416DD0,0x416DF0,0x416E10,0x416CD0,0x416E30,0x416E60,0x416EB0,0x416F10,0x416F60]
PACK_BITS=[(12,8),(12,16),(10,2),(10,64),(12,2),(10,4),(10,8),(10,16),(10,32),(12,4),(10,128)]


def signed(value):return (value+0x80000000)%0x100000000-0x80000000
def div(value,by):return abs(value)//by*(1 if value>=0 else -1)
def mod(value,by):return value-div(value,by)*by
def platform():return dict(asyncResults=[-1,1],ioctlResults=[-1,0],ioctlBytes=[0x78,0x56,0x34,0x12],sendResult=-1,receives=[],methodResult=-2147467259,messageResult=1,postResult=0)


class InputControl(LocalInput):
    def __init__(self,control=False,control_api=API,**loading_options):
        self.control_api=control_api
        super().__init__(control,**loading_options);self.control_running=False
        self.control_stop=None
        # These PCs are also traversed in other calls. A translated block
        # cached by a previous continuation can cross a later emu_start's
        # `until` address. Stop at the actual instruction boundary explicitly.
        for pc in (0x41D46F,0x41D4B7,0x41D5DB):
            self.uc.hook_add(UC_HOOK_CODE,self.control_boundary,begin=pc,end=pc)
        self.uc.hook_add(UC_HOOK_CODE,self.control_helper,begin=0x416C70,end=0x416FAD)
        for pc in (0x401A30,0x431C70,0x43DF00,0x4198F0,0x4197A0,0x419A50,0x4198E9):
            self.uc.hook_add(UC_HOOK_CODE,self.control_helper,begin=pc,end=pc)

    def control_boundary(self,uc,address,size,data):
        if self.control_running and address==self.control_stop:uc.emu_stop()

    def execute(self,start,stop):
        if not self.control_running:return super().execute(start,stop)
        self.control_stop=stop
        try:super().execute(start,stop)
        finally:self.control_stop=None

    def memset(self,uc,address,size,data):
        if self.control_running:
            sp=uc.reg_read(UC_X86_REG_ESP)
            args=[self.u32(sp+i) for i in (4,8,12)]
            assert self.u32(sp)==0x431D09 and args==[0x455378,0x75,300]
            self.write_host(args[0],bytes([args[1]])*args[2]);self.ret(args[0])
        else:super().memset(uc,address,size,data)

    def install_boundaries(self,replay_buffers=True):
        self.uc.mem_map(self.control_api,0x1000);self.control_imports={}
        for i,(iat,name) in enumerate([(0x447274,'asyncSelect'),(0x44728C,'ioctl'),(0x447294,'send'),(0x447298,'receive'),
                                       (0x4471C8,'message'),(0x4471EC,'postMessage'),(0x44717C,'free')]):
            a=self.control_api+i*16;self.put(iat,a);self.control_imports[a]=name
        for offset,count in [(8,1),(0x48,1),(0x34,2),(0x30,4)]:
            a=self.control_api+0x100+offset*4;self.put(VTABLE+offset,a);self.control_imports[a]=(offset,count)
        self.uc.hook_add(UC_HOOK_CODE,self.control_imported,begin=self.control_api,end=self.control_api+0xFFF)
        self.replay_memory=[]
        for address in (BUFFERS if replay_buffers else []):
            self.uc.mem_map(address & ~4095,0x640000)
            r=self.add_region(address,SIZE,'control-replay')
            # Supplied allocation backing, not claimed to originate at43d2c0.
            raw=bytes(i%256 for i in range(SIZE)) if self.control else bytes([0xA5])*SIZE
            r['initial']=raw;r['mask'][:]=b'\1'*SIZE;self.uc.mem_write(address,raw)
            self.replay_memory.append(dict(region=r,live=True))
            self.uc.hook_add(UC_HOOK_MEM_READ,self.track_read,begin=address,end=address+SIZE-1)
            self.uc.hook_add(UC_HOOK_MEM_WRITE,self.track_write,begin=address,end=address+SIZE-1)

    def observation(self,kind,args=(),data=(),response=None):
        self.control_events.append(dict(kind=kind,arguments=list(args),data=[list(x) for x in data],response=response))

    def control_imported(self,uc,address,size,data):
        assert self.control_running
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4);kind=self.control_imports[address];p=self.control_platform
        payload=[];strings=[]
        if isinstance(kind,tuple):
            offset,count=kind;kind='method';args=[arg(0),offset]+[arg(i) for i in range(1,count)];result=p['methodResult'];pop=count*4
        elif kind=='asyncSelect':
            args=[arg(i) for i in range(4)];result=p['asyncResults'][self.async_index];self.async_index+=1;pop=16
        elif kind=='ioctl':
            pointer=arg(2);assert pointer==0 if self.ioctl_index==0 else pointer==self.body_sp+0x44
            args=[arg(0),arg(1),int(pointer!=0)];strings=[] if pointer==0 else [uc.mem_read(pointer,4)]
            result=p['ioctlResults'][self.ioctl_index];self.ioctl_index+=1;pop=12
            if pointer:payload=p['ioctlBytes'];uc.mem_write(pointer,bytes(payload))
        elif kind=='send':
            assert arg(1)==0x44D040 and arg(2)==22
            args=[arg(0),arg(2),arg(3)];strings=[uc.mem_read(arg(1),arg(2))];result=p['sendResult'];pop=16
        elif kind=='receive':
            offset=arg(1)-0x44F198;assert 0<=offset<22 and arg(2)==22-offset
            args=[arg(0),offset,arg(2),arg(3)];item=p['receives'][self.receive_index];self.receive_index+=1
            result=item['result'];payload=item['bytes'];assert len(payload)<=arg(2)
            if payload:uc.mem_write(arg(1),bytes(payload))
            pop=16
        elif kind in ('message','postMessage'):
            args=[arg(i) for i in range(4)];result=p['messageResult' if kind=='message' else 'postResult'];pop=16
            if kind=='message':self.messages[str(arg(1))]=list(self.cstr(arg(1)))
        elif kind=='free':
            args=[arg(0)];allocation=next(x for x in self.replay_memory if x['region']['address']==arg(0))
            assert allocation['live'];allocation['live']=False;result=0;pop=0
        else:raise AssertionError(kind)
        self.observation(kind,args,strings,dict(result=result,bytes=payload));self.ret(result,pop)

    def control_helper(self,uc,address,size,data):
        if not self.control_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address in HELPERS:
            assert self.helper_pending is None
            count=1 if address in (0x416C70,0x416CA0,0x416DD0,0x416DF0) else 2 if address in (0x416CD0,0x416E10,0x416E30) else 3
            self.helper_pending=dict(entry=address,entrySP=sp,returnAddress=self.u32(sp),arguments=[self.u32(sp+4+i*4) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS])
            self.observation('action',[address],[uc.mem_read(self.commands_address,10)])
        elif 0x416C70<=address<=0x416FAD and uc.mem_read(address,1)==b'\xc3':
            call=self.helper_pending;assert call is not None and sp==call['entrySP'] and [uc.reg_read(r) for r in REGISTERS]==call['saved']
            call['returnSP']=sp+4;self.helper_calls.append(call);self.helper_pending=None
        elif address==0x401A30:self.observation('soundRequest',[uc.reg_read(UC_X86_REG_ECX),self.u32(sp+4)])
        elif address==0x431C70:
            assert uc.reg_read(UC_X86_REG_ECX)==self.world_address;self.observation('inputReset')
        elif address==0x43DF00:self.observation('restorePlayback')
        elif address in (0x4198F0,0x4197A0):
            assert self.receive_pending is None and uc.reg_read(UC_X86_REG_ECX)==self.world_address
            count=3 if address==0x4198F0 else 2
            self.receive_pending=dict(entry=address,entrySP=sp,returnAddress=self.u32(sp),arguments=[self.u32(sp+4+i*4) for i in range(count)],saved=[uc.reg_read(r) for r in REGISTERS])
        elif address in (0x419A50,0x4198E9):
            call=self.receive_pending;assert call is not None and sp==call['entrySP'] and [uc.reg_read(r) for r in REGISTERS]==call['saved']
            call['returnSP']=sp+4+4*len(call['arguments']);self.receive_calls.append(call);self.receive_pending=None

    def control_snapshot(self):
        # Whole World and all400 Actor bytes/masks in canonical allocation order.
        # This removes repeated JSON record descriptors, not state or padding.
        regions=[self.world,*self.pool]
        memory=[]
        for item in self.replay_memory:
            r=item['region']
            assert 0 not in r['mask'] # Entire supplied allocation is defined.
            assert self.uc.mem_read(r['address']-16,16)==b'\x96'*16
            assert self.uc.mem_read(r['address']+r['size'],16)==b'\x69'*16
            memory.append(dict(bytes=self.blob(self.uc.mem_read(r['address'],r['size'])),defined=self.blob(r['mask']),live=item['live']))
        return dict(poolBytes=self.blob(b''.join(bytes(self.uc.mem_read(r['address'],r['size'])) for r in regions)),
                    poolMask=self.blob(b''.join(bytes(r['mask']) for r in regions)),globals=self.globals(),
                    saved=self.blob(self.uc.mem_read(0x458588,0x320)),pointers=self.blob(self.uc.mem_read(0x4588A8,8)),
                    memory=memory)

    def control_step(self,label,stimulus=None,p=None,paused=0,inherited=False):
        s=json.loads(json.dumps(stimulus or dict(globals=[],actors=[],world=[],seats=[],saved=None,pointers=None,buffers=[],live=None,commands=None,playback=None)))
        p=json.loads(json.dumps(p or platform()))
        for v in s['globals']:self.uc.mem_write(v['address'],bytes.fromhex(v['bytes']))
        for v in s['actors']:self.write_host(self.pool[v['slot']]['address']+v['offset'],bytes.fromhex(v['bytes']))
        for v in s['world']:self.write_host(self.world_address+v['offset'],bytes.fromhex(v['bytes']))
        for seat,slot in enumerate(s['seats']):self.write_host(self.world_address+0x194+seat*4,struct.pack('<I',self.pool[slot]['address']))
        if s['saved'] is not None:self.uc.mem_write(0x458588,bytes(s['saved']))
        if s['pointers'] is not None:self.uc.mem_write(0x4588A8,struct.pack('<II',*s['pointers']))
        if s['live'] is not None:
            for m,live in zip(self.replay_memory,s['live']):m['live']=live
        for v in s['buffers']:self.uc.mem_write(BUFFERS[v['index']]+v['offset'],bytes.fromhex(v['bytes']))
        if not inherited:
            self.uc.reg_write(UC_X86_REG_ESP,self.body_sp);self.uc.reg_write(UC_X86_REG_EBX,self.world_address);self.put(self.body_sp+0x38,paused)
            self.uc.mem_write(self.body_sp+0x430,bytes([0xA5]*28))
            self.uc.mem_write(self.commands_address,bytes(s['commands']));self.uc.mem_write(self.body_sp+0x440,bytes(s['playback']))
            self.put(self.body_sp+0x44,0x99887766)
        before=list(self.uc.mem_read(self.body_sp+0x430,28));scratch=self.u32(self.body_sp+0x44)
        self.control_events=[];self.helper_calls=[];self.receive_calls=[];self.helper_pending=None;self.receive_pending=None
        self.async_index=self.ioctl_index=self.receive_index=0;self.control_platform=p
        self.control_running=True;self.phase='control'
        try:
            self.execute(0x41C5E5,0x41D46F)
            intermediate=self.control_snapshot();control_commands=list(self.uc.mem_read(self.commands_address,10));menu=self.uc.reg_read(UC_X86_REG_ESI)
            stop=0x41D4B7 if paused==0 and self.u32(0x450B84)!=0 else 0x41D5DB
            self.execute(0x41D46F,stop)
        except Exception:
            print('CONTROL FAILURE',label,{name:hex(self.uc.reg_read(reg)) for name,reg in [('pc',UC_X86_REG_EIP),('sp',UC_X86_REG_ESP),('eax',UC_X86_REG_EAX),('ecx',UC_X86_REG_ECX),('edx',UC_X86_REG_EDX),('esi',UC_X86_REG_ESI)]},
                  'recent',self.control_events[-8:],flush=True)
            raise
        finally:self.control_running=False
        assert self.helper_pending is None and self.receive_pending is None and not self.reads_before_writes
        assert self.uc.reg_read(UC_X86_REG_ESP)==self.body_sp
        assert self.receive_index==len(p['receives'])
        return dict(label=label,stimulus=s,platform=p,paused=paused,inherited=inherited,stackBefore=before,stackAfter=list(self.uc.mem_read(self.body_sp+0x430,28)),
                    scratchBefore=scratch,scratchAfter=self.u32(self.body_sp+0x44),events=self.control_events,helperCalls=self.helper_calls,receiveCalls=self.receive_calls,
                    control=intermediate,controlCommands=control_commands,menuRegister=menu,after=self.control_snapshot(),endPC=stop)

    def capture_parent_control(self):
        suffix='-control' if self.control else '';parents={}
        for key,doc in zip(('initial-loading','initial-loading-catalog','initial-loading-sounds'),InitialLoading.capture(self)):
            r=json.loads((ROOT/'docs/evidence'/f'initial-loading{suffix}.json').read_bytes())[key];raw=(ROOT/'build/original'/r['corpus']).read_bytes()
            assert digest(raw)==r['sha256'] and (json.dumps(doc,separators=(',',':'))+'\n').encode()==raw,key
            parents[key]=dict(fixture=r['fixture'],sha256=r['fixtureSHA256'])
        self.body_sp=self.uc.reg_read(UC_X86_REG_ESP);self.commands_address=self.body_sp+0x434
        natural=self.step('natural-first-input',parent=True,paused=int(self.control))
        r=json.loads((ROOT/'docs/evidence'/f'local-input{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256'];old=json.loads(raw)
        assert transport(dict(case=natural),self.blobs)==transport(dict(case=old['cases'][0]),old['blobs'])
        parents['local-input']=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']);del raw,old
        self.install_boundaries();self.messages={};context=self.control_snapshot()
        natural=self.control_step('natural-phase-control',paused=int(self.control),inherited=True)
        print('Original loading/local input reproduced; natural control and received-input continuation passed',flush=True)
        return parents,context,natural

    def capture_control(self):
        parents,context,natural=self.capture_parent_control();cases=[natural]

        def inputs(mask=0,network=0,phase=0,replay=0,remote=0,words=None,seats=None,receive_results=None,faults=(),weights=None,activity=None):
            values={0x450B90:phase,0x44D020:0,0x451160:0,0x450B88:replay,0x450B84:int(replay!=0),0x450B80:1,
                    0x450BFC:0,0x44FB60:0,0x44FCB0:0,0x450C2C:1,0x44D02C:1,0x450BDC:0,0x450BE4:1,0x450B70:0,0x450B6C:127,
                    0x450C28:0,0x44D034:0,0x450BC0:0,0x450BB8:0,0x450C18:0,0x450C1C:0,0x450C20:0,0x450C24:0,
                    0x458428:0,0x45842C:1,0x450BF0:0,0x44D03C:1,0x44F620:31475378,0x44F1B4:0x34560001,0x44F46C:0x34560002,
                    0x4546F4:0x23456789,0x44EECC:DEVICE,0x455618:self.u32(0x452948),0x45561C:self.u32(0x45294C),
                    0x44F04C:0,0x44F048:0,0x44F044:0,0x44F040:0,0x457580:1}
            values.update(words or {})
            g=[dict(address=a,bytes=struct.pack('<I',v&0xFFFFFFFF).hex()) for a,v in values.items()]
            g+=[dict(address=0x44F1AF,bytes=bytes([network]).hex()),dict(address=0x455378,bytes=bytes([117]*300).hex())]
            for i,key in enumerate(KEYS):g.append(dict(address=key,bytes=bytes([100 if mask&(1<<i) else 117]).hex()))
            g.append(dict(address=0x44D040,bytes=(bytes([1]*20)+b'\0\xA5').hex()))
            g.append(dict(address=0x44F198,bytes=bytes([0x5A]*22).hex()))
            for i,status in enumerate([-1,-1,-1,-1,1,2,0,-2]):g.append(dict(address=0x450B4C+i*4,bytes=struct.pack('<i',status).hex()))
            actors=[dict(slot=i,offset=0xC6,bytes=bytes((i*17+j*11)&255 for j in range(14)).hex()) for i in [*range(20),399]]
            weights=weights or [101+i for i in range(20)]
            actors += [dict(slot=i,offset=0x2FC,bytes=struct.pack('<i',weights[i]).hex()) for i in range(20)]
            actors.append(dict(slot=399,offset=0x2FC,bytes=struct.pack('<i',-123).hex()))
            table=seats or list(range(8));activity=activity if activity is not None else [1 if i<20 else 0 for i in range(400)]
            playback=[0xE1,0x81,0x41,0x21,0x11,9,5,3,0,0]
            # The same mask selects all7 replay-controlled commands.
            if replay:
                for bit,target in [(0,(9,1)),(1,(9,2)),(4,(8,4)),(7,(8,16)),(8,(8,32)),(9,(8,64)),(10,(8,128))]:
                    if mask&(1<<bit):playback[target[0]] |= target[1]
            s=dict(globals=g,actors=actors,world=[dict(offset=4,bytes=bytes(activity).hex())],seats=table,saved=None,pointers=BUFFERS.copy(),
                   buffers=[dict(index=1,offset=0x630BB8,bytes=struct.pack('<ii',-17,2147483647).hex())],live=[True,True],commands=[0x11]*10,playback=playback)
            p=platform()
            if network in (1,2) and phase==0:
                packet=[1]*22;packet[:8]=[0xFF,0x81,0x41,0x21,0x11,9,5,3]
                checksum=0
                for slot in range(20):
                    a=table[slot] if slot<8 else slot
                    if activity[slot]==1:checksum=signed(checksum+(weights[a] if a<20 else -123))
                for offset,value in [(9,mod(signed(values[0x450BF0]+1),50)),(11,values[0x44D03C]),(13,mod(checksum,100)+1),
                                     (14,mod(signed(values[0x44F620]),256)),(15,mod(div(signed(values[0x44F620]),256),256))]:packet[offset]=value&255
                for i,(offset,bit) in enumerate(PACK_BITS):
                    if remote&(1<<i):packet[offset] |= bit
                for offset in faults:packet[offset] ^= 0x80
                cursor=0
                for result in receive_results or [22]:
                    count=min(max(result,0),22-cursor);payload=packet[cursor:cursor+count];cursor+=count
                    p['receives'].append(dict(result=result,bytes=payload))
            return s,p

        for mask in range(2048):
            s,p=inputs(mask);cases.append(self.control_step(f'local-keys-{mask}',s,p))
        print('All2048 local hotkey combinations captured',flush=True)
        replay_bits=[0,1,4,7,8,9,10]
        for mask in range(128):
            mapped=sum(1<<b for i,b in enumerate(replay_bits) if mask&(1<<i))
            s,p=inputs(mapped,replay=1);cases.append(self.control_step(f'playback-commands-{mask}',s,p))
        patterns=[0,*[1<<i for i in range(11)],*[sum(1<<i for i in pair) for pair in itertools.combinations(range(11),2)],2047]
        for network in (1,2):
            for source in ('keyboard','remote','both'):
                for mask in patterns:
                    s,p=inputs(mask if source!='remote' else 0,network=network,remote=mask if source!='keyboard' else 0)
                    cases.append(self.control_step(f'network-{network}-{source}-{mask}',s,p))
            for results in ([22],[1]*22,[2,3,17],[0],[-1],[4,0],[4,-1],[23],[-2147483648],[2147483647]):
                s,p=inputs(network=network,receive_results=results);cases.append(self.control_step(f'receive-{network}-{results}',s,p))
            for faults in ([9],[11],[13],[14],[15],[9,11,13,14,15]):
                s,p=inputs(network=network,faults=faults);cases.append(self.control_step(f'checks-{network}-{faults}',s,p))
            for value in (-2147483648,-257,-256,-255,-2,-1,0,1,49,50,127,128,255,256,257,2147483647):
                s,p=inputs(network=network,words={0x450BF0:value,0x44D03C:value,0x44F620:value})
                cases.append(self.control_step(f'network-integers-{network}-{value}',s,p))
        print('Network order, fragments, failures and integer controls captured',flush=True)
        for phase in (0,1,2,0xFFFFFFFF,0x80000000):
            for network in (0,1,2,3,127,128,255):
                s,p=inputs(2047,network=network,phase=phase);cases.append(self.control_step(f'phase-network-{phase}-{network}',s,p,paused=-1))
        for address,values in [(0x451160,[-1,0,1,2,3,5,6,2147483647]),(0x44D020,[-1,0,1,10,2147483647]),
            (0x450C28,[-2147483648,-1,0,1,2,2147483647]),(0x450BDC,[-2147483648,-1,0,100,101,2147483647]),
            (0x45842C,[-1,0,1,2]),(0x450BE4,[-1,0,1]),(0x450B80,[-1,0,1]),(0x450BFC,[-2147483648,-1,0,1,2,2147483647])]:
            for value in values:
                for key in (2,5,7,8,9,10):
                    s,p=inputs(1<<key,words={address:value});cases.append(self.control_step(f'helper-boundary-{address:x}-{value}-{key}',s,p))
        for replay in (1,-1):
            for menu in (0,1,10):
                for present in (False,True):
                    s,p=inputs(2047,replay=replay,words={0x44D020:menu,0x44F04C:DEVICE,0x44F048:DEVICE,0x44F044:DEVICE,0x44F040:DEVICE})
                    saved=bytearray([0xA5]*0x320)
                    for offset,value in [(0,b'saved-description'),(0x1F8,b'saved-label'),(0x260,b'saved-arena')]:saved[offset:offset+len(value)+1]=value+b'\0'
                    saved[0x1F4]=0x80 if self.control else 0xFF
                    for i in range(8):
                        value=f'Player{i}'.encode()+b'\0';saved[0x2C8+i*11:0x2C8+i*11+len(value)]=value
                    s['saved']=list(saved);s['pointers'][1]=BUFFERS[1] if present else 0
                    cases.append(self.control_step(f'playback-restore-{replay}-{menu}-{present}',s,p))
        for seats in ([0]*8,[399,9,8,10,11,12,13,14],list(reversed(range(8)))):
            s,p=inputs(2047,replay=1,seats=seats);s['pointers'][1]=0
            cases.append(self.control_step(f'reset-seat-table-{seats}',s,p))
        for network in (1,2):
            for activity in ([0]*400,[2,128,255,1]*100,[0]*20+[1]*380,[1]*400):
                for weights in ([2147483647]*20,[-2147483648]*20,[-257,0,2147483647,-2147483648]*5):
                    s,p=inputs(network=network,activity=activity,weights=weights)
                    cases.append(self.control_step(f'checksum-activity-wrap-{network}-{len(cases)}',s,p))
        for value in (0,1,99,100,101,117,128,255):
            s,p=inputs(2047)
            for key in KEYS:s['globals'].append(dict(address=key,bytes=bytes([value]).hex()))
            cases.append(self.control_step(f'exact-key-byte-{value}',s,p))
        for bit,address in [(0,0x458428),(1,0x45842C)]:
            for value in (-2147483648,-1,0,1,2,2147483647):
                s,p=inputs(1<<bit,words={address:value});cases.append(self.control_step(f'toggle-wrap-{bit}-{value}',s,p))
        for bit,address in [(7,0x450C18),(8,0x450C1C),(9,0x450C20),(10,0x450C24)]:
            s,p=inputs(1<<bit,words={address:2147483647});cases.append(self.control_step(f'counter-wrap-{bit}',s,p))
        doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,parents=parents,worldAddress=self.world_address,objectAddresses=self.object_addresses,
                 actorAddresses=[r['address'] for r in self.pool],bodySP=self.body_sp,bufferAddresses=BUFFERS,initialContext=context,messages=self.messages,cases=cases)
        return transport(doc,self.blobs)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        path=ROOT/'docs/evidence'/f'input-control{suffix}.json';r=json.loads(path.read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];doc=json.loads(raw);temp=ROOT/'build/original'/f'input-control{suffix}-check.json';temp.write_text(pack(doc))
        fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixtures/doc['parents'][k]['fixture']) for k in ('local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--input-control',str(temp),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixtures/('original-'+r['corpus']);data=temp.read_bytes()
        r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((path,r,fixture,data))
    for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:accept();return
    vm=InputControl(a.control);d=vm.capture_control();suffix='-control' if a.control else ''
    path=ROOT/'build/original'/f'input-control{suffix}.json';path.write_text(json.dumps(d,separators=(',',':'))+'\n')
    counts={k:sum(e['kind']==k for c in d['cases'] for e in c['events']) for k in ('action','asyncSelect','ioctl','send','receive','message','method','free','postMessage','inputReset','restorePlayback')}
    r=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(d['cases']),events=counts,nativeComparison='pending')
    (ROOT/'docs/evidence'/f'input-control{suffix}.json').write_text(json.dumps(r,indent=2)+'\n')
    print('Captured',len(d['cases']),'input-control cases',counts,flush=True)


if __name__=='__main__':main()
