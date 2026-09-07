#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""R01.1: run the original dispatch/match control flow with synthetic loaded data.

No game function is replaced to assemble the tick. Platform drawing/presentation,
two socket thunks and the inherited documented CRT/audio boundaries are replaced.
The partial DAT/header initialization is inherited from Projectiles. Therefore
this is a control-flow witness, NOT a full-match or Swift-equivalence oracle.
See docs/research/TICK_PIPELINE.md for the initialization and remaining gaps.
"""
import hashlib
import json

from import_ntsd import EXE_SHA256, ROOT
from oracle_frames import STACK, STOP, STUB
from oracle_movement import ACTOR, WORLD
from oracle_projectiles import Projectiles
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (
    UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EDI,
    UC_X86_REG_EIP, UC_X86_REG_ESI, UC_X86_REG_ESP,
)

MATCH = 0x458B00
# callee stack cleanup, argument count, interpretation; return EAX=0.
BOUNDARIES = {
    0x401250: (0, 2, "surface clear"),
    0x401290: (0, 6, "platform text output"),
    0x43F010: (24, 6, "bitmap output"),
    0x43F310: (28, 7, "bitmap rectangle output"),
    0x43E940: (0, 1, "DirectDraw presentation dispatch"),
    0x43F396: (16, 4, "WSOCK32 ordinal 101; return 0, no events"),
    0x43F3D8: (12, 3, "WSOCK32 ordinal 12; return 0, zero pending bytes"),
}
CALL_ARGS = {
    0x43ECBA: 1, 0x424741: 1, 0x41C5E0: 3, 0x41D490: 3,
    0x41E35F: 2, 0x41E390: 2, 0x41E3C1: 2, 0x41EEF6: 1,
    0x41EF42: 1, 0x41EF6C: 2, 0x41F299: 1, 0x41F491: 2,
    0x41F4A7: 3, 0x41FB06: 2, 0x421A28: 1, 0x4229A3: 2,
}
MARKERS = {
    0x43E9A0: "dispatcher-entry", 0x4246B0: "mode-entry", 0x41BC90: "match-entry",
    0x41D73B: "paused-draw", 0x41D7AC: "advance-periodic-counters",
    0x41E339: "control-pass", 0x41E634: "physics-pass",
    0x41EEFB: "type-zero-hits-pass", 0x41EF55: "item-spawn-check",
    0x41F276: "positive-type-hits-pass", 0x41F2B8: "linked-object-validation",
    0x41F545: "per-slot-lifecycle-pass", 0x4214D5: "requested-item-spawn",
    0x42179B: "resource-and-contact-cleanup-pass", 0x4229CC: "match-dialog-path",
    0x422AB8: "match-return", 0x428805: "mode-return", 0x43ED01: "dispatcher-return",
}
GLOBAL_FIELDS = {
    "phase": 0x450B90, "pause": 0x450BFC, "pendingPause": 0x44FB60,
    "followingPause": 0x44FCB0, "period12": 0x450BD0, "period3": 0x450BD4,
    "alternate": 0x450BD8, "inputTicks": 0x450B8C, "randomIndex": 0x450BCC,
    "randomCounter": 0x450C34, "cameraX": 0x450BC4, "cameraVelocity": 0x450BC8,
}


class TickTrace(Projectiles):
    def __init__(self, *, pause=False, refill=False, projectile=False):
        super().__init__()
        self.prepare([{"x": 350}, {"x": 550}])
        self.uc.mem_map(0, 0x1000)  # Only fs:[0] for original SEH prologue/epilogue.
        self.put(0, 0xFFFFFFFF)
        for slot in range(2, 400):
            self.call(0x4061D0, ACTOR + slot * 0x500)
        # Known control selectors, not a claim about the original new-match defaults.
        self.selectors = {
            0x450B90: 0, 0x450BFC: int(pause), 0x44FB60: int(pause),
            0x44FCB0: int(pause), 0x44D05C: 0, 0x44D020: 0, 0x450BDC: 0,
            0x451160: 0, 0x4593A0: 0, 0x44DCE4: 0, 0x44D02C: 1,
            0x450B4C: 1, 0x450B50: 2,
        }
        for address, value in self.selectors.items():
            self.put(address, value)
        # Existing loaded-object fixture relocated to the original static World.
        self.put(WORLD, 2)
        if refill:
            self.put(ACTOR + 0x308, 100)
            self.put(ACTOR + 0x2FC, 400)
        if projectile:
            actor = ACTOR + 50 * 0x500
            self.put(actor + 0x368, self.bases[440])
            self.put(actor + 0x70, 1)
            self.put(actor + 0x354, 1)
            self.put(actor + 0x364, 2)
            self.put(actor + 0x2F4, -1)
            for offset, value in [(0x58, 800), (0x60, 0), (0x68, 490)]:
                self.double(actor + offset, value)
            for offset, value in [(0x10, 800), (0x14, 0), (0x18, 490)]:
                self.put(actor + offset, value)
            self.uc.mem_write(WORLD + 4 + 50, b"\1")
        self.uc.mem_write(MATCH, bytes(self.uc.mem_read(WORLD, 0x7D8)))
        self.trace = []
        self.writes = set()
        self.current_time = 0
        self.baseline = 0
        self.uc.hook_add(UC_HOOK_CODE, self.observe)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.global_write, begin=0x44D000, end=0x459FFF)
        for event in (UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE):
            self.uc.hook_add(event, self.low_page_access, begin=0, end=0xFFF)
        for address in (STUB + 0x800, STUB + 0x810):
            self.uc.mem_write(address, b"\xc3")

    def low_page_access(self, uc, access, address, size, value, data):
        pc = uc.reg_read(UC_X86_REG_EIP)
        # FS prefix; do not accidentally make null game pointers valid with the SEH page.
        if address != 0 or size != 4 or uc.mem_read(pc, 1) != b"\x64":
            raise ValueError(f"Unexpected low-page access {address:#x} at {pc:#x}")

    def global_write(self, uc, access, address, size, value, data):
        self.writes.add((uc.reg_read(UC_X86_REG_EIP), address, size))

    def imported(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if self.lookup.get(address) == "sprintf" and self.u32(sp) == 0x41F51C:
            # One unconditional debug string in the match routine, six signed %d.
            fmt = self.cstr(self.u32(sp + 8)).decode("ascii")
            if fmt.count("%d") != 6 or fmt.replace("%d", "").find("%") >= 0:
                raise ValueError("Changed debug format")
            values = tuple(int.from_bytes(uc.mem_read(sp + 12 + i * 4, 4), "little", signed=True)
                           for i in range(6))
            out = (fmt % values).encode("ascii")
            uc.mem_write(self.u32(sp + 4), out + b"\0")
            uc.reg_write(UC_X86_REG_EAX, len(out))
            return
        super().imported(uc, address, size, data)

    def observe(self, uc, address, size, data):
        if address < 0x1000:
            raise ValueError("Execution entered SEH data page")
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address in MARKERS:
            self.trace.append(dict(kind="stage", address=hex(address), name=MARKERS[address]))
        if (0x41BC90 <= address < 0x422ABB or address in CALL_ARGS) and uc.mem_read(address, 1) == b"\xe8":
            relative = int.from_bytes(uc.mem_read(address + 1, 4), "little", signed=True)
            item = dict(kind="call", address=hex(address), target=hex(address + 5 + relative))
            if address in CALL_ARGS:
                item["args"] = [self.u32(sp + i * 4) for i in range(CALL_ARGS[address])]
            if address in (0x41E35F, 0x41E652, 0x41FB06):
                item["slot"] = (uc.reg_read(UC_X86_REG_ECX) - ACTOR) // 0x500
            self.trace.append(item)
        if address in BOUNDARIES:
            cleanup, count, label = BOUNDARIES[address]
            args = [self.u32(sp + 4 + i * 4) for i in range(count)]
            self.trace.append(dict(kind="boundary", address=hex(address), name=label,
                                   callerReturn=hex(self.u32(sp)), args=args,
                                   this=uc.reg_read(UC_X86_REG_ECX)))
            if address == 0x43F3D8 and args[2]:
                if args[1] != 0x8004667E:
                    raise ValueError("Unexpected socket control command")
                self.put(args[2], 0)
            uc.reg_write(UC_X86_REG_ESP, sp + 4 + cleanup)
            uc.reg_write(UC_X86_REG_EIP, self.u32(sp))
            uc.reg_write(UC_X86_REG_EAX, 0)
        elif address in (STUB + 0x800, STUB + 0x810):
            sleeping = address == STUB + 0x810
            self.trace.append(dict(kind="clock", name="Sleep" if sleeping else "timeGetTime",
                                   value=self.u32(sp + 4) if sleeping else self.current_time))
            uc.reg_write(UC_X86_REG_EAX, 0 if sleeping else self.current_time)
            uc.reg_write(UC_X86_REG_ESP, sp + (8 if sleeping else 4))
            uc.reg_write(UC_X86_REG_EIP, self.u32(sp))

    def state_summary(self):
        actors = []
        for slot in range(400):
            if self.uc.mem_read(MATCH + 4 + slot, 1)[0]:
                actor = self.u32(MATCH + 0x194 + slot * 4)
                actors.append(dict(slot=slot, id=self.u32(self.u32(actor + 0x368) + 0x6F4),
                                   frame=self.u32(actor + 0x70), hp=self.u32(actor + 0x2FC),
                                   mp=self.u32(actor + 0x308)))
        return dict(globals={name: self.u32(a) for name, a in GLOBAL_FIELDS.items()}, actors=actors)

    def dispatch(self, now=None):
        self.trace = []
        before = self.state_summary()
        if now is None:
            self.call(0x43E9A0, MATCH, (0,))
        else:
            self.current_time = now
            self.uc.reg_write(UC_X86_REG_ESP, STACK + 0xF000)
            self.uc.reg_write(UC_X86_REG_ESI, self.baseline)
            self.uc.reg_write(UC_X86_REG_EDI, STUB + 0x800)
            self.uc.reg_write(UC_X86_REG_EBX, STUB + 0x810)
            self.run(0x43D157, 0x43D1EF)
            self.baseline = self.uc.reg_read(UC_X86_REG_ESI)
        return dict(now=now, before=before, after=self.state_summary(), trace=self.trace,
                    stoppedAt=hex(self.uc.reg_read(UC_X86_REG_EIP)))


def main():
    cases = []
    for name, options, length in [
        ("ordinary", {}, 4), ("paused", {"pause": True}, 4),
        ("single-step-command", {"pause": True}, 4),
        ("resource-recovery", {"refill": True}, 12),
        ("type-three-pass", {"projectile": True}, 2),
        ("timer-through-dispatch", {}, 0),
    ]:
        vm = TickTrace(**options)
        if name == "single-step-command":
            vm.call(0x416DF0, MATCH, (0x44D020,))
        steps = [vm.dispatch() for _ in range(length)] if length else [
            vm.dispatch(now) for now in (0, 33, 34, 66, 67, 100)
        ]
        for step in steps:
            assert step["stoppedAt"] == hex(STOP if step["now"] is None else 0x43D1EF)
            stages = [e["name"] for e in step["trace"] if e["kind"] == "stage"]
            if "dispatcher-entry" in stages:
                assert stages[:3] == ["dispatcher-entry", "mode-entry", "match-entry"]
                assert stages[-3:] == ["match-return", "mode-return", "dispatcher-return"]
        if name == "ordinary":
            assert [s["after"]["globals"]["phase"] for s in steps] == [1, 0, 1, 0]
            assert [s["after"]["globals"]["randomCounter"] for s in steps] == [1, 2, 3, 4]
        if name == "paused":
            assert all(s["after"]["globals"]["randomCounter"] == 0 for s in steps)
            assert all("control-pass" not in [e.get("name") for e in s["trace"]] for s in steps)
        if name == "single-step-command":
            assert [s["after"]["globals"]["randomCounter"] for s in steps] == [0, 1, 2, 2]
        if name == "resource-recovery":
            assert [s["after"]["actors"][0]["mp"] for s in steps] == [100, 100, 102, 102, 102, 104, 104, 104, 106, 106, 106, 107]
            assert [s["after"]["actors"][0]["hp"] for s in steps] == [400] * 11 + [401]
        if name == "timer-through-dispatch":
            assert [sum(e.get("name") == "match-entry" for e in s["trace"]) for s in steps] == [0, 0, 1, 0, 1, 1]
        if name == "type-three-pass":
            for step in steps:
                hits = [(e["address"], e["args"][0]) for e in step["trace"]
                        if e["kind"] == "call" and e["target"] == "0x42e100"]
                assert hits == [("0x41ef42", 0), ("0x41ef42", 1), ("0x41f299", 50)], hits
        cases.append(dict(name=name, options=options,
                          selectors={hex(a): v for a, v in vm.selectors.items()}, steps=steps,
                          globalWrites=[dict(instruction=hex(pc), address=hex(a), size=n)
                                        for pc, a, n in sorted(vm.writes)]))
        print(f"{name}: {len(steps)} observations, "
              f"RNG calls={steps[-1]['after']['globals']['randomCounter']}", flush=True)
    legacy = Projectiles()
    legacy.prepare([{"x": 350, "hp": 400, "mp": 100}, {"x": 550}])
    legacy_steps = [legacy.tick2([0, 0]) for _ in range(12)]
    wide_steps = next(c["steps"] for c in cases if c["name"] == "resource-recovery")
    comparison = dict(
        scope="Only RNG counter and actor 0 HP/MP; same initial resources and no pressed buttons, different declared harnesses",
        legacy=[dict(randomCounter=s["randomCounter"], hp=s["actors"][0]["hp"], mp=s["actors"][0]["mp"])
                for s in legacy_steps],
        wide=[dict(randomCounter=s["after"]["globals"]["randomCounter"],
                   hp=s["after"]["actors"][0]["hp"], mp=s["after"]["actors"][0]["mp"])
              for s in wide_steps],
    )
    assert comparison["legacy"] == [dict(randomCounter=0, hp=400, mp=100)] * 12
    assert comparison["wide"][-1] == dict(randomCounter=12, hp=401, mp=107)
    doc = dict(exeSHA256=EXE_SHA256,
               scope="Synthetic loaded-world control-flow witnesses; not Windows captures or native equivalence",
               boundaries={hex(a): dict(cleanup=c, arguments=n, meaning=t)
                           for a, (c, n, t) in BOUNDARIES.items()}, cases=cases, sliceComparison=comparison)
    output = ROOT / "build/original/tick-trace.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    report = dict(exeSHA256=EXE_SHA256, scope=doc["scope"], corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                  boundaries=doc["boundaries"], sliceComparison=comparison,
                  cases=[dict(name=c["name"], observations=len(c["steps"]),
                              matchCalls=sum(e.get("name") == "match-entry" for s in c["steps"] for e in s["trace"]),
                              finalState=c["steps"][-1]["after"]) for c in cases])
    (ROOT / "docs/evidence/tick-trace.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Saved control-flow witnesses: {output}")


if __name__ == "__main__":
    main()
