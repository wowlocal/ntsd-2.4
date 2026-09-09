#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Controlled original gameplay output and normal422ab8/ret4 compatibility.

Pinned EXE/VC80 on one Unicorn CPU at CW023f. Execute the actual41bc90 prologue,
then the declared422994 output context: mode label/font/bitmap/clip, notice/GDI,
music volume, presentation, enabled queued sound and original normal epilogue.
Memory/register traces recover global mutation, ordered requests and restoration.
COM/GDI/PTD responses are boundaries. No damaged control pointers or cookies,
initialized intervening gameplay, host device output or Windows claim.
"""
import argparse
import json
import itertools
import struct
from collections import Counter
from oracle_playback_information import PlaybackInformation, SPRINTF
from oracle_bitmap_font import BITMAP, TARGET, VTABLE, API, SP, GLOBAL, GLOBAL_SIZE, SIZE, REGS, FONTS
from oracle_state import ROOT, STOP, EXE_SHA256, STACK
from oracle_bitmap_drawing import digest, signed
from oracle_crt import DLL_SHA256, PACKAGE_SHA256
from unicorn.x86_const import *

START, END, PROLOGUE_END = 0x422994, STOP, 0x41bcd0
COM, CTABLE, CAPI = 0x25000020, 0x25003000, STOP+0x3000
QUEUES=((400,0x457588,0x452170,0x457bc8,0x452948),(80,0x453e10,0x4554c8,0x4527e8,0x451db0))
METHODS={0:3,8:1,0x14:6,0x1c:2,0x20:2,0x2c:3,0x3c:2,0x40:2,0x48:1,0x34:2,0x30:4}
HELPERS={0x41b130:8,0x4028a0:0,0x43e940:0,0x419e60:0,0x401a30:4,0x402810:0,0x401f30:0,
         0x401290:0,SPRINTF:0,0x423940:0,0x423a70:0,0x43f010:24,0x43ef70:0,0x4450b2:0}
STAGES=(0x41b130,0x4028a0,0x43e940,0x419e60)


class GameplayOutput(PlaybackInformation):
    def __init__(self):
        super().__init__()
        self.uc.mem_map(COM&~0xfff,0x5000)
        for n in range(490):self.put(COM+16*n,CTABLE)
        self.com={CAPI+16*n:(offset,count) for n,(offset,count) in enumerate(METHODS.items())}
        for p,(offset,_) in self.com.items():self.put(CTABLE+offset,p)
        self.gdi={CAPI+0x800+16*n:name for n,name in enumerate(('setBackgroundColor','setTextColor','stringLength','textOut','getDC','releaseDC'))}
        for iat,p in ((0x44702c,CAPI+0x800),(0x447034,CAPI+0x810),(0x447084,CAPI+0x820),(0x447038,CAPI+0x830),
                      (VTABLE+0x44,CAPI+0x840),(VTABLE+0x68,CAPI+0x850)):
            self.put(iat,p)
        self.formats={p:bytes(self.uc.mem_read(p,48)).split(b'\0')[0] for p in (0x4477f0,0x4477d8,0x4477bc,0x4477a8)}
        self.prologue=False

    def cstring(self,p):
        if GLOBAL<=p<GLOBAL+GLOBAL_SIZE:extent=min(1024,GLOBAL+GLOBAL_SIZE-p)
        else:
            assert STACK<=p<STACK+0x10000,hex(p)
            extent=min(512,STACK+0x10000-p)
        raw=bytes(self.uc.mem_read(p,extent));end=raw.find(b'\0');assert end>=0
        return raw[:end]

    def global_write(self,uc,access,p,size,value,data):
        if not self.running:return
        pc=uc.reg_read(UC_X86_REG_EIP);assert not self.prologue
        assert size in (1,2,4) and GLOBAL<=p<p+size<=GLOBAL+GLOBAL_SIZE
        value&=(1<<(8*size))-1
        self.global_writes.append(dict(pc=pc,address=p,size=size,value=value))
        self.global_written[p-GLOBAL:p-GLOBAL+size]=b'\1'*size
        if 0x41b130<=pc<0x41b387:self.event('labelWrite',[p,size,value])
        elif pc==0x423a49:
            assert size==1 and value==0;self.event('stringWrite',[p-self.text_pointer,0])
        elif pc in (0x419e9f,0x419f7f):
            assert size==4 and value==0;self.event('queueWrite',[p,0])
        else:assert 0x402810<=pc<0x402a60,hex(pc)

    def code(self,uc,pc,size,data):
        if not self.running:return
        if self.prologue:
            if pc==PROLOGUE_END:uc.emu_stop();return
            assert 0x41bc90<=pc<PROLOGUE_END,hex(pc)
            self.prologue_pcs.append(pc);return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.pending and pc==self.pending[-1]['returnPC']:
            h=self.pending.pop()
            assert sp==h['sp']+4+h['pop'],h
            # 4450b2 is the compiler cookie check: it preserves the saved four
            # registers on its normal return, as do all modeled helpers.
            assert h.pop('saved')==[uc.reg_read(r) for r in REGS],h
            h['returnSP']=sp;self.helpers.append(h)
            if h['entry']==0x43f010:self.bitmap=None
            if h['entry']==SPRINTF:
                count=signed(uc.reg_read(UC_X86_REG_EAX));assert 0<=count<500
                raw=bytes(uc.mem_read(h['destination'],count+1));assert raw[-1]==0
                h.update(result=count,output=raw.hex());self.event('format',[count],[bytes(h['format']),raw[:-1]])
        if self.clip and pc==self.clip['returnPC']:
            h=self.clip;self.clip=None
            self.event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
        if pc==END:
            assert not self.pending and self.clip is None and self.bitmap is None
            uc.emu_stop();return
        if pc in self.gdi:
            name=self.gdi[pc];dc=self.input['dc']
            if name=='getDC':self.event(name,[arg(0)]);self.put(arg(1),dc);self.ret(self.input['dcResult'],8)
            elif name=='releaseDC':self.event(name,[arg(0),arg(1)]);self.ret(self.input['methodResult'],8)
            elif name in ('setBackgroundColor','setTextColor'):self.event(name,[arg(0),arg(1)]);self.ret(0xffffffff,8)
            elif name=='stringLength':raw=self.cstring(arg(0));self.event(name,[],[raw]);self.ret(len(raw),4)
            else:self.event(name,[arg(0),arg(1),arg(2),arg(4)],[bytes(uc.mem_read(arg(3),arg(4)))]);self.ret(0,20)
            return
        if pc in self.com:
            offset,count=self.com[pc];assert COM<=arg(0)<COM+490*16 and (arg(0)-COM)%16==0
            if offset==0:
                self.event('queryInterface',[arg(0)],[bytes(uc.mem_read(arg(1),16))]);self.put(arg(2),self.input['queriedAudio']);result=self.input['queryResult']
            elif offset==0x20:
                self.event('audioVolumeRead',[arg(0)]);self.put(arg(1),self.input['audioVolume']);result=self.input['audioGetResult']
            else:
                strings=[bytes(uc.mem_read(arg(1),16))] if offset==0x14 else []
                self.event('method',[arg(0),offset,*[arg(n) for n in range(1,count)]],strings)
                result=self.input['audioSetResult'] if offset==0x1c else self.input['methodResult']
            self.methods+=1;self.ret(result,4*count);return
        if pc==API:
            assert arg(0)==TARGET and arg(2) in [0,*[TARGET+0x100+16*n for n in range(3)]] and arg(5)==0
            self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
                destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=None))
            result=self.results[self.blits%len(self.results)];self.blits+=1;self.ret(result,24);return
        if pc in self.crt.boundaries:return
        if pc in (0x43f18c,0x43f190,0x43f197,0x43f19e):
            offset={0x43f18c:0x10,0x43f190:0xfb0,0x43f197:0x7e0,0x43f19e:0x1780}[pc]
            effective=(4*uc.reg_read(UC_X86_REG_EAX)+offset)&0xffffffff
            assert effective<=SIZE-4,('Bitmap access outside declared record',hex(pc),effective)
        self.instructions.add(pc);self.case_instructions.add(pc)
        if pc in STAGES:self.event('stage',[pc])
        if pc in HELPERS:
            h=dict(entry=pc,sp=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS])
            self.pending.append(h)
            if pc==SPRINTF:
                assert arg(1) in self.formats
                fmt=self.formats[arg(1)];h.update(destination=arg(0),format=list(fmt),arguments=[arg(n+2) for n in range(fmt.count(b'%'))])
            elif pc==0x423940:
                self.text_pointer=arg(0);self.event('fontPass',[arg(n) for n in range(1,7)],[self.cstring(arg(0))])
            elif pc==0x401a30:self.event('play',[uc.reg_read(UC_X86_REG_ECX),arg(0)])
            elif pc==0x43f010:
                pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer>=BITMAP and (pointer-BITMAP)%0x2000==0
                self.bitmap=(pointer-BITMAP)//0x2000;assert self.bitmap<3
                self.event('draw',[pointer,*[arg(n) for n in range(6)]])
            elif pc==0x43ef70:
                src=[arg(n) for n in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
                self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        assert any(a<=pc<b for a,b in ((START,0x4229cc),(0x422a95,0x422abb),(0x41b130,0x41b387),
            (0x401290,0x4012ff),(0x401f30,0x402000),(0x402810,0x402a60),(0x43e940,0x43e99f),
            (0x419e60,0x41a044),(0x401a30,0x401a72),(0x423940,0x423afb),(0x43ef70,0x43f2ff),
            (0x4450b2,0x4450bd),(0x78130000,0x78230000))),hex(pc)

    def probe(self,spec):
        self.running=False;self.spec=spec;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.methods=0;self.case_instructions=set()
        self.global_writes=[];self.global_written=bytearray(GLOBAL_SIZE);self.label_reads=[];self.text_pointer=0x450c38
        self.input=dict(targetSurface=TARGET,methodResult=-2147467259,queryResult=0,audioGetResult=0,audioSetResult=-1,
            queriedAudio=COM+16*483,audioVolume=-1234,dcResult=0,dc=0x76543210,postResult=0)
        self.input.update(spec.get('input',{}));self.results=spec.get('results',[-2147467259,0,-1,1])
        self.uc.mem_write(GLOBAL,self.initial_globals);self.put(TARGET,VTABLE);self.put(VTABLE+0x14,API)
        self.bitmap_masks=[];bitmaps=[]
        for n in range(3):
            raw=bytearray(b'\xa5'*SIZE);mask=bytearray(b'\1'*SIZE)
            struct.pack_into('<4I',raw,0,TARGET+0x100+16*n,32+n*8,48+n*16,spec.get('count',500)&0xffffffff)
            for k in range(500):
                for offset,value in ((0x10,k*3),(0x7e0,k*5),(0xfb0,8+n),(0x1780,16+n)):struct.pack_into('<i',raw,offset+4*k,value)
            for index,offset,size in spec.get('undefinedBitmap',[]):
                if index==n:mask[offset:offset+size]=bytes(size)
            self.uc.mem_write(BITMAP+n*0x2000-16,b'\x96'*16+bytes(raw)+b'\x69'*16)
            self.bitmap_masks.append(mask);bitmaps.append(dict(bytes=self.blob(raw),defined=self.blob(mask)))
        for n,p in enumerate(FONTS):self.put(p,BITMAP+n*0x2000)
        defaults={0x455608:TARGET,0x44d78c:800,0x44d790:600,0x451160:0,0x450b84:0,0x450c30:1,0x450b94:0,
            0x44d000:50,0x44f190:0,0x450b70:0,0x450b6c:0,0x450bfc:0,0x458348:3,0x44eecc:COM+16*480,
            0x455634:COM+16*481,0x453e0c:COM+16*482,0x44f040:COM+16*484}
        defaults.update({p:COM+16*(485+n) for n,p in enumerate(range(0x45560c,0x455620,4))})
        defaults.update({int(k,0):v for k,v in spec.get('globals',{}).items()})
        for p,v in defaults.items():self.put(p,v)
        self.uc.mem_write(0x4553f2,bytes(spec.get('keys',[0x75,0x75])))
        self.uc.mem_write(0x453ccc,struct.pack('<4i',-7,20,807,563))
        for p,text in ((0x450c38,b'retained '),(0x44fd98,bytes.fromhex(spec.get('name',b'Naruto-Sasuke.lfr'.hex())))):
            assert len(text)<200;self.uc.mem_write(p,text+b'\0')
        for group,(count,pending,first,second,buffers) in enumerate(QUEUES):
            for n in range(count):
                self.put(pending+4*n,0);self.put(first+4*n,70);self.put(second+4*n,30);self.put(buffers+4*n,COM+16*(n+(400 if group else 0)))
        for group,n,flag,right,left in spec.get('slots',[[0,6,1,70,30],[1,2,1,20,80]]):
            count,pending,first,second,buffers=QUEUES[group];assert 0<=n<count
            self.put(pending+4*n,flag);self.put(first+4*n,right);self.put(second+4*n,left)
        before=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));resources=bytes(self.uc.mem_read(COM&~0xfff,0x5000))
        self.uc.mem_write(SP-0x3000,b'\xa5'*0x3800)
        entry_sp=SP+0x624;seh=0x12345678;saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        self.put(entry_sp,END);self.put(entry_sp+4,TARGET);self.put(0,seh)
        for r,v in zip(REGS,saved):self.uc.reg_write(r,v)
        self.uc.reg_write(UC_X86_REG_ESP,entry_sp);self.uc.reg_write(UC_X86_REG_FPCW,0x23f);self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.prologue_pcs=[];self.running=True;self.prologue=True;self.uc.emu_start(0x41bc90,0,count=1000);self.prologue=False
        body_sp=self.uc.reg_read(UC_X86_REG_ESP);assert body_sp==SP-4,(hex(body_sp),hex(SP))
        self.uc.reg_write(UC_X86_REG_EBX,0x24000000)
        self.uc.emu_start(START,0,count=40_000_000);self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==END and self.uc.reg_read(UC_X86_REG_ESP)==entry_sp+8
        assert saved==[self.uc.reg_read(r) for r in REGS] and self.u32(0)==seh
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        assert bytes(self.uc.mem_read(COM&~0xfff,0x5000))==resources
        for n,b in enumerate(bitmaps):assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
        return dict(spec=spec,input=self.input,globals=self.blob(before),globalsAfter=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
            written=self.blob(self.global_written),writes=self.global_writes,bitmaps=bitmaps,events=self.events,blits=self.blits,methods=self.methods,
            helpers=self.helpers,instructions=sorted(self.case_instructions),prologue=self.prologue_pcs,
            abi=dict(entrySP=entry_sp,bodySP=body_sp,returnSP=entry_sp+8,saved=saved,restoredSEH=seh,returnPC=END))


def probes():
    yield dict(label='ordinary')
    yield dict(label='volume-before-sound',keys=[0x75,0x64])
    yield dict(label='notice-and-sound',globals={'0x450b70':2})
    for mode,alternate in itertools.product((-1,0,1,2,3,4,5),(0,1)):
        yield dict(label=f'label-{mode}-{alternate}',globals={'0x451160':mode,'0x450b84':alternate,'0x450b94':50})
    for notice,timer,block in itertools.product((-1,0,1,2,3,4),(-1,0,239,240,241,2147483647),(0,1)):
        yield dict(label=f'notice-{notice}-{timer}-{block}',globals={'0x450b70':notice,'0x450b6c':timer,'0x450bfc':block,'0x44f190':2})
    for level,keys in itertools.product((-2147483648,-1,0,1,50,99,100,101,2147483647),([0x75,0x75],[0x64,0x75],[0x75,0x64],[0x64,0x64])):
        yield dict(label=f'volume-{level}-{keys}',keys=keys,globals={'0x44d000':level,'0x44f190':1})
    for key,value in itertools.product(('queryResult','audioGetResult','audioSetResult','dcResult','methodResult'),(-2147467259,-1,0,1)):
        yield dict(label=f'response-{key}-{value}',keys=[0x75,0x64],input={key:value},globals={'0x450b70':1})
    for mode,device in itertools.product((-1,0,1,2,3,4),(0,1)):
        yield dict(label=f'present-{mode}-{device}',globals={'0x458348':mode,'0x44eecc':COM+16*480 if device else 0})
    for right,left,flag in ((-1,0,1),(0,0,1),(50,50,-1),(50,50,0),(1,0,1),(2147483647,1,1),(-2147483648,-1,2),(1431656,0,1),(70,30,2147483647)):
        yield dict(label=f'queue-{right}-{left}-{flag}',keys=[0x75,0x64],slots=[[0,0,flag,right,left],[0,399,flag,right,left],[1,0,flag,right,left],[1,79,flag,right,left]])
    yield dict(label='all-queues',slots=[[g,n,1,70,30] for g,count in ((0,400),(1,80)) for n in range(count)])
    for n in range(3):yield dict(label=f'undefined-font-{n}',undefinedBitmap=[[n,0,16]])


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);args=parser.parse_args()
    vm=GameplayOutput();cases=[]
    for spec in list(probes())[:args.limit]:
        print('START',len(cases)+1,spec['label'],flush=True);cases.append(vm.probe(spec))
    doc=dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,packageSHA256=PACKAGE_SHA256,scope=__doc__,fpcw=0x23f,
        blobEncoding='zlib',bitmapBase=BITMAP,target=TARGET,cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();name='gameplay-output-controlled'
    (ROOT/'build/original'/f'{name}.json').write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,scope=__doc__,corpus=f'{name}.json',sha256=digest(raw),bytes=len(raw),cases=len(cases),
        events=dict(Counter(e['kind'] for c in cases for e in c['events'])),helpers=sum(len(c['helpers']) for c in cases),instructions=len(vm.instructions),
        nativeCompared=False,initializedWholeTick=False,windowsVerified=False)
    (ROOT/'build/research'/f'{name}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
