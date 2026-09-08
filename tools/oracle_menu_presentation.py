#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real menu tail/ret4, World1 dispatcher, volume/overlay/present/shutdown helpers.

Extends the original main-menu chain. COM/GDI/free/PostMessage are supplied
boundaries; sprintf runs the real pinned DLL. No actual device/network output.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib
from collections import Counter

from import_ntsd import ROOT, EXE_SHA256
from oracle_crt import DLL_SHA256
from oracle_main_menu import MainMenu
from oracle_match_preparation import GLOBAL, GLOBAL_SIZE, WORLD, digest
from oracle_loaded_catalog import CATALOG
from oracle_objects import DEVICE, STUB, BITMAP_SIZE
from oracle_replay_initialization import POINTERS, SIZE
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_ECX, UC_X86_REG_ESP

ARENA, API = 0x2A000000, 0x30002000
TOKENS = [ARENA+0x20000+i*0x100 for i in range(410)]
FORMATS = (b'Volume: %d', b"Start recording '%s'...", b"Recording file '%s' saved!", b'Recording canceled!')


def platform(index=0, **changes):
    result = dict(targetSurface=DEVICE, methodResult=-2147467259 if index%2 else 0,
                  queryResult=0, audioGetResult=0, audioSetResult=-2147467259,
                  queriedAudio=TOKENS[3], audioVolume=-1234, dcResult=-2147467259 if index%3==1 else 0,
                  dc=0x12345678, postResult=0)
    result.update(changes); return result


class MenuPresentation(MainMenu):
    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        self.presentation_active = False
        self.presentation_memory, self.presentation_controls = [], []
        self.uc.mem_map(ARENA, 0x400000); self.uc.mem_map(API, 0x1000)
        self.presentation_imports = {}
        for index, (iat, name) in enumerate([(0x44702C,'setBackgroundColor'), (0x447034,'setTextColor'),
                (0x447038,'textOut'), (0x447084,'stringLength'), (0x4471EC,'postMessage')]):
            address = API+index*16; self.put(iat,address); self.presentation_imports[address]=name
        # Distinct COM handles share a supplied vtable. Output pointer values
        # are installed at the boundary, not executed as host addresses.
        for token in TOKENS: self.put(token, ARENA+0x10000)
        for offset, name in [(0,'queryInterface'), (8,'release'), (0x14,'blit'), (0x1C,'audioVolumeSet'),
                (0x20,'audioVolumeRead'), (0x2C,'flip'), (0x3C,'volumeSet'), (0x44,'getDC'), (0x68,'releaseDC')]:
            address = API+0x100+offset*4
            self.presentation_imports[address]=name; self.put(ARENA+0x10000+offset,address)
            if offset in (0x2C,0x44,0x68): self.put(DEVICE+0x100+offset,address)
        self.uc.hook_add(UC_HOOK_CODE, self.presentation_imported, begin=API, end=API+0xFFF)
        for hook, callback in [(UC_HOOK_MEM_READ,self.track_read),(UC_HOOK_MEM_WRITE,self.track_write)]:
            self.uc.hook_add(hook,callback,begin=ARENA+0x100000,end=ARENA+0x3FFFFF)
        self.uc.hook_add(UC_HOOK_CODE,self.presentation_bitmap,begin=0x43F010,end=0x43F010)

    def allowed_code(self, uc, address, size, data):
        if self.presentation_active:
            if address == self.execution_stop: uc.emu_stop(); return
            if (0x42873E <= address <= 0x428805 or 0x4246B0 <= address < 0x42473B
                    or 0x423910 <= address <= 0x423938 or 0x43EF50 <= address <= 0x43EF68
                    or 0x401290 <= address <= 0x4012FE or 0x4019B0 <= address <= 0x401A26
                    or 0x401D30 <= address <= 0x401D90 or 0x401F30 <= address <= 0x401FFF
                    or 0x402810 <= address <= 0x402A5F or 0x43E940 <= address <= 0x43E99E
                    or 0x43D280 <= address <= 0x43D2B7 or address == 0x43F010
                    or API <= address < API+0x1000): return
        super().allowed_code(uc,address,size,data)

    def pevent(self, kind, args=(), strings=()):
        self.presentation_events.append(dict(kind=kind,arguments=list(args),strings=[list(x) for x in strings]))

    def presentation_bitmap(self, uc, address, size, data):
        if self.presentation_active:
            sp=uc.reg_read(UC_X86_REG_ESP)
            self.pevent('bitmap',[uc.reg_read(UC_X86_REG_ECX)]+[self.u32(sp+i*4) for i in range(1,7)])
            self.ret(0,24)

    def imported(self, uc, address, size, data):
        if not self.presentation_active: return super().imported(uc,address,size,data)
        sp=uc.reg_read(UC_X86_REG_ESP)
        if self.lookup.get(address)=='sprintf':
            fmt=self.cstr(self.u32(sp+8)); assert fmt in FORMATS
            args=[] if fmt==FORMATS[3] else [self.u32(sp+12)]
            if fmt in FORMATS[1:3]: args=[self.cstr(args[0])]
            result=self.crt.format(fmt,args); raw=bytes.fromhex(result['bytes'])
            assert len(raw)<=512
            self.uc.mem_write(self.u32(sp+4),raw)
            self.pevent('format',[result['result']],[fmt,raw[:-1]])
            self.presentation_formats.append(dict(format=fmt.decode(),**result)); self.ret(result['result'])
        elif address==STUB+0x330:
            pointer=self.u32(sp+4)
            item=next(m for m in self.presentation_memory if m['region']['address']==pointer)
            assert item['live']; item['live']=False
            self.pevent('free',[pointer]); self.ret()
        elif address in (STUB+0x310,STUB+0x320):
            self.com('blit' if address==STUB+0x310 else 'release')
        else: super().imported(uc,address,size,data)

    def com(self, name):
        sp=self.uc.reg_read(UC_X86_REG_ESP); arg=lambda i:self.u32(sp+4+i*4)
        p=self.presentation_input
        if name=='queryInterface':
            self.pevent(name,[arg(0)],[bytes(self.uc.mem_read(arg(1),16))])
            self.put(arg(2),p['queriedAudio']); self.ret(p['queryResult'],12)
        elif name=='audioVolumeRead':
            self.pevent(name,[arg(0)]); self.put(arg(1),p['audioVolume']); self.ret(p['audioGetResult'],8)
        elif name=='getDC':
            self.pevent(name,[arg(0)]); self.put(arg(1),p['dc']); self.ret(p['dcResult'],8)
        elif name=='releaseDC':
            self.pevent(name,[arg(0),arg(1)]); self.ret(p['methodResult'],8)
        else:
            offset,count={'release':(8,1),'blit':(0x14,6),'audioVolumeSet':(0x1C,2),
                          'flip':(0x2C,3),'volumeSet':(0x3C,2)}[name]
            args=[arg(i) for i in range(count)]
            strings=[bytes(self.uc.mem_read(arg(1),16))] if name=='blit' else []
            self.pevent('method',[args[0],offset]+args[1:],strings)
            self.ret(p['audioSetResult'] if name=='audioVolumeSet' else p['methodResult'],count*4)

    def presentation_imported(self,uc,address,size,data):
        assert self.presentation_active
        name=self.presentation_imports[address]; sp=uc.reg_read(UC_X86_REG_ESP); arg=lambda i:self.u32(sp+4+i*4)
        if name in ('setBackgroundColor','setTextColor'):
            self.pevent(name,[arg(0),arg(1)]); self.ret(0xFFFFFFFF,8)
        elif name=='stringLength':
            value=self.cstr(arg(0)); self.pevent(name,[],[value]); self.ret(len(value),4)
        elif name=='textOut':
            self.pevent(name,[arg(0),arg(1),arg(2),arg(4)],[bytes(uc.mem_read(arg(3),arg(4)))]); self.ret(0,20)
        elif name=='postMessage':
            self.pevent(name,[arg(i) for i in range(4)]); self.ret(self.presentation_input['postResult'],16)
        else: self.com(name)

    def psnapshot(self):
        return dict(globals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),world=self.record(self.world_record),
                    pointers=bytes(self.uc.mem_read(POINTERS,8)).hex(),
                    memory=[dict(address=m['region']['address'],live=m['live'],storage=self.record(m['region'])) for m in self.presentation_memory],
                    crtState=self.crt.random_state)

    def pstep(self,label,entry='tail',writes=(),platform_input=None,allocations=()):
        self.presentation_input=platform_input or platform(len(self.presentation_controls))
        stimulus=[]
        for address,raw in writes:
            if isinstance(raw,int): raw=struct.pack('<I',raw & 0xFFFFFFFF)
            self.write_host(address,raw); stimulus.append(dict(address=address,bytes=raw.hex()))
        created=[]
        for count,surface in allocations:
            target=ARENA+0x100020+len(self.presentation_memory)*0x2000
            region=self.add_region(target,count,'presentation-owned')
            region['initial']=bytes(i & 255 for i in range(count)) if self.pool_pattern is None else b'\xA5'*count
            self.uc.mem_write(target,region['initial'])
            if surface is not None:
                self.uc.mem_write(target,struct.pack('<I',surface)); region['mask'][:4]=b'\1'*4
            self.presentation_memory.append(dict(region=region,live=True))
            created.append(dict(address=target,storage=self.record(region)))
        before=self.psnapshot(); self.presentation_events=[]; self.presentation_formats=[]; self.global_accesses=set()
        # Execute the real prologue to establish the cookie/SEH/saved frame.
        # The bounded menu body still has a supplied entry context; its earlier
        # screen-selection path is NOT silently executed or claimed here.
        saved=[(UC_X86_REG_EBX,0x11111111),(UC_X86_REG_EBP,0x22222222),
               (UC_X86_REG_ESI,0x33333333),(UC_X86_REG_EDI,0x44444444)]
        sp=STACK+0xF424
        self.put(sp,STOP);self.put(sp+4,self.presentation_input['targetSurface']);self.put(0,0x12345678)
        for reg,value in saved:self.uc.reg_write(reg,value)
        self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,WORLD)
        self.presentation_active=True
        try:
            if entry=='worldOne': self.execute(0x4246B0,STOP)
            else:
                self.execute(0x4246B0,0x4246EB)
                assert self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xF000
                self.uc.reg_write(UC_X86_REG_EBX,0);self.uc.reg_write(UC_X86_REG_EDI,self.presentation_input['targetSurface'])
                self.execute(0x42873E if entry=='tail' else 0x4287DE,STOP)
        finally:self.presentation_active=False
        assert self.uc.reg_read(UC_X86_REG_ESP)==sp+8 and self.u32(0)==0x12345678
        assert all(self.uc.reg_read(reg)==value for reg,value in saved)
        return dict(label=label,entry=entry,input=self.presentation_input,stimulus=stimulus,allocations=created,
                    before=before,after=self.psnapshot(),events=self.presentation_events,formats=self.presentation_formats,
                    abi=dict(stackAfter=sp+8,savedRegisters=[v for _,v in saved],restoredSEH=0x12345678),
                    accesses=[dict(mode=m,address=a,size=n,instruction=hex(pc)) for m,a,n,pc in sorted(self.global_accesses)])

    def controls(self):
        assert not self.replay_regions and self.u32(POINTERS)==self.u32(POINTERS+4)==0
        def control(label,words=None,bytes_=(),input_=None,entry='tail',allocations=()):
            defaults={0x44D000:50,0x44F190:0,0x450B70:0,0x450B6C:0,0x450BFC:0,
                      0x4546F0:300,0x453CDC:222,0x44D060:0,0x457580:0,0x458348:3,
                      0x455608:DEVICE,0x455634:TOKENS[0],0x453E0C:TOKENS[1],0x451170:0x12345670,
                      0x45118C:0x12345674,0x4511AC:0,0x44EECC:0,0x44F040:0,0x44F044:0,0x44F048:0,0x44F04C:0,
                      0x458438:400,0x45843C:0,0x4546F4:0x34567890}
            defaults.update({0x45560C+i*4:TOKENS[4+i] for i in range(5)})
            defaults.update(words or {})
            writes=list(defaults.items())+[(0x4553F2,b'\x75\x75'),(0x44FD98,b"control_\xe9'%s.lfr\0")]+list(bytes_)
            item=self.pstep(label,entry,writes,input_,allocations); self.presentation_controls.append(item)
        for level in (-2147483648,-1,0,1,50,99,100,101,2147483647):
            for keys in (b'\x75\x75',b'\x64\x75',b'\x75\x64',b'\x64\x64'):
                control(f'volume-{level}-{keys.hex()}',{0x44D000:level,0x44F190:1,0x44F040:TOKENS[2]},[(0x4553F2,keys)])
        for key,value in [('queryResult',-2147467259),('queryResult',1),('audioGetResult',-2147467263),
                          ('audioGetResult',-1),('audioGetResult',1),('audioSetResult',0)]:
            control(f'audio-{key}-{value}',{0x44F040:TOKENS[2]},[(0x4553F2,b'\x64\x75')],platform(**{key:value}))
        for notice in (-2147483648,-1,0,1,2,3,4,2147483647):
            for timer in (-1,0,238,239,240,241,2147483647):
                for block in (0,1):
                    control(f'notice-{notice}-{timer}-{block}',{0x450B70:notice,0x450B6C:timer,0x450BFC:block,0x44F190:2})
        for mode in (-2147483648,-1,0,1,2,3,4,2147483647):
            control(f'present-mode-{mode}',{0x458348:mode},[(0x453CCC,struct.pack('<4i',-7,20,807,563))])
        for x,y in [(-2147483648,-2147483648),(-1,-1),(774,532),(775,533),(776,534),(2147483647,2147483647),(300,2147483646)]:
            control(f'cursor-{x}-{y}',{0x4546F0:x,0x453CDC:y})
        for previous,click in [(0,0),(0,2),(0,-1),(1,1),(-1,1),(0,1)]:
            for x,y in [(62,514),(63,514),(62,513)]:
                control(f'exit-bound-{x}-{y}-{previous}-{click}',{0x4546F0:x,0x453CDC:y,0x44D060:previous,0x457580:click})
        for count,extra in [(0,0),(-1,-1),(1,3),(400,2)]:
            words={0x4546F0:0,0x453CDC:535,0x457580:1,0x44EECC:TOKENS[9],0x458438:count,0x45843C:extra}
            words.update({0x452948+i*4:TOKENS[10+i] for i in range(max(0,count))})
            words.update({0x451DB0+i*4:TOKENS[20+i] for i in range(max(0,extra))})
            words.update({a:TOKENS[i+2] for i,a in enumerate([0x44F040,0x44F044,0x44F048,0x44F04C])})
            control(f'exit-release-{count}-{extra}',words)
            self.presentation_controls.append(self.pstep('held-exit-no-second-release'))
        first=ARENA+0x100020+len(self.presentation_memory)*0x2000
        control('exit-two-replay-pointers',{0x4546F0:0,0x453CDC:535,0x457580:1},
                [(POINTERS,struct.pack('<II',first,first+0x2000))],allocations=[(64,None),(128,None)])
        self.presentation_controls.append(self.pstep('held-exit-no-second-free'))
        for surface in (None,0,TOKENS[0]):
            address=ARENA+0x100020+len(self.presentation_memory)*0x2000
            control(f'world-one-bitmap-{surface}',{WORLD:1,0x4511AC:0 if surface is None else address,0x457580:1,0x44D060:0},
                    entry='worldOne',allocations=[] if surface is None else [(BITMAP_SIZE,surface)])
        control('normal-boundaries-after-controls')

    def probe(self,*args,**kwargs):
        if not self.presentation_controls: self.controls()
        super().probe(*args,**kwargs)
        probe=self.menu_probes[-1]
        entry='tail' if probe['exit']=='present' else 'epilogue'
        writes=[(0x455608,DEVICE),(0x455634,TOKENS[0]),(0x453E0C,TOKENS[1])]
        probe['presentation']=[self.pstep(probe['label']+'-return',entry,writes,platform(len(self.menu_probes)))]
        if self.u32(WORLD)==1:
            probe['presentation'].append(self.pstep(probe['label']+'-world-one','worldOne',platform_input=platform(len(self.menu_probes))))

    def scenario(self,*args,**kwargs):
        result=super().scenario(*args,**kwargs)
        result['presentationControls']=self.presentation_controls if len(self.replay_regions)==1 else []
        return result

    def before_prelude(self):
        super().before_prelude()
        # The intervening screen/selection path to 429730 remains a supplied
        # function context. The preceding dispatcher really returned ret4.
        self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF000)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ramp',action='store_true');parser.add_argument('--accept',action='store_true')
    args=parser.parse_args()
    if args.accept: accept();return
    provenance=next(c for c in json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_text())['corpora'] if c['corpus']=='loaded-catalog.json')
    raw=(ROOT/'build/original'/provenance['corpus']).read_bytes();assert digest(raw)==provenance['corpusSHA256']
    vm=MenuPresentation(json.loads(raw),None if args.ramp else 0xA5);del raw
    staged=vm.bootstrap();by_path={o['path']:o['index'] for o in vm.object_inputs}
    two=[(1,by_path['chars\\naruto.dat'],0),(11,by_path['chars\\sasuke.dat'],0)]+[(0,0,0)]*6
    cases=[]
    for i in range(25):
        vm.milliseconds=0x12345678 if i==0 else None;vm.draws=0;vm.stage=(i%6)*10
        cases.append(vm.scenario(f'presentation-{i}',i%2,i%17,two))
        assert vm.u32(WORLD)==2
        print('  presentation',i,len(vm.menu_probes),'menu probes',flush=True)
    cleanup=vm.cleanup();vm.verify_immutable()
    scope='Real shared menu tail42873e..428805/ret4 and dispatcher4246b0 World1 branch; real volume/overlay/text/present/shutdown helpers to COM/GDI/free/PostMessage, actual CRT sprintf; full menu/catalog/prelude/preparation/replay chain; no pixels/audio/Windows or full screen-selection path'
    doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=scope,loadedCatalog=provenance['corpus'],loadedCatalogSHA256=provenance['corpusSHA256'],loadedFixtureSHA256=provenance['fixtureSHA256'],
        catalogAddress=CATALOG,worldAddress=WORLD,actorAddresses=vm.actor_addresses,objects=vm.object_inputs,objectAddresses=vm.object_addresses,
        bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]],surfaceAddress=DEVICE,
        globalAddress=GLOBAL,globalInitial=vm.blob(vm.global_initial),randomSource=vm.random_source,crtInitialState=1,
        replayPointersAddress=POINTERS,replayPointersInitial=vm.pointer_initial.hex(),cleanup=cleanup,
        pattern='ramp' if args.ramp else 'a5',selector=2,staged=staged,cases=cases,assets=list(vm.asset_inputs.values()),
        readsBeforeWrites=sorted(vm.reads_before_writes),blobs=vm.blobs)
    suffix='-ramp' if args.ramp else '';path=ROOT/f'build/original/menu-presentation{suffix}.json'
    path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    steps=[p for c in cases for p in c['presentationControls']]+[s for c in cases for p in c['mainMenu'] for s in p['presentation']]
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=scope,corpus=path.name,corpusSHA256=digest(path.read_bytes()),
        nativeComparison='pending',cases=len(cases),steps=len(steps),controls=len(vm.presentation_controls),
        entries=dict(Counter(s['entry'] for s in steps)),events=sum(len(s['events']) for s in steps),formats=sum(len(s['formats']) for s in steps),
        abiReturnsVerified=True,readsBeforeWrites=[],immutableCatalogObjectHeapBytesVerified=True,
        casesSummary=[dict(label=s['label'],entry=s['entry'],events=dict(Counter(e['kind'] for e in s['events'])),
                      eventsSHA256=digest(json.dumps(s['events'],sort_keys=True,separators=(',',':')).encode())) for s in steps])
    (ROOT/f'docs/evidence/menu-presentation{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(steps),'presentation steps',flush=True)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    paths,reports=[],[]
    for suffix in ('','-ramp'):
        report_path=ROOT/f'docs/evidence/menu-presentation{suffix}.json';report=json.loads(report_path.read_text())
        raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['corpusSHA256'];doc=json.loads(raw)
        for c in doc['cases']:
            for k in ('globalAccesses','replayGlobalAccesses','replayWrites'):c.pop(k)
            c['randomInitialization'].pop('writes')
            for p in c['mainMenu']:
                p.pop('accesses')
                for s in p['presentation']:s.pop('accesses')
            for s in c['presentationControls']:s.pop('accesses')
        blobs=doc.pop('blobs')
        def keys(x):
            if isinstance(x,str):return {x} if x in blobs else set()
            if isinstance(x,list):return set().union(*(keys(v) for v in x))
            if isinstance(x,dict):return set().union(*(keys(v) for v in x.values()))
            return set()
        doc['blobs']={k:blobs[k] for k in sorted(keys(doc))}
        raw=json.dumps(doc,separators=(',',':')).encode();assert len(raw)<=64*1024*1024
        packed=dict(count=len(raw),sha256=digest(raw),deflate=base64.b64encode(zlib.compress(raw,level=9,wbits=-15)).decode())
        path=ROOT/f'build/original/menu-presentation{suffix}-check.json';path.write_text(json.dumps(packed,separators=(',',':'))+'\n')
        paths.append(path);reports.append((report_path,report,suffix))
    result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--menu-presentation',str(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'),*map(str,paths)],capture_output=True,text=True)
    print(result.stdout,end='',flush=True)
    if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
    for path,(report_path,report,suffix) in zip(paths,reports):
        fixture=ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-menu-presentation{suffix}.json';fixture.write_bytes(path.read_bytes())
        report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,fixtureSHA256=digest(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size)
        report_path.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
