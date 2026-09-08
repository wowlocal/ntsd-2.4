#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real front resources ->427089/423480/427092 through42709b.
Actual VC80 fscanf/fgets/feof execute in the SAME CPU/stack as the EXE.
Fopen/fclose, translated _read bytes, single-thread services and scratch backing
remain supplied boundaries. The first entry continues freshly executed World /
front resources; later entries are explicit calls on persistent state, not full
menu iterations. Caller EBX is the final flag-store value (natural zero).
Independent native comparison is required for fixture acceptance. Windows file
opening/translation, pixels and the full menu remain outside this capture.
"""
import argparse
import hashlib
import json
import struct
import subprocess
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from oracle_front_menu_resources import FrontMenuResources,GLOBAL,GLOBAL_SIZE,WORLD,WORLD_PREFIX,HEAP,SIZE,BODY_SP,REGISTERS
from oracle_crt import CRT,DLL_SHA256,prepare,AREA,FILE,INPUT,STOP
from oracle_bitmap_drawing import packed,digest
from unicorn import UC_HOOK_CODE,UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EIP,UC_X86_REG_ESP

OPEN,CLOSE=STOP+0x40,STOP+0x50
SCAN,GETS,EOF=0x78175F0B,0x7817A00D,0x78179E0D
ENTRY_SP=BODY_SP-4
SCRATCH=ENTRY_SP-0x1F8
SCRATCH_SIZE=0x1F4 # Bytes up to, but excluding, the cookie. Not a C array-size claim.


class SettingsLoading(FrontMenuResources):
    def __init__(self,control=False):
        self.settings_active=False
        super().__init__(control)
        # This is freshly executed evidence, not a stored after-state fed back in.
        self.front=self.step('first-front-resources')
        assert self.front['continuation']=='settings' and self.uc.reg_read(UC_X86_REG_EIP)==0x427089
        self.initial_settings_globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE))
        self.initial_settings_world=self.world_record()
        self.initial_settings_records=[dict(address=r['address'],storage=self.record(r)) for r in self.regions]
        self.scratch_initial=self.backing(SCRATCH_SIZE);self.uc.mem_write(SCRATCH,self.scratch_initial)
        self.scratch_mask=bytearray(SCRATCH_SIZE)
        self.attach_crt()
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.settings_write,begin=GLOBAL,end=GLOBAL+GLOBAL_SIZE-1)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.settings_write,begin=SCRATCH,end=SCRATCH+SCRATCH_SIZE-1)

    def attach_crt(self):
        # Actual _initptd in its established standalone harness supplies one PTD.
        # All subsequent file functions run on the existing game's Unicorn CPU.
        crt=CRT();raw=prepare().read_bytes();pe=PE(raw)
        self.uc.mem_map(pe.base,0x100000);self.uc.mem_write(pe.base,bytes(crt.uc.mem_read(pe.base,0x100000)))
        self.uc.mem_map(AREA,0x20000);self.uc.mem_write(AREA,bytes(crt.uc.mem_read(AREA,0x20000)))
        self.uc.mem_map(STOP+0x1000,0xF000)
        crt.uc=self.uc;crt.boundaries={a:n for a,n in crt.boundaries.items() if not STOP<=a<STOP+0x10000}
        for i,item in enumerate(pe.imports()):
            address=STOP+0x6000+16*i;self.put(int(item['iatVA'],16),address);crt.boundaries[address]=item['name']
        for address in crt.boundaries:self.uc.hook_add(UC_HOOK_CODE,crt.boundary,begin=address,end=address)
        self.crt=crt
        for at,to in [(0x447190,OPEN),(0x447184,CLOSE),(0x447188,SCAN),(0x44719C,GETS),(0x44718C,EOF)]:self.put(at,to)

    def stream_position(self):return self.crt.read_position-self.u32(FILE+4)
    def stream_eof(self):return bool(self.u32(FILE+12)&16)
    def scratch_record(self):return dict(bytes=self.blob(self.uc.mem_read(SCRATCH,SCRATCH_SIZE)),defined=self.blob(self.scratch_mask))
    def settings_write(self,uc,access,address,size,value,data):
        if not self.settings_active:return
        pc=uc.reg_read(UC_X86_REG_EIP)
        if SCRATCH<=address and address+size<=SCRATCH+SCRATCH_SIZE:
            self.scratch_mask[address-SCRATCH:address-SCRATCH+size]=b'\1'*size
        else:
            assert GLOBAL<=address and address+size<=GLOBAL+GLOBAL_SIZE,(hex(pc),hex(address),size)
            if 0x423480<=pc<0x4236CA or pc==0x427092:
                self.settings_events.append(dict(kind='write',arguments=[address,size,value&((1<<(8*size))-1)]))

    def code(self,uc,address,size,data):
        if not self.settings_active:return super().code(uc,address,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
        if self.file_pending and address==self.file_pending['returnPC']:
            event=self.file_pending;self.file_pending=None
            assert sp==event.pop('entrySP')+4 and event.pop('saved')==[uc.reg_read(r) for r in REGISTERS]
            event.update(result=uc.reg_read(UC_X86_REG_EAX),position=self.stream_position(),eof=self.stream_eof(),
                         globals=self.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),scratch=self.scratch_record())
            self.settings_events.append(event)
        if address==0x427089:
            assert sp==BODY_SP;return
        if address==0x423480:
            assert sp==ENTRY_SP and self.u32(sp)==0x42708E
            self.helper_saved=[uc.reg_read(r) for r in REGISTERS];return
        if address==0x42708E:
            assert sp==BODY_SP and self.helper_saved==[uc.reg_read(r) for r in REGISTERS]
            self.settings_events.append(dict(kind='settingsReturn',arguments=[sp,uc.reg_read(UC_X86_REG_EAX)],
                                            globals=self.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),scratch=self.scratch_record()))
            return
        if address==0x42709B:
            assert self.file_pending is None and sp==BODY_SP and self.closed
            self.settings_end='ready';uc.emu_stop();return
        if address==OPEN:
            assert self.cstr(arg(0))==b'data\\control.txt' and self.cstr(arg(1))==b'r'
            self.settings_events.append(dict(kind='open',arguments=[FILE if self.present else 0],strings=['data\\control.txt','r']))
            self.uc.mem_write(FILE,struct.pack('<8I',INPUT,0,INPUT,9,0xFFFFFFFF,0,0x10000,0))
            self.ret(FILE if self.present else 0);return
        if address==CLOSE:
            assert self.present and arg(0)==FILE and not self.closed
            self.closed=True;self.settings_events.append(dict(kind='close',arguments=[FILE,self.close_result&0xFFFFFFFF]))
            self.ret(self.close_result);return
        if address==0x4234DB and not self.present:
            # Actual EXE has no fopen failure check. Do not turn CRT's invalid
            # FILE handling into a successful settings load or clear the flag.
            assert uc.reg_read(UC_X86_REG_ESP)==ENTRY_SP-0x21C
            self.settings_end='nullFile';uc.emu_stop();return
        if address in (SCAN,GETS,EOF):
            assert self.file_pending is None and self.present and not self.closed
            event=dict(kind={SCAN:'scan',GETS:'gets',EOF:'eof'}[address],before=self.stream_position(),returnPC=self.u32(sp),
                       entrySP=sp,saved=[uc.reg_read(r) for r in REGISTERS])
            if address==SCAN:
                assert arg(0)==FILE
                fmt=self.cstr(arg(1)).decode('latin1');assert fmt in ('%d','%s %s %s %s\n','%d\n')
                count=4 if fmt.startswith('%s') else 1
                event.update(format=fmt,arguments=[arg(2+i) for i in range(count)])
            elif address==GETS:
                assert arg(1)==100 and arg(2)==FILE and arg(0) in (0x44FD18,0x44F890,SCRATCH)
                event.update(arguments=[arg(0),100])
            else:assert arg(0)==FILE
            self.file_pending=event;return
        assert (0x423480<=address<0x4236CA or 0x42708E<=address<0x42709B or
                0x4450B2<=address<=0x4450BA or 0x78130000<=address<0x78230000 or
                STOP+0x6000<=address<STOP+0x8000),hex(address)

    def settings_step(self,label,data,chunk=4096,*,present=True,close_result=0,writes=()):
        stimulus=[]
        for address,raw in writes:
            self.uc.mem_write(address,raw);stimulus.append(dict(address=address,bytes=raw.hex()))
        self.crt.data=data;self.crt.chunk=chunk;self.crt.read_position=0
        self.present=present;self.close_result=close_result;self.closed=False;self.file_pending=None
        self.settings_events=[];self.settings_end=None
        if self.uc.reg_read(UC_X86_REG_ESP)!=BODY_SP:
            # A preceding null-file case stopped inside its caller. Later probes
            # explicitly provide the already established outer caller frame.
            self.uc.reg_write(UC_X86_REG_ESP,BODY_SP)
        caller_ebx=self.uc.reg_read(UC_X86_REG_EBX)
        self.settings_active=True
        try:self.uc.emu_start(0x427089,0,count=5_000_000)
        except Exception:
            print('SETTINGS FAILURE',label,hex(self.uc.reg_read(UC_X86_REG_EIP)),self.settings_events[-3:],flush=True);raise
        finally:self.settings_active=False
        assert self.settings_end and self.file_pending is None
        assert self.world_record()==self.initial_settings_world
        assert [dict(address=r['address'],storage=self.record(r)) for r in self.regions]==self.initial_settings_records
        return dict(label=label,input=self.blob(data),chunk=chunk,present=present,closeResult=close_result,callerEBX=caller_ebx,stimulus=stimulus,
                    events=self.settings_events,continuation=self.settings_end,endPC=self.uc.reg_read(UC_X86_REG_EIP),endSP=self.uc.reg_read(UC_X86_REG_ESP),
                    globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),scratch=self.scratch_record())

    def capture_settings(self):
        raw=(DEFAULT_SOURCE/'data/control.txt').read_bytes();logical=raw.replace(b'\r\n',b'\n')
        # Translation is a declared _read boundary, independently of CRT parsing.
        cases=[self.settings_step('first-source-text',logical)]
        prefix=logical[:logical.index(b'<No name>')]
        probes=[('source-raw',raw),('trailing-lf',logical+b'\n'),('two-info-lines',logical+b'\nsecond\n'),
                ('empty',b''),('only-whitespace',b' \t\r\n\v\f'),('cut-before-profile',prefix),
                ('empty-info',prefix+b'name\nemail\n'),('empty-name-line',prefix+b'\nemail\ninfo'),
                ('tab-trim',prefix+b'name\t \nemail\t \ninfo'),('all-trim',prefix+b' \r\n \r\ninfo'),
                ('nul-profile',prefix+b'name\0tail\nemail\0tail\ninfo\0hidden'),
                ('backtick-names',logical.replace(b'1 2 3 4\n',b'one`a two``b ```four `\n')),
                ('overlapping-names',logical.replace(b'1 2 3 4\n',b'abcdefghijklmnopqrst 2 long``thirdname 4\n')),
                ('name99',prefix+b'n'*99+b'\nemail\ninfo'),('name100',prefix+b'n'*100+b'\nemail\ninfo'),
                ('info99',prefix+b'name\nemail\n'+b'i'*99),('info100',prefix+b'name\nemail\n'+b'i'*100),
                ('info198',prefix+b'name\nemail\n'+b'i'*198),('info-long',prefix+b'name\nemail\n'+b'i'*1500),
                ('bad-first-integer',b'x '+logical),('sign-first-integer',b'+ '+logical),
                ('overflow-first-integer',b'4294967296'+logical[1:]),
                ('huge-first-integer',b'-'+b'9'*1024+logical[1:]),('single-sign',b'-'),('single-token',b'23'),
                ('profile-no-email',prefix+b'name'),('profile-email-no-info',prefix+b'name\nemail')]
        for label,data in probes:
            for chunk in (1,7,4096):cases.append(self.settings_step(f'{label}-chunk{chunk}',data,chunk))
        for value in (-2147483648,-1,0,1,2147483647):cases.append(self.settings_step(f'close-{value}',logical,close_result=value))
        for flag in (-2147483648,-1,1,2,2147483647):
            cases.append(self.settings_step(f'flag-{flag}',logical,writes=[(0x44D068,struct.pack('<i',flag))]))
        cases.append(self.settings_step('open-null',logical,present=False,writes=[(0x44D068,struct.pack('<I',1))]))
        cases.append(self.settings_step('retry-after-open-null',logical))
        return dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,control=self.control,
                    source=dict(path='data/control.txt',raw=self.blob(raw),logical=self.blob(logical)),
                    frontInitialGlobals=self.initial_globals,worldBacking=self.blob(self.world_initial),initialWorld=self.initial_world,
                    front=self.front,sources=list(self.sources.values()),settingsInitialGlobals=self.initial_settings_globals,
                    settingsWorld=self.initial_settings_world,settingsRecords=self.initial_settings_records,
                    scratchAddress=SCRATCH,scratchBacking=self.blob(self.scratch_initial),cases=cases,blobs=self.blobs,
                    crtBoundaries=sorted(self.crt.visited))


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--control',action='store_true');parser.add_argument('--accept',action='store_true');args=parser.parse_args()
    if args.accept:
        subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
        pending=[]
        for suffix in ('','-control'):
            report_path=ROOT/'docs/evidence'/f'settings-loading{suffix}.json';report=json.loads(report_path.read_bytes())
            raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['sha256']
            data=(json.dumps(packed(raw),separators=(',',':'))+'\n').encode()
            temp=ROOT/'build/original'/f'settings-loading{suffix}-check.json';temp.write_bytes(data)
            comparison=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--settings-loading',str(temp)],capture_output=True,text=True)
            print(comparison.stdout,end='',flush=True)
            if comparison.returncode:print(comparison.stderr,end='',flush=True);comparison.check_returncode()
            fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report['corpus'])
            report.update(nativeCompared=True,nativeComparison=comparison.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(data),fixtureBytes=len(data))
            pending.append((report_path,report,fixture,data))
        for path,report,fixture,data in pending:fixture.write_bytes(data);path.write_text(json.dumps(report,indent=2)+'\n')
        return
    doc=SettingsLoading(args.control).capture_settings();suffix='-control' if args.control else ''
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path=ROOT/'build/original'/f'settings-loading{suffix}.json';path.write_bytes(raw)
    counts={kind:sum(e['kind']==kind for c in doc['cases'] for e in c['events']) for kind in ('open','scan','gets','eof','close','settingsReturn','write')}
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=path.name,sha256=hashlib.sha256(raw).hexdigest(),
                cases=len(doc['cases']),events=counts,continuations={kind:sum(c['continuation']==kind for c in doc['cases']) for kind in ('ready','nullFile')},nativeCompared=False)
    (ROOT/'docs/evidence'/f'settings-loading{suffix}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':main()
