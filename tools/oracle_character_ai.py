#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real4094b0(World,slot,mode) called directly after verified first loading,
under declared World/Actor/global stimuli bound to real loaded Objects and
Frames. Owners are real characters; a dedicated family enters the
special-move selector 403a40 for every own-id block (level 0 makes its entry
roll always succeed) across distance, chakra, health and frame thresholds.
Targets are real characters (standing and lying frames), projectiles (state
3000), items and healing balls. The main corpus runs under CW027f with the
legacy float conversion; the control corpus uses CW037f, the control loading
and the SSE2 conversion flag45971c. The first case declares a match-start RNG
table. No game code is stubbed; the constructor memset stays a host boundary.
"""
import argparse
import json
import random
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_object_input import ObjectInput
from oracle_catalog_sounds import pack, REGISTERS
from oracle_state import STACK, STOP
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE
from unicorn.x86_const import UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

BODIES = [(0x4094B0, 0x40BBE3), (0x403A40, 0x406197), (0x4034F0, 0x403A3F), (0x408CB0, 0x4094A3)]
ALLOWED = BODIES + [(0x417170, 0x4171BD), (0x4034E0, 0x4034EB), (0x4061A0, 0x4061C5), (0x4450D0, 0x44517B)]
WORDS = {0x450BCC, 0x450C34, 0x44F604, 0x44F608, 0x44F60C, 0x44F610, 0x44F614, 0x44F618, 0x44F61C}
UNRECOVERED = set()  # every 403a40 block is ported
SPECIAL_IDS = [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 32, 33, 34, 35, 36, 38, 39, 50, 51, 52]


class CharacterAI(ObjectInput):
    def block(self, uc, address, size, data):
        if not self.running:
            return
        assert any(a <= address < b for a, b in ALLOWED) or address in (STOP, 0x4450A0), hex(address)
        if any(a <= address < b for a, b in BODIES):
            self.blocks.add(address)

    def ai(self, label, slot, mode, stimulus, cw, sse2):
        for item in stimulus['globals']:
            self.uc.mem_write(item['address'], bytes.fromhex(item['bytes']))
        for item in stimulus['world']:
            self.write_host(self.world_address + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['actors']:
            self.write_host(self.pool[item['slot']]['address'] + item['offset'], bytes.fromhex(item['bytes']))
        for item in stimulus['bindings']:
            target = self.pool[item['slot']]['address']
            self.write_host(target + 0x368, struct.pack('<I', self.object_addresses[item['object']]))
            self.write_host(target + 0x70, struct.pack('<I', item['frame']))
        self.uc.mem_write(0x45971C, struct.pack('<I', int(sse2)))
        before_actors = [self.raw(r) for r in self.pool]
        before_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        self.random = []
        sp = STACK + 0xD000
        self.uc.mem_write(sp, struct.pack('<III', STOP, slot, mode & 0xFFFFFFFF))
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
            self.execute(0x4094B0, STOP)
        finally:
            self.running = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 12, label
        assert [self.uc.reg_read(r) for r in REGISTERS] == saved, label
        fpu = [top, (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7, self.uc.reg_read(UC_X86_REG_FPTAG)]
        assert fpu[0] == fpu[1] and fpu[2] == 0xFFFF, (label, fpu)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == cw, label
        undefined = sorted([list(r) for r in self.reads_before_writes])
        self.reads_before_writes.clear()
        after_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        changed = {GLOBAL + (i & ~3) for i in range(GLOBAL_SIZE) if after_globals[i] != before_globals[i]}
        assert changed <= WORDS, (label, sorted(hex(w) for w in changed))
        actors = {}
        for i, r in enumerate(self.pool):
            if self.raw(r) != before_actors[i]:
                actors[str(i)] = {k: v for k, v in self.record(r).items() if k != 'initial'}
        world = {k: v for k, v in self.record(self.world).items() if k != 'initial'}
        return dict(label=label, slot=slot, mode=mode, controlWord=cw, sse2=sse2, stimulus=stimulus, random=self.random,
                    undefinedReads=undefined, words={hex(w): self.u32(w) for w in sorted(WORDS)}, world=world, actors=actors)

    def capture_ai(self):
        parents = self.parents()
        print('Verified parent reproduced', flush=True)
        for k in range(400):
            assert self.u32(self.world_address + 0x194 + 4 * k) == self.pool[k]['address']
        R = random.Random(0x4094B0 + int(self.control))
        cw, sse2 = (0x37F, True) if self.control else (0x27F, False)
        objects = []
        for n, a in enumerate(self.object_addresses):
            frames = [self.s32(a + 0x7A4 + f * 0x178 + 8) for f in range(400)]
            nexts = [self.s32(a + 0x7A4 + f * 0x178 + 0x2C) for f in range(400)]
            objects.append(dict(ordinal=n, type=self.s32(a + 0x6F8), id=self.s32(a + 0x6F4), states=frames, nexts=nexts))
        by_id = {o['id']: o for o in objects}
        chars = [o for o in objects if o['type'] == 0]
        owners = [o for o in chars if o['id'] not in UNRECOVERED]
        assert any(o['id'] == 33 for o in owners)

        def frames(o, states=None):
            return [f for f, st in enumerate(o['states']) if (st != 0 or f == 0) and (states is None or st in states)]
        standing = [(o['ordinal'], f) for o in chars for f in frames(o) if o['states'][f] != 14]
        lying = [(o['ordinal'], f) for o in chars for f in frames(o, {14})]
        projectiles = [(o['ordinal'], f) for o in objects if o['type'] != 0 for f in frames(o, {3000})]
        items = [(by_id[i]['ordinal'], f) for i in (100, 101, 120, 121, 122, 123, 124, 150, 151, 213) if i in by_id for f in frames(by_id[i])]
        balls = [(by_id[200]['ordinal'], f) for f in range(40, 70) if by_id[200]['states'][f] != 0]
        dangers = [(by_id[211]['ordinal'], f) for f in frames(by_id[211], {18})] + [(by_id[212]['ordinal'], f) for f in range(150, 171) if by_id[212]['states'][f] != 0]
        assert lying and projectiles and items and balls and dangers
        by_state = {}
        for o in chars:
            for f in frames(o):
                by_state.setdefault(o['states'][f], []).append((o['ordinal'], f))
        grabbable = [(by_id[i]['ordinal'], f) for i in (100, 101, 120, 121, 124, 150, 151) if i in by_id for f in frames(by_id[i], {1004, 2004})]
        weapons = {i: [(by_id[i]['ordinal'], f) for f in frames(by_id[i])] for i in (100, 101, 120, 121, 122, 123, 124, 150, 151) if i in by_id}
        assert grabbable and all(by_state.get(k) for k in (2, 3, 8, 16, 17))
        crt, table = 0x4094B0 + 17 * int(self.control), bytearray()
        for _ in range(3000):
            crt = (crt * 0x343FD + 0x269EC3) & 0xFFFFFFFF
            table.append(((crt >> 16) & 0x7FFF) % 255 + 1)
        table_write = dict(address=0x44FF90, bytes=(bytes(table) + b'\0').hex())

        def d(value):
            return struct.pack('<d', value).hex()

        def i32(value):
            return struct.pack('<i', value).hex()

        def scenario(owner, family):
            s = R.choice([10, 11, 19, 20, 21, 55, 120, 399]) if R.random() < 0.3 else R.randrange(10, 400)
            activity, bindings, writes = [0] * 400, {}, []

            def put(slot, offset, raw):
                writes.append(dict(slot=slot, offset=offset, bytes=raw))
            own = frames(owner)
            bindings[s] = (owner['ordinal'], R.choice([f for f in own if owner['states'][f] in (0, 1, 2, 3, 7, 9, 16, 17, 19)] or own)
                           if R.random() < 0.6 else R.choice(own))
            special = {7: range(250, 266), 9: range(276, 295), 32: range(236, 250)}.get(owner['id'])
            if family == 'idle' and special and R.random() < 0.7:
                bindings[s] = (owner['ordinal'], R.choice(list(special)))
            if family in ('walk2', 'weapon', 'clone', 'weapon2', 'approach2', 'item2', 'remember') and R.random() < 0.6:
                wanted = [f for f in own if owner['states'][f] in ((2, 17) if family in ('weapon', 'weapon2') else (2,))]
                if wanted:
                    bindings[s] = (owner['ordinal'], R.choice(wanted))
            activity[s] = 1
            sx, sz = R.randint(-50, 1600), R.randint(150, 550)
            team = R.choice([1, 2, 3, 5, 0])
            steps = [0, 1, -1, 2, -2, 3, -3, 6, -6, 7, -7, 13, -13, 20, -21, 29, 31, 45, 46, 60, 61, 79, 80, 99, 100, 101,
                     149, 151, 169, 171, 199, 201, 239, 241, 249, 251, 299, 301, 349, 351, 401]
            put(s, 0x10, i32(sx)); put(s, 0x14, i32(R.choice([0, -10, -60]))); put(s, 0x18, i32(sz))
            put(s, 0x40, d(R.choice([0.0, -0.0, 3.5, -3.5, 10.0, -10.0, R.uniform(-20, 20)])))
            put(s, 0x80, bytes([R.choice([0, 1, 0, 1, 2])]).hex())
            put(s, 0x8, i32(R.choice([0, 0, 0, 1, 3, -3])))
            put(s, 0x2FC, i32(R.choice([500, 400, 300, 200, 139, 140, 100, 50, 1])))
            put(s, 0x300, i32(R.choice([500, 500, 450, 200])))
            put(s, 0x304, i32(R.choice([500, 500, 450, 100, 99, 101])))
            put(s, 0x308, i32(R.choice([500, 300, 251, 250, 151, 150, 0])))
            put(s, 0x364, i32(team))
            put(s, 0x2F4, i32(R.choice([-1, -1, -1, 0, 5])))
            for o in (0x3E8, 0x3EC, 0x3F0, 0x3F4):
                put(s, o, i32(R.choice([0, 0, 0, 1, 2])))
            put(s, 0x404, i32(R.choice([0, 0, 0, 1, 2])))
            walk = family in ('walk', 'walk2') or R.random() < 0.05
            put(s, 0x3FC, i32(sx + R.choice(steps) * R.choice([1, -1]) if walk else -1000))
            put(s, 0x400, i32(sz + R.choice(steps[:20]) * R.choice([1, -1]) if walk else -1000))
            others = [k for k in range(400) if k != s]
            count = R.choice([0, 1, 1, 2, 2, 3, 4, 6])
            if family == 'idle':
                count = R.choice([0, 0, 1, 2])
            elif family in ('clone', 'band', 'weapon', 'weapon2', 'approach2', 'remember'):
                count = R.choice([1, 1, 2])
            elif family == 'item2':
                count = R.choice([0, 1])
            people = R.sample(R.choice([others[:10] + others[10:40], others]), count)
            for k in people:
                bindings[k] = R.choice(lying) if R.random() < 0.2 else R.choice(standing)
                if family in ('clone', 'band') and R.random() < 0.7:
                    bindings[k] = R.choice(by_state[R.choice([16, 8, 16, 3])] if family == 'clone' else by_state[R.choice([16, 16, 301 if 301 in by_state else 3, 3])])
                activity[k] = R.choice([1, 1, 1, 1, 2])
                put(k, 0x8, i32(R.choice([0] * 6 + [1, 3, -3])))
                put(k, 0x10, i32(sx + R.choice(steps) * R.choice([1, -1])))
                put(k, 0x18, i32(sz + R.choice(steps[:24]) * R.choice([1, -1])))
                put(k, 0x40, d(R.choice([0.0, 4.0, -4.0, 12.0, -12.0])))
                put(k, 0x80, bytes([R.choice([0, 1])]).hex())
                put(k, 0x98, i32(R.choice([0, 0, 1])))
                put(k, 0x2FC, i32(R.choice([500, 250, 100, 1, 0, -5])))
                put(k, 0x364, i32(R.choice([team, team, 5, R.randint(0, 3)])))
                if family == 'idle':
                    put(k, 0x364, i32(team))
                if family in ('pickup', 'item2'):
                    put(k, 0x10, i32(sx + R.choice([1, -1]) * R.randint(300, 900)))
                if family == 'weapon2':
                    put(k, 0x10, i32(R.choice([sx + R.choice([1, -1]) * R.randint(351, 1500), R.randint(0, 399), R.randint(1200, 2000)])))
                    put(k, 0x18, i32(sz + R.choice([0, 5, -5, 69, 70, -70, 71, 120, -140])))
                    put(k, 0x364, i32((team + 1) % 4 if team != 5 else 1))
                if family == 'approach2':
                    put(k, 0x10, i32(sx + R.choice([1, -1]) * R.choice([10, 61, 100, 200])))
                    put(k, 0x364, i32((team + 1) % 4 if team != 5 else 1))
                if family == 'remember':
                    put(k, 0x364, i32(team))
                    put(k, 0x10, i32(sx + R.choice([1, -1]) * R.choice([20, 60, 115, 250])))
                    put(k, 0x18, i32(sz + R.choice([0, 3, -4, 10])))
                if family in ('clone', 'band', 'weapon'):
                    put(k, 0x10, i32(sx + R.choice([1, -1]) * R.choice([0, 5, 20, 40, 59, 61, 90, 99, 101, 120, 160, 175, 260, 360])))
                    put(k, 0x18, i32(sz + R.choice([0, 1, -1, 3, -4, 6, -6, 8, 12, 20])))
                    put(k, 0x364, i32((team + 1) % 4 if team != 5 else 1))
            extras = []
            for pool, weight in ((projectiles, 0.5), (items, 0.5), (balls, 0.3), (dangers, 0.3)):
                if family in ('mixed', 'items') and R.random() < weight or family == 'items' and pool is items:
                    for _ in range(R.choice([1, 1, 2])):
                        free = [k for k in (range(20, 400) if R.random() < 0.8 else range(10, 400)) if k not in bindings]
                        k = R.choice(free)
                        extras.append(k)
                        bindings[k] = R.choice(pool)
                        activity[k] = 1
                        put(k, 0x10, i32(sx + R.choice(steps) * R.choice([1, -1])))
                        put(k, 0x18, i32(sz + R.choice(steps[:24]) * R.choice([1, -1])))
                        put(k, 0x40, d(R.choice([0.0, 8.0, -8.0, 15.0, -15.0])))
                        put(k, 0x98, i32(R.choice([0, 0, 1])))
                        put(k, 0x2FC, i32(R.choice([500, 1, 0])))
                        put(k, 0x364, i32(R.choice([team, 0, 5, R.randint(0, 3)])))
                        put(k, 0x8, i32(0))
            if family == 'approach2':
                for pool in (balls, dangers):
                    if R.random() < 0.7:
                        k = R.choice([k for k in range(20, 400) if k not in bindings])
                        extras.append(k)
                        bindings[k] = R.choice(pool)
                        activity[k] = 1
                        put(k, 0x10, i32(sx + R.choice([1, -1]) * R.choice([0, 5, 50, 79, 101, 140])))
                        put(k, 0x18, i32(sz + R.choice([0, 5, -5, 15, -19, 21, -21])))
                        put(k, 0x364, i32(R.choice([team, (team + 1) % 4])))
                        put(k, 0x98, i32(0))
                        put(k, 0x2FC, i32(500))
                        put(k, 0x8, i32(0))
            if family in ('pickup', 'item2'):
                for _ in range(R.choice([1, 1, 2, 3])):
                    k = R.choice([k for k in range(20, 400) if k not in bindings])
                    extras.append(k)
                    bindings[k] = R.choice(grabbable)
                    activity[k] = 1
                    put(k, 0x10, i32(sx + R.choice([0, 1, -1, 5, -5, 6, -6, 7, -7, 30, -30, 99, -99, 101, -101, 249, -249, 251, -251, 400]
                                                   + ([-60, 60, -90, 90, -300, 300, -500, 500] if family == 'item2' else []))))
                    put(k, 0x18, i32(sz + R.choice([0, 1, -1, 3, -3, 4, -4, 10, -10])))
                    put(k, 0x98, i32(R.choice([0, 0, 0, 1])))
                    put(k, 0x364, i32(R.choice([0, team])))
                    put(k, 0x2FC, i32(500))
                    put(k, 0x8, i32(0))
            holding = R.random() < 0.25 or family in ('weapon', 'weapon2', 'remember')
            if family in ('weapon', 'weapon2', 'remember'):
                k = R.choice([k for k in range(20, 400) if k not in bindings])
                extras.append(k)
                kinds = [i for i in (122, 123) if i in weapons] if family == 'weapon2' else sorted(weapons)
                bindings[k] = R.choice(weapons[R.choice(kinds)])
                activity[k] = R.choice([0, 1])
                put(k, 0x98, i32(1))
                put(k, 0x364, i32(team))
            put(s, 0x98, i32(R.choice([1, 2]) if holding else 0))
            if family in ('pickup', 'idle', 'item2', 'approach2'):
                put(s, 0x98, i32(0))
            held_slots = [k for k in extras if objects[bindings[k][0]]['id'] in (100, 101, 120, 121, 122, 123, 124, 150, 151)]
            held = R.choice(held_slots) if holding and held_slots else R.choice([k for k in range(400) if k not in bindings])
            if held not in bindings:
                bindings[held] = R.choice(items)
            put(s, 0x9C, i32(held))
            candidates = people + extras
            put(s, 0x360, i32(R.choice([-1, -1, 400, 7] + candidates)))
            if family == 'idle':
                put(s, 0x360, i32(-1))
            if family == 'remember' and people:
                put(s, 0x360, i32(R.choice(people)))
                for k in people:
                    activity[k] = 1
                    put(k, 0x2FC, i32(500))
            if family == 'far404':
                put(s, 0x404, i32(1)); put(s, 0x3FC, i32(R.choice([-1001, -2000, -1000]))); put(s, 0x400, i32(R.choice([-1000, sz, sz + 100])))
            if family in ('clone', 'weapon', 'band', 'weapon2', 'approach2', 'remember'):
                put(s, 0x308, i32(R.choice([500, 300, 151])))
                put(s, 0x80, bytes([R.choice([0, 1])]).hex())
                put(s, 0x404, i32(R.choice([0, 0, 1])))
            g = [dict(address=0x450BAC, bytes=i32(1 if family == 'scripted' else R.choice([0, 0, 0, 2])))]
            g.append(dict(address=0x450BB4, bytes=i32(R.choice([0, 0, -5, 800, 1600]))))
            g.append(dict(address=0x44D024, bytes=i32(R.randrange(0, 17))))
            g.append(dict(address=0x450C2C, bytes=i32(R.choice([0, 0, 0, 1]))))
            g.append(dict(address=0x450C30, bytes=i32(R.choice([-1, 0, 1, 2, 3, 3]))))
            if R.random() < 0.5:
                g.append(dict(address=0x450BCC, bytes=struct.pack('<I', R.randrange(3000)).hex()))
                g.append(dict(address=0x450C34, bytes=struct.pack('<I', R.randrange(1234)).hex()))
            mode = 1 if family == 'scripted' else R.choice([0, 1, 1, 4, 4, 2, 3])
            if family in ('approach2', 'item2') and R.random() < 0.5:
                mode = 1
                k = R.choice([k for k in range(0, 10) if k not in bindings])
                bindings[k] = R.choice(standing)
                activity[k] = 1
                put(k, 0x10, i32(sx - R.choice([150, 300, 450, 700])))
                put(k, 0x18, i32(sz))
                put(k, 0x2FC, i32(500))
                put(k, 0x364, i32(team))
            stimulus = dict(globals=g, world=[dict(offset=4, bytes=bytes(activity).hex())], actors=writes,
                            bindings=[dict(slot=k, object=o, frame=f) for k, (o, f) in sorted(bindings.items())])
            return s, mode, stimulus

        DX = [0, 5, 20, 39, 41, 44, 46, 49, 51, 59, 61, 74, 76, 79, 81, 84, 86, 89, 91, 99, 101, 119, 121, 129, 131, 149, 151,
              159, 161, 169, 171, 199, 201, 239, 241, 249, 251, 269, 271, 279, 281, 299, 301, 349, 351, 369, 371, 399, 401, 499,
              501, 549, 551, 649, 651, 699, 701, 899, 901, 949, 951, 1199, 1201]
        DZ = [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 19, 20, 21, 24, 25, 29, 30, 31, 34, 35, 39, 40, 49, 50, 51, 54, 55, 59,
              60, 64, 65, 69, 70, 71, 149, 150, 151, 169, 170, 171, 199, 200, 201, 239, 240, 241, 249, 250, 251]
        MPS = [0, 50, 75, 76, 99, 100, 101, 120, 121, 125, 126, 150, 151, 170, 171, 200, 201, 220, 221, 250, 251, 260, 261,
               300, 301, 320, 321, 350, 351, 360, 361, 450, 451, 500, 501]
        windows = {7: list(range(255, 262)) + list(range(268, 283)), 1: list(range(260, 290)), 51: list(range(266, 280)), 10: [271]}
        pein_frames = [(o['ordinal'], f) for o in chars for f in (263, 264) if o['states'][f] != 0]

        def special_scenario(owner):
            s = R.choice([10, 15, 19]) if R.random() < 0.1 else R.randrange(20, 400)
            activity, bindings, writes = [0] * 400, {}, []

            def put(slot, offset, raw):
                writes.append(dict(slot=slot, offset=offset, bytes=raw))
            own = frames(owner)
            oid = owner['id']
            if oid in windows and R.random() < 0.5:
                f = R.choice(windows[oid])
            elif oid == 11 and R.random() < 0.4:
                f = R.choice([f for f in range(400) if owner['nexts'][f] == 290] or own)
            elif oid == 6 and R.random() < 0.4:
                f = R.choice(frames(owner, {9}) or own)
            else:
                f = R.choice([f for f in own if owner['states'][f] in (0, 1, 2, 3, 7)] or own)
            bindings[s] = (owner['ordinal'], f)
            activity[s] = 1
            sx, sz, team = R.randint(300, 1500), R.randint(200, 500), R.choice([1, 2, 3, 0])
            mode = R.choice([0, 0, 2, 3, 4, 1])
            enemy_team = 5 if mode == 1 else (team + 1) % 4
            for o, v in ((0x10, sx), (0x14, R.choice([0, 0, -10])), (0x18, sz), (0x8, 0), (0x2FC, R.choice([50, 139, 140, 200, 280, 299, 300, 400, 500])),
                         (0x300, R.choice([500, 500, 450])), (0x304, 500), (0x308, R.choice(MPS)), (0x364, team), (0x2F4, -1),
                         (0x3E8, 0), (0x3EC, 0), (0x3F0, 0), (0x3F4, 0), (0x404, R.choice([0, 0, 0, 1])), (0x3FC, -1000), (0x400, -1000), (0x360, -1)):
                put(s, o, i32(v))
            put(s, 0x40, d(R.choice([0.0, 3.0, -3.0, 10.0, -10.0, 25.0])))
            put(s, 0x80, bytes([R.choice([0, 1, 0, 1, 2])]).hex())
            holding = R.random() < 0.1
            put(s, 0x98, i32(1 if holding else 0))
            k = R.choice([k for k in (range(0, 10) if R.random() < 0.3 else range(10, 400)) if k != s])
            state = R.choice([3, 8, 11, 12, 13, 16, 18, 1, 2, 0, 7])
            pool = by_state.get(state) or standing
            bindings[k] = R.choice(pein_frames) if pein_frames and R.random() < 0.1 else R.choice(pool)
            activity[k] = 1
            for o, v in ((0x10, sx + R.choice([1, -1]) * R.choice(DX)), (0x14, R.choice([0, 0, -10, -45])), (0x18, sz + R.choice([1, -1]) * R.choice(DZ)),
                         (0x2FC, R.choice([500, 300, 100, 50])), (0x308, R.choice([0, 171, 221, 500])), (0x364, enemy_team), (0x8, 0), (0x98, 0)):
                put(k, o, i32(v))
            put(k, 0x40, d(R.choice([0.0, 4.0, -4.0, 12.0])))
            put(k, 0x80, bytes([R.choice([0, 1])]).hex())
            if oid in (2, 34, 36, 10) and R.random() < 0.6:
                for _ in range(R.choice([1, 2, 3])):
                    free = [a for a in (range(0, 20) if oid != 36 or R.random() < 0.5 else range(0, 100)) if a not in bindings]
                    if not free:
                        break
                    a = R.choice(free)
                    bindings[a] = R.choice(standing)
                    activity[a] = R.choice([1, 1, 2])
                    for o, v in ((0x10, sx + R.choice([1, -1]) * R.choice([0, 3, 4, 5, 6, 100, 249, 251, 400])), (0x18, sz + R.choice([0, 20, 59, 61])),
                                 (0x2FC, R.choice([50, 139, 140, 200, 280, 299, 300, 409, 411, 500, 0])), (0x300, 500), (0x364, team), (0x8, 0), (0x98, 0)):
                        put(a, o, i32(v))
            held = R.choice([a for a in range(400) if a not in bindings])
            bindings[held] = R.choice(items)
            put(s, 0x9C, i32(held))
            g = [dict(address=0x450BAC, bytes=i32(0)), dict(address=0x450BB4, bytes=i32(0)), dict(address=0x44D024, bytes=i32(R.randrange(0, 17)))]
            if R.random() < 0.8:
                g.append(dict(address=0x450C2C, bytes=i32(1)))
            else:
                g += [dict(address=0x450C2C, bytes=i32(0)), dict(address=0x450C30, bytes=i32(R.choice([0, 1, 2, 3])))]
            if R.random() < 0.5:
                g.append(dict(address=0x450BCC, bytes=struct.pack('<I', R.randrange(3000)).hex()))
                g.append(dict(address=0x450C34, bytes=struct.pack('<I', R.randrange(1234)).hex()))
            stimulus = dict(globals=g, world=[dict(offset=4, bytes=bytes(activity).hex())], actors=writes,
                            bindings=[dict(slot=a, object=o, frame=f) for a, (o, f) in sorted(bindings.items())])
            return s, mode, stimulus

        cases = []
        plan = [('scripted', 40), ('walk', 80), ('fight', 500), ('mixed', 500), ('items', 200),
                ('pickup', 300), ('weapon', 400), ('band', 200), ('clone', 200), ('idle', 150), ('walk2', 100), ('far404', 100),
                ('weapon2', 300), ('approach2', 250), ('item2', 250), ('remember', 200), ('special', 4000)]
        for family, total in plan:
            for index in range(total):
                owner = by_id[33] if index % 3 == 0 else R.choice(owners)
                if family == 'idle':
                    owner = R.choice([by_id[i] for i in (7, 9, 32) if i in by_id] + chars)
                elif family == 'band':
                    owner = by_id[31] if index % 2 == 0 else R.choice(owners)
                elif family == 'clone':
                    owner = by_id[33]
                if family == 'special':
                    s, mode, stimulus = special_scenario(by_id[SPECIAL_IDS[index % len(SPECIAL_IDS)]])
                else:
                    s, mode, stimulus = scenario(owner, family)
                if not cases:
                    stimulus['globals'].insert(0, table_write)
                cases.append(self.ai(f'{family}-{index}', s, mode, stimulus, cw, sse2))
            print(family, total, 'blocks', len(self.blocks), flush=True)
        doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, parents=parents, worldAddress=self.world_address,
                   objectAddresses=self.object_addresses, actorAddresses=[r['address'] for r in self.pool],
                   controlWord=cw, sse2=sse2, blocks=sorted(self.blocks), cases=cases)
        from oracle_initial_loading import transport
        return transport(doc, self.blobs)


def accept():
    from oracle_wave_loader import digest
    subprocess.run(['xcrun', '--toolchain', 'XcodeDefault', 'swift', 'build', '--package-path', str(ROOT / 'native'),
                    '--scratch-path', str(ROOT / 'build/swiftpm-app'), '--build-system', 'native', '-c', 'release',
                    '--product', 'NTSDCatalogCheck'], check=True)
    pending = []
    for suffix in ('', '-control'):
        report_path = ROOT / 'docs/evidence' / f'character-ai{suffix}.json'
        report = json.loads(report_path.read_bytes())
        raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
        assert digest(raw) == report['sha256']
        temporary = ROOT / 'build/original' / f'character-ai{suffix}-check.json'
        temporary.write_text(pack(json.loads(raw)))
        fixture_root = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
        parents = [str(fixture_root / f'original-{key}{suffix}.json') for key in ('initial-loading', 'initial-loading-catalog', 'initial-loading-sounds')]
        result = subprocess.run([str(ROOT / 'build/swiftpm-app/release/NTSDCatalogCheck'), '--character-ai', str(temporary), *parents], capture_output=True, text=True)
        print(result.stdout, end='', flush=True)
        if result.returncode:
            print(result.stderr, end='', flush=True)
            result.check_returncode()
        fixture = fixture_root / ('original-' + report['corpus'])
        data = temporary.read_bytes()
        report.update(nativeComparison=result.stdout.strip(), fixture=fixture.name, fixtureSHA256=digest(data), fixtureBytes=len(data))
        pending.append((report_path, report, fixture, data))
    for report_path, report, fixture, data in pending:
        fixture.write_bytes(data)
        report_path.write_text(json.dumps(report, indent=2) + '\n')


def main():
    from oracle_wave_loader import digest
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--control', action='store_true')
    p.add_argument('--accept', action='store_true')
    args = p.parse_args()
    if args.accept:
        accept()
        return
    vm = CharacterAI(args.control)
    doc = vm.capture_ai()
    suffix = '-control' if args.control else ''
    path = ROOT / 'build/original' / f'character-ai{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(path.read_bytes()),
                  cases=len(doc['cases']), blocks=len(doc['blocks']), nativeComparison='pending')
    (ROOT / 'docs/evidence' / f'character-ai{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Captured', len(doc['cases']), 'character AI cases', flush=True)


if __name__ == '__main__':
    main()
