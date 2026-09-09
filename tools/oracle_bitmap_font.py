#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole423940/423a70 with actual43f010/43ef70 and mutable input strings.

Controlled independent string/global/three-bitmap storage, masks, viewport and
COM Blt responses. No text/bitmap/clip helper is replaced. No real device pixels,
initialized label caller, original allocator provenance or Windows claim.
"""
import argparse
import base64
import itertools
import json
import struct
import zlib
from collections import Counter
from oracle_state import Constructors, AREA, STACK, STOP, ROOT, EXE_SHA256
from oracle_bitmap_drawing import digest, signed
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX,
    UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG)

TEXT, BITMAP, TARGET, VTABLE, API = AREA+0x20, 0x23000020, AREA+0x3000, AREA+0x3200, STOP+0x100
SP, GLOBAL, GLOBAL_SIZE, SIZE = STACK+0xf000, 0x44d000, 0xb440, 0x1f50
REGS = [UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_EDI]
HELPERS = {0x423940:0,0x423a70:0,0x43f010:24,0x43ef70:0}
FONTS = [0x44faf4,0x44f888,0x44fcbc]


class BitmapFont(Constructors):
    def __init__(self):
        self.running=False
        super().__init__()
        self.uc.mem_map(BITMAP&~0xfff,0x10000)
        self.uc.hook_add(UC_HOOK_CODE,self.code)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=BITMAP,end=BITMAP+0x5fff)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.text_read,begin=TEXT,end=TEXT+0x1fff)
        self.instructions=set();self.blobs={}
        self.initial_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))

    def put(self,p,v):self.uc.mem_write(p,struct.pack('<I',v&0xffffffff))
    def ret(self,value,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xffffffff)
        self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def blob(self,value):
        raw=bytes(value);key=digest(raw)
        if key not in self.blobs:self.blobs[key]=dict(count=len(raw),deflate=base64.b64encode(zlib.compress(raw,9)).decode())
        return key
    def event(self,kind,arguments=(),strings=(),**fields):
        self.events.append(dict(kind=kind,arguments=list(arguments),strings=[list(s) for s in strings],**fields))
    def cstring(self,p):
        assert TEXT<=p<TEXT+self.text_size
        data=bytes(self.uc.mem_read(p,TEXT+self.text_size-p));end=data.find(b'\0')
        assert end>=0;return data[:end]
    def written(self,uc,access,p,size,value,data):
        if not self.running:return
        assert TEXT<=p and p+size<=TEXT+self.text_size and size==1 and value==0
        assert uc.reg_read(UC_X86_REG_EIP)==0x423a49
        self.text_mask[p-TEXT]=1;self.text_written[p-TEXT]=1
        self.event('stringWrite',[p-self.text_pointer,0])
    def memset(self,*args):raise AssertionError('Unexpected bitmap-font memset')
    def text_read(self,uc,access,p,size,value,data):
        if not self.running:return
        assert TEXT<=p and p+size<=TEXT+self.text_size and size==1
        assert self.text_mask[p-TEXT]
        self.text_read_offsets.add(p-TEXT);self.text_read_counts[uc.reg_read(UC_X86_REG_EIP)]+=1
    def read(self,uc,access,p,size,value,data):
        if not self.running:return
        n,offset=divmod(p-BITMAP,0x2000)
        assert n==self.bitmap and 0<=n<3 and size==4 and offset+size<=SIZE,(hex(uc.reg_read(UC_X86_REG_EIP)),hex(p),n,offset)
        self.event('read',read=dict(offset=offset,value=self.u32(p),defined=all(self.bitmap_masks[n][offset:offset+4])))
    def code(self,uc,pc,size,data):
        if not self.running:return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda n:self.u32(sp+4+4*n)
        while self.pending and pc==self.pending[-1]['returnPC']:
            h=self.pending.pop();assert sp==h['sp']+4+h['pop'] and h.pop('saved')==[uc.reg_read(r) for r in REGS]
            h['returnSP']=sp;self.helpers.append(h)
            if h['entry']==0x43f010:self.bitmap=None
        if self.clip and pc==self.clip['returnPC']:
            h=self.clip;self.clip=None
            self.event('clip',clip=dict(beforeSource=h['source'],beforeDestination=h['destination'],
                source=[signed(self.u32(p)) for p in h['src']],destination=[signed(self.u32(p)) for p in h['dst']],
                visible=uc.reg_read(UC_X86_REG_EAX)==1))
        if pc==STOP:
            assert not self.pending and self.clip is None and self.bitmap is None;uc.emu_stop();return
        if pc==API:
            assert arg(0)==TARGET and arg(2) in [0,*[TARGET+0x100+16*n for n in range(3)]] and arg(5)==0
            self.event('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),
                source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),
                flags=arg(4),effects=None))
            result=self.results[self.blits%len(self.results)];self.blits+=1;self.ret(result,24);return
        # Reject a probe whose effective indexed read would consume guard or
        # neighboring storage. Do not let the arena mapping invent bitmap
        # provenance. Accepted probes below remain inside the declared record.
        if pc in (0x43f18c,0x43f190,0x43f197,0x43f19e):
            offset={0x43f18c:0x10,0x43f190:0xfb0,0x43f197:0x7e0,0x43f19e:0x1780}[pc]
            index=uc.reg_read(UC_X86_REG_EAX);effective=(4*index+offset)&0xffffffff
            assert effective<=SIZE-4,('Probe outside declared bitmap backing',hex(pc),signed(index),effective)
        self.instructions.add(pc);self.case_instructions.add(pc)
        if pc in HELPERS:
            self.pending.append(dict(entry=pc,sp=sp,pop=HELPERS[pc],returnPC=self.u32(sp),saved=[uc.reg_read(r) for r in REGS]))
        if pc==0x423940:
            assert arg(0)==self.text_pointer
            self.event('fontPass',[arg(n) for n in range(1,7)],[self.cstring(arg(0))])
        elif pc==0x43f010:
            pointer=uc.reg_read(UC_X86_REG_ECX);assert pointer>=BITMAP and (pointer-BITMAP)%0x2000==0
            self.bitmap=(pointer-BITMAP)//0x2000;assert self.bitmap<3
            self.event('draw',[pointer,*[arg(n) for n in range(6)]])
        elif pc==0x43ef70:
            assert self.clip is None
            src=[arg(n) for n in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
            self.clip=dict(returnPC=self.u32(sp),src=src,dst=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        assert any(a<=pc<=b for a,b in ((0x423940,0x423afa),(0x43f010,0x43f2fe),(0x43ef70,0x43f000))),hex(pc)

    def probe(self,spec):
        self.running=False;self.events=[];self.helpers=[];self.pending=[];self.clip=None;self.bitmap=None;self.blits=0;self.case_instructions=set()
        self.results=spec.get('results',[-2147467259,0,-1,1])
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
        before_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        text=bytes.fromhex(spec['text']);offset=spec.get('offset',16);self.text_size=max(512,offset+len(text)+65)
        assert 0<=offset and self.text_size<=0x2000
        initial=bytearray((i*17+53)&255 for i in range(self.text_size));initial[offset:offset+len(text)+1]=text+b'\0'
        self.text_mask=bytearray(self.text_size);self.text_mask[offset:offset+len(text)+1]=b'\1'*(len(text)+1)
        before_mask=bytes(self.text_mask);self.text_written=bytearray(self.text_size);self.text_read_offsets=set();self.text_read_counts=Counter()
        self.text_pointer=TEXT+offset;self.uc.mem_write(TEXT-16,b'\x96'*16+bytes(initial)+b'\x69'*16)
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for reg,value in zip(REGS,saved):self.uc.reg_write(reg,value)
        self.uc.mem_write(SP-0x1000,b'\xa5'*0x1100);self.put(SP,STOP)
        arguments=[self.text_pointer,spec.get('x',80),spec.get('y',50),spec.get('columns',8),spec.get('lines',3),spec.get('style',0),spec.get('cursor',0)]
        for n,value in enumerate(arguments):self.put(SP+4+4*n,value)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        self.running=True;self.uc.emu_start(spec['entry'],0,count=20_000_000);self.running=False
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4
        assert saved==[self.uc.reg_read(r) for r in REGS] and not self.pending
        assert self.uc.reg_read(UC_X86_REG_FPCW)==0x23f and self.uc.reg_read(UC_X86_REG_FPSW)==0 and self.uc.reg_read(UC_X86_REG_FPTAG)==0xffff
        assert bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))==before_globals
        assert bytes(self.uc.mem_read(TEXT-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(TEXT+self.text_size,16))==b'\x69'*16
        for n,b in enumerate(bitmaps):assert digest(bytes(self.uc.mem_read(BITMAP+n*0x2000,SIZE)))==b['bytes']
        return dict(spec=spec,textBefore=self.blob(initial),maskBefore=self.blob(before_mask),textAfter=self.blob(self.uc.mem_read(TEXT,self.text_size)),
            maskAfter=self.blob(self.text_mask),written=self.blob(self.text_written),textReadOffsets=sorted(self.text_read_offsets),textReadCounts=dict(self.text_read_counts),
            globals=self.blob(before_globals),bitmaps=bitmaps,events=self.events,blits=self.blits,helpers=self.helpers,
            instructions=sorted(self.case_instructions),end=dict(pc=STOP,sp=SP+4))


def probes():
    def case(label,text=b'ABCDE\nFG',**values):return dict(label=label,text=text.hex(),**values)
    for entry in (0x423940,0x423a70):
        for text,columns,lines,style,cursor in itertools.product(
                (b'',b'A',b'ABC',b'\n',b'A\nBC',b'AB\n\nCD',b'\r\t\x7f'),(-1,0,1,3,2147483647),(-1,0,1,2),(0,1,2,3),(0,1)):
            yield case(f'grid-{entry:x}-{text.hex()}-{columns}-{lines}-{style}-{cursor}',text,entry=entry,columns=columns,lines=lines,style=style,cursor=cursor)
        for text in (bytes(range(1,128)),bytes(range(128,256)),b'AB\0unread tail',b'ABCDEFGHIJK'*20):
            for style in (0,1,2,3):
                yield case(f'bytes-{entry:x}-{text[:4].hex()}-{style}',text,entry=entry,columns=300,lines=3,style=style,cursor=1,count=-2147483648 if text[0]==128 else 500)
        for axis,value in itertools.product(('x','y'),(-2147483648,-100,-1,0,1,600,800,2147483647)):
            yield case(f'position-{entry:x}-{axis}-{value}',b'ABC',entry=entry,cursor=1,**{axis:value})
        for field,value in itertools.product(('columns','lines','style'),(-2147483648,2147483647)):
            yield case(f'signed-{entry:x}-{field}-{value}',entry=entry,cursor=0xffffffff,**{field:value})
        for n,count in itertools.product(range(3),(-2147483648,-1,0,1,65,66,500,2147483647)):
            yield case(f'count-{entry:x}-{n}-{count}',b'AB',entry=entry,style=n,cursor=1,bitmapPatches=[[n,0xc,count]])
        for n,offset in itertools.product(range(3),(0,4,8,0xc,0x10+4*65,0x7e0+4*65,0xfb0+4*65,0x1780+4*65)):
            yield case(f'undefined-{entry:x}-{n}-{offset}',b'A',entry=entry,style=n,cursor=1,undefinedBitmap=[[n,offset,4]])
        for style,n in itertools.product(range(3),range(3)):
            bindings=[0,1,2];bindings[style]=n
            yield case(f'alias-{entry:x}-{style}-{n}',entry=entry,style=style,cursor=1,fontBindings=bindings)
        for width,height in ((0,0),(-1,-1),(1,1),(2147483647,2147483647)):
            yield case(f'viewport-{entry:x}-{width}-{height}',entry=entry,cursor=1,width=width,height=height)
    # Append after the original2438 cases so their complete captured records
    # can be retained unchanged. These indices reach whole-picture drawing
    # AND the original indexed fallthrough, whose reads stay within the record.
    for entry,style,undefined in itertools.product((0x423940,0x423a70),range(3),(False,True)):
        yield case(f'negative-fallthrough-{entry:x}-{style}-{undefined}',b'\xfc\xfd\xfe\xff',
            entry=entry,style=style,cursor=1,x=-1,y=0,columns=4,lines=2,
            undefinedBitmap=[[style,0,16]] if undefined else [])


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--limit',type=int);parser.add_argument('--resume',action='store_true');args=parser.parse_args()
    vm=BitmapFont();cases=[];selected=list(probes())[:args.limit]
    if args.resume:
        # Use only after confirming the prior source and comparison processes
        # terminal. Retain completed original records; remaining probes use a
        # fresh CPU and only declared before-state inputs.
        old=json.loads((ROOT/'build/original/bitmap-font.json').read_bytes())
        assert old['exeSHA256']==EXE_SHA256 and old['blobEncoding']=='zlib' and old['fpcw']==0x23f
        assert [c['spec'] for c in old['cases']]==selected[:len(old['cases'])]
        for key,b in old['blobs'].items():
            value=zlib.decompress(base64.b64decode(b['deflate']));assert len(value)==b['count'] and digest(value)==key
        cases.extend(old['cases']);vm.blobs.update(old['blobs']);vm.instructions.update(old['instructions'])
        print('RETAIN',len(cases),'hash-verified completed font cases from terminal capture',flush=True)
    for spec in selected[len(cases):]:
        cases.append(vm.probe(spec))
        if len(cases)%100==0:print('BITMAP FONT',len(cases),'cases',sum(c['blits'] for c in cases),'Blts',flush=True)
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,fpcw=0x23f,blobEncoding='zlib',bitmapBase=BITMAP,target=TARGET,
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions))
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original/bitmap-font.json';path.write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),bytes=len(raw),cases=len(cases),
        helpers=sum(len(c['helpers']) for c in cases),events=sum(len(c['events']) for c in cases),blits=sum(c['blits'] for c in cases),
        instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/bitmap-font.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)


if __name__=='__main__':main()
