#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real43dfa0(0x451160, World+4, World+0x194, catalog) — the playback start —
called directly after the verified first loading, with 4588ac pointing at a
decompressed recording written by the app (VS, War, Mission Stage 1) or a
declared variant (absent Object IDs, arena 99, mode changes, empty seats,
other RNG/War fields). Callees 40c0e0 (release a background's layers),
40c030 (load a background's layers) and 4025b0 (play 44eed0) are recorded
boundaries; the Actor constructor 4061d0 and memset execute. Globals, the
recording buffer, World and every Actor are compared. Main CW027f; control
CW037f over the control loading. APPLICATION_PLAYBACK_PLAN.md P2.
"""
import argparse, json, random, struct, zlib
from import_ntsd import EXE_SHA256, ROOT
from oracle_initial_loading import transport
from oracle_object_input import ObjectInput
from oracle_catalog_sounds import REGISTERS
from oracle_state import STACK, STOP
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

BODIES = [(0x43DFA0, 0x43E61B)]
ALLOWED = BODIES + [(0x4061D0, 0x4064CD), (0x4450A0, 0x4450A1)]
BOUNDARIES = {0x40C0E0: ('releaseLayers', 1, 4, True), 0x40C030: ('loadLayers', 1, 4, True), 0x4025B0: ('playMusic', 0, 0, False)}
RECORDING, SIZE = 0x52000000, 0x630E18


class ReplayPlayback(ObjectInput):
    def __init__(self, control=False):
        super().__init__(control)
        self.calls = []
        self.written = set()
        # First free 16 MB-aligned region for the recording buffer.
        global RECORDING
        taken = list(self.uc.mem_regions())
        RECORDING = next(b for b in range(0x40000000, 0xF0000000, 0x1000000)
                         if all(b + 0x700000 <= lo or b > hi for lo, hi, _ in taken))
        self.uc.mem_map(RECORDING, 0x700000)
        for pc in BOUNDARIES:
            self.uc.hook_add(UC_HOOK_CODE, self.boundary, begin=pc, end=pc)

    def block(self, uc, address, size, data):
        if not self.running:
            return
        assert any(a <= address < b for a, b in ALLOWED) or address in BOUNDARIES or address == STOP, hex(address)
        if any(a <= address < b for a, b in BODIES):
            self.blocks.add(address)

    def boundary(self, uc, address, size, data):
        if not self.running:
            return
        kind, count, pop, this = BOUNDARIES[address]
        sp = uc.reg_read(UC_X86_REG_ESP)
        call = dict(kind=kind, caller=self.u32(sp), arguments=[self.u32(sp + 4 + 4 * i) for i in range(count)])
        if this:
            call['this'] = uc.reg_read(UC_X86_REG_ECX)
        if kind == 'playMusic':
            call['path'] = self.cstr(0x44EED0).hex()
        self.calls.append(call)
        self.ret(0, pop)

    def track(self, uc, access, address, size, value, data):
        if self.running:
            self.written.update(range(address, address + size))

    @staticmethod
    def runs(addresses):
        out, run = [], None
        for a in sorted(addresses):
            if run is not None and run[1] == a:
                run[1] = a + 1
            else:
                if run is not None:
                    out.append(tuple(run))
                run = [a, a + 1]
        if run is not None:
            out.append(tuple(run))
        return out

    def call_playback(self, label, recording, stimulus, cw):
        for item in stimulus['globals']:
            self.uc.mem_write(item['address'], bytes.fromhex(item['bytes']))
        # Plain backing: the recording is wholly defined; 4588ac is a global.
        self.uc.mem_write(RECORDING, recording)
        self.uc.mem_write(0x4588AC, struct.pack('<I', RECORDING))
        before_actors = [self.raw(r) for r in self.pool]
        before_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        constructors_before = len(self.actor_calls)
        self.calls = []; self.written = set()
        sp = STACK + 0xD000
        catalog = self.u32(self.world_address + 0x7D4)
        self.uc.mem_write(sp, struct.pack('<IIIII', STOP, 0x451160, self.world_address + 4, self.world_address + 0x194, catalog))
        saved = [0x11111111, 0x22222222, 0x33333333, 0x44444444]
        for reg, value in zip(REGISTERS, saved):
            self.uc.reg_write(reg, value)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_FPCW, cw)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xFFFF)
        top = (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7
        self.running = True
        try:
            self.execute(0x43DFA0, STOP)
        finally:
            self.running = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 4, label
        assert [self.uc.reg_read(r) for r in REGISTERS] == saved, label
        fpu = [top, (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7, 0xFFFF, self.uc.reg_read(UC_X86_REG_FPTAG)]
        assert fpu[0] == fpu[1] and fpu[3] == 0xFFFF, (label, fpu)
        undefined = sorted([list(r) for r in self.reads_before_writes])
        self.reads_before_writes.clear()
        actors = {}
        for i, r in enumerate(self.pool):
            if self.raw(r) != before_actors[i]:
                actors[str(i)] = {k: v for k, v in self.record(r).items() if k != 'initial'}
        world = {k: v for k, v in self.record(self.world).items() if k != 'initial'}
        global_writes = [dict(address=a, bytes=bytes(self.uc.mem_read(a, b - a)).hex())
                         for a, b in self.runs(x for x in self.written if GLOBAL <= x < GLOBAL + GLOBAL_SIZE)]
        saved_writes = [dict(offset=a - 0x458588, bytes=bytes(self.uc.mem_read(a, b - a)).hex())
                        for a, b in self.runs(x for x in self.written if 0x458588 <= x < 0x4588A8)]
        recording_writes = [dict(offset=a - RECORDING, bytes=bytes(self.uc.mem_read(a, b - a)).hex())
                            for a, b in self.runs(x for x in self.written if RECORDING <= x < RECORDING + SIZE)]
        return dict(label=label, controlWord=cw, stimulus=stimulus, calls=self.calls, globalWrites=global_writes,
                    recordingWrites=recording_writes, savedWrites=saved_writes, constructors=self.actor_calls[constructors_before:],
                    undefinedReads=undefined, fpu=fpu, world=world, actors=actors)

    def capture_inputs(self):
        parents = self.parents()
        print('Verified parent reproduced', flush=True)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=GLOBAL, end=GLOBAL + GLOBAL_SIZE - 1)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=RECORDING, end=RECORDING + SIZE - 1)
        # The playback backups 458588..4588a8 lie past the tracked globals.
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=0x458588, end=0x4588A7)
        R = random.Random(0x43DFA0 + int(self.control))
        cw = 0x37F if self.control else 0x27F
        g = (ROOT / 'native/Sources/NTSDCore/Resources/OriginalStartup/initial.bin').read_bytes()
        key = g[0x7A0:g.index(b'\0', 0x7A0)]
        bases = {}
        for name in ('vs', 'war', 'mission'):
            data = (ROOT / f'build/research/playback/inputs/{name}.lfr').read_bytes()
            n = struct.unpack_from('<I', data)[0]; p = bytearray(data[4:4 + n])
            for i in range(min(n, len(key))): p[i] = (p[i] - key[i] + 0x30) & 255
            bases[name] = zlib.decompress(bytes(p)); assert len(bases[name]) == SIZE
        cases = []

        def g32(address, value):
            return dict(address=address, bytes=struct.pack('<i', value).hex())

        def variant(name, kind):
            rec = bytearray(bases[name]); edits = []
            def put(offset, value):
                struct.pack_into('<i', rec, offset, value); edits.append([offset, value])
            if kind == 'absent':
                for seat in R.sample(range(18), 4): put(0x1F0 + 4 * seat, R.choice([9999, -1, 0]))
            elif kind == 'arena':
                put(0x1A4, R.choice([99, 0, 5, 16]))
            elif kind == 'mode':
                put(0x148, R.choice([0, 1, 4, 5]))
            elif kind == 'seats':
                for seat in range(18): put(0x238 + 4 * seat, R.choice([0, 0, 1, 1, 0x101, 2]))
            elif kind == 'fields':
                for seat in R.sample(range(18), 6):
                    for off in (0x280, 0x2C8, 0x310, 0x358, 0x3A0, 0x3E8, 0x430, 0x478, 0x4C0, 0x508, 0x1A8):
                        put(off + 4 * seat, R.randrange(-2000, 2000))
            elif kind == 'war':
                for k in range(88): put(0x74C + 4 * k, R.randrange(-5, 60))
                put(0x8C4, R.randrange(3000))
            return bytes(rec), edits

        plan = [(n, k) for n in ('vs', 'war', 'mission') for k in ('base', 'absent', 'arena', 'mode', 'seats', 'fields', 'war') for _ in range(4)]
        for index, (name, kind) in enumerate(plan):
            rec, edits = variant(name, kind)
            glob = [g32(0x450C30, R.choice([-1, 0, 1, 2])), g32(0x458428, R.choice([0, 1])), g32(0x45842C, R.choice([0, 1]))]
            stimulus = dict(recording=name, edits=edits, globals=glob)
            cases.append(self.call_playback(f'{name}-{kind}-{index}', rec, stimulus, cw))
            print('case', index, name, kind, len(cases[-1]['calls']), len(cases[-1]['constructors']), flush=True)
        doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, parents=parents, worldAddress=self.world_address,
                   catalogAddress=self.u32(self.world_address + 0x7D4), objectAddresses=self.object_addresses,
                   actorAddresses=[r['address'] for r in self.pool], controlWord=cw, blocks=sorted(self.blocks),
                   recordingAddress=RECORDING, cases=cases)
        return transport(doc, self.blobs)


def main():
    from oracle_wave_loader import digest
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--control', action='store_true')
    args = p.parse_args()
    vm = ReplayPlayback(args.control)
    doc = vm.capture_inputs()
    suffix = '-control' if args.control else ''
    path = ROOT / 'build/original' / f'replay-playback{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(path.read_bytes()),
                  cases=len(doc['cases']), blocks=len(doc['blocks']), nativeComparison='pending')
    (ROOT / 'docs/evidence' / f'replay-playback{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Captured', len(doc['cases']), 'playback start cases', flush=True)


if __name__ == '__main__':
    main()
