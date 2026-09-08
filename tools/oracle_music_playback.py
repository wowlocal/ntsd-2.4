#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole402020/401d30/401c90/401da0/401f30 after reproduced first round.
Primary continues real4229cc->429730 with music still enabled, stopping4297ae
before menu bitmap initialization. Paused control supplies this menu entry;
it does not pretend to have rendered the pause branch. COM/Win32/allocator
outputs are explicit inputs, sprintf executes the pinned VC80 DLL. No output
devices or actual Windows file/codec execution, and no baseline file writes.
"""
import argparse
import json
import struct
import subprocess
from import_ntsd import ROOT, EXE_SHA256
from oracle_match_round import MatchRound
from oracle_initial_loading import transport, WORLD
from oracle_catalog_sounds import REGISTERS, pack
from oracle_wave_loader import digest
from oracle_crt import DLL_SHA256
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP

ARENA, API = 0x2C000000, 0x30004000
TOKENS=[ARENA+0x2000+i*0x100 for i in range(5)]
HELPERS=(0x402020,0x401D30,0x401C90,0x401DA0,0x401F30)


def platform(**changes):
    c=dict(createResult=0,createPointer=TOKENS[0],queryResults=[0]*4,queryPointers=TOKENS[1:],
           methodResult=-2147467259,renderResult=0,getResult=0,setResult=-1,fileResult=-1,
           nullAllocation=False,conversion='complete',conversionResult=None)
    # queryPointers: control,event,position,basic-audio.
    c.update(changes);return c


class MusicPlayback(MatchRound):
    def __init__(self,control=False,music_arena=ARENA,music_api_address=API,**loading_options):
        self.music_api_address=music_api_address;self.music_arena=music_arena;self.music_tokens=[music_arena+0x2000+i*0x100 for i in range(5)]
        super().__init__(control,**loading_options);self.music_running=False;self.music_allocations=[];self.music_pending=[]
        self.uc.mem_map(self.music_arena,0x400000);self.uc.mem_map(self.music_api_address,0x1000)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.track_write,begin=self.music_arena+0x10000,end=self.music_arena+0x3FFFFF)

    def install_music(self):
        # Keep the strict whole-instruction guard off the already independently
        # instrumented loading parent. It has no work until this continuation.
        self.uc.hook_add(UC_HOOK_CODE,self.music_code)
        self.music_imports={}
        for i,(iat,name) in enumerate([(0x4472B8,'createInstance'),(0x447094,'createFile'),(0x447090,'convert'),
                                     (0x44708C,'closeHandle'),(0x4471C8,'message'),(0x447174,'format')]):
            a=self.music_api_address+i*16;self.put(iat,a);self.music_imports[a]=name
        for token in self.music_tokens:
            self.put(token,token+0x40)
            for offset in (0,8,0x1C,0x20,0x34,0x38,0x3C):
                a=self.music_api_address+0x100+offset*4;self.put(token+0x40+offset,a);self.music_imports[a]=offset

    def write_host(self,address,raw):
        if self.music_arena+0x10000<=address<self.music_arena+0x400000:
            self.track_write(self.uc,0,address,len(raw),0,None);self.uc.mem_write(address,raw)
        else:super().write_host(address,raw)

    def mevent(self,kind,args=(),strings=(),result=0,pointer=None,raw=None):
        response=dict(result=result,pointer=pointer,bytes=None if raw is None else list(raw))
        self.music_events.append(dict(kind=kind,arguments=list(args),strings=[list(s) for s in strings],response=response))

    def music_code(self,uc,address,size,data):
        if not self.music_running:return
        sp=uc.reg_read(UC_X86_REG_ESP)
        if self.music_pending and address==self.music_pending[-1]['returnAddress']:
            c=self.music_pending.pop();assert sp==c['entrySP']+4 and c['saved']==[uc.reg_read(r) for r in REGISTERS]
            c['returnSP']=sp;c['returned']=uc.reg_read(UC_X86_REG_EAX);self.music_calls.append(c)
        if address==self.music_end:self.music_finished=True;uc.emu_stop();return
        if address in HELPERS:
            args=[address];strings=[]
            if address in (0x402020,0x401DA0):strings=[self.cstr(self.u32(sp+4))]
            if address==0x401F30:args.append(self.u32(sp+4))
            self.mevent('helper',args,strings)
            self.music_pending.append(dict(entry=address,entrySP=sp,returnAddress=self.u32(sp),saved=[uc.reg_read(r) for r in REGISTERS]))
        if address==0x4450C8:
            count=self.u32(sp+4);assert count<=0x10000
            token=0
            if not self.music_input['nullAllocation']:
                token=self.music_arena+0x10020+len(self.music_allocations)*0x1000
                r=self.add_backing(token,count,'music-wide');self.music_allocations.append(r)
                raw=r['initial']
            else:raw=None
            self.mevent('allocate',[count],pointer=token,raw=raw);self.ret(token);return
        if address in self.music_imports:self.music_api(self.music_imports[address]);return
        assert (0x401C90<=address<=0x401E85 or 0x401F30<=address<=0x4020F6 or 0x4450B2<=address<=0x4450BA
                or 0x429730<=address<=0x4297AE or 0x4229CC<=address<=0x4229E2),hex(address)

    def music_api(self,name):
        sp=self.uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+i*4);c=self.music_input
        if isinstance(name,int):
            token=arg(0);assert token in self.music_tokens
            if name==0:
                iid=bytes(self.uc.mem_read(arg(1),16));index={0xB1:0,0xB6:1,0xB2:2,0xB3:3}[iid[0]]
                pointer=c['queryPointers'][index];result=c['queryResults'][index]
                self.mevent('queryInterface',[token],[iid],result,pointer)
                if pointer is not None:self.put(arg(2),pointer)
                self.ret(result,12)
            elif name==0x20:
                self.mevent('audioVolumeRead',[token],result=c['getResult'],pointer=0xFFFFFB2E)
                self.put(arg(1),0xFFFFFB2E);self.ret(c['getResult'],8)
            else:
                count={8:1,0x1C:1 if token==self.music_tokens[1] else 2,0x34:3 if token==self.music_tokens[0] else 4,0x38:2,0x3C:2}[name]
                args=[token,name]+[arg(i) for i in range(1,count)];strings=[];result=c['methodResult']
                if name==0x34 and token==self.music_tokens[0]:
                    result=c['renderResult']
                    if arg(1):strings=[bytes(self.uc.mem_read(arg(1),self.region(arg(1),1)['size']))]
                elif name==0x1C and token==self.music_tokens[4]:result=c['setResult']
                self.mevent('method',args,strings,result);self.ret(result,count*4)
        elif name=='createInstance':
            args=[arg(i) for i in range(5)];assert args==[0x44A2A4,0,1,0x44A254,0x44F040]
            self.mevent(name,args,result=c['createResult'],pointer=c['createPointer'])
            if c['createPointer'] is not None:self.put(arg(4),c['createPointer'])
            self.ret(c['createResult'],20)
        elif name=='format':
            fmt=self.cstr(arg(1));assert fmt==b'%s\\graph.log'
            result=self.crt.format(fmt,[self.cstr(arg(2))]);raw=bytes.fromhex(result['bytes']);assert len(raw)<=260
            self.uc.mem_write(arg(0),raw);self.mevent(name,[result['result']],[fmt,raw[:-1]])
            self.music_formats.append(result);self.ret(result['result'])
        elif name=='createFile':
            self.mevent(name,[arg(i) for i in range(1,7)],[self.cstr(arg(0))],c['fileResult']);self.ret(c['fileResult'],28)
        elif name=='convert':
            path=self.cstr(arg(2));pointer=arg(4);count=arg(5)
            assert [arg(0),arg(1),arg(3)]==[0,0,0xFFFFFFFF] and count==len(path)+1
            raw=b''.join(bytes([b,0]) for b in path+b'\0')
            if c['conversion']=='none' or pointer==0:raw=b''
            elif c['conversion']=='partial':raw=raw[:max(1,len(raw)//3)]
            elif c['conversion']=='opaque':raw=bytes([0x81,0xD8,0x41,0])[:len(raw)]
            if raw:self.write_host(pointer,raw)
            result=(count if raw else 0) if c['conversionResult'] is None else c['conversionResult']
            self.mevent(name,[arg(0),arg(1),arg(3),pointer,count],[path],result,raw=raw);self.ret(result,24)
        elif name=='closeHandle':self.mevent(name,[arg(0)],result=0);self.ret(0,4)
        elif name=='message':self.mevent(name,[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))],7);self.ret(7,16)
        else:raise AssertionError(name)

    def music_step(self,label,path=b'bgm\\main.wma',writes=(),cfg=None,kind='play',inherited=False):
        stimulus=[]
        for address,value in writes:
            raw=struct.pack('<I',value&0xFFFFFFFF) if isinstance(value,int) else value
            self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
        self.music_input=cfg or platform();self.music_events=[];self.music_calls=[];self.music_formats=[]
        assert not self.music_pending
        if kind=='menu':
            if not inherited:
                self.uc.reg_write(UC_X86_REG_ESP,self.body_sp);self.uc.reg_write(UC_X86_REG_EBX,self.world_address)
            start=0x4229CC;self.music_end=0x4297AE
        else:
            start=0x402020;self.music_end=STOP
            self.uc.mem_write(self.music_arena+0x1000,path+b'\0')
            self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF004);self.put(STACK+0xF004,STOP);self.put(STACK+0xF008,self.music_arena+0x1000)
        self.music_running=True;self.music_finished=False;self.phase='music'
        try:
            pc=start
            for _ in range(20):
                self.uc.emu_start(pc,0,count=2_000_000);pc=self.uc.reg_read(UC_X86_REG_EIP)
                if self.music_finished:break
            assert self.music_finished
        except Exception:
            print('MUSIC FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.music_events[-3:],flush=True);raise
        finally:self.music_running=False
        assert not self.music_pending
        snapshot=self.control_snapshot()
        for k,v in self.music_initial.items():
            if k!='globals':assert snapshot[k]==v,(label,k)
        return dict(label=label,path=list(path),kind=kind,inherited=inherited,stimulus=stimulus,events=self.music_events,
                    calls=self.music_calls,formats=self.music_formats,afterGlobals=snapshot['globals'],
                    allocations=[dict(address=r['address'],storage=self.record(r)) for r in self.music_allocations],
                    endPC=self.music_end,endSP=self.uc.reg_read(UC_X86_REG_ESP))

    def capture_parent_music(self):
        parents,initial,natural=self.capture_parent_round();suffix='-control' if self.control else ''
        r=json.loads((ROOT/'docs/evidence'/f'match-round{suffix}.json').read_bytes());raw=(ROOT/'build/original'/r['corpus']).read_bytes()
        assert digest(raw)==r['sha256'];old=json.loads(raw);assert parents==old['parents']
        assert transport(dict(initialContext=initial,case=natural),self.blobs)==transport(dict(initialContext=old['initialContext'],case=old['cases'][0]),old['blobs'])
        parents['match-round']=dict(fixture=r['fixture'],sha256=r['fixtureSHA256']);del old,raw
        assert self.u32(0x44D010)==1 and self.u32(0x44D020)==10 and self.u32(0x4512CC)==0
        self.music_initial=self.control_snapshot();self.install_music()
        natural=self.music_step('first-menu-music',kind='menu',inherited=not self.control)
        print('Real menu prefix and enabled402020 returned; no loaded state replaced',flush=True)
        return parents,self.music_initial,natural

    def capture_music(self):
        parents,initial,natural=self.capture_parent_music();cases=[natural]
        self.music_probes(cases)
        return transport(dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parents=parents,
                              initialContext=initial,cases=cases),self.blobs)

    def music_probes(self,cases):
        def writes(enabled=1,cached=b'old.wma',mask=15,volume=75,directory=b'C:\\NTSD'):
            return [(0x44D010,enabled),(0x44D000,volume),(0x44EF04,cached+b'\0'),(0x44EF38,directory+b'\0')]+[
                (address,self.music_tokens[i] if mask&(1<<i) else 0) for i,address in enumerate((0x44F040,0x44F044,0x44F048,0x44F04C))]
        for enabled in (0,1,-1,-2147483648,2147483647):
            for mask in range(16):
                for cached in (b'old.wma',b'bgm\\main.wma'):
                    cases.append(self.music_step(f'gate-{enabled}-{mask}-{cached.decode()}',writes=writes(enabled,cached,mask)))
        for previous in (-2147483648,-1,0,9,10,11,2147483647):
            for menu in (-2147483648,-1,0,9,10,11,2147483647):
                cases.append(self.music_step(f'menu-{previous}-{menu}',kind='menu',writes=writes()+[(0x4512CC,previous),(0x44D020,menu)]))
        for volume in (-2147483648,-101,-1,0,1,50,100,101,2147483647):
            for result in (-2147467263,-2147467259,-1,0,1,2147483647):
                cases.append(self.music_step(f'volume-{volume}-{result}',writes=writes(volume=volume),cfg=platform(getResult=result,setResult=result)))
        for result in (-2147483648,-1,0,1,2147483647):
            for key in ('createResult','renderResult'):
                for pointer in (0,self.music_tokens[0]) if key=='createResult' and result<0 else (self.music_tokens[0],):
                    cfg=platform(**{key:result});cfg['createPointer']=pointer
                    cases.append(self.music_step(f'{key}-{result}-{pointer}',writes=writes(),cfg=cfg))
            for index in range(4):
                cfg=platform();cfg['queryResults'][index]=result
                cases.append(self.music_step(f'query-{index}-{result}',writes=writes(),cfg=cfg))
        for index in (0,2):
            for pointer in (0,None):
                cfg=platform();cfg['queryPointers'][index]=pointer
                cases.append(self.music_step(f'optional-interface-{index}-{pointer}',writes=writes(),cfg=cfg))
        for result in (-1,0,1,2147483647):
            for mode in ('none','partial','opaque','complete'):
                cases.append(self.music_step(f'conversion-{result}-{mode}',writes=writes(),cfg=platform(conversion=mode,conversionResult=result)))
        cases.append(self.music_step('null-wide-allocation',writes=writes(),cfg=platform(nullAllocation=True)))
        for path in (b'',b'odd',b'1234',b'bgm\\MAIN.wma',b'A'*51,b'A'*52,b'A'*99,bytes([0x81,0xFF,0x41])):
            cases.append(self.music_step('path-'+path.hex(),path=path,writes=writes()))
        for directory in (b'',b'C:\\NTSD 2.4',b'A'*248,b'A'*249,bytes([0x81,0xFF])):
            cases.append(self.music_step('log-'+directory.hex(),writes=writes(directory=directory)))
        for name in ('main','stage1','stage2','stage3','stage4','stage5','boss1','boss2'):
            cases.append(self.music_step('original-path-'+name,path=('bgm\\'+name+'.wma').encode(),writes=writes()))
        for result in (-2147483648,-1,0,1,2147483647):
            for key in ('fileResult','methodResult'):
                cases.append(self.music_step(f'{key}-{result}',writes=writes(),cfg=platform(**{key:result})))
        for result in (-2147483648,-1):
            cases.append(self.music_step(f'failed-create-untouched-{result}',writes=writes(),cfg=platform(createResult=result,createPointer=None)))
            for pointer in (0,None):
                cfg=platform();cfg['queryResults'][3]=result;cfg['queryPointers'][3]=pointer
                cases.append(self.music_step(f'failed-audio-query-{result}-{pointer}',writes=writes(),cfg=cfg))
        for i in range(20):
            cases.append(self.music_step(f'consecutive-{i}',path=b'bgm\\main.wma' if i%4<2 else b'bgm\\stage1.wma',
                writes=writes() if i==0 else (),cfg=platform(renderResult=-1 if i%3==0 else 0)))
        return cases


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    pending=[]
    for suffix in ('','-control'):
        path=ROOT/'docs/evidence'/f'music-playback{suffix}.json';r=json.loads(path.read_bytes())
        raw=(ROOT/'build/original'/r['corpus']).read_bytes();assert digest(raw)==r['sha256'];doc=json.loads(raw)
        temp=ROOT/'build/original'/f'music-playback{suffix}-check.json';temp.write_text(pack(doc));fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
        parents=[str(fixtures/doc['parents'][k]['fixture']) for k in ('match-round','replay-tick','input-control','local-input','initial-loading','initial-loading-catalog','initial-loading-sounds')]
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--music-playback',str(temp),*parents],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        fixture=fixtures/('original-'+r['corpus']);data=temp.read_bytes()
        r.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data),parents=doc['parents'])
        pending.append((path,r,fixture,data))
    for path,r,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(r,indent=2)+'\n')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');a=p.parse_args()
    if a.accept:accept();return
    vm=MusicPlayback(a.control);doc=vm.capture_music();suffix='-control' if a.control else ''
    path=ROOT/'build/original'/f'music-playback{suffix}.json';path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    counts={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in ('helper','method','queryInterface','allocate','message','format','convert')}
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(path.read_bytes()),
                cases=len(doc['cases']),events=counts,nativeComparison='pending')
    (ROOT/'docs/evidence'/f'music-playback{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(doc['cases']),'music cases',counts,flush=True)


if __name__=='__main__':main()
