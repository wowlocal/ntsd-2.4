#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real43a860(World; unused) — the War battle logic: troop counts per side and
unit type, reserve spawns into free seats 20..399, the battle-over flag 451b7c,
the two status lines and the preset labels in 451c80 — called directly after
the verified first loading, on the loaded catalog's real Objects and arenas.
Stimuli declare the War unit tables (44d350 IDs, 44d6a8 reserves, 44d700 limits,
44d37c count), display/strength/multiplier globals, arena, and seats with their
side/team/HP bound to real Objects. The accepted callees 401290 (surface text)
and 423a70 (bitmap font) are recorded boundaries (arguments and text); sprintf
executes the pinned VC80 DLL; RNG 417170, the Actor constructor 4061d0 and the
cookie check 4450b2 execute. Main corpus CW027f; control CW037f over the control
loading. APPLICATION_WAR_PLAN.md W3.
"""
import argparse
import json
import random
import struct
from import_ntsd import EXE_SHA256, ROOT
from oracle_initial_loading import transport
from oracle_object_input import ObjectInput
from oracle_catalog_sounds import REGISTERS
from oracle_crt import CRT
from oracle_state import STACK, STOP
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

BODIES = [(0x43A860, 0x43B3CE)]
ALLOWED = BODIES + [(0x417170, 0x4171BD), (0x4061D0, 0x4064CD), (0x4450A0, 0x4450A1), (0x4450B2, 0x4450BC)]
# entry: (kind, stack arguments); both are cdecl.
BOUNDARIES = {0x401290: ('text', 6), 0x423A70: ('bitmapFont', 7)}
FORMATS = (b'Man: %3d     HP: %4d     Reserve: %3d     Die: %3d', b'Defense: %d.%d')
UNITS = [30, 31, 33, 34, 39, 32, 35, 36, 37, 122, 123]


class WarBattle(ObjectInput):
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
        kind, count = BOUNDARIES[address]
        sp = uc.reg_read(UC_X86_REG_ESP)
        args = [self.u32(sp + 4 + 4 * i) for i in range(count)]
        text = self.cstr(args[1] if kind == 'text' else args[0])
        self.calls.append(dict(kind=kind, caller=self.u32(sp), arguments=args, text=text.hex()))
        self.ret(0, 0)

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

    def call_battle(self, label, stimulus, cw):
        for item in stimulus['globals']:
            self.uc.mem_write(item['address'], bytes.fromhex(item['bytes']))
        for item in stimulus['world']:
            self.write_host(self.world_address + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['actors']:
            self.write_host(self.pool[item['slot']]['address'] + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['bindings']:
            self.write_host(self.pool[item['slot']]['address'] + 0x368, struct.pack('<I', self.object_addresses[item['object']]))
        before_actors = [self.raw(r) for r in self.pool]
        before_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        constructors_before = len(self.actor_calls)
        self.random, self.calls = [], []
        self.written = set()
        sp = STACK + 0xD000
        self.uc.mem_write(sp, struct.pack('<II', STOP, stimulus['argument']))
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
            self.execute(0x43A860, STOP)
        finally:
            self.running = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 8, label
        assert [self.uc.reg_read(r) for r in REGISTERS] == saved, label
        fpu = [top, (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7, 0xFFFF, self.uc.reg_read(UC_X86_REG_FPTAG)]
        assert fpu[0] == fpu[1] and fpu[3] == 0xFFFF, (label, fpu)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == cw, label
        undefined = sorted([list(r) for r in self.reads_before_writes])
        self.reads_before_writes.clear()
        after_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        changed = sorted({GLOBAL + (i & ~3) for i in range(GLOBAL_SIZE) if after_globals[i] != before_globals[i]})
        globals_after = {hex(w): after_globals[w - GLOBAL:w - GLOBAL + 4].hex() for w in changed}
        actors = {}
        for i, r in enumerate(self.pool):
            if self.raw(r) != before_actors[i]:
                actors[str(i)] = {k: v for k, v in self.record(r).items() if k != 'initial'}
        world = {k: v for k, v in self.record(self.world).items() if k != 'initial'}
        global_writes = [dict(address=a, bytes=bytes(self.uc.mem_read(a, b - a)).hex())
                         for a, b in self.runs(x for x in self.written if GLOBAL <= x < GLOBAL + GLOBAL_SIZE)]
        return dict(label=label, controlWord=cw, stimulus=stimulus, random=self.random, calls=self.calls,
                    globalWrites=global_writes, constructors=self.actor_calls[constructors_before:],
                    undefinedReads=undefined, fpu=fpu, globals=globals_after, world=world, actors=actors)

    def capture_inputs(self):
        parents = self.parents()
        print('Verified parent reproduced', flush=True)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.track, begin=GLOBAL, end=GLOBAL + GLOBAL_SIZE - 1)
        R = random.Random(0x43A860 + int(self.control))
        cw = 0x37F if self.control else 0x27F
        objects = []
        for n, a in enumerate(self.object_addresses):
            objects.append(dict(ordinal=n, type=self.s32(a + 0x6F8), id=self.s32(a + 0x6F4)))
        by_id = {}
        for o in objects:
            by_id.setdefault(o['id'], o)
        troops = [o for o in objects if 30 <= o['id'] <= 39 or o['id'] in (122, 123)]
        characters = [o for o in objects if o['type'] == 0]
        others = [o for o in objects if o['type'] not in (0, 5)]
        fives = [o for o in objects if o['type'] == 5]
        assert troops and characters and others
        print('troops', [(o['id'], o['type']) for o in troops], 'type5', len(fives), flush=True)
        arenas = [a for a in range(17)]
        cases = []

        def i32(value):
            return struct.pack('<i', value).hex()

        def g(address, value):
            return dict(address=address, bytes=struct.pack('<i', value).hex())

        def scenario(family):
            count = 11
            if family == 'count':
                count = R.choice([-1, 1, 2, 3, 5, 9, 11, 11])
            units = list(UNITS)
            if family in ('spawn', 'count', 'kinds') and R.random() < 0.5:
                for _ in range(R.choice([1, 2, 3])):
                    pool = [38, 9999, 1, 5] + [o['id'] for o in R.sample(others, min(3, len(others)))] + \
                           ([o['id'] for o in fives[:2]] if fives else []) + [o['id'] for o in R.sample(characters, 2)]
                    units[R.randrange(11)] = R.choice(pool)
            reserves = [R.choice([0, 0, 1, 2, 5, 30, -1]) for _ in range(22)]
            limits = [R.choice([0, 1, 2, 3, 5, 10, 40]) for _ in range(22)]
            if family == 'over':
                side = R.randrange(2)
                reserves = [0 if (k // 11 == side and R.random() < 0.9) else r for k, r in enumerate(reserves)]
            glob = [g(0x44D37C, count)] + [g(0x44D350 + 4 * k, u) for k, u in enumerate(units)] + \
                   [g(0x44D6A8 + 4 * k, r) for k, r in enumerate(reserves)] + [g(0x44D700 + 4 * k, v) for k, v in enumerate(limits)]
            glob += [g(0x44D380, R.choice([-1, 0, 1, 2, 3, 4, 5, 6, 7, -2])), g(0x44D384, R.choice([-1, 0, 1, 2, 3, 4, 5, 6, 7, -2])),
                     g(0x451B74, R.choice([-1, 0, 1, 2, 3])), g(0x451B78, R.choice([-1, 0, 1, 2, 3])),
                     g(0x44D758, R.choice([100, 100, 150, 200, 250, 300, 0, -150, 305, 99, 1234])),
                     g(0x44D75C, R.choice([100, 100, 150, 200, 250, 300, 0, -150, 305, 99, 1234])),
                     g(0x451B64, R.choice([0, 1, 7, 150, 1000, -3])), g(0x451B68, R.choice([0, 1, 7, 150, 1000, -3])),
                     g(0x44D024, R.choice(arenas)), g(0x451B7C, R.choice([0, 1, 5]))]
            if R.random() < 0.5:
                glob.append(g(0x450BCC, R.randrange(3000)))
                glob.append(g(0x450C34, R.randrange(1234)))
            activity = [0] * 400
            writes, bindings = [], {}
            # Players/leaders: seats 0..19 (characters), sides 1/2.
            for k in R.sample(range(20), R.choice([0, 1, 2, 3, 6])):
                o = R.choice(characters)
                bindings[k] = o['ordinal']
                activity[k] = R.choice([1, 1, 1, 2, 0x80])
                writes += [dict(slot=k, offset=0x2FC, bytes=i32(R.choice([500, 300, 1, 0, -5]))),
                           dict(slot=k, offset=0x364, bytes=i32(R.choice([1, 1, 2, 2, 0, 3]))),
                           dict(slot=k, offset=0x344, bytes=i32(R.choice([1, 2, 0, 3])))]
            # Troops and other objects: seats 20..399.
            fill = {'full': 380, 'count': R.choice([0, 10, 60, 200]), 'spawn': R.choice([0, 5, 30, 120, 300]),
                    'kinds': R.choice([0, 20, 80]), 'over': R.choice([0, 10, 40]), 'labels': R.choice([0, 10])}[family]
            seats = R.sample(range(20, 400), fill)
            for k in seats:
                r = R.random()
                o = R.choice(troops) if r < 0.6 else (R.choice(characters) if r < 0.8 else R.choice(others))
                bindings[k] = o['ordinal']
                activity[k] = R.choice([1, 1, 1, 1, 2])
                writes += [dict(slot=k, offset=0x2FC, bytes=i32(R.choice([100, 50, 1, 0, -2, 500]))),
                           dict(slot=k, offset=0x364, bytes=i32(R.choice([1, 2, 0, 1, 2]))),
                           dict(slot=k, offset=0x344, bytes=i32(R.choice([1, 2, 1, 2, 0, 3, -1])))]
            if family == 'full' and R.random() < 0.3:
                free = R.choice(range(20, 400))
                activity[free] = 0
            return dict(argument=R.choice([0x5555, self.u32(0x455608)]), globals=glob,
                        world=[dict(offset=4, bytes=bytes(activity).hex())], actors=writes,
                        bindings=[dict(slot=k, object=o) for k, o in sorted(bindings.items())])

        crt, table = 0x43A860 + 17 * int(self.control), bytearray()
        for _ in range(3000):
            crt = (crt * 0x343FD + 0x269EC3) & 0xFFFFFFFF
            table.append(((crt >> 16) & 0x7FFF) % 255 + 1)
        table_write = dict(address=0x44FF90, bytes=(bytes(table) + b'\0').hex())
        families = [('spawn', 500), ('count', 250), ('kinds', 250), ('full', 60), ('over', 150), ('labels', 200)]
        for family, total in families:
            for index in range(total):
                stimulus = scenario(family)
                if not cases:
                    stimulus['globals'].insert(0, table_write)
                cases.append(self.call_battle(f'{family}-{index}', stimulus, cw))
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
    vm = WarBattle(args.control)
    doc = vm.capture_inputs()
    suffix = '-control' if args.control else ''
    path = ROOT / 'build/original' / f'war-battle{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(path.read_bytes()),
                  cases=len(doc['cases']), blocks=len(doc['blocks']), nativeComparison='pending')
    (ROOT / 'docs/evidence' / f'war-battle{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Captured', len(doc['cases']), 'War battle cases', flush=True)


if __name__ == '__main__':
    main()
