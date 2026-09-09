#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole41b390/ret12 with actual VC80 sprintf and mutable bitmap-font children.

EXE and CRT share one controlled CPU, C-locale PTD and CW023f. Declared global
text/bitmap backing and COM responses. No whole-tick, pixels or Windows claim.
"""
import argparse
import itertools
import json
import struct
from collections import Counter
from oracle_mode_label import ModeLabel
from oracle_bitmap_font import BitmapFont, BITMAP, TARGET, VTABLE, API, SP, GLOBAL, GLOBAL_SIZE, SIZE, REGS, FONTS
from oracle_state import ROOT, STOP, EXE_SHA256
from oracle_bitmap_drawing import digest, signed
from oracle_crt import CRT, DLL_SHA256, PACKAGE_SHA256, prepare, AREA as CRT_AREA
from inspect_original import PE
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_ESI, UC_X86_REG_EDI,
    UC_X86_REG_ECX, UC_X86_REG_EFLAGS, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

START, END, LABEL, SPRINTF = 0x41b390, 0x41b5cf, 0x450c38, 0x7817775d
FORMAT_ADDRESSES = (0x44910c,0x4490fc,0x4490ec,0x4490d8)


class PlaybackInformation(ModeLabel):
    def __init__(self):
        super().__init__()
        crt=CRT();pe=PE(prepare().read_bytes())
        self.uc.mem_map(pe.base,0x100000);self.uc.mem_write(pe.base,bytes(crt.uc.mem_read(pe.base,0x100000)))
        self.uc.mem_map(CRT_AREA,0x20000);self.uc.mem_write(CRT_AREA,bytes(crt.uc.mem_read(CRT_AREA,0x20000)))
        self.uc.mem_map(0,0x1000);self.uc.mem_map(STOP+0x1000,0xf000)
        crt.uc=self.uc;crt.boundaries={a:n for a,n in crt.boundaries.items() if not STOP<=a<STOP+0x10000}
        for i,item in enumerate(pe.imports()):
            address=STOP+0x6000+16*i;self.put(int(item['iatVA'],16),address);crt.boundaries[address]=item['name']
        for address in crt.boundaries:self.uc.hook_add(UC_HOOK_CODE,crt.boundary,begin=address,end=address)
        self.crt=crt;self.put(0x447174,SPRINTF)
        self.formats={p:bytes(self.uc.mem_read(p,40)).split(b'\0')[0] for p in FORMAT_ADDRESSES}
        self.literals={hex(p):bytes(self.uc.mem_read(p,n)).hex() for p,n in ((0x449134,10),(0x44912c,8),(0x449120,10),(0x449118,8))}
        self.copies=[];self.copy=None

    def cstring(self,p):
        assert GLOBAL<=p<GLOBAL+GLOBAL_SIZE
        data=bytes(self.uc.mem_read(p,min(1024,GLOBAL+GLOBAL_SIZE-p)));end=data.find(b'\0');assert end>=0
        return data[:end]

    def global_write(self,uc,access,p,size,value,data):
        if not self.running:return
        pc=uc.reg_read(UC_X86_REG_EIP)
        assert GLOBAL<=p and p+size<=GLOBAL+GLOBAL_SIZE and size in (1,4)
        assert START<=pc<END or pc==0x423a49 or 0x78130000<=pc<0x78230000
        value&=(1<<(8*size))-1
        self.global_writes.append(dict(pc=pc,address=p,size=size,value=value))
        self.global_written[p-GLOBAL:p-GLOBAL+size]=b'\1'*size
        if pc==0x423a49:
            assert size==1 and value==0;self.event('stringWrite',[p-self.text_pointer,0])
        else:self.event('infoWrite',[p,size,value])

    def code(self,uc,pc,size,data):
        if not self.running:return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        # The small caller REP copies are separately checked from raw hooks.
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
        if START<=pc<END or 0x78130000<=pc<0x78230000:
            while self.pending and pc==self.pending[-1]['returnPC']:
                h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[uc.reg_read(r) for r in REGS]
                h['returnSP']=sp
                if h['entry']==SPRINTF:
                    count=signed(uc.reg_read(UC_X86_REG_EAX));assert 0<=count<100
                    raw=bytes(uc.mem_read(h['destination'],count+1));assert raw[-1]==0
                    self.event('format',[count],[bytes(h['format']),raw[:-1]])
                    h['result']=count;h['output']=raw.hex()
                self.helpers.append(h)
            if pc in self.crt.boundaries:return
            self.instructions.add(pc);self.case_instructions.add(pc)
            if pc in (START,SPRINTF):
                h=dict(entry=pc,sp=sp,pop=12 if pc==START else 0,returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS])
                if pc==SPRINTF:
                    assert arg(0) in (0x450e30,0x450e98) and arg(1) in self.formats
                    fmt=self.formats[arg(1)];h.update(destination=arg(0),format=list(fmt),arguments=[signed(arg(n+2)) for n in range(fmt.count(b'%'))])
                self.pending.append(h)
            return
        if pc in self.crt.boundaries:return
        if pc==0x423a70:self.event('infoText',[arg(0)])
        if pc==0x423940:self.text_pointer=arg(0)
        BitmapFont.code(self,uc,pc,size,data)

    def probe(self,spec):
        self.running=False;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.case_instructions=set()
        self.copies=[];self.copy=None;self.global_writes=[];self.global_written=bytearray(GLOBAL_SIZE);self.label_reads=[]
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
        for p,default,field,extent in ((0x44fd18,b'<No name>','author',128),(0x44f900,b'<No info>','info',400)):
            text=bytes.fromhex(spec.get(field,default.hex()));assert len(text)<extent
            initial=bytearray((i*17+53)&255 for i in range(extent));initial[:len(text)+1]=text+b'\0'
            self.uc.mem_write(p,bytes(initial))
        for p in (0x450e30,0x450e98,0x450f60):self.uc.mem_write(p,b'\xa5'*100)
        before_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for reg,value in zip(REGS,saved):self.uc.reg_write(reg,value)
        self.uc.mem_write(SP-0x1000,b'\xa5'*0x1100);self.put(SP,STOP)
        for n,value in enumerate((spec.get('mode',0),spec.get('recorded',0),spec.get('current',0))):self.put(SP+4+4*n,value)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.running=True;self.uc.emu_start(START,0,count=40_000_000);self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+16
        assert saved==[self.uc.reg_read(r) for r in REGS] and not self.pending
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        for n,b in enumerate(bitmaps):assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
        return dict(spec=spec,globals=self.blob(before_globals),globalsAfter=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
            copies=self.copies,written=self.blob(self.global_written),writes=self.global_writes,labelReads=self.label_reads,bitmaps=bitmaps,events=self.events,
            blits=self.blits,helpers=self.helpers,instructions=sorted(self.case_instructions),end=dict(pc=STOP,sp=SP+16))


def probes():
    for mode,author,info in itertools.product((0,4), (b'<No name>',b'author'),(b'<No info>',b'info')):
        yield dict(label=f'labels-{mode}-{author.hex()}-{info.hex()}',mode=mode,author=author.hex(),info=info.hex(),current=12345,recorded=54321)
    values=(-2147483648,-2147483634,-2147483633,-1801,-1800,-1799,-46,-45,-44,-16,-15,-14,-1,0,1,14,15,16,44,45,46,1784,1785,1786,1799,1800,1801,107984,107985,107986,108000,108015,2147483632,2147483633,2147483647)
    for n,value in enumerate(values):
        for field in ('current','recorded'):
            yield dict(label=f'time-{field}-{value}',mode=n%5,**{field:value})
    for field in ('author','info'):
        for text in (b'',b'<No name>\0tail',b'<No info>\0tail',b'A\nBC',b'\n'*5,b'\xfc\xfd\xfe\xff',b'A'*63,b'A'*64,b'A'*65,b'A'*127):
            yield dict(label=f'text-{field}-{text[:10].hex()}-{len(text)}',mode=4,**{field:text.hex()})
    for size in (128,255,256,257,399):yield dict(label=f'info-size-{size}',info=(b'A'*size).hex())
    for width,height in ((0,0),(-1,-1),(1,1),(80,150),(800,510),(2147483647,2147483647)):
        yield dict(label=f'viewport-{width}-{height}',author=b'author'.hex(),info=b'info'.hex(),width=width,height=height)
    for count in (-2147483648,-1,0,1,48,58,500,2147483647):yield dict(label=f'count-{count}',count=count,current=2147483647,recorded=2147483632)
    for n in range(3):yield dict(label=f'font-{n}',fontBindings=[n,1,2],undefinedBitmap=[[n,0,16]])


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);args=parser.parse_args()
    vm=PlaybackInformation();cases=[]
    for spec in list(probes())[:args.limit]:
        cases.append(vm.probe(spec))
        if len(cases)%20==0:print('PLAYBACK INFORMATION',len(cases),'cases',sum(c['blits'] for c in cases),'Blts',flush=True)
    doc=dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,packageSHA256=PACKAGE_SHA256,scope=__doc__,fpcw=0x23f,blobEncoding='zlib',bitmapBase=BITMAP,target=TARGET,
        literals=vm.literals,formats={hex(p):fmt.hex() for p,fmt in vm.formats.items()},cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/playback-information.json';path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
        helpers=sum(len(c['helpers']) for c in cases),events=dict(Counter(e['kind'] for c in cases for e in c['events'])),
        blits=sum(c['blits'] for c in cases),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/playback-information.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
