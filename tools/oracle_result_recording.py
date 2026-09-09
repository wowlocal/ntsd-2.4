#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.6"]
# ///
"""Execute whole421cdc..422218/422944 with actual43df00 and43dd60 children.

Controlled full400-slot pool, Object headers, recording/playback allocations,
saved settings and rootSP64. Inherited allocator/thread/descriptor boundaries;
no source instruction or compression result is replaced. Not an own continuation.
"""
import argparse
import base64
import gc
import json
import random
import struct
import time
import zlib
from oracle_replay_writer import (ReplayWriter, ROOT, EXE_SHA256, DLL_SHA256, CPP_SHA256,
    PACKAGE_SHA256, SP, CAPACITY, SOURCE_COUNT, SOURCE, DESTINATION, GLOBAL, GLOBAL_COUNT,
    POINTER, NAME, KEY, digest, recording_inputs)
from oracle_replay_stream import SAVED
from unicorn import UcError, UC_HOOK_CODE, UC_HOOK_MEM_WRITE, UC_HOOK_MEM_READ, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDX,
    UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW)

ENTRY, ROOT_SP = 0x421cdc, SP+4
WORLD, ACTORS, OBJECTS, PLAYBACK = 0x22000000, 0x22100000, 0x22200000, 0x23000000
ACTOR_SIZE, WORLD_SIZE, HEADER_SIZE = 0x420, 0x7d8, 0x76c
SAVED_SETTINGS, SAVED_SIZE = 0x458588, 0x320


class ResultRecording(ReplayWriter):
    def __init__(self, **options):
        super().__init__(**options)
        self.caller_pcs=set();self.restore_pcs=set();self.caller_helpers=[];self.caller_pending=[]
        self.recording_writes=[];self.stack_accesses=[];self.result_started=False;self.writer_input=None
        for address,size in ((WORLD,0x1000),(ACTORS,0x100000),(OBJECTS,0x10000),(PLAYBACK,0x800000)):
            self.uc.mem_map(address,size)
        self.uc.hook_add(UC_HOOK_CODE,self.caller,begin=ENTRY,end=0x422218)
        self.uc.hook_add(UC_HOOK_CODE,self.caller,begin=0x422944,end=0x422944)
        self.uc.hook_add(UC_HOOK_CODE,self.caller,begin=0x43df00,end=0x43e020)
        self.uc.hook_add(UC_HOOK_CODE,self.caller,begin=0x43dd60,end=0x43dd60)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.recording_write,begin=SOURCE,end=SOURCE+SOURCE_COUNT-1)
        self.uc.hook_add(UC_HOOK_MEM_READ|UC_HOOK_MEM_WRITE,self.stack_access,begin=ROOT_SP+0x64,end=ROOT_SP+0x67)

    def recording_write(self,uc,access,address,size,value,data):
        if self.result_started:
            self.recording_writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),offset=address-SOURCE,size=size,value=value&((1<<(8*size))-1)))

    def stack_access(self,uc,access,address,size,value,data):
        if self.result_started:
            self.stack_accesses.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),sp=uc.reg_read(UC_X86_REG_ESP),
                address=address,size=size,write=access==UC_MEM_WRITE))

    def caller(self,uc,pc,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if pc in (0x422218,0x422944):
            assert not self.caller_pending;uc.emu_stop();return
        if self.caller_pending and pc==self.caller_pending[-1]['returnPC']:
            h=self.caller_pending.pop()
            assert sp==h['entrySP']+4 and h.pop('saved')==[uc.reg_read(r) for r in SAVED]
            h['returnSP']=sp;self.caller_helpers.append(h)
        if pc in (0x43df00,0x43dd60):
            self.caller_pending.append(dict(entry=pc,entrySP=sp,returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in SAVED]))
            if pc==0x43dd60:
                assert sp==SP
                self.writer_input=bytes(uc.mem_read(SOURCE,SOURCE_COUNT))
        if ENTRY<=pc<0x422218:self.caller_pcs.add(pc)
        elif 0x43df00<=pc<=0x43e020:self.restore_pcs.add(pc)

    def execute_result(self, spec, source):
        uc=self.uc
        self.source_freed=False
        # Entire controlled records are declared backing; native receives the
        # same before bytes, with pointers normalized only at known fields.
        world=bytearray(b'\xa5'*WORLD_SIZE);world[4:404]=bytes(400)
        actors=bytearray(b'\x96'*(ACTOR_SIZE*400));headers=bytearray(b'\x69'*(HEADER_SIZE*4))
        for n in range(400):
            struct.pack_into('<I',world,0x194+4*n,ACTORS+n*ACTOR_SIZE)
            struct.pack_into('<I',actors,n*ACTOR_SIZE+0x368,OBJECTS+(n%4)*HEADER_SIZE)
            for offset,value in ((0x2fc,500),(0x364,1),(0x348,n*111-123),(0x34c,n*213+5),
                                 (0x350,n*313-44),(0x358,n*417+14),(0x35c,n*513-26)):
                struct.pack_into('<i',actors,n*ACTOR_SIZE+offset,value)
        for n,(identity,kind) in enumerate(((17,0),(21,0),(300,1),(-72,0))):
            struct.pack_into('<ii',headers,n*HEADER_SIZE+0x6f4,identity,kind)
        for slot,flag in spec.get('active',[[0,1],[1,2],[12,255]]):world[4+slot]=flag
        for slot,index in spec.get('aliases',[]):struct.pack_into('<I',world,0x194+4*slot,ACTORS+index*ACTOR_SIZE)
        for index,offset,value in spec.get('actors',[]):struct.pack_into('<I',actors,index*ACTOR_SIZE+offset,value&0xffffffff)
        for index,offset,value in spec.get('headers',[]):struct.pack_into('<I',headers,index*HEADER_SIZE+offset,value&0xffffffff)
        uc.mem_write(WORLD,bytes(world));uc.mem_write(ACTORS,bytes(actors));uc.mem_write(OBJECTS,bytes(headers))
        uc.mem_write(SOURCE,source+b'\x96'*16);uc.mem_write(DESTINATION,b'\xa5'*CAPACITY+b'\x69'*16)
        playback=bytearray(b'\x3c'*SOURCE_COUNT)
        struct.pack_into('<II',playback,0x630bb8,0xfedcba98,0x76543210)
        uc.mem_write(PLAYBACK,bytes(playback))
        settings=bytearray(b'\x87'*SAVED_SIZE)
        for address,value in [(0x458588,b'Saved path'),(0x458780,b'Saved host'),(0x4587e8,b'Saved name')]+[
                (0x458850+11*n,f'Seat{n}'.encode()) for n in range(8)]:
            offset=address-SAVED_SETTINGS;settings[offset:offset+len(value)+1]=value+b'\0'
        settings[0x45877c-SAVED_SETTINGS]=spec.get('savedByte',0x80)
        uc.mem_write(SAVED_SETTINGS,bytes(settings))
        uc.mem_write(NAME,spec.get('name','result.lfr').encode()+b'\0')
        uc.mem_write(KEY,bytes.fromhex(spec.get('key','313239'))+b'\0')
        defaults={0x450bdc:101,0x450bbc:0x7fffffff,0x450be4:1,0x450b80:1,0x450b84:0,
            0x451160:0,0x450bf8:1,0x450b88:0,0x44fb6c:0x12345678,
            0x450c18:11,0x450c1c:22,0x450c20:33,0x450c24:44,
            0x451b64:10,0x451b68:20,0x451b6c:30,0x451b70:40,
            0x44d758:1234,0x44d75c:5678,0x44d380:2,0x44d384:3,0x451b74:4,0x451b78:5}
        defaults.update({int(k,0):v for k,v in spec.get('globals',{}).items()})
        for address,value in defaults.items():self.put(address,value&0xffffffff)
        self.put(POINTER,SOURCE)
        playback_pointer=SOURCE if spec.get('playbackAlias') else PLAYBACK if spec.get('playback') else 0
        self.put(POINTER+4,playback_pointer)
        before=bytes(uc.mem_read(GLOBAL,GLOBAL_COUNT));pointers=bytes(uc.mem_read(POINTER,8))
        uc.mem_write(SP-0x800,b'\xa5'*0xf00);self.put(ROOT_SP+0x64,spec.get('stageDefeated',0))
        uc.reg_write(UC_X86_REG_ESP,ROOT_SP);uc.reg_write(UC_X86_REG_EBX,WORLD)
        uc.reg_write(UC_X86_REG_ESI,0x7817775d);uc.reg_write(UC_X86_REG_EDI,0)
        uc.reg_write(UC_X86_REG_FPCW,0x23f)
        self.writer_events=[];self.result_started=True
        try:uc.emu_start(ENTRY,0,count=2_000_000_000)
        except UcError:
            if not self.fault:raise
        self.result_started=False;pc=uc.reg_read(UC_X86_REG_EIP)
        if not self.fault:
            assert pc in (0x422218,0x422944) and uc.reg_read(UC_X86_REG_ESP)==ROOT_SP
            assert not self.pending and not self.stream_pending and self.u32(0)==0x12345678
        assert uc.reg_read(UC_X86_REG_FPCW)==0x23f
        assert bytes(uc.mem_read(WORLD,WORLD_SIZE))==world and bytes(uc.mem_read(ACTORS,len(actors)))==actors
        assert bytes(uc.mem_read(OBJECTS,len(headers)))==headers
        assert bytes(uc.mem_read(PLAYBACK,SOURCE_COUNT))==playback and bytes(uc.mem_read(SAVED_SETTINGS,SAVED_SIZE))==settings
        assert bytes(uc.mem_read(SOURCE+SOURCE_COUNT,16))==b'\x96'*16
        assert bytes(uc.mem_read(DESTINATION+CAPACITY,16))==b'\x69'*16
        assert self.u32(ROOT_SP+0x64)==spec.get('stageDefeated',0)
        assert all(not raw or rep for raw,rep in zip(self.mask,self.rep_mask))
        return dict(spec=spec,globals=before,globalsAfter=bytes(uc.mem_read(GLOBAL,GLOBAL_COUNT)),world=bytes(world),actors=bytes(actors),headers=bytes(headers),
            source=source,sourceAfter=bytes(uc.mem_read(SOURCE,SOURCE_COUNT)),playback=bytes(playback),saved=bytes(settings),
            pointers=pointers,pointersAfter=bytes(uc.mem_read(POINTER,8)),writerInput=self.writer_input,
            compressed=self.compressed,adjusted=getattr(self,'adjusted',None),codecWritten=bytes(self.rep_mask),rawHookWritten=bytes(self.mask),
            sourceFreed=self.source_freed,writerEvents=self.writer_events,allocations=self.writer_allocations,
            libraryEvents=self.events,streams=self.stream_calls,helpers=self.helpers,callerHelpers=self.caller_helpers,
            codecStatus=self.codec_result,length=getattr(self,'length',None),fault=self.fault,
            longestMatchCalls=self.searches,processorSignatures=self.processor_signatures,
            recordingWrites=self.recording_writes,stackAccesses=self.stack_accesses,copies=self.copies,
            callerPCs=sorted(self.caller_pcs),restorePCs=sorted(self.restore_pcs),writerPCs=sorted(self.writer_pcs),libraryPCs=self.instructions(),
            end=dict(pc=pc,sp=uc.reg_read(UC_X86_REG_ESP)),
            registers={name:uc.reg_read(reg) for name,reg in [('eax',UC_X86_REG_EAX),('ebx',UC_X86_REG_EBX),
                ('ecx',UC_X86_REG_ECX),('edx',UC_X86_REG_EDX),('esi',UC_X86_REG_ESI),('edi',UC_X86_REG_EDI)]})


def probes():
    yield 'ordinary',{}
    for timer in (-0x80000000,-1,0,99,100,102,349,350,0x7fffffff):
        yield f'timer-{timer}',dict(globals={'0x450bdc':timer})
    for address,value in [(0x450be4,0),(0x450b80,0),(0x450b84,1),(0x450b84,-1)]:
        yield f'gate-{address:x}-{value}',dict(globals={hex(address):value})
    for mode in (0,1,4,5,-1):
        yield f'empty-mode-{mode}',dict(active=[],globals={'0x451160':mode})
    for mode in (0,1,4):
        for choice in ('primary','fallback','both'):
            slots=list(range(8)) if choice=='primary' else list(range(10,18)) if choice=='fallback' else list(range(8))+list(range(10,18))
            yield f'seats-{mode}-{choice}',dict(active=[[n,[1,2,128,255][n%4]] for n in slots],globals={'0x451160':mode},
                actors=[[n,0x2fc,[-0x80000000,-1,0,1,0x7fffffff][n%5]] for n in slots])
    for defeated in (0,1,2,0xffffffff):
        yield f'stage-{defeated}',dict(stageDefeated=defeated,globals={'0x451160':1})
    for winner in (-0x80000000,-1,0,1,2,5,0x7fffffff):
        yield f'winner-{winner}',dict(globals={'0x450bf8':winner},actors=[[0,0x2fc,0],[1,0x364,2],[12,0x364,5]])
    for offset in range(5):
        yield f'enemy-unroll-{offset}',dict(globals={'0x451160':1},active=[[395+offset,255]],
            actors=[[395+offset,0x368,OBJECTS],[395+offset,0x364,5]])
    yield 'all-enemies',dict(globals={'0x451160':1},active=[[n,1] for n in range(400)],
        actors=[[n,o,v] for n in range(400) for o,v in ((0x368,OBJECTS),(0x364,5))])
    yield 'aliases',dict(active=[[n,1] for n in range(18)],aliases=[[n,0] for n in range(18)],globals={'0x451160':1})
    for pointer,flag in ((True,0),(False,1),(True,1)):
        yield f'restore-{pointer}-{flag}',dict(playback=pointer,globals={'0x450b88':flag,'0x451160':4})
    yield 'playback-alias',dict(playbackAlias=True,globals={'0x450b88':1,'0x451160':1})
    for n in (-0x80000000,-10001,-101,-100,-99,-11,-10,-9,-1,0,1,9,10,11,99,100,101,10001,0x7fffffff):
        yield f'packed-{n}',dict(globals={'0x451160':4,'0x44d758':n,'0x44d75c':-n if n!=-0x80000000 else n,
            '0x44d380':n,'0x44d384':n,'0x451b74':n,'0x451b78':n})
    rng=random.Random(0x421cdc)
    for n in range(16):
        yield f'packed-random-{n}',dict(globals={'0x451160':4,**{hex(a):rng.randrange(-2**31,2**31) for a in
            (0x44d758,0x44d75c,0x44d380,0x44d384,0x451b74,0x451b78)}})
    for label,options in [('open-failure',dict(open_failure=True)),('short-write',dict(short_write=1,write_result=-1)),
                          ('close-failure',dict(close_failure=True)),('buffer-failure',dict(buffer_failure=True)),
                          *[(f'allocate-{n}',dict(allocation_failure=n)) for n in range(2,7)],
                          ('no-temporary',dict(allocation_failure=1,open_failure=True))]:
        yield label,dict(options=options,key='' if label=='no-temporary' else '313239',playback=True,globals={'0x450b88':1,'0x451160':4})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);parser.add_argument('--resume',action='store_true')
    args=parser.parse_args();provenance,source=next(recording_inputs());cases=[];blobs={}
    checkpoint=ROOT/'build/research/result-recording-progress.json'
    def intern(raw):
        key=digest(raw)
        if key not in blobs:blobs[key]=dict(count=len(raw),deflate=base64.b64encode(zlib.compress(raw,9)).decode())
        return key
    def document():
        return dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cppSHA256=CPP_SHA256,packageSHA256=PACKAGE_SHA256,
            scope=__doc__,recordingInput=provenance,blobEncoding='zlib',cases=cases,blobs=blobs)
    selected=list(probes())[:args.limit]
    if args.resume:
        old=json.loads(checkpoint.read_bytes())
        assert old['recordingInput']==provenance and old['exeSHA256']==EXE_SHA256
        for key,item in old['blobs'].items():
            raw=zlib.decompress(base64.b64decode(item['deflate']));assert len(raw)==item['count'] and digest(raw)==key
        cases.extend(old['cases']);blobs.update(old['blobs'])
        assert [(c['label'],c['spec']) for c in cases]==selected[:len(cases)]
    for label,spec in selected[len(cases):]:
        start=time.monotonic();print('START',label,flush=True)
        vm=ResultRecording(**spec.get('options',{}))
        case=vm.execute_result(spec,source);case['label']=label
        for field,value in list(case.items()):
            if isinstance(value,bytes):case[field]=intern(value)
        for event in case['writerEvents']+case['libraryEvents']:
            if 'bytes' in event:event['bytes']=intern(bytes.fromhex(event['bytes']))
        cases.append(case);temporary=checkpoint.with_suffix('.tmp')
        temporary.write_text(json.dumps(document(),separators=(',',':'))+'\n');temporary.replace(checkpoint)
        print('DONE',label,'seconds',round(time.monotonic()-start,3),'status',case['codecStatus'],
            'caller PCs',len(case['callerPCs']),'fault',case['fault'],flush=True)
        del vm;gc.collect()
    raw=(json.dumps(document(),separators=(',',':'))+'\n').encode()
    (ROOT/'build/original/result-recording.json').write_bytes(raw)
    print('CORPUS',len(cases),'bytes',len(raw),'sha256',digest(raw),flush=True)


if __name__=='__main__':main()
