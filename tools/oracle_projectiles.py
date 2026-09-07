#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original spawned-object/Chidori reference; development-only x86 execution."""

import hashlib
import json
import struct
import subprocess
import sys

from import_ntsd import EXE_SHA256, ROOT
from oracle_combat import B2, B3, Combat
from oracle_combat import scenarios as melee_scenarios
from oracle_frames import BASE, COUNT, FRAME_RE, STACK, STRIDE
from oracle_movement import ACTOR, BG, INPUT, WORLD
from unicorn.x86_const import (
    UC_X86_REG_EBX,
    UC_X86_REG_ECX,
    UC_X86_REG_EDI,
    UC_X86_REG_EDX,
    UC_X86_REG_ESP,
)

PROJECTILE_FRAMES = {224: set(range(8)), 440: set(range(1, 14))}
SASUKE_FRAMES = {246, *range(261, 267)}


class Projectiles(Combat):
    def __init__(self):
        super().__init__()
        j = json.loads((ROOT / "build/imported/game.json").read_text())
        self.catalog = []
        self.local_player = 0
        # Extend Sasuke's real sections; the previous slices remain unchanged.
        extra = [
            m[0]
            for m in FRAME_RE.finditer(self.objs[1]["originalText"])
            if int(m[1]) in SASUKE_FRAMES
        ]
        self.defs[1] += extra
        for s in extra:
            self.apply(s)
        sasuke = bytes(self.uc.mem_read(BASE, 0x40000))
        self.bases = {2: B2, 11: BASE, 203: B3}
        voice = next(o for o in j["objects"] if o["id"] == 203)
        self.voice_defs += [
            m[0] for m in FRAME_RE.finditer(voice["originalText"]) if int(m[1]) == 334
        ]
        for oid, numbers in {
            203: {200, 201, 207, 208, 334},
            **PROJECTILE_FRAMES,
        }.items():
            self.uc.mem_write(BASE, b"\xa5" * 0x40000)
            self.defined = [set() for _ in range(COUNT)]
            for n in range(COUNT):
                self.call(0x40BBF0, BASE + 0x7A4 + n * STRIDE)
            # Header defaults 0x40efe2..0x40f01a (no weapon header overrides).
            for off in range(0x90, 0xA4, 4):
                self.put(BASE + off, 0)
            for off in (0xA4, 0xA8, 0xAC):
                self.put(BASE + off, -1)
            self.put(BASE + 0x6F4, oid)
            self.put(BASE + 0x6F8, 3)
            obj = next(o for o in j["objects"] if o["id"] == oid)
            defs = [
                m[0]
                for m in FRAME_RE.finditer(obj["originalText"])
                if int(m[1]) in numbers
            ]
            for s in defs:
                self.apply(s)
            base = B3 if oid == 203 else 0x20300000 + len(self.catalog) * 0x100000
            if oid != 203:
                self.uc.mem_map(base, 0x40000)
            self.uc.mem_write(base, bytes(self.uc.mem_read(BASE, 0x40000)))
            self.bases[oid] = base
            if oid != 203:
                self.catalog.append(dict(id=oid, definitions=defs))
        self.uc.mem_write(BASE, sasuke)
        for i, base in enumerate(self.bases.values()):
            self.put(BG - 0x4D45DB0 + i * 4, base)
        self.put(BG - 0x4D45DB0 + 0x4D82380, len(self.bases))
        for base in self.bases.values():
            for n in range(COUNT):
                rec = base + 0x7A4 + n * STRIDE
                ptr = self.u32(rec + 0x170)
                if ptr:
                    self.paths[self.u32(rec + 0x174)] = self.cstr(ptr).decode("latin-1")
        self.put(0x44D034, 1)  # Original chakra-spending flag; no infinite-MP cheat.

    def active(self):
        return [i for i in range(400) if self.uc.mem_read(WORLD + 4 + i, 1)[0]]

    def rec(self, i):
        a = ACTOR + i * 0x500
        return self.u32(a + 0x368) + 0x7A4 + self.u32(a + 0x70) * STRIDE

    def registers(self, i):
        self.uc.reg_write(UC_X86_REG_EBX, WORLD)
        self.uc.reg_write(UC_X86_REG_EDI, i)
        self.uc.reg_write(UC_X86_REG_EDX, 0)
        self.uc.reg_write(UC_X86_REG_ESP, STACK + 0x8000)

    def pose(self, i):
        a = ACTOR + i * 0x500
        return (
            self.u32(a + 0x70),
            self.uc.mem_read(a + 0x80, 1)[0],
            *[
                struct.unpack("<i", self.uc.mem_read(a + off, 4))[0]
                for off in (16, 20, 24)
            ],
        )

    def snapshot_actor(self, i):
        result = super().snapshot_actor(i)
        result["vrest"] = list(
            struct.unpack("400b", self.uc.mem_read(ACTOR + i * 0x500 + 0xF0, 400))
        )
        return result

    def tick2(self, masks):
        self.events = []
        self.uc.mem_write(INPUT, bytes(masks) + b"\0" * 6)
        self.call(0x4198F0, WORLD, (INPUT, 0, INPUT + 16))
        for i in self.active():
            self.call(0x413080, ACTOR + i * 0x500, (0, 0))
        for i in self.active():
            self.call(0x40E490, ACTOR + i * 0x500)
        self.call(0x417F80, WORLD)
        self.call(0x419380, WORLD, (0,))
        for i in self.active():
            self.call(0x42E100, WORLD, (i,))
        self.put(0x450B4C, 1 if self.local_player == 0 else -1)
        self.put(0x450B50, 1 if self.local_player == 1 else 0)
        self.call(0x41B5D0, WORLD, (0, 0), stop=0x41BC74)
        self.put(0x450B4C, -1)
        self.put(0x450B50, -1)
        self.render = {i: self.pose(i) for i in self.active()}
        draws = [
            dict(
                slot=i,
                id=self.u32(self.u32(ACTOR + i * 0x500 + 0x368) + 0x6F4),
                frame=p[0],
                facing=p[1],
                x=p[2],
                y=p[3],
                z=p[4],
            )
            for i, p in self.render.items()
            if i >= 50
        ]
        self.call(0x4196F0, WORLD)
        for i in range(400):
            if not self.uc.mem_read(WORLD + 4 + i, 1)[0]:
                continue
            self.call(0x40D960, ACTOR + i * 0x500, (0, i))
            self.registers(i)
            if self.u32(ACTOR + i * 0x500 + 0x70) >= 400:
                # Actual original invalid-frame deletion branch.
                self.uc.reg_write(UC_X86_REG_ECX, ACTOR + i * 0x500)
                self.run(0x4213A9, 0x4214C6)
                continue
            self.run(0x41FB0B, 0x41FC61)
            rec = self.rec(i)
            if self.u32(rec + 0x58) > 0:
                if self.u32(rec + 0x70) not in self.bases:
                    raise ValueError("Unsupported object ID")
                self.registers(i)
                self.run(0x41FC61, 0x420E93)
        objects = []
        for i in self.active():
            if i < 50:
                continue
            a = ACTOR + i * 0x500
            # Rendering is a separate draw list. These legacy movement-only
            # fields are neutral in projectile state, not original actor storage.
            self.render[i] = (0, 0, 480, 0, 490)
            objects.append(
                dict(
                    slot=i,
                    id=self.u32(self.u32(a + 0x368) + 0x6F4),
                    owner=self.u32(a + 0x354),
                    team=self.u32(a + 0x364),
                    motion=self.snapshot_actor(i),
                )
            )
        result = dict(
            actors=[self.snapshot_actor(i) for i in range(2)],
            sounds=self.events.copy(),
            randomIndex=self.u32(0x450BCC),
            randomCounter=self.u32(0x450C34),
            cameraX=self.u32(0x450BC4),
            cameraVelocity=struct.unpack("<i", self.uc.mem_read(0x450BC8, 4))[0],
            projectiles=objects,
            projectileDraws=draws,
            mpSpent=[self.u32(ACTOR + i * 0x500 + 0x350) for i in range(2)],
        )
        for i in self.active():
            a = ACTOR + i * 0x500
            for off in (0x2E8, 0x2EC, 0x2F0):
                self.put(a + off, 1000)
            self.put(a + 0x2E4, 0)
            self.uc.mem_write(a + 0xEB, b"\0")
        return result


def scenarios():
    yield "snake", [{"x": 360}, {"frame": 70, "x": 450}], [[0, 0]] * 70
    yield (
        "snake-guard",
        [{"x": 360, "frame": 110}, {"frame": 70, "x": 450}],
        [[2, 0]] * 70,
    )
    for side in (0, 1):
        for x in (350, 400, 450, 500, 540):
            initial = [
                {"x": x if side else 1160 - x, "facing": 1 - side},
                {"x": 580, "facing": side},
            ]
            for guard in (False, True):
                inputs = [[0, 2], [0, 32 if side else 16], [0, 8]] + [
                    [2 if guard and t >= 16 else 0, 0] for t in range(67)
                ]
                yield f"needles-{side}-{x}-guard{guard}", initial, inputs
    for aim in (64, 128, 192):
        yield (
            f"aim-{aim}",
            [{"x": 400}, {"x": 580}],
            [[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 17 + [[0, aim]] * 50,
        )
    for mp in (0, 99, 100):
        yield (
            f"mp-{mp}",
            [{"x": 400}, {"x": 580, "mp": mp}],
            [[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 67,
        )
    yield (
        "snake-mirrored",
        [{"x": 540, "facing": 1}, {"frame": 70, "x": 450, "facing": 0}],
        [[0, 0]] * 70,
    )
    yield "snake-from-attack", [{"x": 450}, {"x": 495}], [[0, 8]] * 160
    yield (
        "slot-reuse-mp-exhaustion",
        [{"x": 100}, {"x": 580}],
        ([[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 67) * 7,
    )
    for hp in (2, 25, 50):
        for guard in (False, True):
            yield (
                f"lethal-{hp}-guard{guard}",
                [{"x": 400, "hp": hp}, {"x": 580}],
                [[0, 2], [0, 32], [0, 8]]
                + [[2 if guard and t >= 16 else 0, 0] for t in range(117)],
            )
    for z in (450, 475, 476, 490, 504, 505, 525):
        yield (
            f"depth-{z}",
            [{"x": 400, "z": z}, {"x": 580}],
            [[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 67,
        )
    for z in (450, 525):
        for aim in (64, 128):
            yield (
                f"edge-aim-{z}-{aim}",
                [{"x": 400, "z": z}, {"x": 580, "z": z}],
                [[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 17 + [[0, aim]] * 50,
            )
    for state in (
        {"frame": 212, "y": -35, "vy": -4},
        {"frame": 186, "y": -30, "vy": -4},
        {"invulnerability": 30},
    ):
        yield (
            f"target-{state}",
            [{"x": 400, **state}, {"x": 580}],
            [[0, 2], [0, 32], [0, 8]] + [[0, 0]] * 97,
        )
    for label, initial, inputs in melee_scenarios():
        yield "regression-" + label, initial, inputs


def export_evidence(document, output):
    retained = {
        "snake",
        "snake-guard",
        "snake-mirrored",
        "snake-from-attack",
        "needles-0-400-guardFalse",
        "needles-0-400-guardTrue",
        "needles-1-500-guardFalse",
        "needles-1-500-guardTrue",
        "aim-64",
        "aim-128",
        "aim-192",
        "mp-0",
        "mp-99",
        "mp-100",
        "slot-reuse-mp-exhaustion",
        "lethal-2-guardTrue",
        "lethal-25-guardFalse",
        "depth-505",
        "edge-aim-450-128",
        "edge-aim-525-64",
    }
    fixture = {
        **document,
        "cases": [c for c in document["cases"] if c["label"] in retained],
    }
    path = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-projectiles.json"
    path.write_text(json.dumps(fixture, separators=(",", ":")) + "\n")
    report = dict(
        exeSHA256=EXE_SHA256,
        sequences=len(document["cases"]),
        ticks=sum(len(c["states"]) for c in document["cases"]),
        projectileSequences=sum(
            not c["label"].startswith("regression-") for c in document["cases"]
        ),
        projectileTicks=sum(
            len(c["states"])
            for c in document["cases"]
            if not c["label"].startswith("regression-")
        ),
        fixtureSequences=len(fixture["cases"]),
        fixtureTicks=sum(len(c["states"]) for c in fixture["cases"]),
        corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
        fixtureSHA256=hashlib.sha256(path.read_bytes()).hexdigest(),
        replaySHA256=document["random"]["sourceSHA256"],
        addresses=dict(
            constructor="0x4061d0",
            headerDefaults="0x40efe2..0x40f01a",
            input="0x4198f0",
            control="0x413080",
            comboTransfer="0x40e2d0",
            physics="0x40e490",
            collision="0x419380",
            hit="0x42e100",
            boundsCamera="0x41b5d0..0x41bc74",
            pending="0x4196f0",
            scheduler="0x40d960",
            postScheduler="0x41fb0b..0x41fc61",
            spawn="0x41fc61..0x420e93",
            deletion="0x4213a9..0x4214c6",
        ),
        scope=(
            "Two Naruto/Sasuke fighters, voice 203, snake 224, Chidori needles 440; "
            "original replay RNG. Exact per-tick states, 400-slot vrest, draw poses, "
            "sounds and MP spending. Includes previous melee/movement sequences "
            "with the object pipeline enabled. No whole-match, regeneration, "
            "pixel/audio-mix or latency equivalence."
        ),
    )
    (ROOT / "docs/evidence/projectiles-oracle.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )
    print(
        f"Retained {report['fixtureTicks']} ticks / "
        f"{report['fixtureSequences']} offline cases"
    )


def main():
    vm = Projectiles()
    cases = []
    for number, (label, initial, inputs) in enumerate(scenarios()):
        vm.local_player = number % 2
        vm.prepare(initial)
        states = [vm.tick2(masks) for masks in inputs]
        cases.append(
            dict(
                label=label,
                localPlayer=vm.local_player,
                initial=initial,
                inputs=inputs,
                states=states,
            )
        )
    doc = dict(
        exeSHA256=EXE_SHA256,
        random=vm.rng,
        randomSamples=[],
        headers=[o["header"] for o in vm.objs],
        definitions=vm.defs,
        voiceDefinitions=vm.voice_defs,
        projectileDefinitions=vm.catalog,
        cases=cases,
    )
    output = ROOT / "build/original/projectiles-oracle.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    print(
        f"Captured {sum(len(c['states']) for c in cases)} ticks / {len(cases)} cases",
        flush=True,
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
        export_evidence(doc, output)


if __name__ == "__main__":
    main()
