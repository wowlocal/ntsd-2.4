#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Fresh World/front resources/settings ->42709b through first real screen draw.
Whole4237e0/43c450,415160,423840/43ee50,43f010/43ef70; actual VC80 sprintf.
First caller stays on the same CPU/stack. Later caller entries, timer/thread/
allocator/device responses and fill-stack backing are declared inputs. Stops
before4236d0/alternate screen or invalid dereference; no Windows/pixel claim.
"""
import argparse,json,struct,subprocess
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from oracle_settings_loading import SettingsLoading,SCRATCH,DLL_SHA256
from oracle_front_menu_resources import GLOBAL,GLOBAL_SIZE,HEAP,SIZE,SOURCE,VTABLE,API,BODY_SP,REGISTERS
from oracle_bitmap_drawing import digest,packed,signed
from oracle_state import STACK,STOP
from unicorn import UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_ECX,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_EIP

PAPI,SURFACE,OTHER=STOP+0x9000,HEAP+0x6400,HEAP+0x6300
HELPERS={0x4237E0:0,0x43C450:0,0x415160:0,0x423840:0,0x43EE50:12,0x43F010:24,0x43EF70:0}


class FrontScreenPrelude(SettingsLoading):
    def before_front_resources(self):
        self.put(0x455608,SOURCE) # Declared surface binding before the fresh parent.
        self.initial_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
    def __init__(self,control=False):
        self.prefix_active=False
        super().__init__(control)
        raw=(DEFAULT_SOURCE/'data/control.txt').read_bytes();logical=raw.replace(b'\r\n',b'\n')
        settings=self.settings_step('first-source-text',logical)
        self.parent=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,control=control,
            source=dict(path='data/control.txt',raw=self.blob(raw),logical=self.blob(logical)),
            frontInitialGlobals=self.initial_globals,worldBacking=self.blob(self.world_initial),initialWorld=self.initial_world,
            front=self.front,sources=list(self.sources.values()),settingsInitialGlobals=self.initial_settings_globals,
            settingsWorld=self.initial_settings_world,settingsRecords=self.initial_settings_records,
            scratchAddress=SCRATCH,scratchBacking=self.blob(self.scratch_initial),cases=[settings])
        self.prefix_initial_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE));self.parent_count=len(self.regions)
        self.put(SURFACE,VTABLE);self.put(OTHER,VTABLE);self.put(VTABLE+0x14,PAPI)
        for at,to in [(0x447250,PAPI+16),(0x447174,0x7817775D),(0x4470A0,PAPI+32),(0x44709C,PAPI+48),(0x4470B0,PAPI+64),(0x4470A8,PAPI+80)]:self.put(at,to)
        self.uc.hook_add(UC_HOOK_MEM_READ,self.prefix_read,begin=HEAP,end=HEAP+0x3FFFFFF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.prefix_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.prefix_write,begin=STACK,end=STACK+0xFFFF)
        self.background_sources={}
    def emit(self,kind,arguments=(),strings=(),**extra):self.prefix_events.append(dict(kind=kind,arguments=list(arguments),strings=[list(s) for s in strings],**extra))
    def prefix_write(self,uc,access,address,size,value,data):
        if not self.prefix_active:return
        pc=uc.reg_read(UC_X86_REG_EIP)
        if GLOBAL<=address and address+size<=GLOBAL+GLOBAL_SIZE:
            self.emit('write',[address,size,value&((1<<(8*size))-1)])
        elif self.fill_effects is not None and self.fill_effects<=address and address+size<=self.fill_effects+100 and 0x415160<=pc<=0x4151C2:
            self.fill_mask[address-self.fill_effects:address-self.fill_effects+size]=[True]*size
    def prefix_read(self,uc,access,address,size,value,data):
        if not self.prefix_active or self.current_bitmap is None or not 0x43F010<=uc.reg_read(UC_X86_REG_EIP)<=0x43F2FE:return
        if self.current_bitmap<=address and address+size<=self.current_bitmap+SIZE:
            assert size==4;r,offset=self.locate(address,size)
            self.emit('read',read=dict(offset=offset,value=self.u32(address),defined=all(r['mask'][offset:offset+4])))
    def code(self,uc,address,size,data):
        if not self.prefix_active:return super().code(uc,address,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
        while self.calls_pending and address==self.calls_pending[-1]['returnPC']:
            call=self.calls_pending.pop();assert sp==call['entrySP']+4+call['pop'] and call['saved']==[uc.reg_read(r) for r in REGISTERS]
            call.update(returnSP=sp,result=uc.reg_read(UC_X86_REG_EAX));self.helper_returns.append(call)
        if self.format_pending and address==0x4238B9:
            assert sp==self.format_pending['sp']+4
            n=self.format_pending['number'];output=bytes(uc.mem_read(self.format_pending['destination'],14))
            self.emit('format',[n,uc.reg_read(UC_X86_REG_EAX)],[b'MENU_BACK%d',output]);self.format_pending=None
        if self.clip_pending and address==self.clip_pending['returnPC']:
            c=self.clip_pending;self.clip_pending=None
            self.emit('clip',clip=dict(beforeSource=c['source'],beforeDestination=c['destination'],source=[signed(self.u32(p)) for p in c['sourcePointers']],
                destination=[signed(self.u32(p)) for p in c['destinationPointers']],visible=uc.reg_read(UC_X86_REG_EAX)==1))
            assert uc.reg_read(UC_X86_REG_EAX) in (0,1)
        if address in (0x427127,0x4275CB):
            assert sp==BODY_SP and not self.calls_pending and self.clip_pending is None
            self.prefix_end='critical' if address==0x427127 else 'alternate';uc.emu_stop();return
        if address in (0x4151B6,0x43F04B,0x43F12B,0x43F2E6):
            pointer=uc.reg_read(UC_X86_REG_ESI if address==0x43F04B else UC_X86_REG_EAX)
            if pointer==0:
                self.prefix_end={0x4151B6:'nullFillTarget',0x43F04B:'nullBitmap',0x43F12B:'nullDrawTarget',0x43F2E6:'nullDrawTarget'}[address]
                uc.emu_stop();return
        if address in HELPERS:
            self.calls_pending.append(dict(entry=address,entrySP=sp,returnPC=self.u32(sp),pop=HELPERS[address],saved=[uc.reg_read(r) for r in REGISTERS]))
        if address==0x415160:
            assert [arg(i) for i in range(5)]==[0,0,794,550,self.input.get('fillColor',0x10206C)]
            self.fill_effects=sp-100;self.fill_backing=self.blob(uc.mem_read(self.fill_effects,100));self.fill_mask=[False]*100
        if address==0x43F010:
            self.current_bitmap=uc.reg_read(UC_X86_REG_ECX)
            assert [arg(0),arg(2),arg(3),arg(4),arg(5)]==[0,0xFFFFFFFF,1,0,self.input['drawTarget']]
            self.emit('draw',[self.current_bitmap,*[arg(i) for i in range(6)]])
        if address==0x43EF70:
            assert self.clip_pending is None
            src=[arg(i) for i in range(4)];dst=[uc.reg_read(UC_X86_REG_ECX),uc.reg_read(UC_X86_REG_EDI),arg(4),arg(5)]
            self.clip_pending=dict(returnPC=self.u32(sp),sourcePointers=src,destinationPointers=dst,source=[signed(self.u32(p)) for p in src],destination=[signed(self.u32(p)) for p in dst])
        if address==PAPI:
            if self.u32(sp)==0x4151BF:
                assert arg(2)==arg(3)==0 and arg(4)==0x1000400 and arg(5)==self.fill_effects
                self.emit('fill',fill=dict(target=arg(0),rectangle=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),
                    effects=list(uc.mem_read(arg(5),100)),defined=self.fill_mask.copy()));self.ret(self.input['fillResult'],24)
            else:
                assert arg(0)==self.input['drawTarget'] and arg(2) in (0,SURFACE)
                self.emit('blit',blit=dict(sourceSurface=arg(2),targetSurface=arg(0),source=list(struct.unpack('<4i',uc.mem_read(arg(3),16))),
                    destination=list(struct.unpack('<4i',uc.mem_read(arg(1),16))),flags=arg(4),effects=list(uc.mem_read(arg(5),100)) if arg(5) else None))
                result=self.input['drawResults'][self.blit_count%len(self.input['drawResults'])];self.blit_count+=1;self.ret(result,24)
            return
        if address==PAPI+16:self.emit('timer',[self.input['milliseconds']]);self.ret(self.input['milliseconds']);return
        if address in (PAPI+32,PAPI+48):
            assert arg(0)==0x4554A4;self.emit('enter' if address==PAPI+32 else 'leave',[arg(0)]);self.ret(0,4);return
        if address==PAPI+64:
            assert [arg(i) for i in range(5)]==[0,0,0x43C240,0,0] and arg(5)==BODY_SP-8
            self.put(arg(5),self.input['threadID']);self.emit('createThread',[*[arg(i) for i in range(5)],self.input['threadHandle'],self.input['threadID']]);self.ret(self.input['threadHandle'],24);return
        if address==PAPI+80:self.emit('lastError',[self.input['lastError']]);self.ret(self.input['lastError'],0);return
        if address==0x7817775D:
            assert self.cstr(arg(1))==b'MENU_BACK%d' and self.u32(sp)==0x4238B9
            self.format_pending=dict(sp=sp,destination=arg(0),number=arg(2));return
        if address==0x4450AC:
            assert arg(0)==SIZE and self.allocation is None;self.emit('allocate',[SIZE]);token=0
            if not self.null_allocation:
                logical=len(self.regions);physical=6144-logical if self.control else logical+8;token=HEAP+physical*0x2000+0x20;raw=self.backing(SIZE)
                self.uc.mem_write(token-16,b'\x96'*16+raw+b'\x69'*16);self.regions.append(dict(address=token,mask=bytearray(SIZE)))
                self.allocation=dict(address=token,backing=self.blob(raw))
            else:self.allocation=dict(address=0,backing=None)
            self.ret(token);return
        if address==0x43EE50:
            assert self.allocation and self.allocation['address']==uc.reg_read(UC_X86_REG_ECX) and [arg(0),arg(2)]==[0x40,0]
            self.path=self.cstr(arg(1)).decode();self.emit('construct',[uc.reg_read(UC_X86_REG_ECX),0x40,0],[self.path.encode()])
        if address==0x43ED10:
            assert self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode()==self.path and [arg(i) for i in range(3)]==[self.u32(0x457578),0x40,0]
            desc=self.resources[self.path];raw=self.pe.data[desc['fileOffset']:desc['fileOffset']+desc['size']];w,h=struct.unpack_from('<ii',raw,4)
            self.background_sources[self.path]=dict(path=self.path,width=w,height=h,dib=self.blob(raw))
            surface=0 if self.missing else SURFACE
            self.bitmap_input=dict(resource=dict(path=self.path,present=not self.missing,width=None if self.missing else w,height=None if self.missing else h),surface=surface,colorKeyResult=self.key)
            self.emit('load',[self.u32(0x457578),0x40,0],[self.path.encode()])
            if surface:self.write_host(arg(3),struct.pack('<i',w));self.write_host(arg(4),struct.pack('<i',h))
            self.ret(surface);return
        if API<=address<=API+48:
            if address==API:
                assert [arg(0),arg(1)]==[SURFACE,8] and bytes(uc.mem_read(arg(2),8))==bytes(8)
                self.emit('colorKey',[SURFACE,8],[bytes(8)]);self.ret(self.key,12)
            elif address==API+16:self.emit('release',[arg(0)]);self.ret(17,4)
            elif address==API+32:self.emit('message',[arg(0),arg(3)],[self.cstr(arg(1)),self.cstr(arg(2))]);self.ret(7,16)
            else:self.emit('debug',strings=[self.cstr(arg(0))]);self.ret(0x87654321,4)
            return
        assert (address==getattr(self,'prefix_return',None) or 0x42709B<=address<=0x427121 or 0x4237E0<=address<=0x423909 or 0x43C450<=address<=0x43C495 or
                0x415160<=address<=0x4151C2 or 0x43EE50<=address<=0x43F2FE or 0x4450B2<=address<=0x4450BA or
                0x78130000<=address<0x78230000 or STOP+0x6000<=address<STOP+0x8000),hex(address)
    def prefix_step(self,label,writes=(),milliseconds=0,missing=False,key=0,null=False,draw_target=SOURCE,thread=0x12345678,thread_id=0xABCD,error=5,fill_result=0,draw_results=(0,)):
        stimulus=[]
        for address,value in writes:
            raw=struct.pack('<I',value&0xFFFFFFFF) if isinstance(value,int) else value
            self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
        self.input=dict(drawTarget=draw_target,milliseconds=milliseconds,threadHandle=thread,threadID=thread_id,lastError=error,fillResult=fill_result,drawResults=list(draw_results))
        self.missing=missing;self.key=key;self.null_allocation=null;self.allocation=None;self.bitmap_input=None
        self.prefix_events=[];self.calls_pending=[];self.helper_returns=[];self.clip_pending=None;self.format_pending=None
        self.prefix_end=None;self.fill_effects=None;self.fill_backing=None;self.current_bitmap=None;self.blit_count=0
        if label!='first-screen-prefix':
            # Explicit later caller inputs. Only the first entry continues its
            # original predecessor without supplying registers/stack position.
            self.uc.reg_write(UC_X86_REG_ESP,BODY_SP);self.uc.reg_write(UC_X86_REG_EBX,0);self.uc.reg_write(UC_X86_REG_ESI,0xFFFFFFFF);self.uc.reg_write(UC_X86_REG_EDI,draw_target)
        assert [self.uc.reg_read(r) for r in (UC_X86_REG_ESP,UC_X86_REG_EBX,UC_X86_REG_ESI,UC_X86_REG_EDI)]==[BODY_SP,0,0xFFFFFFFF,draw_target]
        self.prefix_active=True
        try:self.uc.emu_start(0x42709B,0,count=500000)
        except Exception:
            print('PREFIX FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.prefix_events[-3:],flush=True);raise
        finally:self.prefix_active=False
        assert self.prefix_end and self.fill_backing and self.clip_pending is None and self.format_pending is None
        assert self.world_record()==self.initial_settings_world
        for r in self.regions:assert bytes(self.uc.mem_read(r['address']-16,16))==b'\x96'*16 and bytes(self.uc.mem_read(r['address']+SIZE,16))==b'\x69'*16
        return dict(label=label,stimulus=stimulus,input=self.input,fillBacking=self.fill_backing,allocation=self.allocation,bitmapInput=self.bitmap_input,events=self.prefix_events,
                    helpers=self.helper_returns,pending=self.calls_pending,continuation=self.prefix_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),
                    globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),world=self.world_record(),records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions])
    def capture_prefix(self):
        cases=[self.prefix_step('first-screen-prefix')]
        for selector in (-2147483648,-3,-2,-1,0,1,2147483647):
            for setting in (-2147483648,-1,0,1,2,2147483647):cases.append(self.prefix_step(f'select-{selector}-{setting}',[(0x44D064,selector),(0x450BE8,setting)]))
        for value in [*range(13),13,25,26,0x7FFFFFFF,0x80000000,0xFFFFFFFE,0xFFFFFFFF]:
            cases.append(self.prefix_step(f'timer-{value}',[(0x4511AC,0),(0x44D064,0)],milliseconds=value))
        for label,left,right,gate in [('sentinel',b'z\0',b'a\0',-99),('now',b'now\0',b'a\0',0),('equal',b'abc\0',b'abc\0',0),('less',b'ab\0',b'abc\0',0),('greater',b'abc\0',b'ab\0',0),('high-less',b'\x7f\0',b'\x80\0',0),('high-greater',b'\xff\0',b'\x80\0',0),('empty',b'\0',b'a\0',0)]:
            for status in (-1,0,1,2):
                for thread in (0,0x87654321):
                    cases.append(self.prefix_step(f'worker-{label}-{status}-{thread}',[(0x44D064,-2),(0x450BE8,1),(0x44D788,gate),(0x4527B0,left),(0x451D48,right),(0x458424,status)],thread=thread))
        for y in (-2147483648,-551,-547,-1,0,1,549,550,551,2147483647):
            for width,height in ((794,550),(0,0),(-1,-1)):
                cases.append(self.prefix_step(f'view-{y}-{width}-{height}',[(0x44D064,0),(0x453DA4,y),(0x44D78C,width),(0x44D790,height)],fill_result=-1,draw_results=(-1,1)))
        for missing in (False,True):
            for key in (-2147483648,-1,0,1,2147483647):
                cases.append(self.prefix_step(f'device-{missing}-{key}',[(0x4511AC,0),(0x44D064,0),(0x453DA4,0),(0x44D78C,794),(0x44D790,550)],missing=missing,key=key))
        cases.append(self.prefix_step('null-allocation',[(0x4511AC,0)],null=True))
        cases.append(self.prefix_step('null-fill',[(0x455608,0)]))
        cases.append(self.prefix_step('null-draw',[(0x455608,OTHER),(0x4511AC,0)],draw_target=0))
        for i in range(8):cases.append(self.prefix_step(f'reuse-{i}',[(0x455608,SOURCE),(0x44D064,i%2)],milliseconds=12-i,draw_results=(-2147483648,2147483647)))
        return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,parent=self.parent,
                    initialGlobals=self.prefix_initial_globals,sources=list(self.background_sources.values()),cases=cases,blobs=self.blobs)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--accept',action='store_true');args=p.parse_args()
    if args.accept:
        subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
        pending=[]
        for suffix in ('','-control'):
            path=ROOT/'docs/evidence'/f'front-screen-prelude{suffix}.json';report=json.loads(path.read_bytes());raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
            data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode();temp=ROOT/'build/original'/f'front-screen-prelude{suffix}-check.json';temp.write_bytes(data)
            result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--front-screen-prelude',str(temp)],capture_output=True,text=True);print(result.stdout,end='',flush=True)
            if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
            fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus']);report.update(nativeCompared=True,nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data))
            pending.append((path,report,fixture,data))
        for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
        return
    doc=FrontScreenPrelude(args.control).capture_prefix();suffix='-control' if args.control else '';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
    path=ROOT/'build/original'/f'front-screen-prelude{suffix}.json';path.write_bytes(raw)
    kinds=sorted({e['kind'] for c in doc['cases'] for e in c['events']})
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=digest(raw),cases=len(doc['cases']),sources=len(doc['sources']),
        events={k:sum(e['kind']==k for c in doc['cases'] for e in c['events']) for k in kinds},helpers=sum(len(c['helpers']) for c in doc['cases']),
        continuations={k:sum(c['continuation']==k for c in doc['cases']) for k in sorted({c['continuation'] for c in doc['cases']})},nativeCompared=False)
    (ROOT/'docs/evidence'/f'front-screen-prelude{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
