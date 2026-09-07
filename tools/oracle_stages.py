#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute original Stage loader 40c910 and explicit-destination decoder 414a30.

Full 60-slot storage and byte provenance are retained losslessly with raw DEFLATE
and SHA-256; no projection onto a guessed spawn struct. CRT/stdio remain explicit
boundaries shared with the Object harness. Original assets are never modified.
"""
import argparse
import base64
import hashlib
import json
import struct
import subprocess
import zlib

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from oracle_objects import Objects, STUB
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

CATALOG, TABLE_OFFSET, STAGE_SIZE, PHASE_SIZE = 0x26000000, 0x7D0, 0x149B08, 0x34C0
TABLE_SIZE = STAGE_SIZE*60
PROBE = b'''ignored <stage> id: 59
<phase> music: long_music_name.ogg x: -31 hp: -17 ratio: -0.0
bound: 2147483647
id: -2147483648 x: 99 hp: -3 times: 4 reserve: 5 join: 6 join_reserve: 7 y: -8 act: 9 ratio: .125
<boss> <soldier> times: 13 <boss>
id: nope hp: 444
id: 2147483647 ratio: 4:0 reserve: nope
bound: -50 when_clear_goto_phase: 99 music: X
<phase_end>
<phase> id: 33 x: 123 bound: 800 id: 44 x: -17 ratio: 1e-3 <soldier> <phase_end>
<stage_end>
<stage> id: 0 <phase> id: 7 hp: 42 <phase_end> id: nope <phase> id: 8 <boss> <phase_end> <stage_end>
<end>\n'''
RELOAD = b'<stage> id: 59 <phase> id: 123 ratio: -0 <phase_end> <stage_end>\n'


def encoded(payload):
    """Synthetic encrypted control at the input boundary; decoded result checked independently."""
    key = b'SiuHungIsAGoodBearBecauseHeIsVeryGood'
    return b'H'*123 + bytes((v + key[(i + 123) % len(key)]) & 255 for i, v in enumerate(payload))


def limits():
    phases = [b'<phase> <phase_end>']*99
    entries = b' '.join(b'id: ' + str(i - 30).encode() + b' hp: ' + str(i).encode() for i in range(60))
    phases.append(b'<phase> bound: 2147483647 bound: nope ' + entries + b' when_clear_goto_phase: -7 <phase_end>')
    return b'<stage> id: 59 ' + b' '.join(phases) + b' <stage_end>\n<end>'


class Stages(Objects):
    def __init__(self, text_mode=True, pattern=0xA5):
        super().__init__(text_mode=text_mode, pattern=pattern)
        start = CATALOG + TABLE_OFFSET
        self.uc.mem_map(CATALOG, ((TABLE_OFFSET + TABLE_SIZE + 16 + 4095)//4096)*4096)
        raw = bytes([pattern])*TABLE_SIZE if pattern is not None else (bytes(range(256))*(TABLE_SIZE//256 + 1))[:TABLE_SIZE]
        self.table = dict(address=start, size=TABLE_SIZE, kind='stage-table', initial=raw, mask=bytearray(TABLE_SIZE))
        self.regions.append(self.table)
        self.uc.mem_write(start - 16, b'\x96'*16 + raw + b'\x69'*16)
        self.blobs, self.stage_accesses, self.stage_reads = {}, {}, set()
        self.current_stage = None
        self.checkpoints, self.stage_ids, self.phase_ids = [], [], []
        for mode, callback in [(UC_HOOK_MEM_READ, self.read_stage), (UC_HOOK_MEM_WRITE, self.write_stage)]:
            self.uc.hook_add(mode, callback, begin=CATALOG, end=CATALOG + TABLE_OFFSET + TABLE_SIZE + 15)
        for address in (0x40C957, 0x40C9F5, 0x40CB83, 0x40CBD8, 0x40D022):
            self.uc.hook_add(UC_HOOK_CODE, self.stage_checkpoint, begin=address, end=address)
        # No game child other than 414a30 is called; original code stays within
        # these intervals. A block hook avoids per-instruction Python overhead.
        from unicorn import UC_HOOK_BLOCK
        self.uc.hook_add(UC_HOOK_BLOCK, self.allowed_block)

    def allowed_block(self, uc, address, size, data):
        assert (0x40C910 <= address <= 0x40D09D or 0x414A30 <= address <= 0x414B6F
                or 0x4450B2 <= address <= 0x4450BA or STUB <= address < STUB + 0x400), hex(address)

    def access(self, mode, address, size, pc):
        offset = address - self.table['address']
        assert 0 <= offset and offset + size <= TABLE_SIZE, ('Stage table escape', hex(address), hex(pc))
        stage, local = divmod(offset, STAGE_SIZE)
        assert local + size <= STAGE_SIZE
        item = self.stage_accesses.setdefault((mode, size, pc), dict(stages=set(), offsets=set(), count=0))
        item['stages'].add(stage); item['offsets'].add(local); item['count'] += 1
        return offset

    def write_stage(self, uc, access, address, size, value, data):
        offset = self.access('write', address, size, uc.reg_read(UC_X86_REG_EIP))
        self.table['mask'][offset:offset + size] = b'\1'*size

    def read_stage(self, uc, access, address, size, value, data):
        offset = self.access('read', address, size, uc.reg_read(UC_X86_REG_EIP))
        if not all(self.table['mask'][offset:offset + size]):
            self.stage_reads.add((offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def write_host(self, address, raw):
        if CATALOG <= address < CATALOG + TABLE_OFFSET + TABLE_SIZE:
            self.write_stage(self.uc, 0, address, len(raw), 0, None)
            self.uc.mem_write(address, raw)
        else:
            super().write_host(address, raw)

    def imported(self, uc, address, size, data):
        if self.lookup.get(address) == 'fscanf':
            sp = uc.reg_read(UC_X86_REG_ESP)
            if self.cstr(self.u32(sp + 8)) == b'%s':
                caller = self.u32(sp)
                assert caller in (0x40C995, 0x40C9C5, 0x40CBF9, 0x40CD05)
                h = self.handles[self.u32(sp + 4)]
                tokens = h['data'][h['pos']:].split()
                limit = 224 if caller == 0x40CD05 else 192  # bounded scratch limit; cookie is at +f4
                if tokens:
                    assert len(tokens[0]) < limit
        super().imported(uc, address, size, data)

    def blob(self, raw):
        raw = bytes(raw)
        digest = hashlib.sha256(raw).hexdigest()
        if digest not in self.blobs:
            compressed = zlib.compress(raw, level=9, wbits=-15)
            assert zlib.decompress(compressed, wbits=-15) == raw
            self.blobs[digest] = dict(count=len(raw), deflate=base64.b64encode(compressed).decode())
        return digest

    def record(self, stage):
        offset = stage*STAGE_SIZE
        raw = bytes(self.uc.mem_read(self.table['address'] + offset, STAGE_SIZE))
        mask = self.table['mask'][offset:offset + STAGE_SIZE]
        # Efficient whole-byte invariant, including allocator contents under false flags.
        for i in range(STAGE_SIZE):
            if not mask[i] and raw[i] != self.table['initial'][offset + i]:
                raise AssertionError(('Untracked write', stage, i))
        return dict(bytes=self.blob(raw), defined=self.blob(mask))

    def stage_checkpoint(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x40C957:
            self.decoded = next(h['data'] for h in list(self.handles.values())[::-1] if h['mode'] == b'r')
        elif address == 0x40C9F5:
            self.current_stage = self.u32(sp + 0x1C)
            assert self.current_stage < 60
            self.stage_ids.append(self.current_stage)
            self.initializing = True
        elif address == 0x40CB83 and self.initializing:
            self.checkpoints.append(dict(kind='initialized', stage=self.current_stage, phase=None, record=self.record(self.current_stage)))
            self.initializing = False
        elif address == 0x40CBD8:
            phase = self.u32(sp + 0x18)//PHASE_SIZE
            assert phase < 100
            self.phase_ids.append([self.current_stage, phase])
        elif address == 0x40D022:
            phase = self.u32(sp + 0x18)//PHASE_SIZE
            self.checkpoints.append(dict(kind='phase', stage=self.current_stage, phase=phase, record=self.record(self.current_stage)))

    def run(self, name, source):
        self.files[b'data\\stage.dat'] = source
        self.current_stage, self.initializing = None, False
        self.checkpoints, self.stage_ids, self.phase_ids = [], [], []
        start_s, start_e = len(self.scans), len(self.events)
        before_checksum = self.u32(0x44F620)
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack('<I', STOP))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, CATALOG)
        self.uc.emu_start(0x40C910, STOP, timeout=180_000_000, count=50_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP, ('Stage limit', hex(self.uc.reg_read(UC_X86_REG_EIP)))
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 4
        assert all(h['closed'] for h in self.handles.values())
        assert self.files[b'data\\temporary.txt'] == b'Do not erase this file.'
        assert self.uc.mem_read(self.table['address'] - 16, 16) == b'\x96'*16
        assert self.uc.mem_read(self.table['address'] + TABLE_SIZE, 16) == b'\x69'*16
        assert self.u32(0x44F620) == before_checksum
        result = dict(name=name, source=source.hex(), sourceSHA256=hashlib.sha256(source).hexdigest(), decoded=self.decoded.hex(),
                      initialChecksum=before_checksum, checksum=self.u32(0x44F620), stageIDs=self.stage_ids, phaseIDs=self.phase_ids,
                      checkpoints=self.checkpoints, records=[self.record(i) for i in range(60)],
                      scans=self.scans[start_s:], events=self.events[start_e:])
        print(f"{name}: {len(self.stage_ids)} stage initializations, {len(self.phase_ids)} phases, {len(self.checkpoints)} checkpoints, complete 60-slot table retained", flush=True)
        return result


def capture(name):
    vm = Stages(text_mode=name != 'baseline-raw-zero', pattern=0 if name.endswith('zero') else (None if name == 'controls' else 0xA5))
    vm.put(0x44F620, 0xFFFF1234)
    initial = [vm.record(i) for i in range(60)]
    if name.startswith('baseline'):
        inputs = [('original-stage.dat', read_bytes(DEFAULT_SOURCE/'data/stage.dat'))]
    else:
        inputs = [('control-fields-order', encoded(PROBE)), ('control-reload', encoded(RELOAD)),
                  ('control-100-phases-60-entries', encoded(limits())), ('control-empty-reset', encoded(b'<end>\n'))]
    cases = [vm.run(n, s) for n, s in inputs]
    accesses = [dict(mode=m, size=n, instruction=hex(pc), stages=sorted(d['stages']), offsets=sorted(d['offsets']), count=d['count'])
                for (m, n, pc), d in sorted(vm.stage_accesses.items())]
    doc = dict(exeSHA256=EXE_SHA256, name=name, translation='text' if vm.text_mode else 'raw',
               scope='Complete 40c910/414a30 instructions, C-locale in-range integers and supplied finite-decimal binary64, explicit text/raw stdio; no stage gameplay, actual MSVCR80 or Windows capture',
               initialRecords=initial, cases=cases, blobs=vm.blobs, accesses=accesses,
               readsBeforeWrites=[dict(offset=o, size=n, instruction=hex(pc)) for o, n, pc in sorted(vm.stage_reads)])
    assert not doc['readsBeforeWrites'], doc['readsBeforeWrites'][:20]
    output = ROOT/'build/original'/('stages-' + name + '.json')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    print(f"Unaccepted Stage corpus: {output}, {len(vm.blobs)} lossless blobs", flush=True)
    return doc, output


def compact(doc):
    return {**{k: v for k, v in doc.items() if k not in ('accesses', 'readsBeforeWrites', 'cases')},
            'cases': [{k: v for k, v in c.items() if k not in ('scans', 'events')} for c in doc['cases']]}


def compact_accesses(items):
    """Lossless arithmetic runs for repeated local offsets, verified by expansion."""
    result = []
    for item in items:
        offsets, runs, index = item['offsets'], [], 0
        while index < len(offsets):
            step = offsets[index + 1] - offsets[index] if index + 1 < len(offsets) else 0
            end = index + 1
            while end < len(offsets) and offsets[end] == offsets[index] + (end - index)*step:
                end += 1
            runs.append([offsets[index], step, end - index])
            index = end
        assert [start + i*step for start, step, count in runs for i in range(count)] == offsets
        result.append({k: v for k, v in item.items() if k != 'offsets'} | dict(offsetRuns=runs))
    return result


def accept(captured):
    subprocess.run(['swift', 'build', '--package-path', str(ROOT/'native'), '-c', 'release', '--product', 'NTSDStageCheck'], check=True)
    checks, summaries = [], []
    for doc, output in captured:
        check = compact(doc)
        path = output.with_stem(output.stem + '-check')
        path.write_text(json.dumps(check, separators=(',', ':')) + '\n')
        subprocess.run([str(ROOT/'native/.build/release/NTSDStageCheck'), str(path)], check=True)
        checks.append(check)
        summaries.append(dict(name=doc['name'], corpus=output.name, corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                              comparisonSHA256=hashlib.sha256(path.read_bytes()).hexdigest(), translation=doc['translation'],
                              readsBeforeWrites=doc['readsBeforeWrites'], cases=[dict(name=c['name'], sourceSHA256=c['sourceSHA256'],
                              decodedSHA256=hashlib.sha256(bytes.fromhex(c['decoded'])).hexdigest(), stageIDs=c['stageIDs'], phases=len(c['phaseIDs']),
                              checkpoints=len(c['checkpoints']), recordBytes=(60 + len(c['checkpoints']))*STAGE_SIZE, checksum=c['checksum']) for c in doc['cases']]))
    fixture = ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-stages.json'
    fixture.write_text(json.dumps(dict(corpora=checks), separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=captured[0][0]['scope'],
                  nativeScope='All bytes/masks of all 60 stages at EOF and the entire selected stage after every stage initializer/phase; complete decoder bytes and unchanged shared checksum. Lossless raw DEFLATE with per-blob SHA-256.',
                  fixtureSHA256=hashlib.sha256(fixture.read_bytes()).hexdigest(), corpora=summaries,
                  accessScope='Instruction-grouped stage IDs and local offsets are marginal sets, not their Cartesian product; full original snapshots retained.',
                  accesses=compact_accesses(captured[0][0]['accesses']))
    (ROOT/'docs/evidence/stage-loader.json').write_text(json.dumps(report, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='store_true')
    parser.add_argument('--controls', action='store_true')
    args = parser.parse_args()
    captured = [capture(n) for n in (['baseline', 'baseline-raw-zero', 'controls'] if args.suite else ['controls' if args.controls else 'baseline'])]
    if not args.suite:
        return
    accept(captured)


if __name__ == '__main__':
    main()
