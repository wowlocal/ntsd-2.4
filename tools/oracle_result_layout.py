#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Recover whole422218/422944..422994 result table and replay indicator.

Pinned game EXE and actual VC80 sprintf execute on one controlled Unicorn CPU
at CW023f with the original bitmap, clip, GDI-text and playback-info children.
Full World/400Actor/fourObject, bitmap and caller backing are declared inputs.
Memory/register hooks establish label/format writes, retained round/target reads
and helper order for the native macOS port. COM/GDI/PTD responses are boundaries;
no source instruction is replaced. Not initialized gameplay, pixels or Windows.
"""
import argparse
import itertools
import json
import struct
from collections import Counter
from oracle_playback_information import PlaybackInformation, SPRINTF
from oracle_bitmap_font import BITMAP, TARGET, VTABLE, API, SP, GLOBAL, GLOBAL_SIZE, SIZE, REGS
from oracle_state import ROOT, STOP, EXE_SHA256
from oracle_bitmap_drawing import digest, signed
from oracle_crt import DLL_SHA256, PACKAGE_SHA256
from unicorn import UcError, UC_HOOK_MEM_INVALID, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDI,
    UC_X86_REG_ESI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_EFLAGS,
    UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

START, INDICATORS, END = 0x422218, 0x422944, 0x422994
WORLD, ACTORS, HEADERS, PLAYBACK = 0x24000000, 0x24100000, 0x24200000, 0x24400000
WORLD_SIZE, ACTOR_SIZE, HEADER_SIZE = 0x7d8, 0x420, 0x76c
LOCAL, LOCAL_SIZE, COOKIE = SP+0x44c, 0x174, SP+0x5c0
SECOND_TARGET, GAPI = TARGET+0x40, STOP+0x2000
RESOURCES = [0x44faf4,0x44f888,0x44fcbc,0x44fb68,0x44faf8,0x44fcb4,0x44fd8c,
             0x44fb64,0x44fd90,0x44fd94,0x44f87c,0x44f88c,0x45116c]
BITMAP_COUNT = len(RESOURCES)+4
HELPERS = {SPRINTF:0,0x401290:0,0x41b390:12,0x423940:0,0x423a70:0,0x43f010:24,0x43ef70:0}


class ResultLayout(PlaybackInformation):
    def __init__(self):
        super().__init__()
        self.uc.mem_map((BITMAP&~0xfff)+0x10000,0x20000)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=BITMAP+0x6000,end=BITMAP+BITMAP_COUNT*0x2000-1)
        for address,size in ((WORLD,0x1000),(ACTORS,0x100000),(HEADERS,0x10000),(PLAYBACK,0x1000)):
            self.uc.mem_map(address,size)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.local_write,begin=SP+0x34,end=SP+0x6b)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.local_write,begin=LOCAL,end=COOKIE+3)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.retained_read,begin=SP+0x64,end=SP+0x6b)
        self.uc.hook_add(UC_HOOK_MEM_INVALID,self.invalid_memory)
        self.gdi={GAPI+16*i:name for i,name in enumerate(('setBackgroundColor','setTextColor','stringLength','textOut','getDC','releaseDC'))}
        for iat,address in ((0x44702c,GAPI),(0x447034,GAPI+16),(0x447084,GAPI+32),(0x447038,GAPI+48),
                            (VTABLE+0x44,GAPI+64),(VTABLE+0x68,GAPI+80)):
            self.put(iat,address)
        self.formats.update({p:bytes(self.uc.mem_read(p,40)).split(b'\0')[0] for p in (0x447b08,0x449184,0x449170)})

    def cstring(self,p):
        if LOCAL<=p<LOCAL+LOCAL_SIZE:end=LOCAL+LOCAL_SIZE
        else:assert GLOBAL<=p<GLOBAL+GLOBAL_SIZE;end=min(p+1024,GLOBAL+GLOBAL_SIZE)
        raw=bytes(self.uc.mem_read(p,end-p));n=raw.find(b'\0');assert n>=0
        return raw[:n]

    def retained_read(self,uc,access,p,size,value,data):
        if self.running:
            self.retained_reads.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),offset=p-SP,size=size))

    def invalid_memory(self,uc,access,p,size,value,data):
        assert self.running and self.spec.get('authorPointerFault') and self.invalid_bitmap==0x41414141
        self.fault=dict(pc=uc.reg_read(UC_X86_REG_EIP),access=access,address=p,size=size,bitmap=self.invalid_bitmap)
        return False

    def local_write(self,uc,access,p,size,value,data):
        if not self.running:return
        pc=uc.reg_read(UC_X86_REG_EIP);value&=(1<<(8*size))-1
        assert size in (1,4) and p+size<=COOKIE
        self.local_writes.append(dict(pc=pc,offset=p-SP,size=size,value=value))
        if p>=LOCAL:
            assert 0x78130000<=pc<0x78230000 and size==1
            self.local_written[p-LOCAL:p-LOCAL+size]=b'\1'*size
            self.event('formatWrite',[p-LOCAL,size,value])
        else:
            assert START<=pc<INDICATORS and p+size<=SP+0x64
            self.low_written[p-SP-0x34:p-SP-0x34+size]=b'\1'*size
            normalized=(value+WORLD+4)&0xffffffff if p==SP+0x50 else value
            self.event('localWrite',[p-SP,size,normalized])

    def read(self,uc,access,p,size,value,data):
        if not self.running:return
        n,offset=divmod(p-BITMAP,0x2000)
        assert n==self.bitmap and 0<=n<BITMAP_COUNT and size==4 and offset+size<=SIZE,(hex(uc.reg_read(UC_X86_REG_EIP)),hex(p),n,offset)
        self.event('read',read=dict(offset=offset,value=self.u32(p),defined=all(self.bitmap_masks[n][offset:offset+4])))

    def code(self,uc,pc,size,data):
        if not self.running:return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        if self.copy and pc!=self.copy['pc']:
            h=self.copy;self.copy=None
            assert uc.reg_read(UC_X86_REG_ECX)==0 and uc.reg_read(UC_X86_REG_ESI)==h['source']+h['bytes']
            assert uc.reg_read(UC_X86_REG_EDI)==h['destination']+h['bytes']
            assert bytes(uc.mem_read(h['destination'],h['bytes'])).hex()==h['before']
            assert all(self.global_written[h['destination']-GLOBAL:h['destination']-GLOBAL+h['bytes']])
            self.copies.append(h)
        if pc in (0x41b5a6,0x41b5bf) and self.copy is None:
            count=uc.reg_read(UC_X86_REG_ECX);source=uc.reg_read(UC_X86_REG_ESI);destination=uc.reg_read(UC_X86_REG_EDI)
            amount=count*(4 if pc==0x41b5a6 else 1)
            assert not uc.reg_read(UC_X86_REG_EFLAGS)&0x400 and 0x450e30<=source<=source+amount<=0x450e98
            self.copy=dict(pc=pc,source=source,destination=destination,count=count,bytes=amount,before=bytes(uc.mem_read(source,amount)).hex())
        while self.pending and pc==self.pending[-1]['returnPC']:
            h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[uc.reg_read(r) for r in REGS],h
            h['returnSP']=sp;self.helpers.append(h)
            if h['entry']==0x43f010:self.bitmap=None
            if h['entry']==SPRINTF:
                count=signed(uc.reg_read(UC_X86_REG_EAX));assert 0<=count<100
                raw=bytes(uc.mem_read(h['destination'],count+1));assert raw[-1]==0
                self.event('format',[count],[bytes(h['format']),raw[:-1]])
                h['result']=count;h['output']=raw.hex()
        if self.clip and pc==self.clip['returnPC']:
            h=self.clip;self.clip=None
            self.event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
        if pc==END:
            assert not self.pending and self.clip is None and self.bitmap is None;uc.emu_stop();return
        if pc in self.gdi:
            name=self.gdi[pc];dc=self.spec.get('dc',0x76543210)
            if name=='getDC':self.event(name,[arg(0)]);self.put(arg(1),dc);self.ret(self.spec.get('dcResult',0),8)
            elif name=='releaseDC':self.event(name,[arg(0),arg(1)]);self.ret(self.spec.get('methodResult',-2147467259),8)
            elif name in ('setBackgroundColor','setTextColor'):self.event(name,[arg(0),arg(1)]);self.ret(0xffffffff,8)
            elif name=='stringLength':raw=self.cstring(arg(0));self.event(name,[],[raw]);self.ret(len(raw),4)
            else:raw=bytes(uc.mem_read(arg(3),arg(4)));self.event(name,[arg(0),arg(1),arg(2),arg(4)],[raw]);self.ret(0,20)
            return
        if pc==API:
            assert arg(0) in (TARGET,SECOND_TARGET) and arg(2) in [0,*[TARGET+0x100+16*n for n in range(BITMAP_COUNT)]] and arg(5)==0
            self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
                destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
            result=self.results[self.blits%len(self.results)];self.blits+=1;self.ret(result,24);return
        if pc in self.crt.boundaries:return
        if pc in (0x43f18c,0x43f190,0x43f197,0x43f19e):
            offset={0x43f18c:0x10,0x43f190:0xfb0,0x43f197:0x7e0,0x43f19e:0x1780}[pc]
            effective=(4*uc.reg_read(UC_X86_REG_EAX)+offset)&0xffffffff
            assert effective<=SIZE-4,('Probe outside declared bitmap backing',hex(pc),effective)
        self.instructions.add(pc);self.case_instructions.add(pc)
        if pc in HELPERS:
            h=dict(entry=pc,sp=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]);self.pending.append(h)
            if pc==SPRINTF:
                assert arg(0) in (LOCAL,0x450e30,0x450e98) and arg(1) in self.formats
                fmt=self.formats[arg(1)];h.update(destination=arg(0),format=list(fmt),arguments=[signed(arg(n+2)) for n in range(fmt.count(b'%'))])
            elif pc==0x401290:self.event('text',[arg(0),*[arg(n) for n in range(2,6)]],[self.cstring(arg(1))])
            elif pc==0x423a70:self.event('infoText',[arg(0)])
            elif pc==0x423940:
                self.text_pointer=arg(0);self.event('fontPass',[arg(n) for n in range(1,7)],[self.cstring(arg(0))])
            elif pc==0x43f010:
                pointer=uc.reg_read(UC_X86_REG_ECX)
                self.event('draw',[pointer,*[arg(n) for n in range(6)]])
                if pointer<BITMAP or (pointer-BITMAP)%0x2000!=0 or (pointer-BITMAP)//0x2000>=BITMAP_COUNT:
                    # This declared malformed author input overwrites the row
                    # bitmap word with41414141. Let the actual EXE dereference
                    # its unmapped value; record the fault, never map backing.
                    assert self.spec.get('authorPointerFault') and pointer==0x41414141
                    self.invalid_bitmap=pointer;self.bitmap=None
                else:self.bitmap=(pointer-BITMAP)//0x2000
            elif pc==0x43ef70:
                src=[arg(n) for n in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
                self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        assert any(a<=pc<b for a,b in ((START,END),(0x401290,0x4012ff),(0x41b390,0x41b5cf),
            (0x423940,0x423afb),(0x43ef70,0x43f2ff),(0x78130000,0x78230000))),hex(pc)

    def probe(self,spec):
        self.running=False;self.spec=spec;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.case_instructions=set()
        self.copies=[];self.copy=None;self.global_writes=[];self.global_written=bytearray(GLOBAL_SIZE);self.label_reads=[]
        self.local_writes=[];self.local_written=bytearray(LOCAL_SIZE);self.low_written=bytearray(0x38);self.retained_reads=[]
        self.fault=None;self.invalid_bitmap=None
        self.results=spec.get('results',[-2147467259,0,-1,1]);self.text_pointer=0x450e98
        self.uc.mem_write(GLOBAL,self.initial_globals);self.put(TARGET,VTABLE);self.put(SECOND_TARGET,VTABLE);self.put(VTABLE+0x14,API)
        self.bitmap_masks=[];bitmaps=[]
        for n in range(BITMAP_COUNT):
            raw=bytearray(b'\xa5'*SIZE);mask=bytearray(b'\1'*SIZE)
            struct.pack_into('<4I',raw,0,TARGET+0x100+16*n,32+n*8,48+n*16,spec.get('count',500)&0xffffffff)
            for k in range(500):
                for offset,value in ((0x10,k*3),(0x7e0,k*5),(0xfb0,8+n),(0x1780,16+n)):struct.pack_into('<i',raw,offset+4*k,value)
            for index,offset,value in spec.get('bitmapPatches',[]):
                if index==n:struct.pack_into('<I',raw,offset,value&0xffffffff)
            for index,offset,size in spec.get('undefinedBitmap',[]):
                if index==n:mask[offset:offset+size]=bytes(size)
            self.uc.mem_write(BITMAP+n*0x2000-16,b'\x96'*16+bytes(raw)+b'\x69'*16)
            self.bitmap_masks.append(mask);bitmaps.append(dict(bytes=self.blob(raw),defined=self.blob(mask)))
        for n,address in enumerate(RESOURCES):self.put(address,BITMAP+n*0x2000)
        for address,n in spec.get('resourceAliases',[]):self.put(address,BITMAP+n*0x2000)
        defaults={0x455608:TARGET,0x44d78c:800,0x44d790:600,0x451160:0,0x450bbc:12345,
            0x450bf8:1,0x450b84:0,0x44d030:0,0x451b64:10,0x451b68:20,0x451b6c:30,0x451b70:40}
        defaults.update({int(k,0):v for k,v in spec.get('globals',{}).items()})
        for p,value in defaults.items():self.put(p,value)
        for p,text in ((0x44fd18,bytes.fromhex(spec.get('author',b'<No name>'.hex()))),(0x44f900,bytes.fromhex(spec.get('info',b'<No info>'.hex())))):
            self.uc.mem_write(p,text+b'\0')
        world=bytearray(b'\xa5'*WORLD_SIZE);world[4:404]=bytes(400)
        actors=bytearray(b'\x96'*(ACTOR_SIZE*400));headers=bytearray(b'\x69'*(HEADER_SIZE*4))
        for n in range(400):
            struct.pack_into('<I',world,0x194+4*n,ACTORS+n*ACTOR_SIZE)
            struct.pack_into('<I',actors,n*ACTOR_SIZE+0x368,HEADERS+(n%4)*HEADER_SIZE)
            for offset,value in ((0x2fc,500),(0x364,1),(0x348,n*111-123),(0x34c,n*213+5),(0x350,n*313-44),(0x358,n*417+14),(0x35c,n*513-26)):
                struct.pack_into('<i',actors,n*ACTOR_SIZE+offset,value)
        for n in range(4):struct.pack_into('<I',headers,n*HEADER_SIZE+0x728,BITMAP+(len(RESOURCES)+n)*0x2000)
        for slot,flag in spec.get('active',[[0,1],[1,2],[12,255]]):world[4+slot]=flag
        for slot,n in spec.get('aliases',[]):struct.pack_into('<I',world,0x194+4*slot,ACTORS+n*ACTOR_SIZE)
        for n,offset,value in spec.get('actors',[]):struct.pack_into('<I',actors,n*ACTOR_SIZE+offset,value&0xffffffff)
        for n,offset,value in spec.get('headers',[]):struct.pack_into('<I',headers,n*HEADER_SIZE+offset,value&0xffffffff)
        for address,raw in ((WORLD,world),(ACTORS,actors),(HEADERS,headers)):self.uc.mem_write(address,bytes(raw))
        playback=bytearray(b'\x3c'*0x148);struct.pack_into('<I',playback,0x144,spec.get('recorded',54321)&0xffffffff)
        self.uc.mem_write(PLAYBACK,bytes(playback));self.put(0x4588ac,PLAYBACK)
        before_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        self.uc.mem_write(SP-0x2000,bytes((i*13+17)&255 for i in range(0x2600)))
        self.put(SP+0x64,spec.get('stageDefeated',0));self.put(SP+0x68,spec.get('indicatorTarget',SECOND_TARGET))
        low_before=bytes(self.uc.mem_read(SP+0x34,0x38));local_before=bytes(self.uc.mem_read(LOCAL,LOCAL_SIZE));cookie=bytes(self.uc.mem_read(COOKIE,4))
        for reg,value in zip(REGS,(WORLD,0x22334455,SPRINTF,0)):self.uc.reg_write(reg,value)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.running=True
        try:self.uc.emu_start(spec.get('entry',START),0,count=40_000_000)
        except UcError:
            if not self.fault:raise
        self.running=False
        if self.spec.get('authorPointerFault'):assert self.fault is not None and self.pending
        else:assert self.fault is None and self.uc.reg_read(UC_X86_REG_EIP)==END and self.uc.reg_read(UC_X86_REG_ESP)==SP and not self.pending
        assert self.uc.reg_read(UC_X86_REG_EBX)==WORLD and self.uc.reg_read(UC_X86_REG_FPCW)==0x23f
        assert self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        assert bytes(self.uc.mem_read(COOKIE,4))==cookie
        for address,raw in ((WORLD,world),(ACTORS,actors),(HEADERS,headers),(PLAYBACK,playback)):assert bytes(self.uc.mem_read(address,len(raw)))==raw
        assert self.u32(0x4588ac)==PLAYBACK and self.u32(SP+0x64)==spec.get('stageDefeated',0) and self.u32(SP+0x68)==spec.get('indicatorTarget',SECOND_TARGET)
        for n,b in enumerate(bitmaps):
            assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
            assert bytes(self.uc.mem_read(BITMAP+n*0x2000-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(BITMAP+n*0x2000+SIZE,16))==b'\x69'*16
        return dict(spec=spec,globals=self.blob(before_globals),globalsAfter=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
            world=self.blob(world),actors=self.blob(actors),headers=self.blob(headers),playback=self.blob(playback),
            localBefore=self.blob(local_before),localAfter=self.blob(self.uc.mem_read(LOCAL,LOCAL_SIZE)),localWritten=self.blob(self.local_written),
            lowBefore=self.blob(low_before),lowAfter=self.blob(self.uc.mem_read(SP+0x34,0x38)),lowWritten=self.blob(self.low_written),
            localWrites=self.local_writes,retainedReads=self.retained_reads,copies=self.copies,written=self.blob(self.global_written),writes=self.global_writes,
            bitmaps=bitmaps,events=self.events,blits=self.blits,helpers=self.helpers,instructions=sorted(self.case_instructions),
            fault=self.fault,pendingAtFault=self.pending,end=dict(pc=self.uc.reg_read(UC_X86_REG_EIP),sp=self.uc.reg_read(UC_X86_REG_ESP)))


def probes():
    yield dict(label='ordinary')
    for mode in (0,1,4):yield dict(label=f'empty-{mode}',active=[],globals={'0x451160':mode})
    yield dict(label='whole-playback',globals={'0x451160':4,'0x450b84':1,'0x44d030':1},author=b'author'.hex(),info=b'info'.hex())
    yield dict(label='skip-all',entry=INDICATORS)
    for entry,flag,replay,mode in itertools.product((START,INDICATORS),(0,1,-1),(0,1,-1),(0,1,4)):
        yield dict(label=f'gates-{entry:x}-{flag}-{replay}-{mode}',entry=entry,globals={'0x450b84':flag,'0x44d030':replay,'0x451160':mode})
    for count,choice,mode in itertools.product(range(9),('primary','fallback','both'),(0,1,4)):
        slots=list(range(count)) if choice=='primary' else list(range(10,10+count)) if choice=='fallback' else list(range(count))+list(range(10,10+count))
        yield dict(label=f'seats-{count}-{choice}-{mode}',active=[[n,[1,2,128,255][n%4]] for n in slots],globals={'0x451160':mode},actors=[[n,0x364,n%7-1] for n in slots])
    for seat in range(8):
        for fallback in (False,True):yield dict(label=f'single-{seat}-{fallback}',active=[[seat+(10 if fallback else 0),255]])
    for winner,team,hp in itertools.product((-2147483648,-1,0,1,2,5,2147483647),(-1,0,1,2,3,4,5),(-1,0,1)):
        yield dict(label=f'outcome-{winner}-{team}-{hp}',active=[[0,1]],globals={'0x450bf8':winner},actors=[[0,0x364,team],[0,0x2fc,hp]])
    for defeated,hp in itertools.product((0,1,2,0xffffffff),(-2147483648,-1,0,1,2147483647)):
        yield dict(label=f'stage-{defeated}-{hp}',active=[[12,1]],stageDefeated=defeated,globals={'0x451160':1},actors=[[12,0x2fc,hp]])
    values=(-2147483648,-2147483634,-2147483633,-1801,-1800,-1799,-46,-45,-44,-16,-15,-14,-1,0,1,14,15,16,44,45,46,1784,1785,1786,1799,1800,1801,107984,107985,107986,108000,108015,2147483632,2147483633,2147483647)
    for mode,value in itertools.product((0,4),values):
        yield dict(label=f'time-{mode}-{value}',globals={'0x451160':mode,'0x450bbc':value})
    for offset,value in itertools.product((0x358,0x348,0x34c,0x350,0x35c),(-2147483648,-100000,-101,-10,-9,-1,0,1,9,10,101,100000,2147483647)):
        yield dict(label=f'stat-{offset:x}-{value}',active=[[0,1]],actors=[[0,offset,value]])
    for n,value in itertools.product(range(4),(-2147483648,-1,0,1,2147483647)):
        yield dict(label=f'summary-{n}-{value}',globals={'0x451160':4,hex(0x451b64+4*n):value})
    for dc_result,method in itertools.product((-2147483648,-1,0,1,2147483647),(-2147483648,-1,0,1,2147483647)):
        yield dict(label=f'device-{dc_result}-{method}',dcResult=dc_result,results=[method],methodResult=method,globals={'0x451160':4,'0x450b84':1,'0x44d030':1})
    for count in (-2147483648,-1,0,1,24,25,500,2147483647):
        yield dict(label=f'bitmap-count-{count}',count=count,globals={'0x451160':4,'0x450b84':1,'0x44d030':1})
    for n,offset in itertools.product(range(BITMAP_COUNT),(0,4,8,12)):
        yield dict(label=f'undefined-{n}-{offset}',active=[[i,1] for i in range(8)],globals={'0x451160':4,'0x450b84':1,'0x44d030':1},
            actors=[[i,0x364,i%5] for i in range(8)],undefinedBitmap=[[n,offset,4]])
    for width,height in ((-2147483648,-2147483648),(-1,-1),(0,0),(1,1),(150,155),(580,550),(800,600),(2147483647,2147483647)):
        yield dict(label=f'viewport-{width}-{height}',globals={'0x44d78c':width,'0x44d790':height,'0x451160':4,'0x450b84':1,'0x44d030':1})
    yield dict(label='actor-aliases',active=[[i,1] for i in range(18)],aliases=[[i,399] for i in range(18)],actors=[[399,0x2fc,0]])
    yield dict(label='resource-aliases',globals={'0x451160':4,'0x450b84':1,'0x44d030':1},resourceAliases=[[p,2] for p in RESOURCES])
    for field in ('author','info'):
        for raw in (b'',b'A\nBC',b'\xfc\xfd\xfe\xff',b'A'*64,b'A'*127):
            yield dict(label=f'overlay-{field}-{len(raw)}-{raw[:4].hex()}',globals={'0x451160':4,'0x450b84':1,'0x44d030':1},
                **{field:raw.hex()},**({'authorPointerFault':True} if field=='author' and len(raw)==127 else {}))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);parser.add_argument('--resume',action='store_true');args=parser.parse_args()
    vm=ResultLayout();cases=[];selected=list(probes());assert len({c['label'] for c in selected})==len(selected)
    selected=selected[:args.limit];checkpoint=ROOT/'build/research/result-layout-progress.json'
    if args.resume:
        old=json.loads(checkpoint.read_bytes());assert old['exeSHA256']==EXE_SHA256 and [c['spec'] for c in old['cases']]==selected[:len(old['cases'])]
        import base64,zlib
        for key,b in old['blobs'].items():
            raw=zlib.decompress(base64.b64decode(b['deflate']));assert len(raw)==b['count'] and digest(raw)==key
        cases.extend(old['cases']);vm.blobs.update(old['blobs']);vm.instructions.update(old['instructions'])
    def document():return dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,packageSHA256=PACKAGE_SHA256,scope=__doc__,fpcw=0x23f,
        blobEncoding='zlib',bitmapBase=BITMAP,target=TARGET,indicatorTarget=SECOND_TARGET,worldBase=WORLD,actorBase=ACTORS,headerBase=HEADERS,
        formats={hex(p):fmt.hex() for p,fmt in vm.formats.items()},cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    for spec in selected[len(cases):]:
        print('START',len(cases)+1,spec['label'],flush=True);cases.append(vm.probe(spec))
        if len(cases)%20==0 or len(cases)==len(selected) or spec.get('authorPointerFault'):
            temporary=checkpoint.with_suffix('.tmp');temporary.write_text(json.dumps(document(),separators=(',',':'))+'\n');temporary.replace(checkpoint)
            print('RESULT LAYOUT',len(cases),'cases',sum(c['blits'] for c in cases),'Blts',flush=True)
    raw=(json.dumps(document(),separators=(',',':'))+'\n').encode();path=ROOT/'build/original/result-layout.json';path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
        helpers=sum(len(c['helpers']) for c in cases),events=dict(Counter(e['kind'] for c in cases for e in c['events'])),
        blits=sum(c['blits'] for c in cases),instructions=len(vm.instructions),normalReturns=sum(not c.get('fault') for c in cases),
        sourceFaults=sum(bool(c.get('fault')) for c in cases),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/result-layout.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
