#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Continuous real41bc90..41c581: non-playback prologue,18 WAVs,full catalog,
400-slot pool and10 UI constructors. No CPU/stack or loaded-state replacement
between stages. OS/CRT/device/allocator inputs remain explicit boundaries.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_catalog_sounds import SoundCatalog, REGISTERS, pack
from oracle_loaded_catalog import CATALOG, CATALOG_SIZE
from oracle_objects import BITMAP_SIZE, DEVICE as GRAPHICS, STUB
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE, SURFACE, digest
from oracle_wave_loader import SECOND
from oracle_state import STACK, STOP, ACTOR_SIZE, WORLD_PREFIX
from oracle_initial_interface import STORES, SLOTS
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP

WORLD, POOL = 0x68000020, 0x70000020


def transport(doc, blobs):
    def keys(value):
        if isinstance(value, str):return {value} if value in blobs else set()
        if isinstance(value, list):return set().union(*(keys(v) for v in value))
        if isinstance(value, dict):return set().union(*(keys(v) for k,v in value.items() if k != 'blobs'))
        return set()
    return {**doc, 'blobs': {k:blobs[k] for k in sorted(keys(doc))}}


class InitialLoading(SoundCatalog):
    def __init__(self, control=False, uc=None, existing_world=None, second_pointer=SECOND):
        super().__init__(uc=uc,second_pointer=second_pointer)
        self.phase='world';self.control=control;self.pool=[];self.actor_calls=[];self.ui_allocations=[];self.ui_inputs=[];self.ui_events=[];self.ui_calls=[];self.ui_pending=None;self.ui_stores=[]
        self.global_writes=set();self.progress_calls=[]
        self.world_address=WORLD if existing_world is None else existing_world['address']
        if existing_world is None:
            self.uc.mem_map(self.world_address & ~4095,0x1000)
            self.world=self.add_backing(self.world_address,WORLD_PREFIX,'world')
        else:
            assert uc is not None and existing_world['size']==WORLD_PREFIX and existing_world['kind']=='world'
            self.world=existing_world;self.regions.append(self.world)
        self.uc.mem_map(POOL & ~4095,0x80000)
        for start,count in ((self.world_address,WORLD_PREFIX),(POOL,0x7D000)):
            self.uc.hook_add(UC_HOOK_MEM_READ,self.track_read,begin=start,end=start+count-1)
            self.uc.hook_add(UC_HOOK_MEM_WRITE,self.track_write,begin=start,end=start+count-1)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.global_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        for pc in [0x4061D0,*STORES,0x41C320,0x41C363,0x41C3A3,0x41C3E3,0x41C423,0x41C463,0x41C4A3,0x41C4E3,0x41C523,0x41C563]:
            self.uc.hook_add(UC_HOOK_CODE,self.join_checkpoint,begin=pc,end=pc)

    def add_backing(self,address,size,kind):
        r=self.add_region(address,size,kind)
        if self.control:
            r['initial']=bytes(i%256 for i in range(size));self.uc.mem_write(address,r['initial'])
        return r
    def global_write(self,uc,access,address,size,value,data):
        self.global_writes.add((self.phase,address,size,uc.reg_read(UC_X86_REG_EIP)))
    def write_host(self,address,raw):
        if self.world_address<=address<self.world_address+WORLD_PREFIX or POOL<=address<POOL+0x7D000:
            self.track_write(self.uc,0,address,len(raw),0,None);self.uc.mem_write(address,raw)
        else:super().write_host(address,raw)
    def memset(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP);dst,value,count=[self.u32(sp+i) for i in (4,8,12)]
        if self.world_address<=dst<self.world_address+WORLD_PREFIX or POOL<=dst<POOL+0x7D000:
            self.write_host(dst,bytes([value&255])*count);self.ret(dst)
        else:super().memset(uc,address,size,data)
    def sound_call(self,uc,address,size,data):
        if self.phase!='common':super().sound_call(uc,address,size,data)
    def imported(self,uc,address,size,data):
        if self.phase=='interface' and address==STUB+0x300:
            sp=uc.reg_read(UC_X86_REG_ESP)
            self.ui_events.append(dict(kind='colorKey',arguments=[self.u32(sp+4),self.u32(sp+8)],strings=[list(uc.mem_read(self.u32(sp+12),8))]))
        if self.phase=='catalog' and self.lookup.get(address) in ('timeGetTime','Sleep'):
            sp=uc.reg_read(UC_X86_REG_ESP);name=self.lookup[address]
            self.progress_calls.append(dict(kind=name,arguments=[] if name=='timeGetTime' else [self.u32(sp+4)],returned=100 if name=='timeGetTime' else 0))
        super().imported(uc,address,size,data)
    def checkpoint(self,uc,address,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address==0x4450AC and not self.wave.running:
            count=self.u32(sp+4)
            if self.phase=='catalog' and count==CATALOG_SIZE:
                assert self.u32(sp)==0x41BFF5;self.catalog_allocation=dict(address=CATALOG,size=count,caller=self.u32(sp));self.ret(CATALOG);return
            if self.phase=='pool':
                assert count==ACTOR_SIZE and self.u32(sp)==0x41C07A
                index=len(self.pool);assert index<400
                target=POOL+(399-index if self.control else index)*0x500
                self.pool.append(self.add_backing(target,ACTOR_SIZE,'actor'));self.ret(target);return
            if self.phase=='interface':
                assert count==BITMAP_SIZE
                self.ui_events.append(dict(kind='allocate',arguments=[count],strings=[]))
                r=self.allocate(count,'bitmap',self.u32(sp))
                self.ui_allocations.append(dict(address=r['address'],backing=self.blob(r['initial'])));self.ret(r['address']);return
        if self.phase=='interface' and address==0x43EE50:
            target=uc.reg_read(UC_X86_REG_ECX);path=self.cstr(self.u32(sp+8));assert self.u32(sp+4)==0x40 and self.u32(sp+12)==0
            self.ui_events.append(dict(kind='construct',arguments=[target,0x40,0],strings=[list(path)]))
            self.ui_pending=dict(address=target,entrySP=sp,returnAddress=self.u32(sp),savedRegisters=[uc.reg_read(r) for r in REGISTERS])
        if self.phase=='interface' and address==0x43ED10:
            path=self.cstr(uc.reg_read(UC_X86_REG_EDI));r=self.resources[path.decode().lower()]
            raw=self.pe.data[r['fileOffset']:r['fileOffset']+r['size']];width,height=struct.unpack_from('<ii',raw,4)
            self.ui_inputs.append(dict(resource=dict(path=path.decode(),present=True,width=width,height=height),surface=GRAPHICS,colorKeyResult=0,resourcePath=r['path'],dib=self.blob(raw)))
            self.ui_events.append(dict(kind='load',arguments=[self.u32(sp+4),self.u32(sp+8),self.u32(sp+12)],strings=[list(path)]))
        super().checkpoint(uc,address,size,data)
    def join_checkpoint(self,uc,address,size,data):
        if address==0x4061D0:
            slot=next(i for i,r in enumerate(self.pool) if r['address']==uc.reg_read(UC_X86_REG_ECX));self.actor_calls.append(slot)
        elif self.phase=='interface':
            if self.ui_pending is not None and address==self.ui_pending['returnAddress']:
                item=self.ui_pending;self.ui_pending=None
                assert uc.reg_read(UC_X86_REG_ESP)==item['entrySP']+16 and uc.reg_read(UC_X86_REG_EAX)==item['address']
                assert [uc.reg_read(r) for r in REGISTERS]==item['savedRegisters'];self.ui_calls.append(item)
            if address in STORES:
                i=STORES.index(address);self.ui_stores.append(dict(slot=SLOTS[i],value=self.u32(SLOTS[i]),globals=self.globals()))
    def execute(self,start,stop):
        pc=start
        while pc!=stop:
            self.uc.emu_start(pc,stop,count=2_000_000);pc=self.uc.reg_read(UC_X86_REG_EIP)
    def globals(self):return self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
    def pool_snapshot(self):return dict(world=self.record(self.world),actors=[self.record(r) for r in self.pool],constructorSlots=self.actor_calls.copy())
    def capture(self):
        self.put(STACK+0xF000,STOP);self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF000);self.uc.reg_write(UC_X86_REG_ECX,self.world_address)
        self.execute(0x419E40,STOP);self.put(self.world_address,2)
        for at,v in [(0x44D05C,1),(0x450B84,0),(0x450B90,1 if self.control else 0),(0x450BFC,0),(0x44FB60,1 if self.control else 0),(0x44FCB0,3 if self.control else 0),
                     (0x45118C,0x12345678),(0x455608,SURFACE),(0x455634,SURFACE),(0x453E0C,SURFACE),(0x458348,3 if self.control else 1),(0x457578,0x10203040)]:self.put(at,v)
        entry=STACK+0xF004;self.uc.mem_write(entry,struct.pack('<II',STOP,SURFACE))
        self.uc.reg_write(UC_X86_REG_ESP,entry);self.uc.reg_write(UC_X86_REG_ECX,self.world_address)
        self.uc.reg_write(UC_X86_REG_EIP,0x41BC90)
        return self.continue_loading()

    def continue_loading(self):
        """Resume the actual caller at41bc90 without setting World/CPU/stack."""
        assert self.uc.reg_read(UC_X86_REG_EIP)==0x41BC90 and self.uc.reg_read(UC_X86_REG_ECX)==self.world_address
        entry=self.uc.reg_read(UC_X86_REG_ESP);before=self.globals();world_before=self.record(self.world)
        self.phase='prologue';self.execute(0x41BC90,0x41BE98)
        body=self.uc.reg_read(UC_X86_REG_ESP);prologue=self.globals();paused=self.u32(body+0x38)
        commands=bytes(self.uc.mem_read(body+0x434,10))+bytes(self.uc.mem_read(body+0x440,10));assert commands==bytes(20)
        self.phase='common';w=self.wave;w.prefix_mode=0;w.prefix_events=[];w.prefix_loads=[];w.prefix_current=None;w.stack_mask=bytearray(0x10000);w.prefix=w.running=True
        hooks=[self.uc.hook_add(UC_HOOK_CODE,w.allowed),self.uc.hook_add(UC_HOOK_MEM_WRITE,w.stack_written,begin=STACK,end=STACK+0xFFFF)]
        self.execute(0x41BE98,0x41BFEB)
        assert len(w.prefix_loads)==18 and w.prefix_current is None and self.uc.reg_read(UC_X86_REG_ESP)==body-4
        w.prefix=w.running=False
        for h in hooks:self.uc.hook_del(h)
        common=dict(beforeGlobals=prologue,afterGlobals=self.globals(),loads=w.prefix_loads,events=w.prefix_events)
        checksum_before=self.u32(0x44F620)
        self.phase='catalog';self.execute(0x41BFEB,0x41C052)
        assert self.uc.reg_read(UC_X86_REG_EAX)==CATALOG and self.uc.reg_read(UC_X86_REG_ESP)==body
        catalog=self.capture_catalog(initial_checksum=checksum_before);catalog={**catalog,'events':list(catalog['events'])}
        after_catalog=self.globals()
        self.phase='pool';self.execute(0x41C052,0x41C0D8);allocated=self.pool_snapshot()
        self.execute(0x41C0D8,0x41C2F5);staged=self.pool_snapshot();assert self.actor_calls==list(range(400))+list(range(8))
        self.phase='interface';self.execute(0x41C2F5,0x41C581)
        assert self.ui_pending is None and len(self.ui_stores)==10 and len(self.ui_calls)==10 and self.u32(0x44D05C)==0
        assert self.uc.reg_read(UC_X86_REG_ESP)==body and self.uc.reg_read(UC_X86_REG_EDI)==paused
        assert not self.reads_before_writes, sorted(self.reads_before_writes)[:20]
        assert staged==self.pool_snapshot()
        ui=dict(allocations=self.ui_allocations,inputs=self.ui_inputs,events=self.ui_events,calls=self.ui_calls,checkpoints=self.ui_stores,
                records=[dict(address=a['address'],storage=self.record(self.region(a['address'],BITMAP_SIZE))) for a in self.ui_allocations])
        doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,worldAddress=self.world_address,actorAddresses=[r['address'] for r in self.pool],worldBefore=world_before,
                 beforeGlobals=before,afterPrologue=prologue,afterCatalog=after_catalog,afterGlobals=self.globals(),common=common,
                 catalogAllocation=self.catalog_allocation,allocated=allocated,staged=staged,interface=ui,progressCalls=self.progress_calls,
                 entrySP=entry,bodySP=body,endPC=0x41C581,paused=paused,commands=list(commands),globalWrites=sorted(self.global_writes))
        sounds=dict(exeSHA256=EXE_SHA256,calls=self.sound_calls,sources=list(self.sound_sources.values()),finalBuffers=self.blob(self.uc.mem_read(0x452948,4*catalog['soundCount'])))
        blobs={**self.blobs,**w.blobs}
        return [transport(d,blobs) for d in (doc,catalog,sounds)]


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        report_path=ROOT/'docs/evidence'/f'initial-loading{suffix}.json';report=json.loads(report_path.read_bytes());paths=[];fixtures=[]
        for key in ('initial-loading','initial-loading-catalog','initial-loading-sounds'):
            item=report[key];raw=(ROOT/'build/original'/item['corpus']).read_bytes();assert digest(raw)==item['sha256']
            doc=json.loads(raw)
            if key=='initial-loading-catalog':
                doc.pop('scans');doc.pop('readsBeforeWrites');doc['events']=[e for e in doc['events'] if e['kind']=='mirror-blit']
                doc=transport(doc,doc['blobs'])
            path=ROOT/'build/original'/f'{key}{suffix}-check.json';path.write_text(pack(doc));paths.append(str(path))
            fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+item['corpus']);fixtures.append((fixture,path.read_bytes()))
            item.update(fixture=fixture.name,fixtureSHA256=digest(path.read_bytes()),fixtureBytes=path.stat().st_size)
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--initial-loading',*paths],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        report['nativeComparison']=result.stdout.strip();pending.append((report_path,report,fixtures))
    for report_path,report,fixtures in pending:
        for path,raw in fixtures:path.write_bytes(raw)
        report_path.write_text(json.dumps(report,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');args=p.parse_args()
    if args.accept:accept();return
    vm=InitialLoading(args.control);docs=vm.capture();suffix='-control' if args.control else ''
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,nativeComparison='pending')
    for key,doc in zip(('initial-loading','initial-loading-catalog','initial-loading-sounds'),docs):
        path=ROOT/'build/original'/f'{key}{suffix}.json';path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
        report[key]=dict(corpus=path.name,sha256=digest(path.read_bytes()),bytes=path.stat().st_size)
    (ROOT/'docs/evidence'/f'initial-loading{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured actual41bc90..41c581',suffix,flush=True)


if __name__=='__main__':main()
