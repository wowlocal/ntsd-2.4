#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute the five-row menu and network setup, then native match/recording.

Bitmap drawing, OS network results, ShellExecute, Sleep and COM output are
explicit boundaries. No actual network connection or external command is made.
"""
import argparse
import base64
import json
import ipaddress
import struct
import subprocess
import zlib

from import_ntsd import EXE_SHA256, ROOT
from oracle_crt import DLL_SHA256
from oracle_random_initialization import RandomInitialization
from oracle_match_prelude import MatchPrelude, SOUND
from oracle_match_preparation import digest, WORLD, GLOBAL, GLOBAL_SIZE
from oracle_loaded_catalog import CATALOG
from oracle_objects import DEVICE, STUB
from oracle_replay_initialization import POINTERS, SIZE
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ESI, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP

NETWORK, NETWORK_STUB = 0x29000000, 0x30001000


def network_input(index=0):
    strings = [[b'10.0.0.2', b'192.168.1.4', b'169.254.4.5', b'127.0.0.1', b'203.0.113.7'],
               [b'10.0.0.2', b'192.168.1.4'], [b'172.16.0.1', b'203.0.113.7'],
               [b'192.1689', b'169.254x', b'1278', b'192.169.0.1'], [b'1', b'203.0.113.7']][index % 5]
    addresses = []
    for i, value in enumerate(strings):
        try:
            word = int.from_bytes(ipaddress.IPv4Address(value.decode()).packed, 'little')
        except ipaddress.AddressValueError:
            # Deliberately non-OS text probes distinguish the EXE's byte-prefix
            # predicate from a standards-based IP classifier. Keep them explicit.
            word = 0x01020300+i
        addresses.append(dict(word=word, text=list(value)))
    return dict(startupResult=0, version=0x101, hostnameResult=0, hostname=list(b'ntsd-reference'),
                hostEntryAddress=NETWORK+0x20, addresses=addresses,
                socketResult=0x34560001, asyncResult=0, bindResult=0, listenResult=0)


class MainMenu(RandomInitialization):
    def __init__(self, capture, pattern):
        super().__init__(capture, pattern)
        self.menu_active = False
        self.uc.mem_map(NETWORK, 0x10000)
        self.uc.mem_map(NETWORK_STUB, 0x1000)
        self.menu_imports = {}
        for i, (iat, name) in enumerate([(0x4472A8, 'startup'), (0x4472AC, 'hostname'), (0x447268, 'hostLookup'),
                (0x447270, 'htons'), (0x447264, 'addressText'), (0x44726C, 'socket'), (0x447274, 'asyncSelect'),
                (0x447278, 'bind'), (0x44727C, 'listen'), (0x4472A4, 'closeSocket'),
                (0x4471C8, 'message'), (0x4471B8, 'shell'), (0x4471F4, 'windowDefault')]):
            stub = NETWORK_STUB+i*16
            self.menu_imports[stub] = name; self.put(iat, stub)
        self.uc.hook_add(UC_HOOK_CODE, self.menu_imported, begin=NETWORK_STUB, end=NETWORK_STUB+0xFFF)
        for address in (0x43F010, 0x423B00, 0x422AC0, 0x422AF7):
            self.uc.hook_add(UC_HOOK_CODE, self.menu_entry, begin=address, end=address)

    def event(self, kind, arguments=(), strings=()):
        self.menu_events.append(dict(kind=kind, arguments=list(arguments), strings=[list(x) for x in strings]))

    def allowed_code(self, uc, address, size, data):
        if self.menu_active:
            if address in (0x42873E, 0x4287DE):
                uc.emu_stop(); return
            if (0x427915 <= address < 0x427CA7 or 0x402A60 <= address <= 0x402D63
                    or 0x43F38A <= address < 0x43F3FC or address == 0x43F010
                    or 0x423B00 <= address <= 0x423B14 or 0x4242AF <= address <= 0x4242B2
                    or NETWORK_STUB <= address < NETWORK_STUB+0x1000):
                return
            if (0x43B3D0 <= address < 0x43B3F5 or 0x43B8AF <= address < 0x43B924
                    or 0x43BC24 <= address <= 0x43BC3E):
                return
        super().allowed_code(uc, address, size, data)

    def menu_entry(self, uc, address, size, data):
        if not self.menu_active:
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x43F010:
            self.event('bitmap', [uc.reg_read(UC_X86_REG_ECX)]+[self.u32(sp+i) for i in (4, 8, 12, 16, 20, 24)])
            self.ret(0, 24)  # explicit rendering boundary, no pixel claim
        elif address == 0x423B00:
            self.event('panel', [self.u32(sp+4), self.u32(sp+8)])
            pointer = self.u32(0x458420)
            assert pointer == 0 or pointer == NETWORK+0x7000 and self.u32(pointer) == 0
        elif address == 0x422AC0:
            self.table_event = len(self.menu_events)
            self.event('randomTable', [self.crt.random_state, 0])
            self.menu_random = []
        else:
            assert len(self.menu_random) == 3000
            self.menu_events[self.table_event]['arguments'][1] = self.crt.random_state
            self.menu_tables.append(dict(calls=3000, sha256=digest(json.dumps(self.menu_random, separators=(',', ':')).encode())))

    def sound_entry(self, uc, address, size, data):
        if self.menu_active:
            sp = uc.reg_read(UC_X86_REG_ESP)
            assert self.u32(sp) in (0x427A19, 0x427AB9, 0x427BBF, 0x427C19, 0x427C74)
            assert uc.reg_read(UC_X86_REG_ECX) == 0x455610 and self.u32(sp+4) == 0
            self.event('soundRequest', [0])
        else:
            super().sound_entry(uc, address, size, data)

    def imported(self, uc, address, size, data):
        if not self.menu_active:
            return super().imported(uc, address, size, data)
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == STUB+0x390:
            assert self.u32(sp) == 0x422AD2
            call = self.crt.random_call(); self.menu_random.append(call); self.ret(call['result'])
        elif address in (STUB+0x360, STUB+0x370, STUB+0x380):
            offset, count = {STUB+0x360: (0x48, 1), STUB+0x370: (0x34, 2), STUB+0x380: (0x30, 4)}[address]
            assert self.u32(sp+4) == SOUND
            self.event('soundMethod', [SOUND, offset]+[self.u32(sp+8+i*4) for i in range(count-1)])
            self.ret(self.device_result, count*4)
        elif self.lookup.get(address) == 'Sleep':
            assert self.u32(sp) == 0x427C7F and self.u32(sp+4) == 300
            self.event('sleep', [300]); self.ret(0, 4)
        elif self.lookup.get(address) == 'sprintf':
            assert self.u32(sp) == 0x402B1E and self.cstr(self.u32(sp+8)) == b'%s'
            value = self.cstr(self.u32(sp+12))
            result = self.crt.format(b'%s', [value])
            self.uc.mem_write(self.u32(sp+4), bytes.fromhex(result['bytes']))
            self.event('formatAddress', [result['result']], [value])
            self.menu_formats.append(result)
            self.ret(result['result'])
        else:
            super().imported(uc, address, size, data)

    def menu_imported(self, uc, address, size, data):
        assert self.menu_active
        name = self.menu_imports[address]
        sp = uc.reg_read(UC_X86_REG_ESP)
        arg = lambda i: self.u32(sp+4+i*4)
        net = self.menu_input['network']
        if name == 'startup':
            assert arg(0) == 0x101
            self.event(name, [arg(0)])
            uc.mem_write(arg(1), struct.pack('<H', net['version'])+b'\xA5'*398)
            self.ret(net['startupResult'], 8)
        elif name == 'hostname':
            assert arg(1) == 256
            self.event(name, [arg(1)])
            uc.mem_write(arg(0), bytes(net['hostname'])+b'\0')
            self.ret(net['hostnameResult'], 8)
        elif name == 'hostLookup':
            self.event(name, [], [self.cstr(arg(0))]); self.ret(net['hostEntryAddress'], 4)
        elif name == 'htons':
            self.event(name, [arg(0)])
            self.ret(int.from_bytes(struct.pack('>H', arg(0)), 'little'), 4)
        elif name == 'addressText':
            value = next(bytes(a['text']) for a in net['addresses'] if a['word'] == arg(0))
            self.event(name, [arg(0)], [value])
            uc.mem_write(NETWORK+0x5000, value+b'\0'); self.ret(NETWORK+0x5000, 4)
        elif name == 'socket':
            self.event(name, [arg(i) for i in range(3)]); self.ret(net['socketResult'], 12)
        elif name == 'asyncSelect':
            self.event(name, [arg(i) for i in range(4)]); self.ret(net['asyncResult'], 16)
        elif name == 'bind':
            assert arg(1) == 0x44F58C and arg(2) == 16
            self.event(name, [arg(0), arg(2)], [bytes(uc.mem_read(arg(1), arg(2)))]); self.ret(net['bindResult'], 12)
        elif name == 'listen':
            self.event(name, [arg(0), arg(1)]); self.ret(net['listenResult'], 8)
        elif name == 'closeSocket':
            self.event(name, [arg(0)]); self.ret(-1, 4)  # ignored, globals retain the old socket token
        elif name == 'message':
            self.event(name, [arg(0), arg(3)], [self.cstr(arg(1)), self.cstr(arg(2))]); self.ret(7, 16)
        elif name == 'shell':
            self.event(name, [arg(0), arg(3), arg(4), arg(5)], [self.cstr(arg(1)), self.cstr(arg(2))]); self.ret(31, 24)
        elif name == 'windowDefault':
            self.event(name, [arg(i) for i in range(4)])
            self.ret(self.current_mouse['defaultResult'], 16)
        else:
            raise ValueError(name)

    def memset(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if self.menu_active and self.u32(sp+4) == 0x44F340:
            assert self.u32(sp) == 0x427AF9 and self.u32(sp+8) == 0 and self.u32(sp+12) == 200
            self.global_access(uc, 0, 0x44F340, 200, 0, 'write')
            self.uc.mem_write(0x44F340, bytes(200)); self.ret(0x44F340)
        else:
            super().memset(uc, address, size, data)

    def probe(self, label, x=300, relative_y=20, base=0, previous=0, click=0, net=None, mouse=()):
        self.menu_input = dict(targetSurface=DEVICE, panelWord=0 if len(self.menu_probes) % 2 else None,
                               network=net or network_input(len(self.menu_probes)))
        net = self.menu_input['network']
        assert len(net['addresses']) < 128 and len(net['hostname']) < 256
        self.uc.mem_write(NETWORK, b'\xA5'*0x10000)
        self.put(NETWORK+0x2C, NETWORK+0x100)
        for i, item in enumerate(net['addresses']):
            self.put(NETWORK+0x100+i*4, NETWORK+0x1000+i*4)
            self.put(NETWORK+0x1000+i*4, item['word'])
        self.put(NETWORK+0x100+len(net['addresses'])*4, 0)
        self.put(NETWORK+0x7000, 0)
        stimuli = []
        def word(address, value):
            raw = struct.pack('<I', value & 0xFFFFFFFF)
            self.write_host(address, raw); stimuli.append(dict(address=address, bytes=raw.hex()))
        # These are menu-phase inputs, deliberately separate from the older
        # preparation stimuli that are applied before seed/table initialization.
        for address, value in [(WORLD, 0), (0x453DA4, base), (0x4546F0, x), (0x453CDC, base+202+relative_y),
                (0x44D060, previous), (0x457580, click), (0x44D064, 0), (0x4511E0, 0x12345678),
                (0x45117C, NETWORK+0x8000), (0x4511A0, NETWORK+0xA000), (0x4546F4, 0x34567890),
                (0x458420, NETWORK+0x7000 if self.menu_input['panelWord'] is not None else 0)]:
            word(address, value)
        self.menu_events, self.menu_tables, self.menu_formats, self.global_accesses = [], [], [], set()
        def snapshot():
            return dict(globals=self.blob(self.uc.mem_read(GLOBAL, GLOBAL_SIZE)), world=self.record(self.world_record), crtState=self.crt.random_state)
        mouse_steps = []
        for message, lparam in mouse:
            self.current_mouse = dict(window=0x34567890, message=message, wParam=0x12345678,
                                      lParam=lparam, defaultResult=-2147467259)
            first = self.blob(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
            self.uc.mem_write(STACK+0xF000, struct.pack('<5I', STOP, *[self.current_mouse[k] for k in ('window','message','wParam','lParam')]))
            saved = [(UC_X86_REG_EBX,0x11111111),(UC_X86_REG_EBP,0x22222222),(UC_X86_REG_ESI,0x33333333),(UC_X86_REG_EDI,0x44444444)]
            for reg,value in saved: self.uc.reg_write(reg,value)
            self.uc.reg_write(UC_X86_REG_ESP,STACK+0xF000)
            self.menu_active=True
            try: self.execute(0x43B3D0,STOP)
            finally: self.menu_active=False
            assert self.uc.reg_read(UC_X86_REG_ESP)==STACK+0xF014
            assert all(self.uc.reg_read(reg)==value for reg,value in saved)
            assert self.uc.reg_read(UC_X86_REG_EAX)==self.current_mouse['defaultResult'] & 0xFFFFFFFF
            mouse_steps.append(dict(input=self.current_mouse,beforeGlobals=first,afterGlobals=self.blob(self.uc.mem_read(GLOBAL,GLOBAL_SIZE)),
                                    result=self.current_mouse['defaultResult'],stackAfter=STACK+0xF014,savedRegisters=[v for _,v in saved]))
        before = snapshot()
        self.put(STACK+0xF018, WORLD)
        self.uc.reg_write(UC_X86_REG_ESP, STACK+0xF000)
        self.uc.reg_write(UC_X86_REG_EBX, 0); self.uc.reg_write(UC_X86_REG_EDI, DEVICE)
        self.menu_active = True
        try:
            self.uc.emu_start(0x427915, 0, count=2_000_000)
        finally:
            self.menu_active = False
        pc = self.uc.reg_read(UC_X86_REG_EIP)
        assert pc in (0x42873E, 0x4287DE), hex(pc)
        assert self.uc.reg_read(UC_X86_REG_ESP) == STACK+0xF000
        assert not self.reads_before_writes
        item = dict(label=label, input=self.menu_input, stimulus=stimuli, before=before, after=snapshot(),
            events=self.menu_events, tables=self.menu_tables, formats=self.menu_formats, mouse=mouse_steps,
            exit='present' if pc == 0x42873E else 'returnWithoutPresentation', endPC=hex(pc), stackAfter=STACK+0xF000,
            accesses=[dict(mode=m, address=a, size=n, instruction=hex(p)) for m, a, n, p in sorted(self.global_accesses)])
        self.menu_probes.append(item)

    def before_prelude(self):
        super().before_prelude()
        index = len(self.replay_regions)
        self.menu_probes = []
        # Every row endpoint and surrounding pixel, signed/wrapped offsets and
        # exact click/latch values; all probes share the original CRT state.
        bounds = [14,15,16,38,39,40,44,45,46,69,70,71,76,77,78,101,102,103,106,107,108,131,132,133,136,137,138,161,162,163]
        for relative_y in bounds[index % 5::5]:
            self.probe(f'row-edge-{relative_y}', relative_y=relative_y,
                       base=[0,-202,51,-2147483648,2147483647][index % 5])
        for x in [275,276,520,521,-2147483648,2147483647]:
            self.probe(f'x-edge-{x}', x=x, relative_y=[20,50,80,110,145][index % 5])
        row_y = [20,50,80,110,145][index % 5]
        for previous, click in [(0,0),(0,2),(0,-1),(1,1),(-1,1),(0,1)]:
            self.probe(f'flags-{previous}-{click}', relative_y=row_y, previous=previous, click=click)
        if index < 10:
            net = network_input(index)
            overrides = [dict(version=0x202), dict(hostnameResult=-1), dict(hostEntryAddress=0),
                         dict(socketResult=0xFFFFFFFF), dict(asyncResult=1), dict(bindResult=-1), dict(listenResult=-1),
                         dict(startupResult=-1), dict(hostnameResult=-2, socketResult=0), dict(bindResult=-2, listenResult=-2)]
            net.update(overrides[index])
            self.probe(f'network-control-{index}', relative_y=50, click=1, net=net)
        # Continue through the actual first-row action after the menu probes,
        # then feed its table/state into the already verified match chain.
        self.probe('mouse-message-sequence', mouse=[(0x200,0xFFFFFFFF),(0x201,0x12345678),(0x204,0),
            (0x203,0x89ABCDEF),(0x205,0),(0x202,0),(0x200,(252<<16)|300)])
        self.probe('enter-local-play', relative_y=20, previous=0, click=0, mouse=[(0x200,(222<<16)|300),(0x201,0)])
        # 4246b0 and 429730 have different stack layouts. Resume the existing
        # explicit preparation context; do not copy any expected game state.
        self.put(STACK+0xF014, WORLD)
        self.uc.reg_write(UC_X86_REG_EBX, 0)

    def scenario(self, *args, **kwargs):
        # MainMenu extends the stage after the isolated CRT/table checkpoint;
        # RandomInitialization.scenario's old final CRT equality is not applicable.
        item = MatchPrelude.scenario(self, *args, **kwargs)
        item['randomInitialization'] = self.random_initialization
        item['mainMenu'] = self.menu_probes
        assert self.crt.random_state == self.menu_probes[-1]['after']['crtState']
        return item


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'], check=True)
    paths, reports = [], []
    for suffix in ('', '-ramp'):
        path = ROOT/f'docs/evidence/main-menu{suffix}.json'
        report = json.loads(path.read_text())
        raw = (ROOT/'build/original'/report['corpus']).read_bytes()
        assert digest(raw) == report['corpusSHA256']
        doc = json.loads(raw)
        for case in doc['cases']:
            for key in ('globalAccesses','replayGlobalAccesses','replayWrites'):
                case.pop(key)
            case['randomInitialization'].pop('writes')
            for probe in case['mainMenu']:
                probe.pop('accesses')
        blobs = doc.pop('blobs')
        def keys(value):
            if isinstance(value,str): return {value} if value in blobs else set()
            if isinstance(value,list): return set().union(*(keys(v) for v in value))
            if isinstance(value,dict): return set().union(*(keys(v) for v in value.values()))
            return set()
        doc['blobs']={k:blobs[k] for k in sorted(keys(doc))}
        compact=json.dumps(doc,separators=(',',':')).encode()
        packed=dict(count=len(compact),sha256=digest(compact),deflate=base64.b64encode(zlib.compress(compact,level=9,wbits=-15)).decode())
        output=ROOT/f'build/original/main-menu{suffix}-check.json'
        output.write_text(json.dumps(packed,separators=(',',':'))+'\n')
        paths.append(output); reports.append((path,report,suffix))
    result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--main-menu',
        str(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-loaded-catalog.json'),*map(str,paths)],capture_output=True,text=True)
    print(result.stdout,end='',flush=True)
    if result.returncode:
        print(result.stderr,end='',flush=True); result.check_returncode()
    for output,(path,report,suffix) in zip(paths,reports):
        fixture=ROOT/f'native/Tests/NTSDCoreTests/Fixtures/original-main-menu{suffix}.json'
        fixture.write_bytes(output.read_bytes())
        report.update(nativeComparison=result.stdout.strip(),fixture=fixture.name,
                      fixtureSHA256=digest(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size)
        path.write_text(json.dumps(report,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ramp',action='store_true'); parser.add_argument('--accept',action='store_true')
    args=parser.parse_args()
    if args.accept:
        assert not args.ramp
        accept(); return
    provenance=next(c for c in json.loads((ROOT/'docs/evidence/loaded-catalog.json').read_text())['corpora'] if c['corpus']=='loaded-catalog.json')
    raw=(ROOT/'build/original'/provenance['corpus']).read_bytes()
    assert digest(raw)==provenance['corpusSHA256']
    vm=MainMenu(json.loads(raw),None if args.ramp else 0xA5); del raw
    staged=vm.bootstrap()
    by_path={o['path']:o['index'] for o in vm.object_inputs}
    two=[(1,by_path['chars\\naruto.dat'],0),(11,by_path['chars\\sasuke.dat'],0)]+[(0,0,0)]*6
    cases=[]
    for i in range(25):
        vm.milliseconds=0x12345678 if i==0 else None
        vm.draws=0; vm.stage=(i%6)*10
        cases.append(vm.scenario(f'menu-{i}',i%2,i%17,two))
        print('  main menu',i,len(vm.menu_probes),'probes',flush=True)
    cleanup=vm.cleanup(); vm.verify_immutable()
    scope=('WndProc43b3d0 mouse200..205 through ret16; main menu427915..427ca7 to shared presentation/epilogue entries; real CRT table and402b60/402ad0/402a60 network children; '
           'drawBitmap/OS/COM/empty-panel boundaries; full catalog/prelude/preparation/replay chain; no actual network, browser, Windows output or whole menu loop')
    doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=scope,loadedCatalog=provenance['corpus'],
        loadedCatalogSHA256=provenance['corpusSHA256'],loadedFixtureSHA256=provenance['fixtureSHA256'],
        catalogAddress=CATALOG,worldAddress=WORLD,actorAddresses=vm.actor_addresses,objects=vm.object_inputs,objectAddresses=vm.object_addresses,
        bitmapAddresses=[b['address'] for b in vm.bitmaps[:vm.initial_bitmap_count]],surfaceAddress=DEVICE,
        globalAddress=GLOBAL,globalInitial=vm.blob(vm.global_initial),randomSource=vm.random_source,crtInitialState=1,
        replayPointersAddress=POINTERS,replayPointersInitial=vm.pointer_initial.hex(),cleanup=cleanup,
        pattern='ramp' if args.ramp else 'a5',selector=2,staged=staged,cases=cases,assets=list(vm.asset_inputs.values()),
        readsBeforeWrites=sorted(vm.reads_before_writes),blobs=vm.blobs)
    suffix='-ramp' if args.ramp else ''
    path=ROOT/f'build/original/main-menu{suffix}.json'
    path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    probes=[p for c in cases for p in c['mainMenu']]
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=scope,corpus=path.name,corpusSHA256=digest(path.read_bytes()),
        nativeComparison='pending',cases=len(cases),probes=len(probes),loadedCatalogSHA256=provenance['corpusSHA256'],
        readsBeforeWrites=[],immutableCatalogObjectHeapBytesVerified=True,
        tables=sum(len(p['tables']) for p in probes),formats=sum(len(p['formats']) for p in probes),
        events=sum(len(p['events']) for p in probes),mouseMessages=sum(len(p['mouse']) for p in probes),replayBytes=len(cases)*SIZE,
        probeSummary=[dict(label=p['label'],exit=p['exit'],beforeCRT=p['before']['crtState'],afterCRT=p['after']['crtState'],
            events=[e['kind'] for e in p['events']],eventsSHA256=digest(json.dumps(p['events'],sort_keys=True,separators=(',',':')).encode())) for p in probes])
    (ROOT/f'docs/evidence/main-menu{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Captured {len(probes)} menu probes and25 match/recording chains: {path}',flush=True)


if __name__=='__main__':
    main()
