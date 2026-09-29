#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.6"]
# ///
"""Execute whole original43e620 — the playback loader — with the pinned EXE's
own zlib, the actual MSVCP80 ifstream and MSVCR80 stdio in controlled
Unicorn2.1.4. Declared responses: calloc/free (recorded), _fsopen (open or
fail), and descriptor3 _read/_lseek/_lseeki64/_close answered from a supplied
file's bytes. No Windows file is read. Inputs are recordings written by the
app plus declared variants. APPLICATION_PLAYBACK_PLAN.md P1.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE
from oracle_crt import STACK, STOP
from oracle_replay_stream import ReplayStream, FILE, SAVED
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_INVALID, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EIP, UC_X86_REG_ESP

ENTRY, KEY, POINTER = 0x43e620, 0x44d7a0, 0x4588ac
LOADER_API = STOP + 0x8000
RECORDING, PAYLOAD_AREA, SMALL = 0x30100000, 0x31000000, 0x2a000000
PATH = 0x2b000000
digest = lambda b: hashlib.sha256(b).hexdigest()


class ReplayLoader(ReplayStream):
    def __init__(self, content):
        self.loader_imports = {}
        self.content = content
        self.position = 0
        super().__init__(open_failure=content is None)
        raw = read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe'); assert digest(raw) == EXE_SHA256
        pe = PE(raw); self.uc.mem_map(pe.base, 0x100000)
        for s in pe.sections:
            if s['name'] != '.rsrc': self.uc.mem_write(pe.base + s['rva'], raw[s['fileOffset']:s['fileOffset'] + s['fileSize']])
        for index, item in enumerate(pe.imports()):
            name = item['name']; pointer = LOADER_API + 16 * index
            if item['dll'].lower() == 'msvcp80.dll': pointer = self.cpp_exports[name]
            elif item['dll'].lower() == 'msvcr80.dll' and name not in ('calloc', 'free'): pointer = self.crt_exports[name]
            else: self.loader_imports[pointer] = name
            self.put(int(item['iatVA'], 16), pointer)
        for name in ('_read', '_lseek', '_lseeki64'):
            pc = self.crt_exports[name]; self.cpp_boundaries[pc] = name
            self.uc.hook_add(UC_HOOK_CODE, self.boundary, begin=pc, end=pc)
        self.uc.mem_map(RECORDING, 0x700000); self.uc.mem_map(PAYLOAD_AREA, 0x1000000)
        self.uc.mem_map(SMALL, 0x100000); self.uc.mem_map(PATH, 0x1000)
        self.log = []; self.loader_allocations = {}; self.ordinal = 0; self.small = 0x100; self.fault = None
        self.uc.hook_add(UC_HOOK_MEM_INVALID, self.unmapped)
        # Writes past the 0x630e18-byte recording allocation (the original
        # passes capacity 0x631200 to uncompress).
        self.overflow = set()
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.past, begin=RECORDING + 0x630e18, end=RECORDING + 0x6fffff)

    def past(self, uc, access, address, size, value, data):
        self.overflow.update(range(address, address + size))

    def unmapped(self, uc, access, address, size, value, data):
        self.fault = dict(kind='unmapped', pc=uc.reg_read(UC_X86_REG_EIP), address=address, size=size, access=access)
        return False

    def boundary(self, uc, pc, size, data):
        name = self.cpp_boundaries.get(pc)
        sp = uc.reg_read(UC_X86_REG_ESP); arg = lambda i: self.u32(sp + 4 + 4 * i)
        # A second hook registered at this address sees the state after our
        # return (EIP already moved on); the call was served once.
        if uc.reg_read(UC_X86_REG_EIP) != pc: return
        if name == '_read':
            assert arg(0) == 3, (name, [hex(arg(i)) for i in range(4)], hex(self.u32(sp)))
            count = arg(2); chunk = self.content[self.position:self.position + count]
            uc.mem_write(arg(1), chunk); self.position += len(chunk)
            self.log.append(dict(kind='read', count=count, result=len(chunk))); self.ret(len(chunk)); return
        if name in ('_lseek', '_lseeki64'):
            assert arg(0) == 3, (name, [hex(arg(i)) for i in range(4)], hex(self.u32(sp)))
            if name == '_lseek': offset, origin = struct.unpack('<i', struct.pack('<I', arg(1)))[0], arg(2)
            else: offset, origin = struct.unpack('<q', struct.pack('<II', arg(1), arg(2)))[0], arg(3)
            base = {0: 0, 1: self.position, 2: len(self.content)}[origin]
            self.position = base + offset; assert self.position >= 0
            self.log.append(dict(kind='seek', offset=offset, origin=origin, result=self.position))
            if name == '_lseek': self.ret(self.position)
            else: uc.reg_write(UC_X86_REG_EAX, self.position & 0xffffffff); self.ret(self.position & 0xffffffff)
            if name == '_lseeki64':
                from unicorn.x86_const import UC_X86_REG_EDX
                uc.reg_write(UC_X86_REG_EDX, self.position >> 32)
            return
        if pc in self.loader_imports:
            name = self.loader_imports[pc]
            if name == 'calloc':
                count = arg(0) * arg(1); self.ordinal += 1
                if self.ordinal <= 2:
                    address = RECORDING if self.ordinal == 1 else PAYLOAD_AREA
                    assert count <= (0x700000 if self.ordinal == 1 else 0x1000000)
                else:
                    # zlib's own zcalloc (inflate state, window, trees).
                    address = SMALL + self.small; self.small += (count + 31) & ~15
                    assert self.small <= 0x100000
                uc.mem_write(address, b'\0' * count); self.loader_allocations[address] = self.ordinal
                self.log.append(dict(kind='allocate' if self.ordinal <= 2 else 'zlibAllocate', ordinal=self.ordinal, count=count))
                self.ret(address); return
            if name == 'free':
                address = arg(0); ordinal = self.loader_allocations.pop(address)
                self.log.append(dict(kind='free' if ordinal <= 2 else 'zlibFree', ordinal=ordinal)); self.ret(); return
            raise AssertionError(('Unexpected loader import', name, hex(self.u32(sp))))
        start = len(self.events)
        super().boundary(uc, pc, size, data)
        if name in ('_fsopen', '_wfsopen') and self.content is not None:
            # A read-mode open: _IOREAD, descriptor3 (the harness's write FILE is _IOWRT).
            self.uc.mem_write(FILE, struct.pack('<8I', 0, 0, 0, 1, 3, 0, 0, 0))
        for event in self.events[start:]:
            if event['name'] in ('_fsopen', '_wfsopen', '_close'):
                self.log.append(dict(kind=event['name'], **{k: v for k, v in event.items() if k in ('mode', 'share', 'result')}))

    def load(self, key):
        self.uc.mem_write(KEY, key + b'\0')
        self.uc.mem_write(PATH, b'recording\\probe.lfr\0')
        self.put(0x44d030, 7); self.put(0x450b74, 7); self.put(POINTER, 0x13579bdf)
        sp = STACK + 0xf000
        self.uc.mem_write(sp, struct.pack('<II', STOP, PATH))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        before = [self.uc.reg_read(r) for r in SAVED]
        self.uc.emu_start(ENTRY, STOP, count=500_000_000)
        assert self.fault is None, self.fault
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP and self.uc.reg_read(UC_X86_REG_ESP) == sp + 4
        assert before == [self.uc.reg_read(r) for r in SAVED]
        result = struct.unpack('<i', struct.pack('<I', self.uc.reg_read(UC_X86_REG_EAX)))[0]
        recording = bytes(self.uc.mem_read(RECORDING, 0x630e18)) if result == 1 else None
        return dict(result=result, flag=self.u32(0x44d030), cleared=self.u32(0x450b74), pointer=self.u32(POINTER),
                    events=self.log, recordingSHA256=digest(recording) if recording else None, live=sorted(self.loader_allocations.values()),
                    overflowBytes=len(self.overflow))


def cases():
    inputs = ROOT / 'build/research/playback/inputs'
    g = (ROOT / 'native/Sources/NTSDCore/Resources/OriginalStartup/initial.bin').read_bytes()
    o = KEY - 0x44d000; key = g[o:g.index(b'\0', o)]
    out = []
    for name in ('vs', 'war', 'mission'):
        data = (inputs / f'{name}.lfr').read_bytes()
        out.append((name, data, key))
        n = struct.unpack_from('<I', data)[0]
        out.append((name + '-other-key', data, b'2' + key[1:]))
        out.append((name + '-empty-key', data, b''))
        out.append((name + '-truncated', data[:len(data) // 2], key))
        corrupt = bytearray(data); corrupt[4 + n // 2] ^= 0x5a
        out.append((name + '-corrupt', bytes(corrupt), key))
        out.append((name + '-short-length', struct.pack('<I', n - 100) + data[4:], key))
        out.append((name + '-long-length', struct.pack('<I', n + 5000) + data[4:], key))
        out.append((name + '-trailing', data + b'\x01' * 300, key))
    out.append(('missing', None, key))
    out.append(('tiny', b'\x10\x00\x00\x00' + b'\0' * 995, key))
    out.append(('zero-length', b'\0\0\0\0' + b'\x33' * 1200, key))
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--limit', type=int); a = p.parse_args()
    results = []
    for label, data, key in cases()[:a.limit]:
        vm = ReplayLoader(data)
        r = vm.load(key)
        r.update(label=label, fileSHA256=digest(data) if data is not None else None, fileBytes=len(data) if data is not None else None,
                 keySHA256=digest(key), keyLength=len(key))
        results.append(r); print(label, r['result'], [e['kind'] for e in r['events']], flush=True)
    doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, cases=results)
    (ROOT / 'build/research/playback/loader.json').write_text(json.dumps(doc, indent=1) + '\n')
    # Self-contained Native fixture: base recordings, the key and each case's
    # declared variant with the original's observable result.
    import base64
    inputs = ROOT / 'build/research/playback/inputs'
    fixture = dict(exeSHA256=EXE_SHA256, scope=__doc__,
                   recordings={n: base64.b64encode((inputs / f'{n}.lfr').read_bytes()).decode() for n in ('vs', 'war', 'mission')},
                   cases=[dict(label=r['label'], fileSHA256=r['fileSHA256'], keySHA256=r['keySHA256'], result=r['result'],
                               flag=r['flag'], cleared=r['cleared'], pointer=r['pointer'], recordingSHA256=r['recordingSHA256'],
                               allocations=[[e['ordinal'], e['count']] for e in r['events'] if e['kind'] == 'allocate'],
                               frees=[e['ordinal'] for e in r['events'] if e['kind'] == 'free'],
                               closed=any(e['kind'] == '_close' for e in r['events']), live=r['live'], overflowBytes=r['overflowBytes'])
                          for r in results])
    (ROOT / 'native/Tests/NTSDCoreTests/Fixtures/original-replay-loader.json').write_text(json.dumps(fixture) + '\n')
    (ROOT / 'docs/evidence/playback-loader.json').write_text(json.dumps(dict(exeSHA256=EXE_SHA256, scope=__doc__,
        cases=[{k: v for k, v in r.items() if k != 'events'} | dict(events=len(r['events'])) for r in results]), indent=1) + '\n')


if __name__ == '__main__':
    main()
