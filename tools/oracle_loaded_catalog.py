#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute 4122f0 with real Object, BG, Stage, bitmap and sound children.

All original catalog entries run in one VM with shared checksum/sounds/heap.
The pinned VC80 scanf executes in the existing DLL VM; translated file buffers,
malloc addresses and bitmap device results remain supplied boundaries. No pixels
or Windows startup are claimed. Full final storage and masks are retained.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from oracle_objects import Objects, OBJECT_SIZE, BITMAP_SIZE, FRAME_SIZE, DEVICE
from oracle_state import STACK, STOP
from oracle_crt import DLL_SHA256
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP

CATALOG, CATALOG_SIZE = 0x60000020, 0x4D823A8
BG_BASE, BG_SIZE, STAGE_SIZE = 0x4D45DB0, 0x990, 0x149B08
FRAME_KINDS = {'0x410935': 'sound', '0x4114ab': 'interactions', '0x411b85': 'bodies'}
INTERLEAVED = br'''prefix_\xff
<object> id: 50 type: 0 file: chars\pein.dat <object_end>
<background> id: 17 file: bg\sys\District\bg.dat <background_end>
<object> id: 50 type: 0 file: chars\pein.dat
id: 5 type: 0 file: chars\sasuke.dat <object_end>
<background> id: 17 file: bg\sys\District\bg.dat <background_end>
'''.replace(b'\\xff', b'\xff')


class LoadedCatalog(Objects):
    def __init__(self, pattern=0xA5, text_mode=True, uc=None):
        super().__init__(pattern=pattern, text_mode=text_mode, use_crt=True, capacity=137,
                         retain_opaque_frames=True, raw_frames=False, uc=uc)
        self.uc.mem_map(CATALOG & ~0xFFF, (CATALOG_SIZE + 0x20 + 16 + 4095) & ~4095)
        self.catalog = self.add_region(CATALOG, CATALOG_SIZE, 'catalog')
        for hook, callback in [(UC_HOOK_MEM_READ, self.track_read), (UC_HOOK_MEM_WRITE, self.track_write)]:
            self.uc.hook_add(hook, callback, begin=CATALOG, end=CATALOG + CATALOG_SIZE - 1)
        self.requests, self.children, self.object_addresses = [], [], []
        self.parent_tokens, self.stage_ids, self.phase_ids = [], [], []
        self.pending, self.current_frame = None, None
        self.blobs = {}
        self.pe = PE(read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe'))
        self.resources = {str(r['path'][1]).lower(): r for r in self.pe.resources() if r['path'][0] == 2}
        for address in (0x412580, 0x4242E0, 0x40EF70, 0x41269A, 0x40C160, 0x412780,
                        0x40C910, 0x4127D2, 0x40C9F5, 0x40CBD8):
            self.uc.hook_add(UC_HOOK_CODE, self.parent_checkpoint, begin=address, end=address)

    def write_host(self, address, raw):
        if CATALOG <= address < CATALOG + CATALOG_SIZE:
            self.track_write(self.uc, 0, address, len(raw), 0, None)
            self.uc.mem_write(address, raw)
        else:
            super().write_host(address, raw)

    def imported(self, uc, address, size, data):
        # Resolve every file requested by original code, not a regex-preloaded
        # registry or a reconstructed child invocation sequence.
        if self.lookup.get(address) == 'fopen':
            sp = uc.reg_read(UC_X86_REG_ESP)
            path, mode = self.cstr(self.u32(sp + 4)), self.cstr(self.u32(sp + 8))
            if mode == b'r' and path not in self.files:
                source = DEFAULT_SOURCE / path.decode('latin1').replace('\\', '/')
                assert source.resolve().is_relative_to(DEFAULT_SOURCE.resolve())
                self.files[path] = read_bytes(source)
        super().imported(uc, address, size, data)

    def checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x4450AC and self.u32(sp + 4) == OBJECT_SIZE:
            assert self.u32(sp) == 0x41266A
            index = len(self.object_addresses)
            assert index < 137
            target = self.object_base + 0x20 + index*0x40000
            self.add_region(target, OBJECT_SIZE, 'object')
            self.object_addresses.append(target)
            self.ret(target)
        elif address == 0x43ED10 and self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode('latin1').lower() in self.resources:
            key = self.cstr(uc.reg_read(UC_X86_REG_EDI)).decode('latin1')
            resource = self.resources[key.lower()]
            raw = self.pe.data[resource['fileOffset']:resource['fileOffset'] + resource['size']]
            assert struct.unpack_from('<I', raw)[0] >= 40
            width, height = struct.unpack_from('<ii', raw, 4)
            assert width > 0 and height > 0
            item = dict(path=key, present=True, width=width, height=height,
                        resourcePath=resource['path'], sha256=hashlib.sha256(raw).hexdigest())
            self.asset_inputs[key] = item
            self.events.append(dict(kind='bitmap-load', **item))
            self.write_host(self.u32(sp + 16), struct.pack('<i', width))
            self.write_host(self.u32(sp + 20), struct.pack('<i', height))
            self.ret(DEVICE)
        else:
            if address == 0x43EE50 and self.u32(sp) in (0x4123D7, 0x412435, 0x412490, 0x4124EB):
                self.requests.append(dict(kind='bitmap', index=len(self.bitmaps), path=self.cstr(self.u32(sp + 8)).decode('latin1')))
            super().checkpoint(uc, address, size, data)

    def begin_child(self, kind, path, **fields):
        assert self.pending is None
        self.pending = dict(kind=kind, path=path, initialChecksum=self.u32(0x44F620),
                            bitmapStart=len(self.bitmaps), allocationStart=len(self.allocations), **fields)
        self.requests.append({k: v for k, v in self.pending.items() if k in ('kind', 'path', 'index', 'id', 'objectType')})
        if kind == 'stages':
            self.requests[-1].pop('path')  # parent has no Stage filename argument

    def finish_child(self):
        item = self.pending
        assert item is not None
        path = item['path']
        source = self.files[path.encode('latin1')]
        decoded = next(h['data'] for h in reversed(list(self.handles.values())) if h['mode'] == b'r')
        assert self.files[b'data\\temporary.txt'] == b'Do not erase this file.'
        item.update(source=self.blob(source), decoded=self.blob(decoded), checksum=self.u32(0x44F620),
                    bitmapEnd=len(self.bitmaps), allocationEnd=len(self.allocations),
                    soundCount=self.u32(0x458438), soundBytes=self.blob(self.uc.mem_read(0x455638, 0x2E00)))
        if item['kind'] == 'object':
            assert self.constructors == list(range(400))
            item['frameOccurrences'] = len(self.frame_occurrences)
            item['storage'] = self.record(self.current)
            self.current = None
        elif item['kind'] == 'background':
            item['storage'] = self.slice_record(self.catalog, BG_BASE + item['index']*BG_SIZE, BG_SIZE)
        else:
            assert item['checksum'] == item['initialChecksum']
        self.children.append(item)
        print(f"{item['kind']} {path}: checksum {item['initialChecksum']} -> {item['checksum']}, {item['soundCount']} sounds", flush=True)
        self.pending = None

    def parent_checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x412580:
            self.parent_tokens.append(self.cstr(sp + 0x34).hex())
        elif address == 0x4242E0 and self.u32(sp) == 0x412660:
            self.requests.append(dict(kind='progress', path=self.cstr(self.u32(sp + 4)).decode('latin1')))
        elif address == 0x40EF70:
            target = uc.reg_read(UC_X86_REG_ECX)
            assert target == self.object_addresses[-1]
            self.current = self.region(target, OBJECT_SIZE)
            self.constructors, self.outer_tokens, self.frame_occurrences = [], [], []
            self.current_frame = None
            self.begin_child('object', self.cstr(self.u32(sp + 12)).decode('latin1'), index=len(self.object_addresses)-1,
                             id=struct.unpack('<i', uc.mem_read(sp + 4, 4))[0], objectType=struct.unpack('<i', uc.mem_read(sp + 8, 4))[0])
        elif address == 0x40C160:
            assert uc.reg_read(UC_X86_REG_ECX) == CATALOG
            self.begin_child('background', self.cstr(self.u32(sp + 12)).decode('latin1'), index=self.u32(sp + 4),
                             id=struct.unpack('<i', uc.mem_read(sp + 8, 4))[0])
        elif address == 0x40C910:
            assert all(h['closed'] for h in self.handles.values())
            self.begin_child('stages', 'data\\stage.dat')
        elif address in (0x41269A, 0x412780, 0x4127D2):
            self.finish_child()
        elif address == 0x40C9F5:
            self.current_stage = self.u32(sp + 0x1C)
            self.stage_ids.append(self.current_stage)
        elif address == 0x40CBD8:
            self.phase_ids.append([self.current_stage, self.u32(sp + 0x18)//0x34C0])

    def blob(self, raw):
        raw = bytes(raw)
        digest = hashlib.sha256(raw).hexdigest()
        if digest not in self.blobs:
            packed = zlib.compress(raw, level=9, wbits=-15)
            assert zlib.decompress(packed, wbits=-15) == raw
            self.blobs[digest] = dict(count=len(raw), deflate=base64.b64encode(packed).decode())
        return digest

    def slice_record(self, region, offset, count):
        raw = bytes(self.uc.mem_read(region['address'] + offset, count))
        initial, mask = region['initial'][offset:offset+count], region['mask'][offset:offset+count]
        assert all(flag or raw[i] == initial[i] for i, flag in enumerate(mask))
        return dict(initial=self.blob(initial), bytes=self.blob(raw), defined=self.blob(mask))

    def record(self, region):
        assert self.uc.mem_read(region['address'] - 16, 16) == b'\x96'*16
        assert self.uc.mem_read(region['address'] + region['size'], 16) == b'\x69'*16
        return self.slice_record(region, 0, region['size'])

    def run(self, source=None, initial_checksum=0):
        name = b'data\\data.txt'
        if source is not None:
            self.files[name] = source
        self.put(0x44F620, initial_checksum)
        self.uc.mem_write(STACK + 0x100, name + b'\0')
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack('<III', STOP, STACK + 0x100, 0x12345678))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, CATALOG)
        pc = 0x4122F0
        while pc != STOP:
            self.uc.emu_start(pc, STOP, count=2_000_000)
            pc = self.uc.reg_read(UC_X86_REG_EIP)
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 12 and self.uc.reg_read(UC_X86_REG_EAX) == CATALOG
        return self.capture_catalog(name, initial_checksum)

    def capture_catalog(self, name=b'data\\data.txt', initial_checksum=0):
        """Snapshot after real4122f0 has returned, including from its real parent.

        CPU entry/return checks belong to the invoking caller. This method does
        not restore a catalog or run a substitute constructor.
        """
        assert self.pending is None and all(h['closed'] for h in self.handles.values())
        assert not self.reads_before_writes, sorted(self.reads_before_writes)[:20]
        assert self.u32(CATALOG + 0x4D82380) == len(self.object_addresses)
        assert self.u32(CATALOG + 0x4D82384) == sum(c['kind'] == 'background' for c in self.children)
        assert self.uc.mem_read(CATALOG - 16, 16) == b'\x96'*16
        assert self.uc.mem_read(CATALOG + CATALOG_SIZE, 16) == b'\x69'*16
        regions = {str(o): self.slice_record(self.catalog, o, n) for o, n in
                   [(0, 0x7D0), (0x4D82380, 0x28)] + [(BG_BASE+i*BG_SIZE, BG_SIZE) for i in range(101)]}
        stages = [self.slice_record(self.catalog, 0x7D0+i*STAGE_SIZE, STAGE_SIZE) for i in range(60)]
        for r in self.regions:
            self.record(r) if r['kind'] != 'catalog' else None
        bitmaps = [{**b, 'storage': self.record(self.region(b['address'], BITMAP_SIZE))} for b in self.bitmaps]
        allocations = [{**a, 'storage': self.record(self.region(a['address'], a['size']))} for a in self.allocations]
        return dict(exeSHA256=EXE_SHA256, crtSHA256=DLL_SHA256, translation='text' if self.text_mode else 'raw',
                    bitmapFill=self.pattern, surfaceAddress=DEVICE, catalogAddress=CATALOG, objectAddresses=self.object_addresses,
                    source=self.blob(self.files[name]), fileName=name.decode(), initialChecksum=initial_checksum, checksum=self.u32(0x44F620),
                    outerTokens=self.parent_tokens, requests=self.requests, children=self.children, regions=regions, stages=stages,
                    stageIDs=self.stage_ids, phaseIDs=self.phase_ids, bitmaps=bitmaps, allocations=allocations,
                    soundCount=self.u32(0x458438), soundBytes=self.blob(self.uc.mem_read(0x455638, 0x2E00)),
                    assets=list(self.asset_inputs.values()), events=self.events, scans=self.scans, blobs=self.blobs,
                    readsBeforeWrites=[], scope=__doc__)


def accept():
    """Accept only after all three complete captures match the native composition.

    The raw captures retain stdio/device events. The smaller test transport keeps
    all loaded records, all allocation snapshots, child boundaries and blob hashes;
    scans and non-mirror device events aren't part of native comparison.
    """
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDCatalogCheck'], check=True)
    pending, summaries = [], []
    for suffix in ('', '-raw-zero', '-interleaved'):
        path = ROOT/'build/original'/('loaded-catalog'+suffix+'.json')
        raw = path.read_bytes()
        doc = json.loads(raw)
        assert not doc['readsBeforeWrites']
        doc.pop('scans'); doc.pop('readsBeforeWrites')
        doc['events'] = [e for e in doc['events'] if e['kind'] == 'mirror-blit']
        compact = json.dumps(doc, separators=(',', ':')).encode()
        compressed = zlib.compress(compact, level=9, wbits=-15)
        assert zlib.decompress(compressed, wbits=-15) == compact
        packed = dict(count=len(compact), sha256=hashlib.sha256(compact).hexdigest(), deflate=base64.b64encode(compressed).decode())
        check = path.with_stem(path.stem+'-check')
        check.write_text(json.dumps(packed, separators=(',', ':'))+'\n')
        result = subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'), '--loaded', str(check)], check=True, capture_output=True, text=True)
        print(result.stdout, end='', flush=True)
        pending.append((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-loaded-catalog'+suffix+'.json'), check.read_bytes()))
        summaries.append(dict(name='baseline'+suffix, corpus=path.name, corpusSHA256=hashlib.sha256(raw).hexdigest(),
                              fixture=pending[-1][0].name, fixtureSHA256=hashlib.sha256(pending[-1][1]).hexdigest(), fixtureBytes=len(pending[-1][1]),
                              comparison=result.stdout.strip(), translation=doc['translation'], bitmapFill=doc['bitmapFill'],
                              initialChecksum=doc['initialChecksum'], checksum=doc['checksum'], soundCount=doc['soundCount'],
                              objects=len(doc['objectAddresses']), backgrounds=sum(c['kind']=='background' for c in doc['children']),
                              stageIDs=doc['stageIDs'], phases=len(doc['phaseIDs']), bitmaps=len(doc['bitmaps']),
                              frames=sum(c.get('frameOccurrences', 0) for c in doc['children']),
                              frameAllocations=sum(a['caller'] in FRAME_KINDS for a in doc['allocations']),
                              readsBeforeWrites=[], registrySHA256=doc['source'],
                              children=[{k: c[k] for k in ('kind', 'path', 'source', 'decoded', 'initialChecksum', 'checksum', 'soundCount', 'bitmapStart', 'bitmapEnd')} for c in doc['children']],
                              embeddedBitmaps=[a for a in doc['assets'] if 'resourcePath' in a]))
    for path, raw in pending:
        path.write_bytes(raw)
    report = dict(exeSHA256=EXE_SHA256, crtSHA256=DLL_SHA256, scope=__doc__,
                  nativeScope='One OriginalLoadedCatalog invocation per capture: parent requests and outer tokens, per-child decoded bytes/checksum/sounds, all 137 Object bytes/masks, all 101 BG, all 60 Stage, every bitmap wrapper and live/dead Frame allocation; only established parent/header/device pointer bindings. No whole-match, pixel/device or Windows proof.',
                  corpora=summaries)
    (ROOT/'docs/evidence/loaded-catalog.json').write_text(json.dumps(report, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw-zero', action='store_true')
    parser.add_argument('--interleaved', action='store_true')
    parser.add_argument('--accept', action='store_true', help='compare existing three captures, then update fixture/evidence')
    args = parser.parse_args()
    if args.accept:
        assert not args.raw_zero and not args.interleaved
        accept()
        return
    vm = LoadedCatalog(pattern=0 if args.raw_zero else 0xA5, text_mode=not args.raw_zero)
    assert not (args.raw_zero and args.interleaved)
    doc = vm.run(INTERLEAVED if args.interleaved else None, 0xFFFFF123 if args.interleaved else 0)
    if not args.interleaved:
        assert len(doc['objectAddresses']) == 137 and len(doc['children']) == 155
    suffix = '-interleaved' if args.interleaved else ('-raw-zero' if args.raw_zero else '')
    path = ROOT / 'build/original' / ('loaded-catalog' + suffix + '.json')
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    print(f"Unaccepted full catalog: {path}; {len(doc['children'])} children, {len(doc['bitmaps'])} bitmaps, checksum {doc['checksum']}", flush=True)


if __name__ == '__main__':
    main()
