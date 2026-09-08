#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Real400-slot bootstrap followed by10 UI bitmap constructors and first-load clear.

The catalog[0]/Object+90, allocator backing and43ed10/COM/OS responses are
explicit boundaries. Actual43ee50, its ret12/cookie and parent41c2f5..41c581
execute. Embedded DIBs supply dimensions, not a claim of rendered pixels.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT
from inspect_original import PE
from oracle_bootstrap import Bootstrap
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_ESP, UC_X86_REG_EIP

GLOBAL, GLOBAL_SIZE, BITMAP_SIZE = 0x44D000, 0xB440, 0x1F50
BITMAP_BASE, SURFACE_BASE, VTABLE = 0x27000020, 0x26000020, 0x2600F000
STORES = [0x41C338,0x41C378,0x41C3B8,0x41C3F8,0x41C438,0x41C478,0x41C4B8,0x41C4F8,0x41C538,0x41C577]
SLOTS = [0x44FF8C,0x44F8F8,0x44FCB4,0x44FD8C,0x44F88C,0x44F87C,0x44FD90,0x44FD94,0x44FB64,0x44FD7C]
REGISTERS = [UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]


def digest(raw): return hashlib.sha256(raw).hexdigest()


class InitialInterface(Bootstrap):
    def __init__(self, pattern, layout, selector, header_word, control):
        super().__init__(pattern,layout,selector,header_word)
        self.control=control;self.ui_running=False;self.ui_allocations=[];self.ui_calls=[];self.ui_events=[];self.ui_records={};self.inputs=[];self.checkpoints=[]
        self.pending=None;self.sources={}
        pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes())
        self.resources={str(r['path'][1]).lower(): (r,pe.data[r['fileOffset']:r['fileOffset']+r['size']]) for r in pe.resources() if r['path'][0]==2}
        self.uc.mem_map(BITMAP_BASE & ~4095,0x100000);self.uc.mem_map(SURFACE_BASE & ~4095,0x10000)
        for i in range(10):self.put(SURFACE_BASE+i*16,VTABLE)
        self.imports={STOP+0x100:'message',STOP+0x110:'debug',STOP+0x120:'colorKey',STOP+0x130:'release'}
        for at,to in [(0x4471C8,STOP+0x100),(0x447080,STOP+0x110),(VTABLE+0x74,STOP+0x120),(VTABLE+8,STOP+0x130)]:self.put(at,to)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.bitmap_write,begin=BITMAP_BASE,end=BITMAP_BASE+0xFFFFF)
        self.uc.hook_add(UC_HOOK_CODE,self.instruction)
        self.uc.hook_add(UC_HOOK_CODE,self.imported,begin=STOP+0x100,end=STOP+0x130)

    def cstr(self,address):
        result=bytearray()
        while self.uc.mem_read(address,1)!=b'\0':result.extend(self.uc.mem_read(address,1));address+=1
        return bytes(result)
    def ret(self,value=0,pop=0):
        sp=self.uc.reg_read(UC_X86_REG_ESP)
        self.uc.reg_write(UC_X86_REG_EAX,value & 0xFFFFFFFF);self.uc.reg_write(UC_X86_REG_ESP,sp+4+pop);self.uc.reg_write(UC_X86_REG_EIP,self.u32(sp))
    def event(self,kind,args=(),strings=()):self.ui_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))
    def bitmap_write(self,uc,access,address,size,value,data):
        candidates=[r for r in self.ui_records.values() if r['address']<=address<r['address']+BITMAP_SIZE]
        assert len(candidates)==1,(hex(address),size)
        r=candidates[0];offset=address-r['address'];assert offset+size<=BITMAP_SIZE
        r['mask'][offset:offset+size]=b'\1'*size
    def write_bitmap(self,address,raw):
        self.bitmap_write(self.uc,0,address,len(raw),0,None);self.uc.mem_write(address,raw)
    def allocate(self,uc,address,size,data):
        if not self.ui_running:super().allocate(uc,address,size,data);return
        sp=uc.reg_read(UC_X86_REG_ESP);assert self.u32(sp+4)==BITMAP_SIZE
        index=len(self.ui_allocations);assert index<10
        null=self.control=='null-all' or self.control=='null-alternating' and index%2==0 or self.control=='mixed' and index==3
        target=0 if null else BITMAP_BASE+(index if self.layout==0 else 9-index)*0x3000
        backing=bytes([self.actor_initial[0]])*BITMAP_SIZE if self.control!='ramp' and len(set(self.actor_initial))==1 else bytes(i%256 for i in range(BITMAP_SIZE))
        item=dict(address=target,backing=backing.hex())
        self.ui_allocations.append(item);self.event('allocate',[BITMAP_SIZE])
        if target:
            uc.mem_write(target-16,b'\x96'*16+backing+b'\x69'*16)
            self.ui_records[target]=dict(address=target,initial=backing,mask=bytearray(BITMAP_SIZE))
        self.ret(target)
    def instruction(self,uc,address,size,data):
        if not self.ui_running:return
        if self.pending is not None and address==self.pending['returnAddress']:
            item=self.pending;self.pending=None
            assert uc.reg_read(UC_X86_REG_ESP)==item['entrySP']+16
            saved=[uc.reg_read(r) for r in REGISTERS];assert saved==item['savedRegisters']
            assert uc.reg_read(UC_X86_REG_EAX)==item['address']
            self.ui_calls.append(dict(address=item['address'],stackAfter=uc.reg_read(UC_X86_REG_ESP),savedRegisters=saved))
        if address in STORES:
            index=STORES.index(address)
            self.checkpoints.append(dict(slot=SLOTS[index],value=self.u32(SLOTS[index]),globals=bytes(uc.mem_read(GLOBAL,GLOBAL_SIZE)).hex()))
        if address==0x43EE50:
            sp=uc.reg_read(UC_X86_REG_ESP);target=uc.reg_read(UC_X86_REG_ECX);index=len(self.ui_allocations)-1
            path=self.cstr(self.u32(sp+8));assert self.u32(sp+4)==0x40 and self.u32(sp+12)==0
            self.event('construct',[target,0x40,0],[path])
            missing=self.control=='missing-all' or self.control=='mixed' and index==5
            status=-1 if self.control=='key-fail-all' or self.control=='mixed' and index in (2,7) else [0,1,0x7FFFFFFF][index%3]
            r,raw=self.resources[path.decode().lower()];assert len(raw)>=40 and struct.unpack_from('<I',raw)[0]>=40
            width,height=struct.unpack_from('<ii',raw,4);assert width>0 and height>0
            self.sources[path.decode()]=dict(path=path.decode(),resourcePath=r['path'],sha256=digest(raw),bytes=raw.hex(),width=width,height=height)
            resource=dict(path=path.decode(),present=not missing)
            if not missing:resource.update(width=width,height=height)
            self.inputs.append(dict(index=index,resource=resource,surface=0 if missing else SURFACE_BASE+index*16,colorKeyResult=status))
            self.pending=dict(returnAddress=self.u32(sp),entrySP=sp,address=target,savedRegisters=[uc.reg_read(r) for r in REGISTERS])
        elif address==0x43ED10:
            sp=uc.reg_read(UC_X86_REG_ESP);item=self.inputs[-1];path=self.cstr(uc.reg_read(UC_X86_REG_EDI))
            assert path.decode()==item['resource']['path']
            assert self.u32(sp+4)==self.u32(0x457578) and self.u32(sp+8)==0x40 and self.u32(sp+12)==0
            self.event('load',[self.u32(sp+4),0x40,0],[path])
            if item['surface']:
                self.write_bitmap(self.u32(sp+16),struct.pack('<i',item['resource']['width']))
                self.write_bitmap(self.u32(sp+20),struct.pack('<i',item['resource']['height']))
            self.ret(item['surface']);return
        assert 0x41C2F5<=address<0x41C581 or 0x43EE50<=address<=0x43EF41 or 0x4450B2<=address<=0x4450BA or address==0x4450AC or address in self.imports,hex(address)
    def imported(self,uc,address,size,data):
        assert self.ui_running
        name=self.imports[address];sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4)
        if name=='message':self.event(name,[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16)
        elif name=='debug':self.event(name,[],[self.cstr(arg(0))]);self.ret(0x87654321,4)
        elif name=='colorKey':
            assert arg(0)==self.inputs[-1]['surface'] and arg(1)==8 and bytes(uc.mem_read(arg(2),8))==bytes(8)
            self.event(name,[arg(0),arg(1)],[bytes(uc.mem_read(arg(2),8))]);self.ret(self.inputs[-1]['colorKeyResult'],12)
        else:self.event(name,[arg(0)]);self.ret(17,4)

    def capture(self,blobs,label):
        # Supplied outer frame remains in place across the real pool and UI calls.
        self.put(STACK+0xF038,0x12345678);self.put(0x44D05C,1);self.put(0x457578,0x10203040)
        for slot in SLOTS:self.put(slot,0x87654321)
        before=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        self.run(0x41C052,0x41C2F5)
        assert self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xEFFC
        self.ui_running=True
        try:self.run(0x41C2F5,0x41C581)
        finally:self.ui_running=False
        assert self.pending is None and len(self.checkpoints)==10 and self.u32(0x44D05C)==0
        assert self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xF000 and self.uc.reg_read(UC_X86_REG_EDI)==0x12345678
        records=[]
        for address,r in self.ui_records.items():
            raw=bytes(self.uc.mem_read(address,BITMAP_SIZE))
            assert self.uc.mem_read(address-16,16)==b'\x96'*16 and self.uc.mem_read(address+BITMAP_SIZE,16)==b'\x69'*16
            assert all(v or raw[i]==r['initial'][i] for i,v in enumerate(r['mask']))
            records.append(dict(address=address,bytes=raw.hex(),defined=bytes(r['mask']).hex()))
        return dict(label=label,actorInitial=self.actor_initial.hex(),worldInitial=self.world_initial.hex(),
            selector=self.u32(self.world),firstObjectWord90=self.u32(self.object+0x90),
            addresses=dict(world=self.world,catalog=self.catalog,object=self.object,actors=self.addresses),
            beforeGlobals=before.hex(),afterGlobals=bytes(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)).hex(),
            allocations=self.ui_allocations,inputs=self.inputs,events=self.ui_events,calls=self.ui_calls,
            checkpoints=self.checkpoints,records=records,pool=self.capture_pool(blobs,'after-interface'),
            endPC='0x41c581',stackAfter=self.uc.reg_read(UC_X86_REG_ESP),restoredEDI=self.uc.reg_read(UC_X86_REG_EDI))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--accept',action='store_true');args=parser.parse_args()
    if args.accept:accept();return
    blobs={};cases=[];sources={}
    controls=[(p,l,s,w,'normal') for p,s,w in [(0,0,0),(0xA5,2,-1),(0xFF,-7,-2147483648),(None,17,0x12345678)] for l in (0,1)]
    controls += [(None,1,2,-1,c) for c in ('null-all','null-alternating','missing-all','key-fail-all','mixed')]
    for p,l,s,w,c in controls:
        vm=InitialInterface(p,l,s,w,c);label=f'{p}-{l}-{c}'
        cases.append(vm.capture(blobs,label));sources.update(vm.sources)
        print(label,len(vm.ui_calls),'real bitmap constructors',flush=True)
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,sources=list(sources.values()),cases=cases,blobs=blobs)
    output=ROOT/'build/original/initial-interface.json';output.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=output.name,corpusSHA256=digest(output.read_bytes()),
        cases=len(cases),sources=[{k:v for k,v in s.items() if k!='bytes'} for s in sources.values()],
        constructors=sum(len(c['calls']) for c in cases),events=sum(len(c['events']) for c in cases),nativeComparison='pending')
    (ROOT/'docs/evidence/initial-interface.json').write_text(json.dumps(report,indent=2)+'\n')


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    path=ROOT/'docs/evidence/initial-interface.json';report=json.loads(path.read_text())
    raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['corpusSHA256']
    packed=dict(count=len(raw),sha256=digest(raw),deflate=base64.b64encode(zlib.compress(raw,level=9,wbits=-15)).decode())
    temporary=ROOT/'build/original/initial-interface-check.json';temporary.write_text(json.dumps(packed,separators=(',',':'))+'\n')
    result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--initial-interface',str(temporary)],capture_output=True,text=True)
    print(result.stdout,end='',flush=True)
    if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
    fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-initial-interface.json';fixture.write_bytes(temporary.read_bytes())
    report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size)
    path.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
