#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original two-fighter melee reference. See docs/COMBAT.md for boundaries."""

import hashlib
import json
import struct
import subprocess
import sys
import zlib

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from oracle_frames import BASE, COUNT, FRAME_RE, STACK, STRIDE, STUB
from oracle_movement import (
    ACTOR,
    BG,
    BYTES,
    DOUBLES,
    INPUT,
    INTS,
    MOVEMENT_FRAMES,
    PARAMS,
    WORLD,
    OriginalMovement,
)
from original_replay import REPLAY, replay_random
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import (
    UC_X86_REG_EAX,
    UC_X86_REG_EBP,
    UC_X86_REG_EBX,
    UC_X86_REG_EDI,
    UC_X86_REG_EDX,
    UC_X86_REG_EIP,
    UC_X86_REG_ESP,
)

B2 = 0x20100000
B3 = 0x20200000


class Combat(OriginalMovement):
    def run(self, start, stop):
        # Explicit boundary also when Unicorn reuses a translated block previously
        # entered with a different stopping address (post-scheduler/opoint slices).
        hook = self.uc.hook_add(
            UC_HOOK_CODE, lambda uc, a, s, d: uc.emu_stop(), begin=stop, end=stop
        )
        try:
            if start == 0x43E766:
                # This original loop recomputes strlen(key) for every decoded byte.
                self.uc.emu_start(start, stop, timeout=20_000_000, count=12_000_000)
                if self.uc.reg_read(UC_X86_REG_EIP) != stop:
                    raise RuntimeError("Replay prefix instruction/time limit")
            else:
                super().run(start, stop)
        finally:
            self.uc.hook_del(hook)

    def __init__(self):
        j = json.loads((ROOT / "build/imported/game.json").read_text())
        objs = [
            next(x for x in j["objects"] if x["source"] == src)
            for src in ["chars/naruto.dat", "chars/sasuke.dat"]
        ]
        ns = (
            MOVEMENT_FRAMES
            | set(range(60, 75))
            | {85, 95}
            | set(range(110, 115))
            | set(range(180, 192))
            | set(range(220, 232))
        )
        self.objs = objs
        self.defs = [
            [
                m[0]
                for m in FRAME_RE.finditer(o["originalText"])
                if int(m[1]) in (ns | ({240, 241, 242} if o["id"] == 11 else set()))
            ]
            for o in objs
        ]
        super().__init__(objs[0], self.defs[0])
        self.uc.mem_map(B2, 0x40000)
        self.uc.mem_write(B2, bytes(self.uc.mem_read(BASE, 0x40000)))
        self.uc.mem_write(BASE, b"\xa5" * 0x40000)
        self.defined = [set() for _ in range(COUNT)]
        for n in range(COUNT):
            self.call(0x40BBF0, BASE + 0x7A4 + n * STRIDE)
        for source in self.defs[1]:
            self.apply(source)
        for k, off in PARAMS.items():
            if off in (0, 24):
                self.put(BASE + off, int(objs[1]["header"][k]))
            else:
                self.double(BASE + off, float(objs[1]["header"][k]))
        self.put(BASE + 0x6F4, 11)
        self.put(BASE + 0x6F8, 0)
        voice = next(o for o in j["objects"] if o["id"] == 203)
        self.voice_defs = [
            m[0]
            for m in FRAME_RE.finditer(voice["originalText"])
            if int(m[1]) in (200, 201, 207, 208)
        ]
        for section in self.voice_defs:
            self.apply(section)
        self.uc.mem_map(B3, 0x40000)
        self.uc.mem_write(B3, bytes(self.uc.mem_read(BASE, 0x40000)))
        self.put(B3 + 0x6F4, 203)
        self.put(B3 + 0x6F8, 3)
        catalog = BG - 0x4D45DB0
        self.uc.mem_map(catalog & ~0xFFF, 0x1000)
        self.uc.mem_map(BG + 0x10000, 0x40000)
        for i, base in enumerate((B2, BASE, B3)):
            self.put(catalog + i * 4, base)
        self.put(catalog + 0x4D82380, 3)
        self.uc.mem_map(ACTOR + 0x10000, 0x90000)
        for i in range(400):
            self.put(WORLD + 0x194 + i * 4, ACTOR + i * 0x500)
        self.paths = {}
        for base in (BASE, B2):
            for n in range(COUNT):
                rec = base + 0x7A4 + n * STRIDE
                ptr = self.u32(rec + 0x170)
                if ptr:
                    self.paths[self.u32(rec + 0x174)] = self.cstr(ptr).decode("latin-1")
        self.put(0x447198, STUB + 0x500)
        self.uc.mem_write(
            STUB + 0x500, b"\x31\xc0\xc3"
        )  # Controlled CRT rand boundary: spark jitter only.
        self.rng = replay_random(
            DEFAULT_SOURCE, read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe")
        )
        self.reset2()

    def external(self, uc, addr, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if addr == 0x4450A0:
            return super().external(uc, addr, size, data)
        b = self.u32(sp + 8)
        self.events.append(
            getattr(self, "paths", {}).get(b, f"sound:{b}")
            if addr == 0x416FB0
            else f"builtin:{b}"
        )
        uc.reg_write(UC_X86_REG_ESP, sp + 4)
        uc.reg_write(UC_X86_REG_EIP, self.u32(sp))

    def reset2(self, frame=63, guard=False):
        self.uc.mem_write(WORLD + 4, b"\1\1" + b"\0" * 398)
        for i, base in enumerate((B2, BASE)):
            actor = ACTOR + i * 0x500
            self.uc.mem_write(actor, b"\0" * 0x420)
            self.call(0x4061D0, actor)
            self.put(actor + 0x368, base)
            for k, v in dict(x=450 + 35 * i, y=0, z=490, vx=0, vy=0, vz=0).items():
                self.double(actor + DOUBLES[k], v)
            for off, v in [
                (16, 450 + 35 * i),
                (20, 0),
                (24, 490),
                (0x70, frame if i == 0 else (110 if guard else 0)),
                (0x2F4, -1),
                (0x354, i),
                (0x364, i + 1),
            ]:
                self.put(actor + off, v)
            self.uc.mem_write(actor + 0x80, bytes([i]))
            self.put(0x450B4C + i * 4, -1)
        self.put(0x450C34, 0)
        self.put(0x450BCC, 0)
        self.events = []

    def contacts(self):
        for i in range(2):
            self.put(ACTOR + i * 0x500 + 0x2E4, 0)
        self.call(0x419380, WORLD, (0,))
        for i in range(2):
            self.call(0x42E100, WORLD, (i,))

    def prepare(self, initial):
        self.reset2(0)
        for i, values in enumerate(initial):
            a = ACTOR + i * 0x500
            for off in (0x28, 0x30, 0x38):
                self.double(a + off, 0)
            for key, value in values.items():
                if key in DOUBLES:
                    self.double(a + DOUBLES[key], value)
                elif key in INTS:
                    self.put(a + INTS[key], value)
                elif key in COMBAT_INTS:
                    self.put(a + COMBAT_INTS[key], value)
                elif key in ALL_BYTES:
                    self.uc.mem_write(a + ALL_BYTES[key], bytes([value & 255]))
                else:
                    raise ValueError(key)
            for integer, fp in [("ix", "x"), ("iy", "y"), ("iz", "z")]:
                self.put(
                    a + INTS[integer],
                    int(struct.unpack("<d", self.uc.mem_read(a + DOUBLES[fp], 8))[0]),
                )
        self.uc.mem_write(0x44FF90, bytes(self.rng["table"]))
        self.put(0x450BCC, self.rng["index"])
        self.put(0x450C34, 0)
        self.put(0x450BC4, 0)
        self.put(0x450BC8, 0)

    def snapshot_actor(self, i):
        a = ACTOR + i * 0x500
        motion = {
            k: struct.unpack("<i", self.uc.mem_read(a + off, 4))[0]
            for k, off in INTS.items()
        }
        motion.update(
            {
                k: struct.unpack("<d", self.uc.mem_read(a + off, 8))[0]
                for k, off in DOUBLES.items()
            }
        )
        motion.update(
            {k: int(self.uc.mem_read(a + off, 1)[0]) for k, off in BYTES.items()}
        )
        motion.update(
            sounds=[],
            cameraX=0,
            cameraVelocity=0,
            renderFrame=self.render[i][0],
            renderFacing=self.render[i][1],
        )
        motion.update(
            renderX=self.render[i][2],
            renderY=self.render[i][3],
            renderZ=self.render[i][4],
        )
        result = {
            k: struct.unpack("<i", self.uc.mem_read(a + off, 4))[0]
            for k, off in COMBAT_INTS.items()
        }
        result.update(
            {
                k: struct.unpack("<b", self.uc.mem_read(a + off, 1))[0]
                for k, off in COMBAT_BYTES.items()
            }
        )
        result.update(
            {
                k: struct.unpack("<d", self.uc.mem_read(a + off, 8))[0]
                for k, off in HIT_DOUBLES.items()
            }
        )
        result.update(
            **motion,
            vrest=[
                struct.unpack("<b", self.uc.mem_read(a + 0xF0 + n, 1))[0]
                for n in range(2)
            ],
            combos=list(self.uc.mem_read(a + 0xD4, 9)),
        )
        return result

    def tick2(self, masks):
        self.events = []
        self.uc.mem_write(INPUT, bytes(masks) + b"\0" * 6)
        self.call(0x4198F0, WORLD, (INPUT, 0, INPUT + 16))
        for i in range(2):
            a = ACTOR + i * 0x500
            self.call(0x413080, a, (0, 0))
            self.call(0x40E490, a)
        # Initial Z pass, as at 0x41eed3.
        self.call(0x417F80, WORLD)
        self.contacts()
        self.put(0x450B4C, 1)
        self.call(0x41B5D0, WORLD, (0, 0), stop=0x41BC74)
        self.put(0x450B4C, -1)
        self.render = [
            (
                self.u32(ACTOR + i * 0x500 + 0x70),
                self.uc.mem_read(ACTOR + i * 0x500 + 0x80, 1)[0],
                *[
                    struct.unpack("<i", self.uc.mem_read(ACTOR + i * 0x500 + off, 4))[0]
                    for off in (16, 20, 24)
                ],
            )
            for i in range(2)
        ]
        self.call(0x4196F0, WORLD)
        for i in range(2):
            self.call(0x40D960, ACTOR + i * 0x500, (0, i))
            self.uc.reg_write(UC_X86_REG_EBX, WORLD)
            self.uc.reg_write(UC_X86_REG_EDI, i)
            self.uc.reg_write(UC_X86_REG_ESP, STACK + 0x8000)
            self.run(0x41FB0B, 0x41FC61)
        # Original opoint branch for each fighter, including object allocation and
        # placement. Voice objects born in slots >=50 schedule later in this tick.
        for i in range(2):
            frame = self.u32(ACTOR + i * 0x500 + 0x70)
            rec = (B2 if i == 0 else BASE) + 0x7A4 + frame * STRIDE
            if (
                self.u32(rec + 0x58) > 0
                and self.u32(ACTOR + i * 0x500 + 0x88) == 0
                and self.u32(ACTOR + i * 0x500 + 0xB4) == 0
            ):
                if self.u32(rec + 0x70) != 203:
                    raise ValueError("Non-voice opoint outside melee domain")
                self.uc.reg_write(UC_X86_REG_EBX, WORLD)
                self.uc.reg_write(UC_X86_REG_EDI, i)
                self.uc.reg_write(UC_X86_REG_EDX, 0)
                self.uc.reg_write(UC_X86_REG_ESP, STACK + 0x8000)
                self.run(0x41FC61, 0x420E93)
        for i in range(50, 400):
            if self.uc.mem_read(WORLD + 4 + i, 1)[0]:
                self.call(0x40D960, ACTOR + i * 0x500, (0, i))
                assert self.u32(ACTOR + i * 0x500 + 0x70) == 1000
                self.uc.mem_write(WORLD + 4 + i, b"\0")
        result = dict(
            actors=[self.snapshot_actor(i) for i in range(2)],
            sounds=self.events.copy(),
            randomIndex=self.u32(0x450BCC),
            randomCounter=self.u32(0x450C34),
            cameraX=self.u32(0x450BC4),
            cameraVelocity=struct.unpack("<i", self.uc.mem_read(0x450BC8, 4))[0],
        )
        for i in range(2):
            a = ACTOR + i * 0x500
            for off in (0x2E8, 0x2EC, 0x2F0):
                self.put(a + off, 1000)
            self.put(a + 0x2E4, 0)
        return result


COMBAT_INTS = {
    "collisionFrame": 0x7C,
    "fall": 0xB0,
    "freeze": 0xB4,
    "guardDamage": 0xB8,
    "rest": 0xEC,
    "hp": 0x2FC,
    "redHP": 0x300,
    "mp": 0x308,
    "hitCount": 0x20,
    "fallHurt": 0x320,
    "invulnerability": 8,
    "damageDealt": 0x348,
    "damageReceived": 0x34C,
    "kills": 0x358,
}
COMBAT_BYTES = {
    "attackBuffer": 0xBE,
    "defendBuffer": 0xC0,
    "defendCooldown": 0xC1,
    "superPunch": 0xEA,
}
ALL_BYTES = {**BYTES, **COMBAT_BYTES}
HIT_DOUBLES = {"hitVX": 0x28, "hitVY": 0x30, "hitVZ": 0x38}


def scenarios():
    yield "punch", [{}, {}], [[8, 0]] + [[0, 0]] * 70
    yield "guard", [{}, {}], [[8, 2]] + [[0, 0]] * 70
    yield "held-attack", [{}, {}], [[8, 0]] * 90
    yield "punch-chain", [{}, {}], ([[8, 0]] + [[0, 0]] * 9) * 12 + [[0, 0]] * 100
    yield "heavy-hit", [{"frame": 72}, {}], [[0, 0]] * 100
    yield "heavy-guard", [{"frame": 72}, {"frame": 110}], [[0, 0]] * 100
    yield "rear-guard", [{"frame": 63}, {"frame": 110, "facing": 0}], [[0, 0]] * 70
    yield "air-hit", [{"frame": 72}, {"frame": 212, "y": -20}], [[0, 0]] * 100
    for z in [475, 476, 504, 505]:
        yield f"depth-{z}", [{"frame": 63}, {"z": z}], [[0, 0]] * 35
    yield "sasuke-punch", [{}, {"x": 480}], [[0, 8]] + [[0, 0]] * 70
    yield "sasuke-guarded", [{"frame": 110}, {"x": 480}], [[0, 8]] + [[0, 0]] * 70
    yield "mutual-punch", [{}, {}], [[8, 8]] + [[0, 0]] * 100
    yield "mutual-guard", [{}, {}], [[2, 2]] * 50 + [[8, 8]] + [[0, 0]] * 100
    yield "naruto-knockout", [{"hp": 15}, {"x": 480}], [[0, 8]] + [[0, 0]] * 150
    yield "naruto-falling", [{"fall": 60}, {"x": 480}], [[0, 8]] + [[0, 0]] * 150
    yield "both-knocked-out", [{"hp": 0}, {"hp": 0}], [[0, 0]] * 150
    yield (
        "naruto-run-attack",
        [{"x": 360}, {"x": 580}],
        [[16, 0], [0, 0]] + [[16, 0]] * 8 + [[24, 0]] + [[0, 0]] * 110,
    )
    yield "guard-held", [{}, {}], [[0, 2]] * 100
    yield (
        "guard-turn",
        [{}, {}],
        [[2, 0]] + [[18, 0]] * 8 + [[34, 0]] * 8 + [[0, 0]] * 30,
    )
    yield "lethal-punch", [{}, {"hp": 15}], [[8, 0]] + [[0, 0]] * 150
    yield "lethal-chip", [{"frame": 72}, {"frame": 110, "hp": 5}], [[0, 0]] * 150
    # Actual source rectangles, including multiple/auxiliary bodies. Each case
    # starts with both actors in a declared frame; no source box is rewritten.
    for frame in (63, 68, 72):
        for target in (0, 110, 112, 220, 222, 224, 226, 180, 230):
            for facing in (0, 1):
                for distance in (0, 10, 20, 30, 40, 50, 60, 70):
                    yield (
                        f"boxes-{frame}-{target}-{facing}-{distance}",
                        [
                            {"frame": frame},
                            {"frame": target, "facing": facing, "x": 450 + distance},
                        ],
                        [[0, 0]],
                    )
    for target in (0, 110):
        for x in (0, 20, 450, 920, 959):
            yield (
                f"heavy-left-{target}-{x}",
                [
                    {"frame": 72, "facing": 1, "x": x + 35},
                    {"frame": target, "facing": 0, "x": x},
                ],
                [[0, 0]] * 90,
            )
    # Re-run the prior movement corpus through the extended two-fighter pipeline.
    from oracle_movement import scenarios as movement_scenarios

    for label, initial, inputs in movement_scenarios():
        yield "movement-" + label, [initial, {}], [[m, 0] for m in inputs]


def random_reference(vm):
    raw = read_bytes(DEFAULT_SOURCE / REPLAY)
    address = 0x26000000
    vm.uc.mem_map(address, 0x640000)
    vm.uc.mem_write(address, raw[4:])
    sp = STACK + 0x8000
    vm.uc.reg_write(UC_X86_REG_ESP, sp)
    vm.uc.reg_write(UC_X86_REG_EBP, address)
    vm.put(sp + 0x14, len(raw) - 4)
    vm.run(0x43E766, 0x43E7D3)
    decoded = zlib.decompress(bytes(vm.uc.mem_read(address, len(raw) - 4)))
    vm.uc.mem_write(address, decoded)
    vm.uc.reg_write(UC_X86_REG_EAX, address)
    vm.run(0x43E3C5, 0x43E3F8)
    vm.put(0x450C34, 0)
    seed = replay_random(DEFAULT_SOURCE, read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe"))
    assert vm.u32(0x450BCC) == seed["index"]
    assert bytes(vm.uc.mem_read(0x44FF90, 3000)) == bytes(seed["table"])
    samples = []
    for i in range(6500):
        limit = [2, 3, 6, 16, 100, 1, 0, -1][i % 8]
        vm.call(0x417170, args=(130, limit))
        samples.append(
            dict(
                range=limit,
                value=vm.uc.reg_read(UC_X86_REG_EAX),
                index=vm.u32(0x450BCC),
                counter=vm.u32(0x450C34),
            )
        )
    return samples


def export_evidence(document, output):
    fixtures = {
        **document,
        "cases": [
            c for c in document["cases"] if not c["label"].startswith("movement-")
        ],
    }
    fixture_path = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-combat.json"
    fixture_path.write_text(json.dumps(fixtures, separators=(",", ":")) + "\n")
    report = dict(
        exeSHA256=EXE_SHA256,
        sequences=len(document["cases"]),
        ticks=sum(len(c["states"]) for c in document["cases"]),
        fixtureSequences=len(fixtures["cases"]),
        fixtureTicks=sum(len(c["states"]) for c in fixtures["cases"]),
        randomSamples=len(document["randomSamples"]),
        corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
        fixtureSHA256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
        replaySHA256=document["random"]["sourceSHA256"],
        addresses=dict(
            input="0x4198f0",
            control="0x413080",
            physics="0x40e490",
            collision="0x419380",
            hit="0x42e100",
            pendingVelocity="0x4196f0",
            scheduler="0x40d960",
            postScheduler="0x41fb0b..0x41fc61",
            voiceObjects="0x41fc61..0x420e93",
            random="0x417170",
            replayPrefix="0x43e766..0x43e7d3",
            replayRestore="0x43e3c5..0x43e3f8",
        ),
        scope=(
            "Two unarmed Naruto/Sasuke actors with controlled spawn and original "
            "replay RNG seed. Normal melee, guard, damage, falling, recovery, "
            "voices and prior movement corpus. Exact per-tick comparisons; no "
            "whole-match, hit-spark pixels, audio-mix or input latency equivalence."
        ),
    )
    (ROOT / "docs/evidence/combat-oracle.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )


def main():
    vm = Combat()
    vm.prepare([{}, {}])
    samples = random_reference(vm)
    cases = []
    for label, initial, inputs in scenarios():
        vm.prepare(initial)
        states = [vm.tick2(masks) for masks in inputs]
        cases.append(dict(label=label, initial=initial, inputs=inputs, states=states))
    document = dict(
        exeSHA256=EXE_SHA256,
        random=vm.rng,
        randomSamples=samples,
        headers=[o["header"] for o in vm.objs],
        definitions=vm.defs,
        voiceDefinitions=vm.voice_defs,
        cases=cases,
    )
    output = ROOT / "build/original/combat-oracle.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, separators=(",", ":")) + "\n")
    print(
        f"Captured {sum(len(c['states']) for c in cases)} combat ticks "
        f"in {len(cases)} sequences"
    )
    if "--capture-only" not in sys.argv:
        subprocess.run(
            [
                "swift",
                "build",
                "--package-path",
                str(ROOT / "native"),
                "-c",
                "release",
                "--product",
                "NTSDCombatCheck",
            ],
            check=True,
        )
        subprocess.run(
            [str(ROOT / "native/.build/release/NTSDCombatCheck"), str(output)],
            check=True,
        )
        export_evidence(document, output)


if __name__ == "__main__":
    main()
