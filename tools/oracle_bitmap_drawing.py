#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Whole43f010/43ef70 and real43ee50 for34 original embedded resources.
Supplied bitmap backing/control metadata, viewport and COM responses. Compare
all reads/provenance, clipping, Blt rectangles/flags/100-byte effects, actual
returns and unchanged bitmap/globals. No DirectDraw raster, full menu or Windows
allocator provenance claim. Stop BEFORE invalid bitmap/target dereferences.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256
from inspect_original import PE
from oracle_state import Constructors, AREA, STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_EDX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_ESP, UC_X86_REG_EIP

BITMAP, SOURCE, TARGET, VTABLE = AREA+0x20, AREA+0x3000, AREA+0x3100, AREA+0x3200
SP, API, GLOBAL, GLOBAL_SIZE, SIZE = STACK+0xF000, STOP+0x100, 0x44D000, 0xB440, 0x1F50
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
PATHS=['CHARMENU','CM1','CM2','CM3','CM4','CM5','CMA','CMA2','CMC','RFACE','SPARK',
       'PAUSE','DEMO','SCORE_BOARD1','SCORE_BOARD2','SCORE_BOARD3','SCORE_BOARD4','WIN_ALIVE','WIN_DEAD','LOSE_DEAD','BARS',
       *[f'MENU_BACK{i}' for i in range(1,14)]]

def digest(raw):return hashlib.sha256(raw).hexdigest()
def packed(raw):return dict(count=len(raw),sha256=digest(raw),deflate=base64.b64encode(zlib.compress(raw,9,wbits=-15)).decode())
def signed(x):return (x+0x80000000)%0x100000000-0x80000000


class BitmapDrawing(Constructors):
    def __init__(self):
        super().__init__();self.target=BITMAP;self.size=SIZE;self.drawing=False;self.constructing=False
        self.blobs={};self.setups=[];self.cases=[];self.sources={};self.current=-1
        self.pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes())
        self.resources={r['path'][1]:r for r in self.pe.resources() if r['path'][0]==2}
        self.put(SOURCE,VTABLE);self.put(TARGET,VTABLE)
        self.put(0x457578,SOURCE) # Supplied43ee50 graphics-device input.
        for at,to in [(VTABLE+0x14,API),(VTABLE+0x74,API+0x10),(VTABLE+8,API+0x20),
                      (0x4471C8,API+0x30),(0x447080,API+0x40)]:self.put(at,to)
        self.uc.hook_add(UC_HOOK_CODE,self.code)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.read,begin=AREA,end=AREA+0x3FFF)

    def put(self,address,value):self.uc.mem_write(address,struct.pack('<I',value&0xFFFFFFFF))
    def ret(self,value=0,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def blob(self,raw):
        raw=bytes(raw);h=digest(raw)
        if h not in self.blobs:self.blobs[h]=packed(raw)
        return h
    def record(self):return dict(bytes=self.blob(self.uc.mem_read(BITMAP,SIZE)),defined=self.blob(bytes(self.mask)))
    def cstr(self,address):
        raw=bytearray()
        while self.uc.mem_read(address,1)!=b'\0':raw.extend(self.uc.mem_read(address,1));address+=1
        return bytes(raw)
    def event(self,kind,args=(),strings=()):self.constructor_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))
    def read(self,uc,access,address,size,value,data):
        if not self.drawing or not BITMAP<=address<BITMAP+SIZE:return
        assert size==4 and address+size<=BITMAP+SIZE
        i=address-BITMAP;self.reads.append(dict(offset=i,value=self.u32(address),defined=all(self.mask[i:i+4])))
    def memset(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP);dst,value,count=[self.u32(sp+i) for i in (4,8,12)]
        assert self.drawing and STACK<=dst<dst+count<=STACK+0x10000 and value==0 and count==100
        uc.mem_write(dst,bytes(count));self.ret(dst)
    def code(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
        if address==STOP:uc.emu_stop();return
        if self.constructing:
            if address==0x43ED10:
                assert self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode()==self.resource['path']
                assert [arg(i) for i in range(3)]==[SOURCE,0x40,0]
                self.event('load',[SOURCE,0x40,0],[self.resource['path'].encode()])
                if self.surface:
                    for pointer,value in [(arg(3),self.resource['width']),(arg(4),self.resource['height'])]:
                        i=pointer-BITMAP;assert i in (4,8);self.put(pointer,value);self.mask[i:i+4]=[True]*4
                self.ret(self.surface);return
            if address==API+0x10:
                assert [arg(0),arg(1)]==[self.surface,8] and bytes(uc.mem_read(arg(2),8))==bytes(8)
                self.event('colorKey',[arg(0),arg(1)],[bytes(8)]);self.ret(self.key_result,12);return
            if address==API+0x20:self.event('release',[arg(0)]);self.ret(17,4);return
            if address==API+0x30:self.event('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16);return
            if address==API+0x40:self.event('debug',strings=[self.cstr(arg(0))]);self.ret(0x87654321,4);return
            assert 0x43EE50<=address<=0x43EF41 or 0x4450B2<=address<=0x4450BA,hex(address)
            return
        assert self.drawing,hex(address)
        # These effective addresses are checked BEFORE the original load. The
        # mapped guard/device arena must not make an invalid wrapper read valid.
        if address in (0x43F18C,0x43F190,0x43F197,0x43F19E,0x43F272,0x43F27A):
            offset={0x43F18C:0x10,0x43F190:0xFB0,0x43F197:0x7E0,0x43F19E:0x1780,0x43F272:0x10,0x43F27A:0xFB0}[address]
            index=uc.reg_read(UC_X86_REG_ECX if address in (0x43F272,0x43F27A) else UC_X86_REG_EAX)
            offset=(4*index+offset)&0xFFFFFFFF
            if offset>SIZE-4:self.boundary=dict(kind='outsideBitmap',offset=offset,pc=address);uc.emu_stop();return
        if address in (0x43F12B,0x43F2E6) and uc.reg_read(UC_X86_REG_EAX)==0:
            self.boundary=dict(kind='nullTarget',offset=0,pc=address);uc.emu_stop();return
        if self.pending_clip and address==self.pending_clip['returnAddress']:
            c=self.pending_clip;self.pending_clip=None
            assert sp==c['sp']+4 and c['saved']==[uc.reg_read(r) for r in REGISTERS]
            self.clips.append(dict(beforeSource=c['source'],beforeDestination=c['destination'],
                source=[signed(self.u32(p)) for p in c['sourcePointers']],destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
            assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
        if address==0x43EF70:
            assert self.pending_clip is None
            source=[arg(i) for i in range(4)];destination=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
            self.pending_clip=dict(sp=sp,returnAddress=self.u32(sp),saved=[uc.reg_read(r) for r in REGISTERS],sourcePointers=source,destinationPointers=destination,
                                   source=[signed(self.u32(p)) for p in source],destination=[signed(self.u32(p)) for p in destination])
        if address==API:
            assert arg(0)==TARGET and arg(2) in (0,SOURCE)
            event=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
                       destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=list(uc.mem_read(arg(5),100)) if arg(5) else None)
            self.blits.append(event);self.ret(self.results[(len(self.blits)-1)%len(self.results)],24);return
        assert 0x43F010<=address<=0x43F2FE or 0x43EF70<=address<=0x43F000 or address==0x4450A0,hex(address)

    def registers(self,args):
        saved=[0x11223344,0x22334455,0x33445566,0x44556677]
        for r,v in zip(REGISTERS,saved):self.uc.reg_write(r,v)
        self.uc.reg_write(UC_X86_REG_ECX,BITMAP);self.uc.reg_write(UC_X86_REG_ESP,SP)
        self.put(SP,STOP)
        for i,v in enumerate(args):self.put(SP+4+i*4,v)
        return saved
    def setup(self,label,pattern='a5',resource=None,missing=False,key=0,writes=()):
        backing=bytes(i%256 for i in range(SIZE)) if pattern=='ramp' else bytes([0xA5])*SIZE
        self.initial=backing;self.mask=[False]*SIZE;self.writes=[]
        self.uc.mem_write(BITMAP-16,b'\x96'*16+backing+b'\x69'*16)
        self.resource=None;self.constructor_events=[];constructor=None
        if resource:
            desc=self.resources[resource];raw=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']]
            width,height=struct.unpack_from('<ii',raw,4);self.sources[resource]=dict(path=resource,width=width,height=height,dib=self.blob(raw))
            self.resource=dict(path=resource,present=not missing,width=None if missing else width,height=None if missing else height)
            self.surface=0 if missing else SOURCE;self.key_result=key
            self.uc.mem_write(STACK+0x100,resource.encode()+b'\0')
            saved=self.registers([0x40,STACK+0x100,0]);self.constructing=True
            try:self.uc.emu_start(0x43EE50,STOP,count=10000)
            finally:self.constructing=False
            assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+16
            assert self.uc.reg_read(UC_X86_REG_EAX)==BITMAP and saved==[self.uc.reg_read(r) for r in REGISTERS]
            constructor=dict(resource=self.resource,surface=self.surface,colorKeyResult=key,events=self.constructor_events)
        else:writes=[(0,SOURCE),(4,120),(8,90),*writes]
        stimuli=[]
        for offset,value in writes:
            assert 0<=offset<=SIZE-4
            self.put(BITMAP+offset,value);self.mask[offset:offset+4]=[True]*4;stimuli.append(dict(offset=offset,value=value&0xFFFFFFFF))
        self.current=len(self.setups)
        self.setups.append(dict(label=label,backing=self.blob(backing),constructor=constructor,writes=stimuli,storage=self.record()))
        return self.current
    def step(self,label,frame=0,x=0,y=0,key=1,mirror=0,viewport=(794,550),results=(0,),target=TARGET):
        self.put(0x44D78C,viewport[0]);self.put(0x44D790,viewport[1]);before_globals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));before=self.record()
        saved=self.registers([x,y,frame,key,mirror,target]);self.reads=[];self.clips=[];self.blits=[];self.pending_clip=None;self.results=results;self.boundary=None
        self.drawing=True
        try:self.uc.emu_start(0x43F010,STOP,count=10000)
        except Exception:
            print('DRAW FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.reads[-3:],self.blits[-1:],flush=True);raise
        finally:self.drawing=False
        pc=self.uc.reg_read(UC_X86_REG_EIP);sp=self.uc.reg_read(UC_X86_REG_ESP)
        if self.boundary is None:assert pc==STOP and sp==SP+28 and saved==[self.uc.reg_read(r) for r in REGISTERS]
        else:assert pc==self.boundary['pc']
        assert self.pending_clip is None and before==self.record() and before_globals==bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        assert bytes(self.uc.mem_read(BITMAP-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(BITMAP+SIZE,16))==b'\x69'*16
        self.cases.append(dict(label=label,setup=self.current,input=dict(x=x,y=y,frame=frame,colorKey=key,mirrored=mirror,sourceSurface=self.u32(BITMAP),targetSurface=target,viewportWidth=viewport[0],viewportHeight=viewport[1]),
            responses=list(results),reads=self.reads,clips=self.clips,blits=self.blits,boundary=self.boundary,endPC=pc,endSP=sp,returnValue=signed(self.uc.reg_read(UC_X86_REG_EAX)),
            beforeGlobals=self.blob(before_globals),afterGlobals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),after=self.record()))

    def capture(self):
        for pattern in ('a5','ramp'):
            for path in PATHS:
                self.setup(f'{pattern}-{path}',pattern,resource=path)
                for frame in (-1,0,1,19,499):
                    for mirror in (0,1):
                        for xy in ((0,0),(-17,-23),(793,549)):
                            self.step(f'{pattern}-{path}-{frame}-{mirror}-{xy}',frame=frame,x=xy[0],y=xy[1],mirror=mirror,results=(-1,1))
            for missing,key in ((True,0),(False,-1),(False,1),(False,-2147483648)):
                self.setup(f'{pattern}-device-{missing}-{key}',pattern,resource='SPARK',missing=missing,key=key)
                for frame in (-1,0,19):self.step(f'device-{pattern}-{missing}-{key}-{frame}',frame=frame)
        # Supplied metadata controls: not a claim that any loader created these.
        geometry=[(0x0c,1),(0x10,17),(0x7e0,23),(0xfb0,61),(0x1780,48)]
        self.setup('frame-clipping',writes=geometry)
        xs=(-2147483648,-62,-61,-60,-1,0,1,733,734,794,795,2147483647)
        ys=(-2147483648,-49,-48,-47,-1,0,1,502,503,550,551,2147483647)
        for x in xs:
            for y in ys:
                for mirror in (0,1):self.step(f'frame-clip-{x}-{y}-{mirror}',x=x,y=y,mirror=mirror)
        for viewport in ((0,0),(-1,-1),(1,1),(2147483647,2147483647),(-2147483648,-2147483648),(-1,550),(794,-1)):
            for xy in ((0,0),(-1,-1),(1,1),(793,549),(-2147483648,2147483647)):
                for mirror in (0,1):self.step(f'viewport-{viewport}-{xy}-{mirror}',x=xy[0],y=xy[1],viewport=viewport,mirror=mirror)
        for flag in (0,1,2,0x80000000,0xFFFFFFFF):
            for mirror in (0,1,2,0x80000000,0xFFFFFFFF):
                for result in (-2147483648,-1,0,1,2147483647):self.step(f'flags-{flag}-{mirror}-{result}',x=-17,y=-23,key=flag,mirror=mirror,results=(result,))
        for width,height in ((0,0),(-1,-1),(1,1),(-2147483648,2147483647),(2147483647,-2147483648),(61,-48),(-61,48)):
            self.setup(f'inverted-{width}-{height}',writes=geometry+[(0xfb0,width),(0x1780,height)])
            for xy in ((0,0),(-1,-1),(794,550),(2147483647,-2147483648)):
                for mirror in (0,1):self.step(f'inverted-{width}-{height}-{xy}-{mirror}',x=xy[0],y=xy[1],mirror=mirror)
        # Negative/wrapped indices alias actual words inside the same wrapper.
        for count in (-2147483648,-1,0,1,500,501,2147483647):
            writes=[*geometry,(0x0c,count),(0x7dc,7),(0xfac,60),(0x177c,80),
                    (0x7d8,11),(0xfa8,50),(0x1778,70),(0x7d4,13),(0xfa4,40),(0x1774,60),(0x7d0,17),(0xfa0,30),(0x1770,50)]
            self.setup(f'indices-{count}',writes=writes)
            for frame in (-2147483648,-5,-4,-3,-2,-1,0,1,499,500,501,0x40000000,0x40000001,2147483646,2147483647):
                for mirror in (0,1):self.step(f'indices-{count}-{frame}-{mirror}',frame=frame,x=-1,y=-1,mirror=mirror,results=(-1,2147483647))
        # Whole-image branch clips its source BEFORE mirroring, without the
        # per-frame horizontal correction. It still falls through to frame test.
        for width,height in ((120,90),(0,0),(-1,-1),(2147483647,-2147483648)):
            self.setup(f'whole-{width}-{height}',writes=[(0x0c,-1),(4,width),(8,height)])
            for x in xs:
                for y in ys:
                    for mirror in (0,1):self.step(f'whole-{width}-{height}-{x}-{y}-{mirror}',frame=-1,x=x,y=y,mirror=mirror,results=(-1,))
        self.setup('null-target',writes=geometry)
        for frame in (-1,0,1):
            for x in (0,-1000):self.step(f'null-target-{frame}-{x}',frame=frame,x=x,target=0)
        return dict(exeSHA256=EXE_SHA256,scope=__doc__,sources=list(self.sources.values()),setups=self.setups,cases=self.cases,blobs=self.blobs)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--accept',action='store_true');args=parser.parse_args()
    report_path=ROOT/'docs/evidence/bitmap-drawing.json';raw_path=ROOT/'build/original/bitmap-drawing.json'
    if args.accept:
        r=json.loads(report_path.read_bytes());raw=raw_path.read_bytes();assert digest(raw)==r['sha256']
        data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temporary=ROOT/'build/original/bitmap-drawing-check.json';temporary.write_bytes(data)
        subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--bitmap-drawing',str(temporary)],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-bitmap-drawing.json';fixture.write_bytes(data)
        r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));report_path.write_text(json.dumps(r,indent=2)+'\n');return
    doc=BitmapDrawing().capture();raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();raw_path.write_bytes(raw)
    r=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=raw_path.name,sha256=digest(raw),cases=len(doc['cases']),setups=len(doc['setups']),sources=len(doc['sources']),
           constructors=sum(s['constructor'] is not None for s in doc['setups']),reads=sum(len(c['reads']) for c in doc['cases']),undefinedReads=sum(not r['defined'] for c in doc['cases'] for r in c['reads']),
           clips=sum(len(c['clips']) for c in doc['cases']),blits=sum(len(c['blits']) for c in doc['cases']),dualBlits=sum(len(c['blits'])==2 for c in doc['cases']),
           boundaries={kind:sum(c['boundary'] is not None and c['boundary']['kind']==kind for c in doc['cases']) for kind in ('outsideBitmap','nullTarget')},nativeComparison='pending')
    report_path.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items() if k!='scope'},indent=2),flush=True)

if __name__=='__main__':main()
