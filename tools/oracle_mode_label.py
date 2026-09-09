#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole41b130/ret8 with actual mutable423a70/423940 and bitmap children.

Declared global label/bitmap backing, explicit viewport and COM Blt responses.
Unknown modes retain their initial global label, including signed byte text.
No initialized whole-tick, pixel, Windows or private caller-stack comparison.
"""
import argparse
import itertools
import json
import struct
from collections import Counter
from oracle_bitmap_font import BitmapFont, BITMAP, TARGET, VTABLE, API, SP, GLOBAL, GLOBAL_SIZE, SIZE, REGS, FONTS
from oracle_state import ROOT, STOP, EXE_SHA256
from oracle_bitmap_drawing import digest
from unicorn import UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

START, END, LABEL = 0x41b130, 0x41b387, 0x450c38


class ModeLabel(BitmapFont):
    def __init__(self):
        super().__init__()
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.global_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.label_read,begin=LABEL,end=LABEL+1023)
        self.literals={hex(p):bytes(self.uc.mem_read(p,n)).hex() for p,n in (
            (0x4490cc,9),(0x4490c0,12),(0x4490b0,16),(0x44909c,8),(0x449094,8),(0x449084,13),
            (0x4490a4,12),(0x449078,9),(0x449070,7),(0x449064,9))}

    def cstring(self,p):
        assert p==LABEL
        data=bytes(self.uc.mem_read(p,1024));end=data.find(b'\0');assert end>=0
        return data[:end]

    def label_read(self,uc,access,p,size,value,data):
        if not self.running:return
        assert p+size<=LABEL+1024
        self.label_reads.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),offset=p-LABEL,size=size))

    def global_write(self,uc,access,p,size,value,data):
        if not self.running:return
        pc=uc.reg_read(UC_X86_REG_EIP)
        assert LABEL<=p and p+size<=LABEL+1024 and size in (1,2,4)
        value&=(1<<(8*size))-1
        self.global_writes.append(dict(pc=pc,address=p,size=size,value=value))
        self.global_written[p-GLOBAL:p-GLOBAL+size]=b'\1'*size
        if pc==0x423a49:
            assert size==1 and value==0;self.event('stringWrite',[p-LABEL,0])
        else:
            assert START<=pc<END;self.event('labelWrite',[p,size,value])

    def code(self,uc,pc,size,data):
        if not self.running:return
        if START<=pc<END:
            sp=uc.reg_read(UC_X86_REG_ESP)
            while self.pending and pc==self.pending[-1]['returnPC']:
                h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[uc.reg_read(r) for r in REGS]
                h['returnSP']=sp;self.helpers.append(h)
            self.instructions.add(pc);self.case_instructions.add(pc)
            if pc==START:self.pending.append(dict(entry=START,sp=sp,pop=8,returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
            return
        super().code(uc,pc,size,data)

    def probe(self,spec):
        self.running=False;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.case_instructions=set()
        self.global_writes=[];self.global_written=bytearray(GLOBAL_SIZE);self.label_reads=[]
        self.results=spec.get('results',[-2147467259,0,-1,1]);self.text_pointer=LABEL
        self.uc.mem_write(GLOBAL,self.initial_globals);self.put(TARGET,VTABLE);self.put(VTABLE+0x14,API)
        self.bitmap_masks=[];bitmaps=[]
        for n in range(3):
            raw=bytearray(b'\xa5'*SIZE);mask=bytearray(b'\1'*SIZE)
            struct.pack_into('<4I',raw,0,TARGET+0x100+16*n,32+n*8,48+n*16,spec.get('count',500)&0xffffffff)
            for k in range(500):
                for offset,value in ((0x10,k*3),(0x7e0,k*5),(0xfb0,8+n),(0x1780,16+n)):
                    struct.pack_into('<i',raw,offset+4*k,value)
            for index,offset,value in spec.get('bitmapPatches',[]):
                if index==n:struct.pack_into('<I',raw,offset,value&0xffffffff)
            for index,offset,size in spec.get('undefinedBitmap',[]):
                if index==n:mask[offset:offset+size]=bytes(size)
            self.uc.mem_write(BITMAP+n*0x2000-16,b'\x96'*16+bytes(raw)+b'\x69'*16)
            self.bitmap_masks.append(mask);bitmaps.append(dict(bytes=self.blob(raw),defined=self.blob(mask)))
        for n,address in enumerate(FONTS):self.put(address,BITMAP+spec.get('fontBindings',[0,1,2])[n]*0x2000)
        self.put(0x455608,TARGET);self.put(0x44d78c,spec.get('width',800));self.put(0x44d790,spec.get('height',600))
        self.put(0x450b94,spec.get('stage',0));self.put(0x450c30,spec.get('difficulty',0))
        initial=bytearray((i*17+53)&255 for i in range(1024));text=bytes.fromhex(spec.get('text',b'retained '.hex()))
        assert len(text)<1000;initial[:len(text)+1]=text+b'\0';self.uc.mem_write(LABEL,bytes(initial))
        before_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for reg,value in zip(REGS,saved):self.uc.reg_write(reg,value)
        self.uc.mem_write(SP-0x1000,b'\xa5'*0x1100);self.put(SP,STOP)
        for n,value in enumerate((spec.get('mode',0),spec.get('alternate',0))):self.put(SP+4+4*n,value)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.running=True;self.uc.emu_start(START,0,count=40_000_000);self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+12
        assert saved==[self.uc.reg_read(r) for r in REGS] and not self.pending
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        for n,b in enumerate(bitmaps):assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
        return dict(spec=spec,globals=self.blob(before_globals),globalsAfter=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
            written=self.blob(self.global_written),writes=self.global_writes,labelReads=self.label_reads,bitmaps=bitmaps,events=self.events,
            blits=self.blits,helpers=self.helpers,instructions=sorted(self.case_instructions),end=dict(pc=STOP,sp=SP+12))


def probes():
    for mode,difficulty,alternate in itertools.product((-2147483648,-1,0,1,2,3,4,5,2147483647),(-1,0,1,2,3),(0,1)):
        yield dict(label=f'mode-{mode}-{difficulty}-{alternate}',mode=mode,difficulty=difficulty,alternate=alternate)
    for stage in (-2147483648,-60,-59,-50,-49,-1,0,1,49,50,51,59,60,2147483647):
        yield dict(label=f'stage-{stage}',mode=1,stage=stage,difficulty=1)
    for size in (0,1,63,64,65,127,128,255,256,257,511):
        for difficulty in (0,3):
            yield dict(label=f'retained-{size}-{difficulty}',mode=-1,difficulty=difficulty,text=(b'A'*size).hex(),alternate=0xffffffff)
    for text in (b'A\nBC',b'\n'*5,b'AB\0unread tail',b'\xfc\xfd\xfe\xff'):
        yield dict(label=f'text-{text.hex()}',mode=6,difficulty=2,text=text.hex())
    for index in range(3):
        yield dict(label=f'font-{index}',mode=4,difficulty=-1,fontBindings=[index,1,2],undefinedBitmap=[[index,0,16]])
    for count in (-2147483648,-1,0,1,32,65,66,500,2147483647):
        yield dict(label=f'count-{count}',mode=1,difficulty=2,count=count)
    for width,height in ((0,0),(-1,-1),(1,1),(790,510),(800,531),(2147483647,2147483647)):
        yield dict(label=f'viewport-{width}-{height}',mode=2,difficulty=0,width=width,height=height)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);args=parser.parse_args()
    vm=ModeLabel();cases=[]
    for spec in list(probes())[:args.limit]:
        cases.append(vm.probe(spec))
        if len(cases)%20==0:print('MODE LABEL',len(cases),'cases',sum(c['blits'] for c in cases),'Blts',flush=True)
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x23f,blobEncoding='zlib',bitmapBase=BITMAP,target=TARGET,literals=vm.literals,
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/mode-label.json';path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
        helpers=sum(len(c['helpers']) for c in cases),events=dict(Counter(e['kind'] for c in cases for e in c['events'])),
        blits=sum(c['blits'] for c in cases),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/mode-label.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
