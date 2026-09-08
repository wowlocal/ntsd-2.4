#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Real World constructor and4246b0 startup branch through24 bitmap resources,
151 literal menu rectangles and6 interleaved256-glyph tables. Stop BEFORE
423480 settings loading;44d068 is not manually cleared. Flag0 skips to42709b.
43ee50 executes through actual ret12; allocator/DIB/COM responses and each
outer caller frame remain declared boundaries. No whole menu/Windows claim.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256
from inspect_original import PE
from oracle_state import Constructors, AREA, STACK, STOP, WORLD_PREFIX
from oracle_bitmap_drawing import digest, packed
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_ESP, UC_X86_REG_EIP

WORLD, HEAP, API, GLOBAL, GLOBAL_SIZE, SIZE = AREA+0x20, 0x28000000, STOP+0x100, 0x44D000, 0xB440, 0x1F50
SOURCE, VTABLE, BODY_SP, ENTRY_SP = HEAP+0x2020, HEAP+0x5000, STACK+0xF000, STACK+0xF424
REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]
PATHS=['LF2_CURSOR','MENU_CLIP','MENU_CLIP2','MENU_CLIP3','MENU_CLIP4','MENU_CLIP5','MENU_CLIP6','MENU_CLIP7','MENU_WAIT','SLOGAN','ENDING',
       'LF2_CURSOR','CS2','CS3','CS4','CS5','CS6','FRAME','WORDS0','WORDS1','WORDS2','WORDS3','WORDS4','WORDS5']
SLOTS=[0x451170,0x4511A0,0x451168,0x451178,0x45116C,0x45117C,0x4511A4,0x451188,0x45118C,0x45119C,0x451190,
       0x451198,0x451174,0x451164,0x451184,0x451194,0x451180,0x4511A8,0x44FAF4,0x44F888,0x44FCBC,0x44FB68,0x44FAF8,0x44FD80]
CALLS=[0x4247A0,0x424827,0x424866,0x4248A5,0x4248E4,0x424923,0x424962,0x4249A1,0x4249E0,0x424A1F,0x424A5E,
       0x426BBD,0x426C00,0x426C3F,0x426C81,0x426CBC,0x426CFB,0x426D3A,0x426D79,0x426DB4,0x426DF3,0x426E32,0x426E71,0x426EB0]
# First dereference of each initialized resource. Checked before execution,
# since page0 is mapped for the original SEH prologue, not valid NULL metadata.
NULLS={0x424A72:0x45119C,0x424B45:0x451190,0x424CA4:0x4511A0,
       0x4251FD:0x451168,0x4252E5:0x451178,0x425E65:0x45116C,0x4263F2:0x45117C,0x42669F:0x4511A4,0x426866:0x451188,
       0x426EC9:0x44FAF4,0x426ED2:0x44F888,0x426EDB:0x44FCBC,0x426EE4:0x44FB68,0x426EED:0x44FAF8,0x426EF8:0x44FD80}


class FrontMenuResources(Constructors):
    def __init__(self,control=False):
        self.active=False;self.regions=[];self.world_mask=bytearray(WORLD_PREFIX);self.control=control
        super().__init__();self.blobs={};self.sources={}
        self.uc.mem_map(0,0x1000);self.uc.mem_map(HEAP,0x4000000)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=HEAP,end=HEAP+0x3FFFFFF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.written,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        self.uc.hook_add(UC_HOOK_CODE,self.code)
        self.pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());self.resources={r['path'][1]:r for r in self.pe.resources() if r['path'][0]==2}
        for index in range(24):self.put(SOURCE+16*index,VTABLE)
        for at,to in [(VTABLE+0x74,API),(VTABLE+8,API+16),(0x4471C8,API+32),(0x447080,API+48)]:self.put(at,to)
        self.put(0x457578,SOURCE)
        self.world_initial=self.backing(WORLD_PREFIX);self.uc.mem_write(WORLD,self.world_initial)
        self.uc.reg_write(UC_X86_REG_ECX,WORLD);self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.put(ENTRY_SP,STOP)
        self.uc.emu_start(0x419E40,STOP,count=10000)
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP and self.u32(WORLD)==0
        self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.initial_world=self.world_record()

    def backing(self,size):return bytes(i%256 for i in range(size)) if self.control else b'\xa5'*size
    def put(self,address,value):self.uc.mem_write(address,struct.pack('<I',value&0xFFFFFFFF))
    def ret(self,value=0,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP);self.uc.reg_write(UC_X86_REG_EAX,value&0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def blob(self,raw):
        raw=bytes(raw);key=digest(raw)
        if key not in self.blobs:self.blobs[key]=packed(raw)
        return key
    def record(self,region):return dict(bytes=self.blob(self.uc.mem_read(region['address'],SIZE)),defined=self.blob(region['mask']))
    def world_record(self):return dict(bytes=self.blob(self.uc.mem_read(WORLD,WORLD_PREFIX)),defined=self.blob(self.world_mask))
    def cstr(self,address):
        raw=bytearray()
        while self.uc.mem_read(address,1)!=b'\0':raw.extend(self.uc.mem_read(address,1));address+=1
        return bytes(raw)
    def locate(self,address,size):
        physical=(address-HEAP-0x20)//0x2000
        index=6144-physical if self.control else physical-8
        assert 0<=index<len(self.regions),(hex(address),size)
        r=self.regions[index];offset=address-r['address'];assert 0<=offset and offset+size<=SIZE,(hex(address),size,offset)
        return r,offset
    def event(self,kind,args=(),strings=()):self.events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))
    def written(self,uc,access,address,size,value,data):
        pc=uc.reg_read(UC_X86_REG_EIP)
        if WORLD<=address and address+size<=WORLD+WORLD_PREFIX:self.world_mask[address-WORLD:address-WORLD+size]=b'\1'*size;return
        if GLOBAL<=address and address+size<=GLOBAL+GLOBAL_SIZE:token,offset=0,address
        else:
            r,offset=self.locate(address,size);r['mask'][offset:offset+size]=b'\1'*size;token=r['address']
        if self.active and 0x424755<=pc<0x427089:
            assert size in (2,4)
            self.event('write',[token,offset,size,value&((1<<(8*size))-1)])
    def write_host(self,address,raw):
        self.written(self.uc,0,address,len(raw),0,None);self.uc.mem_write(address,raw)
    def memset(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP);dst,value,count=[self.u32(sp+i) for i in (4,8,12)]
        assert not self.active and dst==WORLD+4 and value==0 and count==400
        self.write_host(dst,bytes(count));self.ret(dst)

    def code(self,uc,address,size,data):
        if address==STOP:uc.emu_stop();return
        if not self.active:
            assert 0x419E40<=address<=0x419E5F or address==0x4450A0,hex(address);return
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
        if self.pending and address==self.pending['returnAddress']:
            c=self.pending;self.pending=None
            assert sp==c['entrySP']+16 and uc.reg_read(UC_X86_REG_EAX)==c['address'] and c['saved']==[uc.reg_read(r) for r in REGISTERS]
            c['returnSP']=sp;self.calls.append(c)
        if address in (0x427089,0x42709B):
            self.continuation='settings' if address==0x427089 else 'ready';uc.emu_stop();return
        if address in NULLS and self.u32(NULLS[address])==0:
            self.continuation='nullBitmap';self.null_slot=NULLS[address];uc.emu_stop();return
        if address==0x4450AC:
            assert arg(0)==SIZE;index=len(self.allocations);assert index<24
            token=0;backing=None
            if not self.nulls&(1<<index):
                logical=len(self.regions);physical=6144-logical if self.control else logical+8
                assert 8<=physical<8192
                token=HEAP+physical*0x2000+0x20;raw=self.backing(SIZE);backing=self.blob(raw)
                self.uc.mem_write(token-16,b'\x96'*16+raw+b'\x69'*16)
                self.regions.append(dict(address=token,mask=bytearray(SIZE)))
            self.allocations.append(dict(address=token,backing=backing));self.event('allocate',[SIZE]);self.ret(token);return
        if address==0x43EE50:
            index=len(self.allocations)-1;token=self.allocations[index]['address'];path=self.cstr(arg(1))
            assert token and uc.reg_read(UC_X86_REG_ECX)==token and path.decode()==PATHS[index] and [arg(0),arg(2)]==[0x40,0]
            assert self.u32(sp)==CALLS[index]+5 and self.pending is None
            self.pending=dict(index=index,address=token,entrySP=sp,returnAddress=self.u32(sp),saved=[uc.reg_read(r) for r in REGISTERS])
            self.event('construct',[token,0x40,0],[path])
        if address==0x43ED10:
            index=self.pending['index'];path=self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode();assert path==PATHS[index]
            assert [arg(i) for i in range(3)]==[self.u32(0x457578),0x40,0]
            desc=self.resources[path];raw=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']];width,height=struct.unpack_from('<ii',raw,4)
            self.sources[path]=dict(path=path,width=width,height=height,dib=self.blob(raw))
            surface=0 if self.missing&(1<<index) else SOURCE+16*index
            resource=dict(path=path,present=surface!=0,width=width if surface else None,height=height if surface else None)
            self.inputs.append(dict(index=index,resource=resource,surface=surface,colorKeyResult=self.keys[index]))
            self.event('load',[self.u32(0x457578),0x40,0],[path.encode()])
            if surface:
                self.write_host(arg(3),struct.pack('<i',width));self.write_host(arg(4),struct.pack('<i',height))
            self.ret(surface);return
        if API<=address<=API+48:
            if address==API:
                assert [arg(0),arg(1)]==[self.inputs[-1]['surface'],8] and bytes(uc.mem_read(arg(2),8))==bytes(8)
                self.event('colorKey',[arg(0),8],[bytes(8)]);self.ret(self.keys[self.inputs[-1]['index']],12)
            elif address==API+16:self.event('release',[arg(0)]);self.ret(17,4)
            elif address==API+32:self.event('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16)
            else:self.event('debug',strings=[self.cstr(arg(0))]);self.ret(0x87654321,4)
            return
        assert 0x4246B0<=address<0x427089 or 0x43EE50<=address<=0x43EF41 or 0x4450B2<=address<=0x4450BA,hex(address)

    def step(self,label,writes=(),selector=None,nulls=0,missing=0,keys=None):
        stimulus=[]
        for address,value in writes:
            raw=struct.pack('<I',value&0xFFFFFFFF) if isinstance(value,int) else value
            self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
        if selector is not None:self.put(WORLD,selector)
        world=self.world_record();self.nulls=nulls;self.missing=missing;self.keys=keys or [0]*24
        self.events=[];self.allocations=[];self.inputs=[];self.calls=[];self.pending=None;self.continuation=None;self.null_slot=None
        self.put(0,0x12345678);self.put(ENTRY_SP,STOP);self.put(ENTRY_SP+4,SOURCE)
        self.uc.reg_write(UC_X86_REG_ESP,ENTRY_SP);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.uc.reg_write(r,v)
        self.active=True
        try:self.uc.emu_start(0x4246B0,0,count=500000)
        except Exception:
            print('FRONT RESOURCE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.events[-3:],flush=True);raise
        finally:self.active=False
        assert self.continuation and self.pending is None and self.uc.reg_read(UC_X86_REG_ESP)==BODY_SP
        assert self.world_record()==world
        for r in self.regions:
            assert bytes(self.uc.mem_read(r['address']-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(r['address']+SIZE,16))==b'\x69'*16
        return dict(label=label,stimulus=stimulus,selector=selector,allocations=self.allocations,inputs=self.inputs,calls=self.calls,events=self.events,
                    continuation=self.continuation,nullBitmapSlot=self.null_slot,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=BODY_SP,
                    globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),world=world,records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions])

    def capture(self):
        assert self.u32(0x44D068)==1
        cases=[self.step('first-front-resources')]
        def writes(flag=1):return [(0x44D068,flag),(0x44FCC0,bytes((i*7+3)&255 for i in range(88)))]
        for phase in (-2147483648,-1,0,1,2,3,2147483647):
            for selector in (-2147483648,-1,0,3,2147483647):cases.append(self.step(f'skip-{phase}-{selector}',writes(0)+[(0x4511F8,phase)],selector=selector))
        for flag in (-2147483648,-1,1,2,2147483647):cases.append(self.step(f'flag-{flag}',writes(flag),selector=0))
        for i in range(24):cases.append(self.step(f'null-{i}',writes(),nulls=1<<i))
        for mask in (0xFFFFFF,0x555555,0xAAAAAA,0x7FF,0xFC0000,0xFFF800):cases.append(self.step(f'null-mask-{mask}',writes(),nulls=mask))
        for i in range(24):cases.append(self.step(f'missing-{i}',writes(),missing=1<<i))
        cases.append(self.step('missing-all',writes(),missing=0xFFFFFF))
        for i in range(24):
            keys=[0]*24;keys[i]=-1;cases.append(self.step(f'key-{i}',writes(),keys=keys))
        for key in (-2147483648,-1,0,1,2147483647):cases.append(self.step(f'key-all-{key}',writes(),keys=[key]*24))
        for i in range(8):cases.append(self.step(f'mixed-{i}',writes(-1),nulls=(0x249249<<(i%3))&0xFFFFFF,missing=(0x124924<<(i%3))&0xFFFFFF,keys=[-1 if (i+j)%2 else 1 for j in range(24)]))
        for i in range(12):cases.append(self.step(f'consecutive-{i}',writes() if i%4==0 else [(0x44D068,0)]))
        return dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,worldBacking=self.blob(self.world_initial),initialWorld=self.initial_world,
                    initialGlobals=self.initial_globals,sources=list(self.sources.values()),cases=cases,blobs=self.blobs)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:
        subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
        pending=[]
        for suffix in ('','-control'):
            path=ROOT/'docs/evidence'/f'front-menu-resources{suffix}.json';r=json.loads(path.read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256']
            data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-menu-resources{suffix}-check.json';temp.write_bytes(data)
            result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-menu-resources',str(temp)],capture_output=True,text=True)
            print(result.stdout,end='',flush=True)
            if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
            fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+r['corpus'])
            r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data));pending.append((path,r,fixture,data))
        for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')
        return
    doc=FrontMenuResources(a.control).capture();suffix='-control' if a.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'front-menu-resources{suffix}.json';path.write_bytes(raw)
    kinds=('allocate','construct','load','colorKey','message','debug','release','write')
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),sources=len(doc['sources']),
                events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in kinds},
                continuations={k:sum(c['continuation']==k for c in doc['cases']) for k in ('settings','ready','nullBitmap')},nativeComparison='pending')
    (ROOT/'docs/evidence'/f'front-menu-resources{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
