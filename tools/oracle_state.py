#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""R02.1 constructor bytes and write provenance; independent of native storage.

Executes the original Actor and World constructors. Only memset is substituted,
with its host writes included explicitly in the trace and defined-byte mask.
No game initialization defaults are inferred from the allocator's fill pattern.
"""
import hashlib
import json
import struct
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

ACTOR_SIZE = 0x420
WORLD_PREFIX = 0x7D8  # Observed storage extent, not proof of full C++ sizeof(World).
ENTRIES = {"actor": 0x4061D0, "world": 0x419E40}
STACK, AREA, STOP = 0x10000000, 0x22000000, 0x30000000


def ranges(mask):
    result = []
    for offset, value in enumerate(mask):
        if value and (offset == 0 or not mask[offset - 1]):
            result.append([offset, offset + 1])
        elif value:
            result[-1][1] = offset + 1
    return result


class Constructors:
    def __init__(self):
        exe = read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe")
        if hashlib.sha256(exe).hexdigest() != EXE_SHA256:
            raise ValueError("Unidentified EXE")
        self.uc = Uc(UC_ARCH_X86, UC_MODE_32)
        self.uc.mem_map(0x400000, 0x100000)
        for section in PE(exe).sections:
            if section["name"] != ".rsrc":
                self.uc.mem_write(0x400000 + section["rva"],
                                  exe[section["fileOffset"]:section["fileOffset"] + section["fileSize"]])
        for start, size in [(STACK, 0x10000), (AREA, 0x4000), (STOP, 0x1000)]:
            self.uc.mem_map(start, size)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.written, begin=AREA, end=AREA + 0x3FFF)
        self.uc.hook_add(UC_HOOK_CODE, self.memset, begin=0x4450A0, end=0x4450A0)

    def u32(self, address):
        return int.from_bytes(self.uc.mem_read(address, 4), "little")

    def written(self, uc, access, address, size, value, data):
        if not self.target <= address < address + size <= self.target + self.size:
            raise ValueError("Constructor wrote beyond declared storage")
        offset = address - self.target
        raw = (value & ((1 << (size * 8)) - 1)).to_bytes(size, "little")
        self.writes.append(dict(instruction=hex(uc.reg_read(UC_X86_REG_EIP)),
                               offset=offset, bytes=raw.hex(), kind="instruction"))
        self.mask[offset:offset + size] = [True] * size

    def memset(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        destination, value, count = [self.u32(sp + x) for x in (4, 8, 12)]
        if not self.target <= destination <= destination + count <= self.target + self.size:
            raise ValueError("memset outside constructor storage")
        raw = bytes([value & 0xFF]) * count
        offset = destination - self.target
        self.writes.append(dict(instruction=hex(address), callerReturn=hex(self.u32(sp)),
                               offset=offset, bytes=raw.hex(), kind="memset-boundary"))
        self.mask[offset:offset + count] = [True] * count
        uc.mem_write(destination, raw)
        uc.reg_write(UC_X86_REG_EAX, destination)
        uc.reg_write(UC_X86_REG_ESP, sp + 4)
        uc.reg_write(UC_X86_REG_EIP, self.u32(sp))

    def capture(self, kind, initial, displacement):
        self.target = AREA + displacement
        self.size = len(initial)
        self.mask = [False] * self.size
        self.writes = []
        self.uc.mem_write(self.target - 16, b"\x96" * 16 + initial + b"\x69" * 16)
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack("<I", STOP))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, self.target)
        self.uc.emu_start(ENTRIES[kind], STOP, timeout=5_000_000, count=100_000)
        if self.uc.reg_read(UC_X86_REG_EIP) != STOP:
            raise ValueError("Constructor did not return")
        assert self.uc.mem_read(self.target - 16, 16) == b"\x96" * 16
        assert self.uc.mem_read(self.target + self.size, 16) == b"\x69" * 16
        raw = bytes(self.uc.mem_read(self.target, self.size))
        assert all(written or raw[i] == initial[i] for i, written in enumerate(self.mask))
        return dict(kind=kind, initial=initial.hex(), bytes=raw.hex(), defined=self.mask.copy(),
                    writes=self.writes.copy(), address=hex(self.target),
                    returnEAX=hex(self.uc.reg_read(UC_X86_REG_EAX)))


def main():
    vm = Constructors()
    cases, summaries = [], {}
    for kind, size in [("actor", ACTOR_SIZE), ("world", WORLD_PREFIX)]:
        patterns = {"zero": bytes(size), "a5": b"\xa5" * size, "ff": b"\xff" * size,
                    "ramp": bytes(i & 255 for i in range(size))}
        for label, initial in patterns.items():
            for displacement in (0x100, 0x1400):
                result = vm.capture(kind, initial, displacement)
                result["label"] = f"{kind}-{label}-{displacement:x}"
                cases.append(result)
        representative = next(c for c in cases if c["kind"] == kind)
        mask = representative["defined"]
        assert all(c["defined"] == mask for c in cases if c["kind"] == kind)
        summaries[kind] = dict(entry=hex(ENTRIES[kind]), storageBytes=size,
                               definedBytes=sum(mask), untouchedRanges=ranges([not x for x in mask]),
                               writeRanges=ranges(mask), writes=representative["writes"])
    doc = dict(exeSHA256=EXE_SHA256, scope="Constructor storage bytes, written-byte masks, four initial patterns and two addresses",
               cases=cases)
    output = ROOT / "build/original/state-constructors.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    subprocess.run(["swift", "build", "--package-path", str(ROOT / "native"), "-c", "release",
                    "--product", "NTSDStateCheck"], check=True)
    subprocess.run([str(ROOT / "native/.build/release/NTSDStateCheck"), str(output)], check=True)
    fixture = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-state-constructors.json"
    fixture.write_bytes(output.read_bytes())
    report = dict(exeSHA256=EXE_SHA256, scope=doc["scope"], cases=len(cases),
                  corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(), constructors=summaries)
    (ROOT / "docs/evidence/state-constructors.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Constructor masks:", {k: (v["definedBytes"], v["storageBytes"]) for k, v in summaries.items()})


if __name__ == "__main__":
    main()
