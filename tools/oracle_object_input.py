#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Real406ba0(World,slot) called directly after verified first loading, under
declared World/Actor/RNG stimuli bound to real loaded Objects and Frames. Every
loaded non-character frame whose hit_Fa is one of the values used by the
original DAT (1,3,4,5,7,8,10,12,14) is the called Object's current frame in at
least one case. The main corpus runs under the original startup CW027f; the
control corpus uses CW037f over the control loading (ramp backing, reversed
Actor storage). No game code is stubbed; the constructor memset stays the
existing host boundary. The first case declares a match-start RNG table.
Values 2,6,9,11,13 are not stimulated.
"""
import argparse
import json
import random
import struct
import subprocess
from import_ntsd import EXE_SHA256, ROOT
from oracle_initial_loading import InitialLoading, transport
from oracle_catalog_sounds import pack, REGISTERS
from oracle_state import STACK, STOP
from oracle_wave_loader import GLOBAL, GLOBAL_SIZE
from unicorn import UC_HOOK_BLOCK, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_FPSW, UC_X86_REG_FPTAG

RECOVERED = (1, 3, 4, 5, 7, 8, 10, 12, 14)
BODY = (0x406BA0, 0x408CAE)
ALLOWED = [BODY, (0x4061D0, 0x4064CD), (0x417170, 0x4171BD), (0x4034E0, 0x4034EB), (0x4450A0, 0x4450A1)]
RNG_WORDS = {0x450BCC, 0x450C34}


class ObjectInput(InitialLoading):
    def __init__(self, control=False):
        super().__init__(control)
        self.running = False
        self.blocks = set()
        self.uc.hook_add(UC_HOOK_BLOCK, self.block)
        for pc in (0x417170, 0x41717C, 0x4171BC):
            self.uc.hook_add(UC_HOOK_CODE, self.rng, begin=pc, end=pc)

    def block(self, uc, address, size, data):
        if not self.running:
            return
        assert any(a <= address < b for a, b in ALLOWED) or address == STOP, hex(address)
        if BODY[0] <= address < BODY[1]:
            self.blocks.add(address)

    def rng(self, uc, address, size, data):
        if not self.running:
            return
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x417170:
            self.random.append(dict(stream=self.u32(sp + 4), range=self.u32(sp + 8), caller=self.u32(sp),
                                    before=[self.u32(0x450BCC), self.u32(0x450C34)]))
        else:
            self.random[-1]['result'] = uc.reg_read(UC_X86_REG_EAX)

    def s32(self, address):
        return struct.unpack('<i', self.uc.mem_read(address, 4))[0]

    def raw(self, region):
        return bytes(self.uc.mem_read(region['address'], region['size'])), bytes(region['mask'])

    def call(self, label, slot, stimulus, cw):
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
        before_actors = [self.raw(r) for r in self.pool]
        before_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        calls_before = len(self.actor_calls)
        self.random = []
        sp = STACK + 0xD000
        self.uc.mem_write(sp, struct.pack('<II', STOP, slot))
        saved = [0x11111111, 0x22222222, 0x33333333, 0x44444444]
        for reg, value in zip(REGISTERS, saved):
            self.uc.reg_write(reg, value)
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, self.world_address)
        self.uc.reg_write(UC_X86_REG_FPCW, cw)
        # Unicorn's reset leaves x87 registers tagged valid; QEMU ignores tags
        # for overflow. Declare an empty stack so an unbalanced path is visible.
        self.uc.reg_write(UC_X86_REG_FPTAG, 0xFFFF)
        top = (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7
        tag = self.uc.reg_read(UC_X86_REG_FPTAG)
        self.running = True
        try:
            self.execute(0x406BA0, STOP)
        finally:
            self.running = False
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 8, label
        assert [self.uc.reg_read(r) for r in REGISTERS] == saved, label
        fpu = [top, (self.uc.reg_read(UC_X86_REG_FPSW) >> 11) & 7, tag, self.uc.reg_read(UC_X86_REG_FPTAG)]
        assert fpu[0] == fpu[1] and fpu[2] == fpu[3] == 0xFFFF, (label, fpu)
        assert self.uc.reg_read(UC_X86_REG_FPCW) == cw, label
        undefined = sorted([list(r) for r in self.reads_before_writes])
        self.reads_before_writes.clear()
        after_globals = bytes(self.uc.mem_read(GLOBAL, GLOBAL_SIZE))
        words = {GLOBAL + (i & ~3) for i in range(GLOBAL_SIZE) if after_globals[i] != before_globals[i]}
        assert words <= RNG_WORDS, (label, sorted(hex(w) for w in words))
        actors = {}
        for i, r in enumerate(self.pool):
            if self.raw(r) != before_actors[i]:
                actors[str(i)] = {k: v for k, v in self.record(r).items() if k != 'initial'}
        world = {k: v for k, v in self.record(self.world).items() if k != 'initial'}
        return dict(label=label, slot=slot, controlWord=cw, stimulus=stimulus, random=self.random,
                    constructors=self.actor_calls[calls_before:], undefinedReads=undefined, fpu=fpu, rng=[self.u32(0x450BCC), self.u32(0x450C34)],
                    world=world, actors=actors)

    def parents(self):
        parent = super().capture()
        suffix = '-control' if self.control else ''
        parents = {}
        from oracle_wave_loader import digest
        for key, doc in zip(('initial-loading', 'initial-loading-catalog', 'initial-loading-sounds'), parent):
            report = json.loads((ROOT / 'docs/evidence' / f'initial-loading{suffix}.json').read_bytes())[key]
            raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
            actual = (json.dumps(doc, separators=(',', ':')) + '\n').encode()
            assert digest(raw) == report['sha256'] and actual == raw, key
            parents[key] = dict(fixture=report['fixture'], sha256=report['fixtureSHA256'])
        return parents

    def capture_inputs(self):
        parents = self.parents()
        print('Verified parent reproduced', flush=True)
        for k in range(400):
            assert self.u32(self.world_address + 0x194 + 4 * k) == self.pool[k]['address']
        R = random.Random(0x406BA0 + int(self.control))
        cw = 0x37F if self.control else 0x27F
        objects = []
        for n, a in enumerate(self.object_addresses):
            frames = [(self.s32(a + 0x7A4 + f * 0x178 + 8), self.s32(a + 0x7A4 + f * 0x178 + 0x30)) for f in range(400)]
            objects.append(dict(ordinal=n, type=self.s32(a + 0x6F8), id=self.s32(a + 0x6F4), frames=frames))
        characters = [o for o in objects if o['type'] == 0]
        # Only defined character frames (nonzero state or frame0) are used as targets.
        standing = [(o['ordinal'], f) for o in characters for f, (state, _) in enumerate(o['frames']) if state not in (0, 14) or f == 0]
        lying = [(o['ordinal'], f) for o in characters for f, (state, _) in enumerate(o['frames']) if state == 14]
        others = [(o['ordinal'], 0) for o in objects if o['type'] != 0]
        assert lying and standing
        selves = {h: [(o['ordinal'], f) for o in objects if o['type'] != 0 for f, (_, hit) in enumerate(o['frames']) if hit == h] for h in RECOVERED}
        cases = []

        def d(value):
            return struct.pack('<d', value).hex()

        def i32(value):
            return struct.pack('<i', value).hex()

        def number(scale, specials):
            if R.random() < 0.35:
                return R.choice(specials)
            return round(R.uniform(-scale, scale), R.choice([0, 1, 2, 6, 12]))

        def scenario(h, binding, index):
            s = R.choice([10, 11, 49, 50, 51, 120, 250, 398, 399]) if R.random() < 0.3 else R.randrange(10, 400)
            activity = [0] * 400
            bindings = {s: binding}
            writes = []

            def put(slot, offset, raw):
                writes.append(dict(slot=slot, offset=offset, bytes=raw))
            sx, sy, sz = R.randint(-100, 3000), R.choice([0, -1, -24, -25, -26, R.randint(-250, 20)]), R.randint(100, 600)
            steps = [0, 1, -1, 5, -5, 6, -6, 7, -7, 8, -8, 10, -10, 11, -11, 29, -29, 30, -30, 31, -31, 79, -79, 80, -80, 81]
            activity[s] = R.choice([1] * 10 + [0x80, 2, 0])
            team = R.randint(0, 3)
            slots = [k for k in range(400) if k != s]
            count = R.choice([0, 1, 1, 2, 2, 3, 3, 4, 5, 6, 8, 12])
            chars = R.sample(R.choice([slots[:10] + slots[10:60], slots]), count)
            for k in chars:
                bindings[k] = R.choice(lying) if R.random() < 0.2 else R.choice(standing)
                activity[k] = R.choice([1] * 7 + [0x80, 2])
                put(k, 0x8, i32(R.choice([0] * 8 + [1, 2, 3, -2, -3, -2147483648])))
                put(k, 0x10, i32(sx + (R.choice(steps) if R.random() < 0.5 else R.randint(-400, 400))))
                put(k, 0x14, i32(sy + (R.choice(steps) if R.random() < 0.5 else R.randint(-120, 40))))
                put(k, 0x18, i32(sz + (R.choice(steps) if R.random() < 0.5 else R.randint(-60, 60))))
                put(k, 0x60, d(number(150, [0.0, -40.0, -10.0, float(sy)])))
                put(k, 0x2FC, i32(R.choice([500, 300, 1, 0, -1])))
                put(k, 0x364, i32(R.choice([team, team, R.randint(0, 3)])))
            extra = R.sample([k for k in slots if k not in chars], R.choice([0, 0, 1, 3]))
            for k in extra:
                bindings[k] = R.choice(others)
                activity[k] = R.choice([1, 0x80])
                put(k, 0x364, i32(R.randint(0, 3)))
                put(k, 0x2FC, i32(500))
            pressure = R.random()
            if pressure < 0.08:
                for k in range(50, 400):
                    if k not in bindings:
                        bindings[k] = R.choice(others)
                        activity[k] = 1
            elif pressure < 0.16:
                free = [k for k in range(50, 400) if k not in bindings]
                keep = R.choice(free)
                for k in free:
                    if k != keep:
                        bindings[k] = R.choice(others)
                        activity[k] = 1
            hp = R.choice([500, 500, 500, 1, 0, -3])
            alive = hp > 0 and activity[s] == 1
            candidates = [k for k in chars] + [s] + extra
            target = R.choice([-1, -1] + candidates) if candidates else -1
            if h == 4 or (h == 7 and alive):
                target = R.choice(candidates) if chars else R.choice(chars or candidates)
            if target >= 0 and target not in bindings:
                bindings[target] = R.choice(standing)
            owner = R.choice([-1, -1, -7] + chars + [s])
            put(s, 0x10, i32(sx)); put(s, 0x14, i32(sy)); put(s, 0x18, i32(sz))
            put(s, 0x40, d(number(35, [0.0, -0.0, 13.0, -13.0, 14.0, -14.0, 16.0, 17.0, -17.0, 30.0, -30.0, 13.5, -29.95])))
            put(s, 0x48, d(number(8, [0.0, 4.0, 3.99, 3.6, -1.4, 1.4])))
            put(s, 0x50, d(number(4, [0.0, 2.0, -2.0, 2.2, -2.2, 1.5, -1.5, 2.4, -2.4, 2.1])))
            put(s, 0x58, d(float(sx) + R.choice([0.0, 0.25, -0.5])))
            put(s, 0x60, d(number(120, [0.0, 1.0, 1.4, 3.0, 0.5, -0.5, 1.2, float(sy)])))
            put(s, 0x68, d(float(sz) + R.choice([0.0, 0.75])))
            put(s, 0x80, bytes([R.randint(0, 1)]).hex())
            put(s, 0x2F8, i32(owner)); put(s, 0x2FC, i32(hp)); put(s, 0x354, i32(R.choice([99, 3, 7, -1])))
            put(s, 0x364, i32(team)); put(s, 0x3F8, i32(target))
            g = []
            if R.random() < 0.5:
                g.append(dict(address=0x450BCC, bytes=struct.pack('<I', R.randrange(3000)).hex()))
                g.append(dict(address=0x450C34, bytes=struct.pack('<I', R.randrange(1234)).hex()))
            stimulus = dict(globals=g, world=[dict(offset=4, bytes=bytes(activity).hex())], actors=writes,
                            bindings=[dict(slot=k, object=o, frame=f) for k, (o, f) in sorted(bindings.items())])
            return s, stimulus

        # A match-start game RNG table as 422ac0 builds it: 3000 VC80 rand()%255+1
        # draws from a declared CRT seed, then the zero terminator.
        crt, table = 0x406BA0 + 17 * int(self.control), bytearray()
        for _ in range(3000):
            crt = (crt * 0x343FD + 0x269EC3) & 0xFFFFFFFF
            table.append(((crt >> 16) & 0x7FFF) % 255 + 1)
        table_write = dict(address=0x44FF90, bytes=(bytes(table) + b'\0').hex())
        for h in RECOVERED:
            frames = selves[h]
            assert frames, h
            total = max(40, 3 * len(frames))
            for index in range(total):
                binding = frames[index % len(frames)]
                s, stimulus = scenario(h, binding, index)
                if not cases:
                    stimulus['globals'].insert(0, table_write)
                cases.append(self.call(f'hit{h}-{index}', s, stimulus, cw))
            print('hit_Fa', h, 'cases', total, 'blocks', len(self.blocks), flush=True)
        doc = dict(exeSHA256=EXE_SHA256, scope=__doc__, parents=parents, worldAddress=self.world_address,
                   objectAddresses=self.object_addresses, actorAddresses=[r['address'] for r in self.pool],
                   controlWord=cw, blocks=sorted(self.blocks), cases=cases)
        return transport(doc, self.blobs)


def accept():
    from oracle_wave_loader import digest
    subprocess.run(['xcrun', '--toolchain', 'XcodeDefault', 'swift', 'build', '--package-path', str(ROOT / 'native'),
                    '--scratch-path', str(ROOT / 'build/swiftpm-app'), '--build-system', 'native', '-c', 'release',
                    '--product', 'NTSDCatalogCheck'], check=True)
    pending = []
    for suffix in ('', '-control'):
        report_path = ROOT / 'docs/evidence' / f'object-input{suffix}.json'
        report = json.loads(report_path.read_bytes())
        raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
        assert digest(raw) == report['sha256']
        temporary = ROOT / 'build/original' / f'object-input{suffix}-check.json'
        temporary.write_text(pack(json.loads(raw)))
        fixture_root = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
        parents = [str(fixture_root / f'original-{key}{suffix}.json') for key in ('initial-loading', 'initial-loading-catalog', 'initial-loading-sounds')]
        result = subprocess.run([str(ROOT / 'build/swiftpm-app/release/NTSDCatalogCheck'), '--object-input', str(temporary), *parents], capture_output=True, text=True)
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
    vm = ObjectInput(args.control)
    doc = vm.capture_inputs()
    suffix = '-control' if args.control else ''
    path = ROOT / 'build/original' / f'object-input{suffix}.json'
    path.write_text(json.dumps(doc, separators=(',', ':')) + '\n')
    report = dict(exeSHA256=EXE_SHA256, scope=__doc__, corpus=path.name, sha256=digest(path.read_bytes()),
                  cases=len(doc['cases']), blocks=len(doc['blocks']), nativeComparison='pending')
    (ROOT / 'docs/evidence' / f'object-input{suffix}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Captured', len(doc['cases']), 'object input cases', flush=True)


if __name__ == '__main__':
    main()
