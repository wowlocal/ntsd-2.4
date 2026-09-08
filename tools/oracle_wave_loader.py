#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute original4014e0 for every source WAV with explicit MMIO/COM boundaries.

RIFF file adapter follows documented WinMM chunk/seek semantics; WINMM itself
is not executed. Preserve whole PCM allocations, masks and the format's overlap
with the saved destination pointer. No audio playback/mixer/Windows output claim.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib
from collections import Counter
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256
from oracle_state import Constructors, STACK, AREA, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

DEVICE, VTABLE, ALLOC, FIRST, SECOND = 0x24000020, 0x2400F000, 0x26000020, 0x27000020, 0x28000020
SURFACE, SURFACE_VTABLE = 0x24000040, 0x2400F100
SLOT, GLOBAL, GLOBAL_SIZE = 0x451DB0, 0x44D000, 0xB440


def digest(raw):return hashlib.sha256(raw).hexdigest()


def riff_chunk(raw,position,limit):
    if position+8>limit:return None
    tag,count=struct.unpack_from('<4sI',raw,position)
    if position+8+count>limit:return None
    typed=tag in (b'RIFF',b'LIST')
    if typed and count<4:return None
    return dict(tag=tag,count=count,type=raw[position+8:position+12] if typed else b'\0'*4,
                offset=position+8,end=position+8+count+(count%2))


def data_size(raw):
    position=12
    while position+8<=len(raw):
        c=riff_chunk(raw,position,len(raw));assert c
        if c['tag']==b'data':return c['count']
        position=c['end']
    return 0


def platform(raw,index,**changes):
    count=data_size(raw)
    first=count if index%3==0 else count//2
    result=dict(destination=SLOT,device=DEVICE,stream=0x23450001,buffer=0x24001000+index*16,
                firstPointer=FIRST,secondPointer=0 if index%3==0 else SECOND,
                descendResults=[0,0,0],formatReadResult=18,ascendResult=0,dataReadResult=count,
                createResult=0,lockResults=[0x88780096 if index%5==0 else 0,0],restoreResult=-1,
                unlockResult=-1,closeResult=-1,firstCount=first,secondCount=count-first,ramp=bool(index%2))
    result.update(changes);return result


class WaveLoader(Constructors):
    def __init__(self, uc=None):
        # An attached loader shares the parent's real CPU/stack and uses a
        # disjoint import range. The parent enables instruction/mask hooks only
        # during a wave call, and routes its existing allocator hooks here.
        if uc is None:super().__init__()
        else:self.uc=uc
        self.stub_base=STOP+(0x100 if uc is None else 0x800)
        self.blobs={};self.running=False;self.prefix=False;self.events=[];self.regions={}
        if uc is None:self.uc.mem_map(0x24000000,0x10000)
        for address in (ALLOC,FIRST,SECOND):self.uc.mem_map(address & ~4095,0x200000)
        self.uc.mem_write(DEVICE,struct.pack('<I',VTABLE))
        self.imports={}
        for index,(iat,name) in enumerate([(0x447254,'open'),(0x447258,'descend'),(0x44725C,'close'),
                (0x44723C,'read'),(0x447238,'ascend'),(0x4471C8,'message')]):
            address=self.stub_base+index*16;self.put(iat,address);self.imports[address]=name
        for offset,name in [(0xC,'create'),(0x2C,'lock'),(0x50,'restore'),(0x4C,'unlock')]:
            address=self.stub_base+0x100+offset;self.put(VTABLE+offset,address);self.imports[address]=name
        self.put(SURFACE,SURFACE_VTABLE)
        for offset,name in [(0x14,'blit'),(0x2C,'flip')]:
            address=self.stub_base+0x200+offset;self.put(SURFACE_VTABLE+offset,address);self.imports[address]=name
        self.uc.hook_add(UC_HOOK_CODE,self.imported,begin=self.stub_base,end=self.stub_base+0x2FF)
        if uc is None:
            for address in (0x4450AC,0x4450A6,0x4450C2):self.uc.hook_add(UC_HOOK_CODE,self.crt,begin=address,end=address)
            self.uc.hook_add(UC_HOOK_MEM_WRITE,self.stack_written,begin=STACK,end=STACK+0xFFFF)
            self.uc.hook_add(UC_HOOK_CODE,self.allowed)

    def put(self,address,value):self.uc.mem_write(address,struct.pack('<I',value & 0xFFFFFFFF))
    def ret(self,value=0,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP)
        self.uc.reg_write(UC_X86_REG_EAX,value & 0xFFFFFFFF);self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop)
        self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def cstr(self,address):
        if address==0:return b''
        result=bytearray()
        while self.uc.mem_read(address,1)!=b'\0':result.extend(self.uc.mem_read(address,1));address+=1
        return bytes(result)
    def blob(self,raw):
        raw=bytes(raw);key=digest(raw)
        if key not in self.blobs:self.blobs[key]=dict(count=len(raw),deflate=base64.b64encode(zlib.compress(raw,level=9,wbits=-15)).decode())
        return key
    def event(self,kind,args=(),strings=()):
        event=dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]);self.events.append(event)
        if self.prefix:self.prefix_events.append(dict(wave=event))
    def allowed(self,uc,address,size,data):
        if not self.running:return
        if self.prefix:
            if self.prefix_current is not None and address==self.prefix_current['returnAddress']:
                item=self.prefix_current;self.prefix_current=None
                assert uc.reg_read(UC_X86_REG_ESP)==item['entrySP']+8
                saved=[uc.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)]
                assert saved==item['savedRegisters']
                self.prefix_loads.append(dict(label=self.path.decode(),path=list(self.path),file=self.blob(self.raw),input=self.p,
                    outputBefore=item['outputBefore'],outputAfter=self.u32(self.p['destination']),
                    beforeGlobals=item['beforeGlobals'],afterGlobals=self.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),
                    temporary=self.record('temporary'),temporaryLive=self.regions.get('temporary',{}).get('live',False),
                    first=self.record('first'),second=self.record('second'),format=self.device_format,descriptor=self.descriptor,
                    events=self.events,exit='returned',returned=uc.reg_read(UC_X86_REG_EAX),
                    stackAfter=uc.reg_read(UC_X86_REG_ESP),savedRegisters=saved))
            if address==0x4014E0:
                sp=uc.reg_read(UC_X86_REG_ESP);self.wave_entry_sp=sp
                destination=uc.reg_read(UC_X86_REG_ECX);self.path=self.cstr(self.u32(sp+4))
                self.raw=(DEFAULT_SOURCE/self.path.decode().replace('\\','/')).read_bytes()
                index=len(self.prefix_loads)
                self.p=platform(self.raw,500+index,destination=destination,device=self.u32(0x44EECC),
                                stream=0 if self.prefix_mode==3 and index==7 else 0x23450001)
                self.put(self.p['buffer'],VTABLE)
                self.prefix_current=dict(returnAddress=self.u32(sp),entrySP=sp,outputBefore=self.u32(destination),
                    beforeGlobals=self.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),
                    savedRegisters=[uc.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI)])
                self.regions={};self.events=[];self.device_format=self.descriptor=None;self.descents=self.reads=self.locks=0
                self.region('first',FIRST,self.p['firstCount'])
                if self.p['secondPointer']:self.region('second',SECOND,self.p['secondCount'])
                self.prefix_events.append(dict(wave=dict(kind='load',arguments=[destination],strings=[list(self.path)])))
            if address==0x43F010:
                sp=uc.reg_read(UC_X86_REG_ESP)
                self.prefix_events.append(dict(presentation=dict(kind='bitmap',arguments=[uc.reg_read(UC_X86_REG_ECX)]+[self.u32(sp+i*4) for i in range(1,7)],strings=[])))
                self.ret(0,24);return
            if 0x41BE98<=address<=0x41BFEB or 0x43E940<=address<=0x43E99E:return
        if address==0x40187A and self.p['createResult']!=0:
            uc.emu_stop();return
        assert (0x4014E0<=address<=0x40195E or 0x4450B2<=address<=0x4450BA
                or address in (0x4450AC,0x4450A6,0x4450C2) or self.stub_base<=address<=self.stub_base+0x2FF),hex(address)
    def stack_written(self,uc,access,address,size,value,data):
        if self.running:self.stack_mask[address-STACK:address-STACK+size]=b'\1'*size
    def host_write(self,address,raw):
        self.uc.mem_write(address,raw)
        if STACK<=address<STACK+0x10000:self.stack_mask[address-STACK:address-STACK+len(raw)]=b'\1'*len(raw)
        for region in self.regions.values():
            if region['address']<=address<region['address']+region['count']:
                off=address-region['address'];assert off+len(raw)<=region['count']
                region['mask'][off:off+len(raw)]=b'\1'*len(raw)
    def region(self,name,address,count):
        assert 0<=count<0x1FF000
        initial=bytes(i%256 for i in range(count)) if self.p['ramp'] else b'\xA5'*count
        self.uc.mem_write(address-32,b'\x96'*32+initial+b'\x69'*32)
        self.regions[name]=dict(address=address,count=count,initial=initial,mask=bytearray(count),live=True)
    def record(self,name):
        if name not in self.regions:return None
        r=self.regions[name];a=r['address'];raw=bytes(self.uc.mem_read(a,r['count']))
        assert self.uc.mem_read(a-32,32)==b'\x96'*32 and self.uc.mem_read(a+r['count'],32)==b'\x69'*32
        assert all(v or raw[i]==r['initial'][i] for i,v in enumerate(r['mask']))
        return dict(bytes=self.blob(raw),defined=self.blob(r['mask']),initial=self.blob(r['initial']))

    def imported(self,uc,address,size,data):
        name=self.imports[address];sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
        p=self.p
        if name=='open':
            assert self.cstr(arg(0))==self.path and arg(1)==0 and arg(2)==0x10000
            self.event(name,[arg(1),arg(2)],[self.path]);self.position=0;self.ret(p['stream'],12)
        elif name=='descend':
            request=bytes(uc.mem_read(arg(1),20));tag=request[:4];fcc=request[8:12];flags=arg(3);parent=arg(2)
            self.event(name,[arg(0),flags,int(parent!=0),int.from_bytes(tag,'little'),int.from_bytes(fcc,'little')])
            status=p['descendResults'][self.descents];self.descents+=1
            if status:self.ret(status,16);return
            limit=len(self.raw) if parent==0 else self.u32(parent+12)+self.u32(parent+4)
            current=self.position;found=None
            while (c:=riff_chunk(self.raw,current,limit)) is not None:
                if flags==0 or flags==0x20 and c['tag']==b'RIFF' and c['type']==fcc or flags==0x10 and c['tag']==tag:
                    found=c;break
                current=c['end']
            if found is None:self.ret(1,16);return
            c=found;self.position=c['offset']+(4 if c['tag'] in (b'RIFF',b'LIST') else 0)
            self.host_write(arg(1),c['tag']+struct.pack('<I',c['count'])+c['type']+struct.pack('<II',c['offset'],0))
            self.ret(0,16)
        elif name=='read':
            count=arg(2);self.event(name,[arg(0),count,self.position])
            requested=p['formatReadResult'] if self.reads==0 else p['dataReadResult'];self.reads+=1
            actual=min(requested,len(self.raw)-self.position)
            assert actual<=count
            if actual>0:self.host_write(arg(1),self.raw[self.position:self.position+actual]);self.position+=actual
            self.ret(actual,12)
        elif name=='ascend':
            off,count=self.u32(arg(1)+12),self.u32(arg(1)+4)
            self.event(name,[arg(0),arg(2),off,count]);self.position=off+count+(count%2);self.ret(p['ascendResult'],12)
        elif name=='close':self.event(name,[arg(0),arg(1)]);self.ret(p['closeResult'],8)
        elif name=='message':self.event(name,[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16)
        elif name=='create':
            assert arg(0)==p['device'] and arg(3)==0
            desc=bytearray(uc.mem_read(arg(1),36));fmt=struct.unpack_from('<I',desc,16)[0]
            assert fmt==self.wave_entry_sp-0x190
            struct.pack_into('<I',desc,16,0)
            self.device_format=dict(bytes=self.blob(uc.mem_read(fmt,18)),defined=self.blob(self.stack_mask[fmt-STACK:fmt-STACK+18]))
            self.descriptor=dict(bytes=self.blob(desc),defined=self.blob(self.stack_mask[arg(1)-STACK:arg(1)-STACK+36]))
            self.event(name,[arg(0),arg(3)],[bytes(desc),bytes(uc.mem_read(fmt,18))])
            self.host_write(arg(2),struct.pack('<I',p['buffer']));self.ret(p['createResult'],16)
        elif name=='lock':
            assert arg(0)==p['buffer'] and arg(1)==0 and arg(7)==0
            self.event(name,[arg(0),arg(1),arg(2),arg(7)])
            for i,value in [(3,p['firstPointer']),(4,p['firstCount']),(5,p['secondPointer']),(6,p['secondCount'])]:self.host_write(arg(i),struct.pack('<I',value))
            result=p['lockResults'][min(self.locks,1)];self.locks+=1;self.ret(result,32)
        elif name=='restore':self.event(name,[arg(0)]);self.ret(p['restoreResult'],4)
        elif name=='unlock':self.event(name,[arg(i) for i in range(5)]);self.ret(p['unlockResult'],20)
        elif name in ('blit','flip'):
            assert self.prefix
            count=6 if name=='blit' else 3;offset=0x14 if name=='blit' else 0x2C
            values=[arg(i) for i in range(count)]
            self.prefix_events.append(dict(presentation=dict(kind='method',arguments=[values[0],offset]+values[1:],
                strings=[list(uc.mem_read(arg(1),16))] if name=='blit' else [])))
            self.ret(-1,count*4)

    def crt(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address==0x4450AC:
            count=self.u32(sp+4);assert self.u32(sp)==0x401763
            self.event('allocate',[count]);self.region('temporary',ALLOC,count);self.ret(ALLOC)
        elif address==0x4450A6:
            assert self.u32(sp+4)==ALLOC and self.regions['temporary']['live']
            self.regions['temporary']['live']=False;self.event('free');self.ret()
        else:
            dest,source,count=[self.u32(sp+i) for i in (4,8,12)]
            assert self.regions['temporary']['live'] and ALLOC<=source<=source+count<=ALLOC+self.regions['temporary']['count']
            part=0 if dest==FIRST else 1;assert dest in (FIRST,SECOND)
            self.event('copy',[part,source-ALLOC,count]);self.host_write(dest,bytes(uc.mem_read(source,count)));self.ret(dest)

    def run(self,label,path,raw,p):
        self.p=p;self.raw=raw;self.path=path;self.regions={};self.events=[];self.descents=self.reads=self.locks=0
        self.device_format=self.descriptor=None
        self.region('first',FIRST,p['firstCount'])
        if p['secondPointer']!=0:self.region('second',SECOND,p['secondCount'])
        self.put(DEVICE,VTABLE);self.put(p['buffer'],VTABLE);self.put(0x44EECC,p['device']);self.put(p['destination'],0x87654321)
        self.uc.mem_write(AREA+0x1000,path+b'\0')
        backing=bytes(i%256 for i in range(0x400)) if p['ramp'] else b'\xA5'*0x400
        self.uc.mem_write(STACK+0xEC00,backing)
        self.stack_mask=bytearray(0x10000)
        self.uc.mem_write(STACK+0xF000,struct.pack('<II',STOP,AREA+0x1000))
        self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF000);self.uc.reg_write(UC_X86_REG_ECX,p['destination'])
        self.wave_entry_sp=STACK+0xF000
        saved=[(UC_X86_REG_EBX,0x11111111),(UC_X86_REG_EBP,0x22222222),(UC_X86_REG_ESI,0x33333333),(UC_X86_REG_EDI,0x44444444)]
        for reg,value in saved:self.uc.reg_write(reg,value)
        before=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.running=True
        try:self.uc.emu_start(0x4014E0,STOP,count=1_000_000)
        finally:self.running=False
        pc=self.uc.reg_read(UC_X86_REG_EIP);invalid=p['device']!=0 and self.descriptor is not None and p['createResult']!=0
        assert pc==(0x40187A if invalid else STOP),hex(pc)
        if not invalid:
            assert self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xF008
            assert all(self.uc.reg_read(reg)==value for reg,value in saved)
        return dict(label=label,path=list(path),file=self.blob(raw),input=p,outputBefore=0x87654321,outputAfter=self.u32(p['destination']),
                    beforeGlobals=before,afterGlobals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
                    temporary=self.record('temporary'),temporaryLive=self.regions.get('temporary',{}).get('live',False),
                    first=self.record('first'),second=self.record('second'),format=self.device_format,descriptor=self.descriptor,
                    events=self.events,exit='invalidCreateContinuation' if invalid else 'returned',
                    returned=None if invalid else self.uc.reg_read(UC_X86_REG_EAX),
                    stackAfter=self.uc.reg_read(UC_X86_REG_ESP),savedRegisters=[v for _,v in saved] if not invalid else [])

    def startup(self,mode):
        self.prefix_mode=mode;self.prefix_events=[];self.prefix_loads=[];self.prefix_current=None
        self.put(0x44EECC,0 if mode==2 else DEVICE);self.put(0x44D05C,1);self.put(0x45843C,0x87654321)
        for a,v in [(0x45118C,0x12345678),(0x455608,SURFACE),(0x455634,SURFACE),(0x453E0C,SURFACE),(0x458348,mode)]:self.put(a,v)
        for a,n in [(0x457588,1600),(0x453E10,320),(0x451DB0,72)]:self.uc.mem_write(a,b'\xAB'*n)
        before=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.stack_mask=bytearray(0x10000)
        self.uc.mem_write(STACK+0xE000,b'\xA5'*0x1000)
        self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF000)
        for reg,value in [(UC_X86_REG_EBX,0x11111111),(UC_X86_REG_EBP,0x22222222),(UC_X86_REG_ESI,SURFACE),(UC_X86_REG_EDI,0x44444444)]:self.uc.reg_write(reg,value)
        self.prefix=True;self.running=True
        try:self.uc.emu_start(0x41BE98,0x41BFEB,count=1_000_000)
        finally:self.prefix=False;self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==0x41BFEB and self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xEFFC
        assert len(self.prefix_loads)==18 and self.prefix_current is None
        return dict(mode=mode,targetSurface=SURFACE,beforeGlobals=before,afterGlobals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
                    loads=self.prefix_loads,events=self.prefix_events,endPC='0x41bfeb',stackAfter=STACK+0xEFFC)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--accept',action='store_true');args=parser.parse_args()
    if args.accept:accept();return
    vm=WaveLoader();cases=[];sources=[]
    files=sorted((p for p in DEFAULT_SOURCE.rglob('*') if p.suffix.lower()=='.wav'),key=lambda p:str(p.relative_to(DEFAULT_SOURCE)))
    for i,path in enumerate(files):
        raw=path.read_bytes();name=str(path.relative_to(DEFAULT_SOURCE)).replace('/','\\');p=platform(raw,i)
        cases.append(vm.run('source-'+name,name.encode(),raw,p));sources.append(dict(path=name,sha256=digest(raw),bytes=len(raw)))
    raw=(DEFAULT_SOURCE/'data/001.wav').read_bytes()
    faults=[dict(device=0),dict(stream=0),dict(descendResults=[1,0,0]),dict(descendResults=[0,-1,0]),
            dict(formatReadResult=17),dict(formatReadResult=-1),dict(ascendResult=1),dict(descendResults=[0,0,1]),
            dict(dataReadResult=data_size(raw)-1),dict(dataReadResult=-1),dict(createResult=1),dict(createResult=-1),
            dict(lockResults=[0x88780096,0x88780096]),dict(lockResults=[0x80004005,0]),dict(firstCount=0,secondCount=data_size(raw),secondPointer=SECOND),
            dict(firstCount=data_size(raw),secondCount=0,secondPointer=SECOND)]
    for i,fault in enumerate(faults):
        p=platform(raw,len(cases),**fault);cases.append(vm.run(f'platform-{i}',b'control.wav',raw,p))
    for destination in (0x44FFFC,0x450000,0x44FFFF,0x451DEC):
        cases.append(vm.run(f'destination-{destination:x}',b'control.wav',raw,platform(raw,len(cases),destination=destination)))
    for label,offset,value in [('non-PCM',20,3),('other-first-chunk',12,int.from_bytes(b'JUNK','little'))]:
        modified=bytearray(raw)
        struct.pack_into('<I',modified,offset,value)
        # JUNK with PCM-like bytes still loads: flags0 does not search fmt.
        cases.append(vm.run(label,b'control.wav',bytes(modified),platform(modified,len(cases))))
    startups=[vm.startup(mode) for mode in (1,2,3)]
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,sources=sources,cases=cases,startups=startups,blobs=vm.blobs)
    out=ROOT/'build/original/wave-loader.json';out.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256,corpus=out.name,corpusSHA256=digest(out.read_bytes()),sources=sources,cases=len(cases),
                nativeComparison='pending',events=sum(len(c['events']) for c in cases),startupPasses=len(startups),startupLoads=sum(len(s['loads']) for s in startups),
                eventKinds=dict(Counter(e['kind'] for c in cases for e in c['events'])),
                casesSummary=[dict(label=c['label'],exit=c['exit'],returned=c['returned'],temporaryLive=c['temporaryLive'],
                    eventsSHA256=digest(json.dumps(c['events'],sort_keys=True,separators=(',',':')).encode())) for c in cases])
    (ROOT/'docs/evidence/wave-loader.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(cases),'loads of',len(files),'original WAV files',flush=True)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    report_path=ROOT/'docs/evidence/wave-loader.json';report=json.loads(report_path.read_text())
    raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['corpusSHA256']
    doc=json.loads(raw);raw=json.dumps(doc,separators=(',',':')).encode()
    assert len(raw)<=64_000_000
    packed=dict(count=len(raw),sha256=digest(raw),deflate=base64.b64encode(zlib.compress(raw,level=9,wbits=-15)).decode())
    path=ROOT/'build/original/wave-loader-check.json';path.write_text(json.dumps(packed,separators=(',',':'))+'\n')
    result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--wave-loader',str(path)],capture_output=True,text=True)
    print(result.stdout,end='',flush=True)
    if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
    fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-wave-loader.json';fixture.write_bytes(path.read_bytes())
    report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size)
    report_path.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
