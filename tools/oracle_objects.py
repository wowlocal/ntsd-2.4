#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute the complete original Object loader, decoder and bitmap wrapper.

Development only. CRT/file/device boundaries are explicit; no baseline writes.
The legacy boundary supplies Python binary64 for finite decimal tokens. Optional
--msvcr80 executes the pinned Microsoft DLL's scanf. Pixels remain opaque.
"""
import argparse
import hashlib
import json
import math
import re
import struct
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from oracle_state import Constructors, STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EDI, UC_X86_REG_EIP, UC_X86_REG_ESP

BASE, HEAP, STUB, DEVICE = 0x20000000, 0x21000000, 0x30000100, 0x24000000
OBJECT_SIZE, BITMAP_SIZE, FRAME_SIZE = 0x25360, 0x1F50, 0x178
SPACE = b" \t\r\n\v\f"
FRAME_EXCLUDED = {0x130, 0x134, *range(0x15C, 0x174, 4)}

PROBE = br'''<frame> 3 before_header pic: 7 <frame_end>
<bmp_begin>
name: LongerName name: X
head: sprite\sys\naruto_f.bmp small: sprite\sys\naruto_s.bmp
file(400-0): sprite\sys\kunai.bmp w: 7 h: 9 row: 2 col: 2
walking_frame_rate 2 walking_frame_rate nope walking_speed -0.000000
jump_distancez .125 weapon_hp: -17 weapon_drop_hurt: +12suffix
file(not_a_range): sprite\sys\naruto_0.bmp w: 11 h: 13 row: 3 col: 2
weapon_hit_sound: data\027.wav weapon_hit_sound: data\001.wav
<bmp_end>
<weapon_strength_list>
entry: 3 third dvx: -7 injury: 123
entry: 1 first effect: 2 vrest: 9
<weapon_strength_list_end>
<frame> 0 first sound: data\003.wav bdy: x: -3 y: 7 w: 8 h: 9 bdy_end: <frame_end>
<frame> 0 last sound: data\004.wav wait: 8 <frame_end>
'''.replace(b'\n', b'\r\n')

CRT_PROBE = PROBE + br'''<frame> 1 numeric mp: -6846518779 wait: 99999999999999999999
itr: x: -4564896489452763489789879 w: 4294967296 catchingact: +12suffix 9 itr_end:
<frame_end>
<frame> 1 again mp: +nope dvx: --12 dvy: -99999898425321456555555 <frame_end>
'''.replace(b'\n', b'\r\n')


class Objects(Constructors):
    def __init__(self, text_mode=True, pattern=0xA5, missing_mirrors=False, use_crt=False, capacity=4, retain_opaque_frames=False):
        super().__init__()
        assert 1 <= capacity <= 137
        self.object_base = BASE if capacity <= 4 else 0x50000000
        self.object_arena_size = capacity * 0x40000
        self.heap_size = 0x400000 if capacity <= 4 else 0xF00000  # below Constructors' 0x22000000 arena
        self.retain_opaque_frames = retain_opaque_frames
        self._region_cache = None
        if use_crt:
            from oracle_crt import CRT
            self.crt = CRT()
        else:
            self.crt = None
        self.text_mode, self.pattern = text_mode, pattern
        self.missing_mirrors = missing_mirrors
        self.uc.mem_map(0, 0x1000)  # only SEH FS:0 is used
        self.uc.mem_map(self.object_base, self.object_arena_size)
        self.uc.mem_map(HEAP, self.heap_size)
        self.uc.mem_map(DEVICE, 0x10000)
        self.regions, self.allocations, self.bitmaps, self.events = [], [], [], []
        self.handles, self.files, self.asset_inputs = {}, {}, {}
        self.reads_before_writes, self.accesses, self.formats = set(), set(), {}
        self.scans, self.outer_tokens, self.frame_occurrences, self.constructors = [], [], [], []
        self.current = None
        self.bump = HEAP + 0x20
        self.put(0x44EECC, 0)  # actual sound registration still executes
        self.put(0x458438, 0)
        self.put(0x44F620, 0)
        self.put(0x4511C0, 0)
        self.put(DEVICE, DEVICE + 0x100)
        self.put(DEVICE + 0x100 + 0x74, STUB + 0x300)  # IDirectDrawSurface::SetColorKey
        self.put(DEVICE + 0x100 + 0x14, STUB + 0x310)  # IDirectDrawSurface::Blt
        for start, size in [(self.object_base, self.object_arena_size), (HEAP, self.heap_size), (0x455638, 0x2E04)]:
            self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track_write, begin=start, end=start + size - 1)
            self.uc.hook_add(UC_HOOK_MEM_READ, self.track_read, begin=start, end=start + size - 1)
        self.lookup = {}
        wanted = {"fopen", "fclose", "feof", "fscanf", "fprintf", "sprintf", "malloc", "timeGetTime", "Sleep", "PeekMessageA"}
        for item in PE(read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe")).imports():
            if item["name"] in wanted:
                address = STUB + 16 * len(self.lookup)
                self.lookup[address] = item["name"]
                self.put(int(item["iatVA"], 16), address)
        self.uc.hook_add(UC_HOOK_CODE, self.imported, begin=STUB, end=STUB + 0x3FF)
        for address in [0x4450AC, 0x43ED10, 0x40BBF0, 0x40F0C2, 0x40F161, 0x410421, 0x412277, 0x43EE50]:
            self.uc.hook_add(UC_HOOK_CODE, self.checkpoint, begin=address, end=address)

    def put(self, address, value):
        self.uc.mem_write(address, struct.pack("<I", value & 0xFFFFFFFF))

    def cstr(self, address):
        if 0x447000 <= address < 0x44D000 and address in self.formats:
            return self.formats[address]
        result = bytearray()
        for i in range(4096):
            byte = self.uc.mem_read(address + i, 1)[0]
            if not byte:
                value = bytes(result)
                if 0x447000 <= address < 0x44D000:
                    self.formats[address] = value
                return value
            result.append(byte)
        raise ValueError(f"Unterminated string at {address:x}")

    def ret(self, value=0, pop=0):
        sp = self.uc.reg_read(UC_X86_REG_ESP)
        self.uc.reg_write(UC_X86_REG_EAX, value & 0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_EIP, self.u32(sp))
        self.uc.reg_write(UC_X86_REG_ESP, sp + 4 + pop)

    def region(self, address, size):
        if 0x455638 <= address and address + size <= 0x45843C:
            return None  # original PE global initial bytes are retained separately
        r = self._region_cache
        if r is not None and r['address'] <= address and address + size <= r['address'] + r['size']:
            return r
        for r in reversed(self.regions):
            if r['address'] <= address and address + size <= r['address'] + r['size']:
                self._region_cache = r
                return r
        raise ValueError(f"Access outside allocated storage: {address:x}/{size}")

    def track_write(self, uc, access, address, size, value, data):
        r = self.region(address, size)
        pc = uc.reg_read(UC_X86_REG_EIP)
        if r is None:
            self.accesses.add(("write", "sound-global", address - 0x455638, size, pc))
            return
        offset = address - r['address']
        r['mask'][offset:offset + size] = b"\1" * size
        if r['kind'] == 'object' and offset < 0x7A4:
            self.accesses.add(("write", "header", offset, size, pc))

    def track_read(self, uc, access, address, size, value, data):
        r = self.region(address, size)
        if r is None:
            return
        offset = address - r['address']
        if not all(r['mask'][offset:offset + size]):
            self.reads_before_writes.add((r['kind'], offset, size, uc.reg_read(UC_X86_REG_EIP)))
        if r['kind'] == 'object' and offset < 0x7A4:
            self.accesses.add(("read", "header", offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def write_host(self, address, raw):
        if self.object_base <= address < self.object_base + self.object_arena_size or HEAP <= address < HEAP + self.heap_size:
            self.track_write(self.uc, 0, address, len(raw), 0, None)
        self.uc.mem_write(address, raw)

    def add_region(self, address, size, kind):
        raw = bytes([self.pattern]) * size if self.pattern is not None else bytes(i & 255 for i in range(size))
        r = dict(address=address, size=size, kind=kind, initial=raw, mask=bytearray(size))
        self.regions.append(r)
        self.uc.mem_write(address - 16, b"\x96" * 16 + raw + b"\x69" * 16)
        return r

    def allocate(self, size, kind, caller):
        assert 0 < size <= BITMAP_SIZE and self.bump + size + 32 < HEAP + self.heap_size
        address = self.bump
        self.bump += (size + 63) & ~15
        r = self.add_region(address, size, kind)
        self.allocations.append(dict(address=address, size=size, kind=kind, caller=hex(caller)))
        return r

    def memset(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        dst, value, count = [self.u32(sp + i) for i in (4, 8, 12)]
        assert STACK <= dst < dst + count <= STACK + 0x10000
        self.write_host(dst, bytes([value & 255]) * count)
        self.ret(dst)

    def text_input(self, data):
        return data.split(b"\x1a", 1)[0].replace(b"\r\n", b"\n") if self.text_mode else data

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        arg = lambda i: self.u32(sp + 4 + 4*i)
        if address == STUB + 0x300:
            assert arg(0) == DEVICE and arg(1) == 8 and bytes(uc.mem_read(arg(2), 8)) == bytes(8)
            self.events.append(dict(kind="color-key", bitmap=len(self.bitmaps) - 1))
            self.ret(0, 12)
            return
        if address == STUB + 0x310:
            assert arg(0) == DEVICE and arg(2) == DEVICE and arg(4) == 0x1000800
            slot = self.u32(self.current['address'] + 0x498)
            self.events.append(dict(kind="mirror-blit", bitmap=len(self.bitmaps) - 1,
                                   normalAddress=self.u32(self.current['address'] + 0x750 + slot*4),
                                   destination=list(struct.unpack('<4i', uc.mem_read(arg(1), 16))),
                                   source=list(struct.unpack('<4i', uc.mem_read(arg(3), 16))), effects=bytes(uc.mem_read(arg(5), 100)).hex()))
            self.ret(0, 24)
            return
        name = self.lookup.get(address)
        assert name, hex(address)
        if name == "fopen":
            path, mode = self.cstr(arg(0)), self.cstr(arg(1))
            assert mode in (b"r", b"w")
            handle = len(self.handles) + 1
            if mode == b"w":
                assert path == b"data\\temporary.txt"
                self.files[path] = b""
            assert path in self.files, path
            self.handles[handle] = dict(path=path, mode=mode, data=self.text_input(self.files[path]), pos=0, eof=False, closed=False)
            self.events.append(dict(kind="open", path=path.decode('latin1'), mode=mode.decode(), handle=handle))
            self.ret(handle)
        elif name == "fclose":
            h = self.handles[arg(0)]
            assert not h['closed']
            h['closed'] = True
            self.events.append(dict(kind="close", handle=arg(0)))
            self.ret()
        elif name == "feof":
            assert not self.handles[arg(0)]['closed']
            self.ret(int(self.handles[arg(0)]['eof']))
        elif name == "fprintf":
            h, fmt = self.handles[arg(0)], self.cstr(arg(1))
            assert h['mode'] == b'w' and not h['closed']
            assert fmt in (b'%c', b'Do not erase this file.')
            output = bytes([arg(2) & 255]) if fmt == b'%c' else fmt
            self.files[h['path']] += output.replace(b'\n', b'\r\n') if self.text_mode else output
            self.ret(len(output))
        elif name == "fscanf":
            h, fmt = self.handles[arg(0)], self.cstr(arg(1))
            assert not h['closed'] and h['mode'] == b'r'
            assert fmt in (b'%s', b'%c', b'%d', b'%d %d', b'%d %s', b'%lf', b'%ld', b'%s %s %d %d'), fmt
            if self.crt is not None and fmt != b'%c':
                before = h['pos']
                result = self.crt.scan(h['data'][before:], fmt)
                for i, raw in enumerate(result['outputs']):
                    if raw:
                        self.write_host(arg(2 + i), bytes.fromhex(raw))
                h['pos'] += result['position']
                h['eof'] = h['eof'] or result['eof']
                self.scans.append(dict(caller=hex(self.u32(sp)), format=fmt.decode(), before=before, after=h['pos'],
                                       assignments=max(0, result['result']), eof=h['eof']))
                self.ret(result['result'])
                return
            assigned, before = 0, h['pos']
            for i, spec in enumerate(fmt.split()):
                if spec != b'%c':
                    while h['pos'] < len(h['data']) and h['data'][h['pos']] in SPACE:
                        h['pos'] += 1
                if h['pos'] == len(h['data']):
                    h['eof'] = True
                    break
                start = h['pos']
                if spec == b'%c':
                    end, raw = start + 1, h['data'][start:start + 1]
                elif spec == b'%s':
                    end = start
                    while end < len(h['data']) and h['data'][end] not in SPACE:
                        end += 1
                    raw = h['data'][start:end] + b'\0'
                    assert len(raw) <= 256, "Scratch buffer domain"
                else:
                    expression = rb'[+-]?[0-9]+' if spec in (b'%d', b'%ld') else rb'[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?'
                    match = re.match(expression, h['data'][start:])
                    if not match:
                        break
                    end = start + len(match[0])
                    if spec in (b'%d', b'%ld'):
                        number = int(match[0]); assert -(2**31) <= number < 2**31, ("MSVCR80 overflow", match[0], hex(self.u32(sp)))
                        raw = struct.pack('<i', number)
                    else:
                        number = float(match[0]); assert math.isfinite(number)
                        raw = struct.pack('<d', number)
                self.write_host(arg(2 + i), raw)
                h['pos'] = end
                if spec != b'%c' and end == len(h['data']):
                    h['eof'] = True
                assigned += 1
            if fmt != b'%c':
                self.scans.append(dict(caller=hex(self.u32(sp)), format=fmt.decode(), before=before, after=h['pos'],
                                       assignments=assigned, eof=h['eof']))
            self.ret(assigned if assigned else (-1 if h['eof'] else 0))
        elif name == 'sprintf':
            assert self.cstr(arg(1)) == b'%d'
            raw = str(struct.unpack('<i', struct.pack('<I', arg(2)))[0]).encode()
            self.write_host(arg(0), raw + b'\0'); self.ret(len(raw))
        elif name == 'malloc':
            self.ret(self.allocate(arg(0), 'malloc', self.u32(sp))['address'])
        elif name == 'timeGetTime':
            self.ret(100)
        elif name == 'Sleep':
            assert arg(0) == 5
            self.ret(0, 4)
        elif name == 'PeekMessageA':
            self.ret(0, 20)

    def checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x4450AC:
            assert self.u32(sp + 4) == BITMAP_SIZE
            self.ret(self.allocate(BITMAP_SIZE, 'bitmap', self.u32(sp))['address'])
        elif address == 0x43EE50:
            self.bitmaps.append(dict(address=uc.reg_read(UC_X86_REG_ECX),
                                     path=self.cstr(self.u32(sp + 8)).decode('latin1'), optional=self.u32(sp + 12)))
            assert self.u32(sp + 4) == 64
        elif address == 0x43ED10:
            path = self.cstr(uc.reg_read(UC_X86_REG_EDI))
            p = DEFAULT_SOURCE / path.decode('latin1').replace('\\', '/')
            assert p.resolve().is_relative_to(DEFAULT_SOURCE.resolve())
            available = p.is_file() and not (self.missing_mirrors and path.endswith(b'_mirror.bmp'))
            item = dict(path=path.decode('latin1'), present=available)
            if available:
                raw = read_bytes(p); assert raw[:2] == b'BM'
                width, height = struct.unpack_from('<ii', raw, 18)
                assert width > 0 and height > 0
                item.update(width=width, height=height, sha256=hashlib.sha256(raw).hexdigest())
                self.write_host(self.u32(sp + 16), struct.pack('<i', width))
                self.write_host(self.u32(sp + 20), struct.pack('<i', height))
            else:
                assert path.endswith(b'_mirror.bmp'), ("Required bitmap missing", path)
            self.asset_inputs[path.decode('latin1')] = item
            self.events.append(dict(kind='bitmap-load', **item))
            self.ret(DEVICE if available else 0)
        elif address == 0x40BBF0:
            offset = uc.reg_read(UC_X86_REG_ECX) - self.current['address'] - 0x7A4
            assert offset % FRAME_SIZE == 0 and 0 <= offset // FRAME_SIZE < 400
            self.constructors.append(offset // FRAME_SIZE)
        elif address == 0x40F0C2:
            self.initialized = self.snapshot_region(self.current)
        elif address == 0x40F161:
            self.outer_tokens.append(self.cstr(sp + 0x7C).hex())
        elif address == 0x410421:
            self.current_frame = self.u32(sp + 0x24)
            assert self.current_frame < 400
        elif address == 0x412277:
            if self.current_frame is not None:
                self.frame_occurrences.append(self.frame(self.current_frame))
                self.current_frame = None

    def frame(self, n):
        base = self.current['address'] + 0x7A4 + FRAME_SIZE*n
        mask = self.current['mask'][0x7A4 + FRAME_SIZE*n:0x7A4 + FRAME_SIZE*(n+1)]
        words = {'0': self.uc.mem_read(base, 1)[0]}
        for offset in range(4, FRAME_SIZE, 4):
            if offset not in FRAME_EXCLUDED and all(mask[offset:offset + 4]):
                words[str(offset)] = struct.unpack('<i', self.uc.mem_read(base + offset, 4))[0]
        arrays = {}
        for name, count_offset, pointer_offset, stride in [('interactions', 0x128, 0x130, 80), ('bodies', 0x12C, 0x134, 40)]:
            count = self.u32(base + count_offset); assert count <= 5
            pointer = self.u32(base + pointer_offset)
            arrays[name] = [list(struct.unpack('<' + 'i'*(stride//4), self.uc.mem_read(pointer + i*stride, stride))) for i in range(count)]
        pointer = self.u32(base + 0x170)
        name = self.cstr(base + 0x15C).decode('latin1') if words['0'] else ''
        allocated = not pointer or any(a['address'] <= pointer < a['address'] + a['size'] for a in self.allocations)
        if not allocated:
            assert self.retain_opaque_frames, ('Opaque Frame sound pointer', n, name, hex(pointer))
        record = dict(number=n, name=name, words=words, sound=self.cstr(pointer).decode('latin1') if pointer and allocated else None, **arrays)
        if not allocated:
            record['opaqueSoundPointer'] = hex(pointer)
        return record

    def snapshot_region(self, r):
        raw = bytes(self.uc.mem_read(r['address'], r['size']))
        assert self.uc.mem_read(r['address'] - 16, 16) == b'\x96'*16
        assert self.uc.mem_read(r['address'] + r['size'], 16) == b'\x69'*16
        assert all(flag or raw[i] == r['initial'][i] for i, flag in enumerate(r['mask']))
        return dict(address=r['address'], kind=r['kind'], initial=r['initial'].hex(), bytes=raw.hex(), defined=bytes(r['mask']).hex())

    def load(self, path, object_id, object_type, payload=None):
        raw = read_bytes(DEFAULT_SOURCE / path.replace('\\', '/')) if payload is None else payload
        self.files[path.encode('latin1')] = raw
        count = sum(r['kind'] == 'object' for r in self.regions)
        assert (count + 1) * 0x40000 <= self.object_arena_size
        self.current = self.add_region(self.object_base + 0x20 + count * 0x40000, OBJECT_SIZE, 'object')
        self.current_frame = None
        self.constructors, self.outer_tokens, self.frame_occurrences = [], [], []
        self.initialized = None
        start_bitmap, start_event, start_scan = len(self.bitmaps), len(self.events), len(self.scans)
        initial_checksum = self.u32(0x44F620)
        self.uc.mem_write(STACK + 0x100, path.encode('latin1') + b'\0')
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack('<IIIII', STOP, object_id & 0xFFFFFFFF, object_type & 0xFFFFFFFF, STACK + 0x100, 0x12345678))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, self.current['address'])
        self.uc.emu_start(0x40EF70, STOP, timeout=60_000_000, count=100_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP, ("Object limit", hex(self.uc.reg_read(UC_X86_REG_EIP)))
        assert self.uc.reg_read(UC_X86_REG_EAX) == self.current['address'] and self.uc.reg_read(UC_X86_REG_ESP) == sp + 20
        assert self.constructors == list(range(400))
        assert all(h['closed'] for h in self.handles.values())
        assert self.files[b'data\\temporary.txt'] == b'Do not erase this file.'
        decoded = next(h['data'] for h in list(self.handles.values())[::-1] if h['mode'] == b'r')
        return dict(path=path, id=object_id, type=object_type, source=raw.hex(), sourceSHA256=hashlib.sha256(raw).hexdigest(), sourceBytes=len(raw),
                    decoded=decoded.hex(), initialChecksum=initial_checksum, checksum=self.u32(0x44F620),
                    initialization=self.initialized, storage=self.snapshot_region(self.current),
                    frameOccurrences=self.frame_occurrences, frames=[self.frame(i) for i in range(400)],
                    bitmaps=self.bitmaps[start_bitmap:], events=self.events[start_event:], scans=self.scans[start_scan:],
                    outerTokens=self.outer_tokens, soundCount=self.u32(0x458438), soundBytes=bytes(self.uc.mem_read(0x455638, 0x2E00)).hex())


def compact(doc):
    assert not any('opaqueSoundPointer' in f for c in doc['cases'] for f in c['frames'] + c['frameOccurrences']), 'Raw Frame references require native recovery before comparison'
    def region(r, start=0, end=None):
        return {key: bytes.fromhex(r[key])[start:end].hex() for key in ('initial', 'bytes', 'defined')}
    records = {r['address']: r for r in doc['regions']}
    cases = []
    for c in doc['cases']:
        sounds = {}
        raw = bytes.fromhex(c['storage']['bytes'])
        for ordinal in range(3):
            pointer = struct.unpack_from('<I', raw, 0x98 + ordinal*4)[0]
            if pointer:
                r = records[pointer]
                value = bytes.fromhex(r['bytes']).split(b'\0', 1)[0]
                assert all(bytes.fromhex(r['defined'])[:len(value) + 1])
                sounds[str(ordinal)] = value.decode('latin1')
        cases.append({**{k: c[k] for k in ('path', 'id', 'type', 'source', 'sourceSHA256', 'decoded', 'initialChecksum', 'checksum', 'frames', 'frameOccurrences', 'events', 'soundCount', 'soundBytes')},
                      'header': region(c['storage'], 0, 0x7A4), 'tail': region(c['storage'], 0x25324),
                      'weaponSoundPaths': sounds, 'bitmaps': [{**b, 'storage': region(records[b['address']])} for b in c['bitmaps']]})
    result = dict(exeSHA256=EXE_SHA256, translation='text' if doc['textMode'] else 'raw', bitmapFill=doc['bitmapFill'], surfaceAddress=DEVICE, cases=cases, assetInputs=doc['assetInputs'])
    if 'crtSHA256' in doc:
        result['crtSHA256'] = doc['crtSHA256']
    return result


def capture(names, text_mode=True, pattern=0xA5, missing_mirrors=False, use_crt=False, all_registry=False):
    source_registry = (DEFAULT_SOURCE / 'data/data.txt').read_text()
    registry = re.findall(r'id:\s*(-?\d+)\s+type:\s*(-?\d+)\s+file:\s*(\S+)', source_registry)
    if all_registry:
        assert use_crt and len(registry) == 137
        names = [p for _, _, p in registry]
    vm = Objects(text_mode=text_mode, pattern=pattern, missing_mirrors=missing_mirrors, use_crt=use_crt,
                 capacity=137 if all_registry else 4, retain_opaque_frames=all_registry)
    cases = []
    for ordinal, name in enumerate(names):
        if all_registry:
            object_id, object_type, path = registry[ordinal]
            item = vm.load(path, int(object_id), int(object_type))
            item['sourceKind'] = 'baseline file in source registry order'
        elif name in ('@probe', '@crt-probe'):
            path = 'data\\object-probe.txt'
            item = vm.load(path, -17, 6, CRT_PROBE if name == '@crt-probe' else PROBE)
            item['sourceKind'] = 'synthetic control using unchanged baseline bitmap resources'
        else:
            path = 'chars\\' + name + '.dat'
            match = re.search(r'id:\s*(-?\d+)\s+type:\s*(-?\d+)\s+file:\s*' + re.escape(path) + r'(?:\s|$)', source_registry)
            assert match, path
            item = vm.load(path, *map(int, match.groups()))
            item['sourceKind'] = 'baseline file'
        cases.append(item)
        print(f"{path}: {len(item['frameOccurrences'])} frame occurrences, {len(item['bitmaps'])} bitmaps, {item['soundCount']} shared sounds, checksum {item['checksum']}", flush=True)
    doc = dict(exeSHA256=EXE_SHA256, textMode=vm.text_mode, bitmapFill=vm.pattern, forcedMissingMirrors=vm.missing_mirrors,
               scope='Complete 40ef70/4148a0/43ee50 instruction paths; bounded CRT with supplied finite binary64, file/GDI/DDraw boundaries; no pixel/audio device output or Windows verification',
               cases=cases, assetInputs=list(vm.asset_inputs.values()), regions=[vm.snapshot_region(r) for r in vm.regions], allocations=vm.allocations,
               readsBeforeWrites=[dict(region=r, offset=o, size=n, instruction=hex(pc)) for r, o, n, pc in sorted(vm.reads_before_writes)],
               accesses=[dict(mode=m, region=r, offset=o, size=n, instruction=hex(pc)) for m, r, o, n, pc in sorted(vm.accesses)])
    suffix = '-raw-stdio' if not text_mode else ('-missing-mirrors' if missing_mirrors else '')
    if use_crt:
        from oracle_crt import DLL_SHA256
        doc['crtSHA256'] = DLL_SHA256
        doc['scope'] = 'Complete Object instructions with actual VC80 8.0.50727.6195 fscanf for all formats except decoder %c; supplied translated _read buffers, thread/lock/device boundaries. No Windows startup or pixel/audio output.'
        suffix += '-msvcr80-' + ('registry' if all_registry else '-'.join(n.removeprefix('@') for n in names))
    if pattern == 0: suffix += '-zero'
    if names == ['@probe']: suffix += '-probe'
    output = ROOT / 'build/original' / ('objects' + suffix + '.json')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    print(f"Unaccepted research corpus: {output}; {len(vm.reads_before_writes)} distinct reads before observed writes", flush=True)
    if all_registry:
        registry_report(doc, output)
    return doc, output


def registry_report(doc, output):
    """Research evidence only: deliberately no native acceptance for opaque data."""
    assert len(doc['cases']) == 137 and doc.get('crtSHA256')
    report = dict(exeSHA256=EXE_SHA256, crtSHA256=doc['crtSHA256'], nativeCompared=False,
                  scope=doc['scope'] + ' All Object children in source registry order; parent/BG/Stage not joined. Opaque Frame pointers retained, not interpreted as strings.',
                  corpus=output.name, corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                  translation='text' if doc['textMode'] else 'raw', bitmapFill=doc['bitmapFill'],
                  regions=len(doc['regions']), allocationBytes=sum(a['size'] for a in doc['allocations']),
                  readsBeforeWrites=doc['readsBeforeWrites'], objects=[])
    for ordinal, case in enumerate(doc['cases']):
        raw = bytes.fromhex(case['storage']['bytes'])
        report['objects'].append(dict(ordinal=ordinal, path=case['path'], id=case['id'], type=case['type'],
            sourceSHA256=case['sourceSHA256'], decodedSHA256=hashlib.sha256(bytes.fromhex(case['decoded'])).hexdigest(),
            rawObjectSHA256=hashlib.sha256(raw).hexdigest(), maskSHA256=hashlib.sha256(bytes.fromhex(case['storage']['defined'])).hexdigest(),
            occurrences=len(case['frameOccurrences']), populatedFrames=sum(f['words']['0'] != 0 for f in case['frames']),
            bitmaps=len(case['bitmaps']), sheets=struct.unpack_from('<i', raw, 0x498)[0],
            initialChecksum=case['initialChecksum'], checksum=case['checksum'], soundCount=case['soundCount'],
            opaqueFrameSounds=[dict(number=f['number'], name=f['name'], pointer=f['opaqueSoundPointer'], soundIndex=f['words']['372'])
                               for f in case['frames'] if 'opaqueSoundPointer' in f]))
    report.update(occurrences=sum(x['occurrences'] for x in report['objects']), frames=137*400,
                  bitmaps=sum(x['bitmaps'] for x in report['objects']), soundCount=doc['cases'][-1]['soundCount'],
                  checksum=doc['cases'][-1]['checksum'])
    (ROOT / 'docs/evidence/object-registry-research.json').write_text(json.dumps(report, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--legacy-raw-stdio', action='store_true', help='Explicit previous decoder boundary, to expose file-translation differences')
    parser.add_argument('--files', nargs='+', default=['naruto', 'sasuke'])
    parser.add_argument('--missing-mirrors', action='store_true', help='Explicit device-boundary failure probe, without changing assets')
    parser.add_argument('--zero-fill', action='store_true')
    parser.add_argument('--msvcr80', action='store_true', help='Execute hash-pinned VC80 fscanf for all non-decoder scans')
    parser.add_argument('--all-registry', action='store_true', help='Research capture of all 137 objects in source order with raw unresolved Frame references; requires --msvcr80')
    parser.add_argument('--crt-suite', action='store_true', help='Compare and accept Pein/Naruto/Sasuke and numeric controls with actual VC80 scanf')
    parser.add_argument('--suite', action='store_true', help='Capture both stdio contracts and missing-mirror weapon probe; accept fixtures only after native comparison')
    args = parser.parse_args()
    if args.crt_suite:
        accept([capture(['pein', 'naruto', 'sasuke', '@crt-probe'], use_crt=True)], crt=True)
        return
    if not args.suite:
        capture(args.files, not args.legacy_raw_stdio, 0 if args.zero_fill else 0xA5, args.missing_mirrors, use_crt=args.msvcr80, all_registry=args.all_registry)
        return
    captured = [capture(['naruto', 'sasuke']), capture(['naruto', 'sasuke'], text_mode=False),
                capture(['weapon4'], pattern=0, missing_mirrors=True), capture(['@probe'])]
    accept(captured)


def accept(captured, crt=False):
    subprocess.run(['swift', 'build', '--package-path', str(ROOT / 'native'), '-c', 'release', '--product', 'NTSDObjectCheck'], check=True)
    checks, summaries = [], []
    for doc, output in captured:
        check = compact(doc)
        path = output.with_stem(output.stem + '-check')
        path.write_text(json.dumps(check, separators=(',', ':')) + '\n')
        subprocess.run([str(ROOT / 'native/.build/release/NTSDObjectCheck'), str(path)], check=True)
        checks.append(check)
        summaries.append(dict(corpus=output.name, corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                              comparisonSHA256=hashlib.sha256(path.read_bytes()).hexdigest(), textMode=doc['textMode'],
                              forcedMissingMirrors=doc['forcedMissingMirrors'], bitmapFill=doc['bitmapFill'],
                              cases=[dict(path=c['path'], sourceKind=c['sourceKind'], sourceSHA256=c['sourceSHA256'], decodedSHA256=hashlib.sha256(bytes.fromhex(c['decoded'])).hexdigest(),
                                          occurrences=len(c['frameOccurrences']), populatedFrames=sum(f['words']['0'] != 0 for f in c['frames']),
                                          bitmaps=len(c['bitmaps']), soundCount=c['soundCount'], checksum=c['checksum'],
                                          initializedBytes=sum(bytes.fromhex(c['initialization']['defined'])), loadedBytes=sum(bytes.fromhex(c['storage']['defined']))) for c in doc['cases']],
                              readsBeforeWrites=doc['readsBeforeWrites']))
    fixture = ROOT / ('native/Tests/NTSDCoreTests/Fixtures/original-objects-msvcr80.json' if crt else 'native/Tests/NTSDCoreTests/Fixtures/original-objects.json')
    fixture.write_text(json.dumps(dict(corpora=checks), separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=captured[0][0]['scope'],
                  nativeScope='Decoded bytes under each explicit stdio contract; all header/tail/bitmap bytes and initialization masks; every defined frame word, box and name/sound after each occurrence and at EOF; shared sound cache, checksum and missing-mirror source request. Raw frame padding/pointers and dead malloc blocks are retained only in full research captures.',
                  fixtureSHA256=hashlib.sha256(fixture.read_bytes()).hexdigest(), corpora=summaries,
                  objectHeaderAccesses=[a for a in captured[0][0]['accesses'] if a['region'] == 'header'])
    if crt:
        from oracle_crt import DLL_SHA256
        report['crtSHA256'] = DLL_SHA256
    (ROOT / ('docs/evidence/object-loader-msvcr80.json' if crt else 'docs/evidence/object-loader.json')).write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
