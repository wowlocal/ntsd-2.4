#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real4297ae..429e5a after freshly reproduced loading/input/round/music.
Eleven actual43ee50 constructors, ordered global stores, seat arrays and partial
SPARK rectangles.43ed10/COM/malloc responses remain supplied boundaries. The
primary music/menu entry is continuous; control inherited an explicit4229cc
entry after paused round. Stop before429b21 if its SPARK pointer is null:
the harness maps page0 for SEH and must not fabricate a successful NULL write.
No menu dispatch, pixels, paused rendering or Windows device claim.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import ROOT, EXE_SHA256
from oracle_music_playback import MusicPlayback
from oracle_initial_loading import transport, WORLD
from oracle_catalog_sounds import REGISTERS, pack
from oracle_wave_loader import digest
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBP, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDX, UC_X86_REG_EDI, UC_X86_REG_ESI, UC_X86_REG_ESP, UC_X86_REG_EIP

ARENA, API, SIZE = 0x2D000000, 0x30005000, 0x1F50
MENU_SP = 0x1000DF48
PATHS=['CHARMENU','CM1','CM2','CM3','CM4','CM5','CMA','CMA2','CMC','RFACE','SPARK']
SLOTS=[0x4512C4,0x4512B0,0x4512B4,0x4512B8,0x4512BC,0x4512C0,0x4512AC,0x4512A8,0x44FD88,0x44FD84,0x44F8FC]
STORES=[0x429827,0x429866,0x4298A5,0x4298E4,0x429923,0x429962,0x4299A1,0x4299E0,0x429A1F,0x429A5E,0x429A91]
RETURNS=[0x429812,0x429851,0x429890,0x4298CF,0x42990E,0x42994D,0x42998C,0x4299CB,0x429A0A,0x429A49,0x429A88]


class MenuResources(MusicPlayback):
    def __init__(self,control=False,resource_arena=ARENA,resource_api=API,**loading_options):
        self.resource_api=resource_api;self.resource_arena=resource_arena;self.menu_sp=MENU_SP
        super().__init__(control,**loading_options);self.resources_running=False;self.menu_bitmaps=[];self.resource_sources={}
        self.uc.mem_map(self.resource_arena,0x1000000);self.uc.mem_map(self.resource_api,0x1000)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.track_write,begin=self.resource_arena+0x10000,end=self.resource_arena+0xFFFFFF)

    def install_resources(self):
        self.uc.hook_add(UC_HOOK_CODE,self.resource_code)
        for at,to in [(0x4471C8,self.resource_api),(0x447080,self.resource_api+0x10),(self.resource_arena+0x3000+0x74,self.resource_api+0x20),(self.resource_arena+0x3000+8,self.resource_api+0x30)]:self.put(at,to)
        for index in range(11):self.put(self.resource_arena+0x2000+index*16,self.resource_arena+0x3000)

    def write_host(self,address,raw):
        if self.resource_arena+0x10000<=address<self.resource_arena+0x1000000:
            self.track_write(self.uc,0,address,len(raw),0,None);self.uc.mem_write(address,raw)
        else:super().write_host(address,raw)

    def revent(self,kind,args=(),strings=()):
        self.resource_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings]))

    def checkpoint(self,uc,address,size,data):
        if not getattr(self,'resources_running',False):return super().checkpoint(uc,address,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP)
        if address==0x4450AC:
            assert self.u32(sp+4)==SIZE
            index=len(self.resource_allocations);assert index<11
            token=0;r=None
            if not self.resource_nulls&(1<<index):
                token=self.resource_arena+0x10020+len(self.menu_bitmaps)*0x2000
                assert token+SIZE<self.resource_arena+0x1000000
                r=self.add_backing(token,SIZE,'menu-bitmap');self.menu_bitmaps.append(r)
            self.resource_allocations.append(dict(address=token,backing=None if r is None else self.blob(r['initial'])))
            self.revent('allocate',[SIZE]);self.ret(token)
        elif address==0x43EE50:pass # Actual body/return is observed below, not stubbed.
        elif address==0x43ED10:
            index=self.resource_pending['index'];path=self.cstr(uc.reg_read(UC_X86_REG_EDI));assert path.decode()==PATHS[index]
            assert [self.u32(sp+i) for i in (4,8,12)]==[self.u32(0x457578),0x40,0]
            desc=self.resources[path.decode().lower()];raw=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']]
            width,height=struct.unpack_from('<ii',raw,4);surface=0 if self.resource_missing&(1<<index) else self.resource_arena+0x2000+index*16
            self.resource_sources[path.decode()]=dict(path=path.decode(),resourcePath=desc['path'],width=width,height=height,dib=self.blob(raw))
            resource=dict(path=path.decode(),present=surface!=0,width=width if surface else None,height=height if surface else None)
            self.resource_inputs.append(dict(index=index,resource=resource,surface=surface,colorKeyResult=self.resource_keys[index]))
            self.revent('load',[self.u32(sp+4),0x40,0],[path])
            if surface:
                self.write_host(self.u32(sp+16),struct.pack('<i',width));self.write_host(self.u32(sp+20),struct.pack('<i',height))
            self.ret(surface)
        else:raise AssertionError(hex(address))

    def rcheckpoint(self,kind,index=-1):
        current=[dict(address=a['address'],storage=self.record(self.region(a['address'],SIZE))) for a in self.resource_allocations if a['address']]
        self.resource_checkpoints.append(dict(kind=kind,index=index,globals=self.globals(),records=current))

    def resource_code(self,uc,address,size,data):
        if not self.resources_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if self.resource_pending and address==self.resource_pending['returnAddress']:
            c=self.resource_pending;self.resource_pending=None
            assert sp==c['entrySP']+16 and c['saved']==[uc.reg_read(r) for r in REGISTERS] and uc.reg_read(UC_X86_REG_EAX)==c['address']
            c['returnSP']=sp;self.resource_calls.append(c)
        if address==0x43EE50:
            assert self.resource_pending is None
            index=len(self.resource_allocations)-1;token=self.resource_allocations[index]['address'];path=self.cstr(self.u32(sp+8))
            assert token!=0 and token==uc.reg_read(UC_X86_REG_ECX) and self.u32(sp)==RETURNS[index]
            assert self.u32(sp+4)==0x40 and self.u32(sp+12)==0 and path.decode()==PATHS[index]
            self.resource_pending=dict(index=index,address=token,entrySP=sp,returnAddress=self.u32(sp),saved=[uc.reg_read(r) for r in REGISTERS])
            self.revent('construct',[token,0x40,0],[path])
        elif address==0x4297E1:self.rcheckpoint('prefix')
        elif address in STORES:
            index=STORES.index(address);assert self.u32(SLOTS[index])==self.resource_allocations[index]['address'];self.rcheckpoint('bitmap',index)
        elif address==0x429B21:
            self.rcheckpoint('seats')
            if uc.reg_read(UC_X86_REG_EAX)==0:
                assert self.u32(0x44F8FC)==0
                self.resource_end='nullSpark';uc.emu_stop();return
        elif address==0x429C56:self.rcheckpoint('flag')
        elif address==0x429E5A:self.rcheckpoint('complete');self.resource_end='ready';uc.emu_stop();return
        elif self.resource_api<=address<=self.resource_api+0x30:
            arg=lambda i:self.u32(sp+4+i*4)
            if address==self.resource_api:self.revent('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16)
            elif address==self.resource_api+0x10:self.revent('debug',strings=[self.cstr(arg(0))]);self.ret(0x87654321,4)
            elif address==self.resource_api+0x20:
                item=self.resource_inputs[-1];assert arg(0)==item['surface'] and arg(1)==8 and bytes(uc.mem_read(arg(2),8))==bytes(8)
                self.revent('colorKey',[arg(0),arg(1)],[bytes(8)]);self.ret(item['colorKeyResult'],12)
            else:self.revent('release',[arg(0)]);self.ret(17,4)
            return
        assert (0x4297AE<=address<=0x429E5A or 0x43EE50<=address<=0x43EF41 or address in (0x43ED10,0x4450AC)
                or 0x4450B2<=address<=0x4450BA),hex(address)

    def resource_step(self,label,writes=(),nulls=0,missing=0,keys=None,inherited=False):
        stimulus=[]
        for address,value in writes:
            raw=struct.pack('<I',value&0xFFFFFFFF) if isinstance(value,int) else value
            self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
        if not inherited:
            for reg,value in [(UC_X86_REG_ESP,self.menu_sp),(UC_X86_REG_EBP,0x44D020),(UC_X86_REG_EDI,self.world_address)]:self.uc.reg_write(reg,value)
            for offset,value in [(0x14,self.world_address),(0x1C,0x451160),(0x24,self.u32(self.body_sp+0x68)),(0x40,0x44D020),
                                 (0x20,0x11223344),(0x28,0x11223344),(0x34,0x11223344),(0x38,0x11223344),(0x3C,0x11223344)]:self.put(self.menu_sp+offset,value)
        self.resource_nulls=nulls;self.resource_missing=missing;self.resource_keys=keys or [0]*11
        self.resource_allocations=[];self.resource_inputs=[];self.resource_events=[];self.resource_calls=[];self.resource_checkpoints=[];self.resource_pending=None;self.resource_end=None
        self.resources_running=True;self.phase='menu-resources'
        try:
            pc=0x4297AE
            for _ in range(20):
                self.uc.emu_start(pc,0,count=2_000_000);pc=self.uc.reg_read(UC_X86_REG_EIP)
                if self.resource_end is not None:break
            assert self.resource_end is not None and self.resource_pending is None
        except Exception:
            print('RESOURCE FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.resource_events[-3:],flush=True);raise
        finally:self.resources_running=False
        assert self.uc.reg_read(UC_X86_REG_ESP)==self.menu_sp
        assert [self.u32(self.menu_sp+i) for i in (0x20,0x28,0x34,0x38)]==[0]*4
        assert [self.uc.reg_read(r) for r in (UC_X86_REG_EBX,UC_X86_REG_ESI,UC_X86_REG_EBP,UC_X86_REG_EDI)]==[0xFFFFFFFF,0,0x44D020,self.world_address]
        if self.resource_end=='ready':assert [self.uc.reg_read(r) for r in (UC_X86_REG_ECX,UC_X86_REG_EDX)]==[2,1]
        state=self.control_snapshot()
        for k,v in self.resource_initial.items():
            if k!='globals':assert state[k]==v,(label,k)
        assert [self.record(r) for r in self.music_allocations]==self.resource_music
        return dict(label=label,stimulus=stimulus,inherited=inherited,allocations=self.resource_allocations,inputs=self.resource_inputs,
                    events=self.resource_events,calls=self.resource_calls,checkpoints=self.resource_checkpoints,
                    continuation=self.resource_end,selectionAtEntry=self.u32(self.menu_sp+0x3C),endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.menu_sp,
                    globals=state['globals'],records=[dict(address=r['address'],storage=self.record(r)) for r in self.menu_bitmaps])

    def resource_probes(self,cases):
        def writes(flag=1,menu=10,selection=0):
            return [(0x44D07C,flag),(0x44D020,menu),(0x4512C8,selection),(0x4512CC,0x12345678),
                    (0x451248,bytes((i*7+3)&255 for i in range(96)))]
        for i in range(20):cases.append(self.resource_step(f'unchanged-entry-{i}'))
        values=(-2147483648,-1,0,9,10,11,2147483647)
        for menu in values:
            for selection in values:cases.append(self.resource_step(f'skip-{menu}-{selection}',writes(flag=0,menu=menu,selection=selection)))
        for flag in (-2147483648,-1,1,2,2147483647):cases.append(self.resource_step(f'load-flag-{flag}',writes(flag=flag,selection=flag)))
        for index in range(11):cases.append(self.resource_step(f'null-{index}',writes(),nulls=1<<index))
        for mask in (0x7FF,0x3FF,0x555,0x2AA):cases.append(self.resource_step(f'null-mask-{mask}',writes(),nulls=mask))
        for index in range(11):cases.append(self.resource_step(f'missing-{index}',writes(),missing=1<<index))
        for index in range(11):
            for value in (-2147483648,-1,0,1,2147483647):
                keys=[0]*11;keys[index]=value;cases.append(self.resource_step(f'key-{index}-{value}',writes(),keys=keys))
        cases.append(self.resource_step('missing-all',writes(),missing=0x7FF))
        for value in (-1,1):cases.append(self.resource_step(f'key-all-{value}',writes(),keys=[value]*11))
        for i in range(8):
            cases.append(self.resource_step(f'mixed-{i}',writes(flag=-1,menu=i,selection=~i)+[(0x457578,[0,1,0x10203040,0xFFFFFFFF][i%4])],
                nulls=(0x249<<(i%3))&0x7FF,missing=(0x124<<(i%3))&0x7FF,keys=[-1 if (j+i)%2 else 1 for j in range(11)]))
        for i in range(20):cases.append(self.resource_step(f'consecutive-{i}',writes() if i%5==0 else ()))
        return cases

    def capture_resources(self):
        parents,initial,natural=self.capture_parent_music();suffix='-control' if self.control else ''
        r=json.loads((ROOT/'docs/evidence'/f'music-playback{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];old=json.loads(raw);assert parents==old['parents']
        assert transport(dict(initialContext=initial,case=natural),self.blobs)==transport(dict(initialContext=old['initialContext'],case=old['cases'][0]),old['blobs'])
        parents['music-playback']=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']);del old,raw
        assert self.u32(0x44D07C)==1 and self.uc.reg_read(UC_X86_REG_ESP)==self.menu_sp
        self.resource_initial=self.control_snapshot();self.resource_music=[self.record(r) for r in self.music_allocations];self.install_resources()
        cases=[self.resource_step('first-menu-resources',inherited=True)]
        print('Pinned natural music reproduced; resource continuation',cases[0]['continuation'],flush=True)
        self.resource_probes(cases)
        return transport(dict(exeSHA256=EXE_SHA256,scope=__doc__,control=self.control,parents=parents,initialGlobals=self.resource_initial['globals'],
                              sources=list(self.resource_sources.values()),cases=cases),self.blobs)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        path=ROOT/'docs/evidence'/f'menu-resources{suffix}.json';r=json.loads(path.read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];doc=json.loads(raw);temp=ROOT/'build/original'/f'menu-resources{suffix}-check.json';temp.write_text(pack(doc))
        fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixtures/doc['parents'][k]['fixture']) for k in ('music-playback','match-round','replay-tick','input-control','local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-resources',str(temp),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixtures/('original-'+r['corpus']);data=temp.read_bytes();r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((path,r,fixture,data))
    for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:accept();return
    vm=MenuResources(a.control);doc=vm.capture_resources();suffix='-control' if a.control else '';path=ROOT/'build/original'/f'menu-resources{suffix}.json'
    path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    counts={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in ('allocate','construct','load','colorKey','message','debug','release')}
    report=dict(exeSHA256=EXE_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),cases=len(doc['cases']),events=counts,
                checkpoints=sum(len(c['checkpoints']) for c in doc['cases']),nullSpark=sum(c['continuation']=='nullSpark' for c in doc['cases']),nativeComparison='pending')
    (ROOT/'docs/evidence'/f'menu-resources{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print('Captured',len(doc['cases']),'menu resource cases',counts,flush=True)


if __name__=='__main__':main()
