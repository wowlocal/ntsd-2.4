#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real437860(World; target, 0x44d020) — the Mission Mode stage logic with its
own helpers 437400 (phase spawn) and 436fc0 (next stage) — called directly
after the verified first loading, on the loaded catalog's real stage records.
Stimuli declare stage/phase/banner/wipe/end globals, spawn-slot runtime words
of the current phase, players (seats 0..19) and listed enemies bound to real
Objects. The already accepted callees 43f010 (bitmap draw), 415160 (fill),
401290 (surface text), 401a30 (sound), 402020 (music) and 402100 (music stop)
are recorded boundaries (arguments, text, return with their stack cleanup);
sprintf executes the pinned VC80 DLL. RNG 417170, the Actor constructor 4061d0
(memset boundary) and ftol 4450d0 execute. Main corpus CW027f; control CW037f
over the control loading.
"""
import argparse
import json
import random
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_initial_loading import transport
from oracle_object_input import ObjectInput
from oracle_catalog_sounds import pack, REGISTERS
from oracle_crt import CRT
from oracle_state import STACK, STOP
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

BODIES = [(0x437860, 0x43899E), (0x437400, 0x437856), (0x436FC0, 0x437213)]
ALLOWED = BODIES + [(0x417170, 0x4171BD), (0x4061D0, 0x4064CD), (0x4450D0, 0x44517B), (0x4450A0, 0x4450A1)]
# entry: (kind, stack arguments, callee-popped bytes, records ECX)
BOUNDARIES = {0x43F010: ('bitmapDraw', 6, 0x18, True), 0x415160: ('fill', 5, 0, False), 0x401290: ('text', 6, 0, False),
              0x401A30: ('sound', 1, 4, True), 0x402020: ('music', 1, 0, False), 0x402100: ('musicStop', 0, 0, False)}
STAGE_BASE, STAGE_SIZE, PHASE_STRIDE, SLOT_STRIDE = 0x7D0, 0x149B08, 0x34C0, 0xE0
FORMATS = (b'STAGE %d-%d', b'Survival Stage: %d', b'Man: %3d      HP: %4d', b'Man: %3d      HP: %4d     Reserve: %3d')


class MissionStage(ObjectInput):
    def __init__(self, control=False):
        super().__init__(control)
        self.crt = CRT()
        self.calls = []
        self.written = set()
        for pc in BOUNDARIES:
            self.uc.hook_add(UC_HOOK_CODE, self.boundary, begin=pc, end=pc)

    def block(self, uc, address, size, data):
        if not self.running:
            return
        assert any(a <= address < b for a, b in ALLOWED) or address in BOUNDARIES or address == STOP \
            or self.lookup.get(address) == 'sprintf', hex(address)
        if any(a <= address < b for a, b in BODIES):
            self.blocks.add(address)

    def boundary(self, uc, address, size, data):
        if not self.running:
            return
        kind, count, pop, this = BOUNDARIES[address]
        sp = uc.reg_read(UC_X86_REG_ESP)
        args = [self.u32(sp + 4 + 4 * i) for i in range(count)]
        call = dict(kind=kind, caller=self.u32(sp), arguments=args)
        if this:
            call['this'] = uc.reg_read(UC_X86_REG_ECX)
        if kind == 'text':
            call['text'] = self.cstr(args[1]).hex()
        if kind == 'music':
            call['path'] = self.cstr(args[0]).hex()
        self.calls.append(call)
        self.ret(0, pop)

    def imported(self, uc, address, size, data):
        if self.running and self.lookup.get(address) == 'sprintf':
            sp = uc.reg_read(UC_X86_REG_ESP)
            fmt = self.cstr(self.u32(sp + 8))
            assert fmt in FORMATS, fmt
            values = [self.u32(sp + 12 + 4 * i) for i in range(fmt.count(b'%'))]
            result = self.crt.format(fmt, values)
            raw = bytes.fromhex(result['bytes'])
            self.write_host(self.u32(sp + 4), raw)
            self.written.update(range(self.u32(sp + 4), self.u32(sp + 4) + len(raw)))
            self.calls.append(dict(kind='format', caller=self.u32(sp), arguments=[self.u32(sp + 4)] + values,
                                   format=fmt.hex(), text=raw[:-1].hex()))
            self.ret(result['result'])
            return
        super().imported(uc, address, size, data)

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

    def stage_address(self, s):
        return self.u32(self.world_address + 0x7D4) + STAGE_BASE + s * STAGE_SIZE

    def call_stage(self, label, stimulus, cw):
        for item in stimulus['globals']:
            self.uc.mem_write(item['address'], bytes.fromhex(item['bytes']))
        for item in stimulus['catalog']:
            self.write_host(self.stage_address(item['stage']) + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['world']:
            self.write_host(self.world_address + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['actors']:
            self.write_host(self.pool[item['slot']]['address'] + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['bindings']:
            target = self.pool[item['slot']]['address']
            self.write_host(target + 0x368, struct.pack('<I', self.object_addresses[item['object']]))
            self.write_host(target + 0x70, struct.pack('<I', item['frame']))
        s = self.s32(0x450B94)
        stages = [k for k in (s, s + 1) if 0 <= k < 60]
        before_stages = {k: bytes(self.uc.mem_read(self.stage_address(k), STAGE_SIZE)) for k in stages}
        before_actors = [self.raw(r) for r in self.pool]
        before_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        constructors_before = len(self.actor_calls)
        self.random, self.calls = [], []
        self.written = set()
        sp = STACK + 0xD000
        self.uc.mem_write(sp, struct.pack('<III', STOP, stimulus['target'], 0x44D020))
        saved = [0x11111111, 0x22222222, 0x33333333, 0x44444444]
        for reg, value in zip(REGISTERS, saved):
            self.uc.reg_write(reg, value)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, self.world_address)
        self.uc.reg_write(UC_X86_REG_FPCW, cw)
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xFFFF)
        top = (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7
        self.running = True
        try:
            self.execute(0x437860, STOP)
        finally:
            self.running = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 12, label
        assert [self.uc.reg_read(r) for r in REGISTERS] == saved, label
        fpu = [top, (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7, 0xFFFF, self.uc.reg_read(UC_X86_REG_FPTAG)]
        assert fpu[0] == fpu[1] and fpu[3] == 0xFFFF, (label, fpu)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == cw, label
        undefined = sorted([list(r) for r in self.reads_before_writes])
        self.reads_before_writes.clear()
        after_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        changed = sorted({GLOBAL + (i & ~3) for i in range(GLOBAL_SIZE) if after_globals[i] != before_globals[i]})
        globals_after = {hex(w): after_globals[w - GLOBAL:w - GLOBAL + 4].hex() for w in changed}
        catalog = []
        for k, raw in before_stages.items():
            now = bytes(self.uc.mem_read(self.stage_address(k), STAGE_SIZE))
            if now == raw:
                continue
            run = None
            for block in range(0, STAGE_SIZE, 4096):
                if now[block:block + 4096] == raw[block:block + 4096]:
                    continue
                for i in range(block, min(block + 4096, STAGE_SIZE)):
                    if now[i] != raw[i]:
                        if run is not None and run[1] == i:
                            run[1] = i + 1
                        else:
                            if run is not None:
                                catalog.append(dict(stage=k, offset=run[0], bytes=now[run[0]:run[1]].hex()))
                            run = [i, i + 1]
            if run is not None:
                catalog.append(dict(stage=k, offset=run[0], bytes=now[run[0]:run[1]].hex()))
        actors = {}
        for i, r in enumerate(self.pool):
            if self.raw(r) != before_actors[i]:
                actors[str(i)] = {k: v for k, v in self.record(r).items() if k != 'initial'}
        world = {k: v for k, v in self.record(self.world).items() if k != 'initial'}
        table = self.stage_address(0)
        global_writes, stage_writes = [], []
        for a, b in self.runs(x for x in self.written if GLOBAL <= x < GLOBAL + GLOBAL_SIZE):
            global_writes.append(dict(address=a, bytes=bytes(self.uc.mem_read(a, b - a)).hex()))
        for a, b in self.runs(x for x in self.written if table <= x < table + 60 * STAGE_SIZE):
            k, offset = divmod(a - table, STAGE_SIZE)
            assert (b - 1 - table) // STAGE_SIZE == k, label
            stage_writes.append(dict(stage=k, offset=offset, bytes=bytes(self.uc.mem_read(a, b - a)).hex()))
        return dict(label=label, controlWord=cw, stimulus=stimulus, random=self.random, calls=self.calls,
                    globalWrites=global_writes, stageWrites=stage_writes,
                    constructors=self.actor_calls[constructors_before:], undefinedReads=undefined, fpu=fpu,
                    globals=globals_after, catalog=catalog, world=world, actors=actors)

    def capture_inputs(self):
        parents = self.parents()
        print('Verified parent reproduced', flush=True)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=GLOBAL, end=GLOBAL + GLOBAL_SIZE - 1)
        table = self.stage_address(0)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=table, end=table + 60 * STAGE_SIZE - 1)
        R = random.Random(0x437860 + int(self.control))
        cw = 0x37F if self.control else 0x27F
        objects = []
        for n, a in enumerate(self.object_addresses):
            objects.append(dict(ordinal=n, type=self.s32(a + 0x6F8), id=self.s32(a + 0x6F4)))
        characters = [o for o in objects if o['type'] == 0]
        heavy = [o for o in characters if o['id'] in (0x33, 0x34)]
        others = [o for o in objects if o['type'] != 0]
        assert characters and others
        stages = []
        for s in range(60):
            base = self.stage_address(s)
            count = self.s32(base)
            if count <= 0:
                continue
            phases = []
            for p in range(min(count, 100)):
                slots = [k for k in range(60) if self.s32(base + 0x40 + p * PHASE_STRIDE + k * SLOT_STRIDE + 0xAC) != -1]
                phases.append(slots)
            stages.append(dict(stage=s, count=count, phases=phases))
        assert stages
        print('stages', [(x['stage'], x['count']) for x in stages], flush=True)
        cases = []

        def i32(value):
            return struct.pack('<i', value).hex()

        def g(address, value):
            return dict(address=address, bytes=struct.pack('<i', value).hex())

        def survival(family):
            s = R.randrange(50, 60)
            glob = [g(0x450B94, s), g(0x44FB6C, -1), g(0x450C30, R.choice([-1, 0, 1, 2])), g(0x450BA8, 0),
                    g(0x450BAC, 0), g(0x451B34, R.choice([0, 1])), g(0x450B9C, 0), g(0x450BA4, 0), g(0x450BDC, 0),
                    g(0x450BA0, R.choice([0, 0, 1, 9, 10, 19, 20, 35, 68, 69, 70])), g(0x44F880, R.choice([-1, 0, 3, 12])),
                    g(0x44D024, R.randrange(17)), g(0x44D020, 10)]
            catalog, writes, bindings, activity = [], [], {}, [0] * 400
            if family == 'refill':
                # Declared synthetic survival stage: one phase, bound 1000, one spawn slot of a real record.
                src = R.choice(stages)
                slot = src['phases'][0][0]
                raw = bytes(self.uc.mem_read(self.stage_address(src['stage']) + 0x40 + slot * SLOT_STRIDE + 0xAC, 0x34))
                catalog += [dict(stage=s, offset=0, bytes=i32(1)), dict(stage=s, offset=8, bytes=i32(1000)),
                            dict(stage=s, offset=PHASE_STRIDE + 8, bytes=i32(R.choice([1000, 1400]))),
                            dict(stage=s, offset=0xC, bytes='00'), dict(stage=s, offset=PHASE_STRIDE, bytes=i32(-1)),
                            dict(stage=s, offset=0x40 + 0xAC, bytes=raw.hex())]
                catalog += [dict(stage=s, offset=0x40 + k * SLOT_STRIDE + 0xAC, bytes=i32(-1)) for k in range(1, 60)]
            for k in R.sample(range(20), R.choice([1, 2, 4])):
                bindings[k] = (R.choice(characters)['ordinal'], 0)
                activity[k] = 1
                writes += [dict(slot=k, offset=0x2FC, bytes=i32(R.choice([500, 0, -3]))), dict(slot=k, offset=0x300, bytes=i32(R.choice([1, 4, 5, 300]))),
                           dict(slot=k, offset=0x364, bytes=i32(1)), dict(slot=k, offset=0x30C, bytes=i32(R.choice([0, 2])))]
            return dict(target=self.u32(0x455608), globals=glob, catalog=catalog, world=[dict(offset=4, bytes=bytes(activity).hex())],
                        actors=writes, bindings=[dict(slot=k, object=o, frame=f) for k, (o, f) in sorted(bindings.items())])

        def scenario(family):
            if family in ('survival', 'refill'):
                return survival(family)
            st = R.choice(stages)
            s = st['stage']
            count = st['count']
            phase = R.choice([-1] + list(range(count)) + [count - 1] * 2)
            if family == 'start':
                phase = -1
            base_phase = max(phase, 0)
            writes, catalog, bindings = [], [], {}
            activity = [0] * 400
            glob = [g(0x450B94, s), g(0x44FB6C, phase), g(0x450C30, R.choice([-1, 0, 1, 2])),
                    g(0x450BA8, R.choice([0] * 6 + [1, 2, 3, 4] if family in ('set', 'end') else [0] * 8 + [1, 2])),
                    g(0x450BAC, R.choice([0, 0, 1])), g(0x451B34, R.choice([0, 1])), g(0x451B30, R.choice([0, 1])),
                    g(0x450B9C, R.choice([0] * 6 + [1, 50, 99, 100, 101, 102, 150, 168, 169, 170, 199, 200, 201, 202, 250, 279, 280, 299, 300]
                                        if family == 'banner' else [0] * 10 + [100, 169, 201])),
                    g(0x450BA4, R.choice([20] * 6 + [0, 1, 5, 9, 10, 11, 21] if family == 'set' else [0] * 5 + [1, 5, 9, 10, 11, 12, 15, 19, 20, 21] if family == 'bound' else [0] * 10 + [1, 11])),
                    g(0x450BDC, R.choice([0, 0, 1, 2, 50, 89, 90, 91, 350] if family == 'end' else [0])),
                    g(0x450BA0, R.choice([0, 0, 1, 10, 35, 68, 69, 70])), g(0x44F880, R.choice([-1, -1, 0, 5, 100])),
                    g(0x44D34C, R.choice([-1, 0, 3, 9, 10])), g(0x450B88, R.choice([0, 0, 1])),
                    g(0x44D024, R.randrange(17)), g(0x44D020, R.choice([10, 3, 1, 10]))]
            if R.random() < 0.5:
                glob.append(g(0x450BCC, R.randrange(3000)))
                glob.append(g(0x450C34, R.randrange(1234)))
            # Players: seats 0..19, type-0 characters.
            players = R.sample(range(20), R.choice([1, 1, 2, 2, 3, 4, 6]))
            bound = self.s32(self.stage_address(s) + 8 + base_phase * PHASE_STRIDE)
            for k in players:
                o = R.choice(heavy) if heavy and R.random() < 0.2 else R.choice(characters)
                bindings[k] = (o['ordinal'], 0)
                activity[k] = R.choice([1] * 8 + [0x80, 2])
                hp = R.choice([500, 300, 1, 0, -5])
                writes += [dict(slot=k, offset=0x2FC, bytes=i32(hp)), dict(slot=k, offset=0x300, bytes=i32(R.choice([500, hp, 300]))),
                           dict(slot=k, offset=0x304, bytes=i32(R.choice([500, 700]))), dict(slot=k, offset=0x30C, bytes=i32(R.choice([0, 1, 2, 3, -1, -2]))),
                           dict(slot=k, offset=0x364, bytes=i32(R.choice([1, 1, 2, 5, 0]))),
                           dict(slot=k, offset=0x10, bytes=i32(bound + R.choice([-400, -1, 0, 1, 50, 800]) if family == 'bound' else R.randint(0, 3000))),
                           dict(slot=k, offset=0x70, bytes=i32(R.choice([0, 0, 9, 10, 11, 12, 16, 17, 18, 200])))]
            if family in ('phase', 'start', 'banner') and R.random() < 0.2:
                catalog.append(dict(stage=s, offset=PHASE_STRIDE + base_phase * PHASE_STRIDE, bytes=i32(R.choice([-1, 0, 1, base_phase]))))
            if family in ('start', 'phase') and R.random() < 0.15:
                nxt = min(base_phase + 1, count - 1)
                catalog.append(dict(stage=s, offset=0xC + nxt * PHASE_STRIDE, bytes=(b'bgm\\stage1.wma\0').hex()))
            if family == 'banner' and R.random() < 0.3:
                catalog.append(dict(stage=s, offset=PHASE_STRIDE + 8 + base_phase * PHASE_STRIDE, bytes=i32(bound)))
            # Spawn-slot runtime words of the current phase and their listed seats.
            enemy_seats = iter(R.sample(range(20, 400), 380))
            for k in st['phases'][base_phase]:
                off = 0x40 + base_phase * PHASE_STRIDE + k * SLOT_STRIDE
                target = R.choice([0, 1, 2, 3, 5, 10, 40])
                spawned = min(target, R.choice([0, 1, target, target]))
                listed = R.choice([0, 0, 1, 2, 3, 5]) if phase >= 0 else 0
                catalog += [dict(stage=s, offset=off, bytes=i32(spawned)), dict(stage=s, offset=off + 4, bytes=i32(target)),
                            dict(stage=s, offset=off + 8, bytes=i32(listed))]
                if R.random() < 0.15:
                    catalog.append(dict(stage=s, offset=off + 0xAC, bytes=i32(R.choice([1000, 3000, 3001, 300, 0x7A, 9999]))))
                if R.random() < 0.15:
                    catalog.append(dict(stage=s, offset=off + 0xB0, bytes=i32(-1000)))
                if R.random() < 0.15:
                    catalog.append(dict(stage=s, offset=off + 0xD8, bytes=i32(R.choice([0, 1, 2]))))
                for n in range(listed):
                    seat = R.choice([-1, next(enemy_seats), next(enemy_seats)])
                    catalog.append(dict(stage=s, offset=off + 0xC + 4 * n, bytes=i32(seat)))
                    if seat >= 0:
                        o = R.choice(characters) if R.random() < 0.7 else R.choice(others)
                        bindings[seat] = (o['ordinal'], 0)
                        activity[seat] = R.choice([1, 1, 1, 0])
                        writes += [dict(slot=seat, offset=0x364, bytes=i32(R.choice([5, 5, 5, 0, 1]))),
                                   dict(slot=seat, offset=0x2FC, bytes=i32(R.choice([500, 100, 1, 0, -1]))),
                                   dict(slot=seat, offset=0x30C, bytes=i32(R.choice([0, 1, 2]))),
                                   dict(slot=seat, offset=0x2F4, bytes=i32(R.choice([-1, -1, 0, 1, 2, 19, 20]))),
                                   dict(slot=seat, offset=0x98, bytes=i32(R.choice([0, 5, -1])))]
            pressure = R.random()
            if family == 'pressure' or pressure < 0.05:
                free = [k for k in range(20, 400) if k not in bindings]
                keep = R.choice([None, R.choice(free)])
                for k in free:
                    if k != keep:
                        activity[k] = 1
                        bindings[k] = (R.choice(others)['ordinal'], 0)
            stimulus = dict(target=R.choice([0x5555, self.u32(0x455608)]), globals=glob, catalog=catalog,
                            world=[dict(offset=4, bytes=bytes(activity).hex())], actors=writes,
                            bindings=[dict(slot=k, object=o, frame=f) for k, (o, f) in sorted(bindings.items())])
            return stimulus

        crt, table = 0x437860 + 17 * int(self.control), bytearray()
        for _ in range(3000):
            crt = (crt * 0x343FD + 0x269EC3) & 0xFFFFFFFF
            table.append(((crt >> 16) & 0x7FFF) % 255 + 1)
        table_write = dict(address=0x44FF90, bytes=(bytes(table) + b'\0').hex())
        families = [('start', 400), ('phase', 900), ('banner', 400), ('end', 300), ('bound', 400), ('set', 300), ('pressure', 60),
                    ('survival', 120), ('refill', 80)]
        for family, total in families:
            for index in range(total):
                stimulus = scenario(family)
                if not cases:
                    stimulus['globals'].insert(0, table_write)
                cases.append(self.call_stage(f'{family}-{index}', stimulus, cw))
            print('family', family, 'cases', total, 'blocks', len(self.blocks), flush=True)
        doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, parents=parents, worldAddress=self.world_address,
                   catalogAddress=self.u32(self.world_address + 0x7D4), objectAddresses=self.object_addresses,
                   actorAddresses=[r['address'] for r in self.pool], controlWord=cw, blocks=sorted(self.blocks), cases=cases)
        return transport(doc, self.blobs)


def main():
    from oracle_wave_loader import digest
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--control', action='store_true')
    args = p.parse_args()
    vm = MissionStage(args.control)
    doc = vm.capture_inputs()
    suffix = '-control' if args.control else ''
    path = ROOT / 'build/original' / f'mission-stage{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(path.read_bytes()),
                  cases=len(doc['cases']), blocks=len(doc['blocks']), nativeComparison='pending')
    (ROOT / 'docs/evidence' / f'mission-stage{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Captured', len(doc['cases']), 'mission stage cases', flush=True)


if __name__ == '__main__':
    main()
