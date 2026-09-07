#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Original loading-time Actor pool, before the next bitmap allocation.

Original instructions run from 0x41c052 to 0x41c2f5, with a checkpoint after
all 400 allocations. Only operator new and memset are replaced. The loaded
catalog's first pointer and Object +0x90 are explicit inputs, not a fake loader.
This is not match selection/spawning or the complete loading branch.
"""
import hashlib
import json
import struct
import subprocess

from import_ntsd import EXE_SHA256, ROOT
from oracle_state import ACTOR_SIZE, AREA, STACK, STOP, WORLD_PREFIX, Constructors
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP


class Bootstrap(Constructors):
    def __init__(self, pattern, layout, selector, header_word):
        super().__init__()
        self.layout = layout
        self.stride, self.displacement = [(0x500, 0x20), (0x780, 0x50)][layout]
        self.actor_initial = bytes([pattern]) * ACTOR_SIZE if pattern is not None else bytes(i & 255 for i in range(ACTOR_SIZE))
        self.world_initial = bytes([pattern]) * WORLD_PREFIX if pattern is not None else bytes(i & 255 for i in range(WORLD_PREFIX))
        self.world = 0x23000100 + layout * 0x1000
        self.catalog = 0x24000020 + layout * 0x100
        self.object = 0x25000040 + layout * 0x100
        self.addresses = [AREA + self.displacement + (slot if layout == 0 else 399 - slot) * self.stride for slot in range(400)]
        self.uc.mem_map(AREA + 0x4000, 0x100000 - 0x4000)
        for address in [0x23000000, 0x24000000, 0x25000000]:
            self.uc.mem_map(address, 0x10000)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.written, begin=AREA + 0x4000, end=AREA + 0xFFFFF)
        self.uc.hook_add(UC_HOOK_MEM_WRITE, self.written, begin=self.world, end=self.world + WORLD_PREFIX - 1)
        self.uc.hook_add(UC_HOOK_MEM_READ, self.read, begin=AREA, end=AREA + 0xFFFFF)
        self.uc.hook_add(UC_HOOK_MEM_READ, self.read, begin=self.world, end=self.world + WORLD_PREFIX - 1)
        self.uc.hook_add(UC_HOOK_CODE, self.allocate, begin=0x4450AC, end=0x4450AC)
        self.uc.hook_add(UC_HOOK_CODE, self.constructor_entry, begin=0x4061D0, end=0x4061D0)
        self.masks = {"world": bytearray(WORLD_PREFIX)}
        self.allocations, self.constructors, self.accesses = [], [], set()
        self.uc.mem_write(self.world - 16, b"\x96" * 16 + self.world_initial + b"\x69" * 16)
        self.put(self.catalog, self.object)
        self.put(self.object + 0x90, header_word)
        self.uc.reg_write(UC_X86_REG_ESP, STACK + 0xF000)
        self.put(STACK + 0xF000, STOP)
        self.uc.reg_write(UC_X86_REG_ECX, self.world)
        self.run(0x419E40, STOP)
        self.put(self.world, selector)  # supplied outer dispatcher selector, already defined by ctor
        self.uc.reg_write(UC_X86_REG_ESP, STACK + 0xF000)
        self.uc.reg_write(UC_X86_REG_EAX, self.catalog)
        self.uc.reg_write(UC_X86_REG_EBX, self.world)

    def put(self, address, value):
        self.uc.mem_write(address, struct.pack("<I", value & 0xFFFFFFFF))

    def locate(self, address, size):
        if self.world <= address and address + size <= self.world + WORLD_PREFIX:
            return "world", address - self.world
        physical, offset = divmod(address - AREA - self.displacement, self.stride)
        assert 0 <= physical < 400 and offset + size <= ACTOR_SIZE, (hex(address), size)
        slot = physical if self.layout == 0 else 399 - physical
        return f"actor:{slot}", offset

    def written(self, uc, access, address, size, value, data):
        name, offset = self.locate(address, size)
        self.masks[name][offset:offset + size] = b"\1" * size
        self.accesses.add(("write", name.split(":")[0], offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def read(self, uc, access, address, size, value, data):
        name, offset = self.locate(address, size)
        assert all(self.masks[name][offset:offset + size]), ("Read before initialization", name, hex(offset), hex(uc.reg_read(UC_X86_REG_EIP)))
        self.accesses.add(("read", name.split(":")[0], offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def memset(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        destination, value, count = [self.u32(sp + x) for x in (4, 8, 12)]
        self.written(uc, 0, destination, count, 0, None)
        uc.mem_write(destination, bytes([value & 255]) * count)
        uc.reg_write(UC_X86_REG_EAX, destination)
        uc.reg_write(UC_X86_REG_ESP, sp + 4)
        uc.reg_write(UC_X86_REG_EIP, self.u32(sp))

    def allocate(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        assert self.u32(sp) == 0x41C07A and self.u32(sp + 4) == ACTOR_SIZE
        slot = len(self.allocations)
        assert slot < 400
        target = self.addresses[slot]
        self.allocations.append(target)
        self.masks[f"actor:{slot}"] = bytearray(ACTOR_SIZE)
        uc.mem_write(target - 16, b"\x96" * 16 + self.actor_initial + b"\x69" * 16)
        uc.reg_write(UC_X86_REG_EAX, target)
        uc.reg_write(UC_X86_REG_ESP, sp + 4)
        uc.reg_write(UC_X86_REG_EIP, self.u32(sp))

    def constructor_entry(self, uc, address, size, data):
        name, offset = self.locate(uc.reg_read(UC_X86_REG_ECX), ACTOR_SIZE)
        assert offset == 0
        self.constructors.append(int(name.split(":")[1]))

    def run(self, start, stop):
        self.uc.emu_start(start, stop, timeout=15_000_000, count=1_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == stop, "Bootstrap instruction/time limit"

    def capture_pool(self, blobs, name):
        def blob(raw):
            key = hashlib.sha256(raw).hexdigest()
            blobs.setdefault(key, raw.hex())
            return key
        def record(key, address, size):
            assert self.uc.mem_read(address - 16, 16) == b"\x96" * 16
            assert self.uc.mem_read(address + size, 16) == b"\x69" * 16
            raw = bytes(self.uc.mem_read(address, size))
            initial = self.world_initial if key == "world" else self.actor_initial
            assert all(defined or raw[i] == initial[i] for i, defined in enumerate(self.masks[key]))
            return dict(bytes=blob(raw), defined=blob(bytes(self.masks[key])))
        return dict(name=name, world=record("world", self.world, WORLD_PREFIX),
                    actors=[record(f"actor:{i}", a, ACTOR_SIZE) for i, a in enumerate(self.addresses)],
                    allocations=len(self.allocations), constructorSlots=self.constructors.copy())


def main():
    blobs, cases = {}, []
    for pattern, word, selector in [(0, 0, 0), (0xA5, -1, 2), (0xFF, -2147483648, -7), (None, 0x12345678, 17)]:
        for layout in (0, 1):
            vm = Bootstrap(pattern, layout, selector, word)
            vm.run(0x41C052, 0x41C0D8)
            allocated = vm.capture_pool(blobs, "allocated")
            vm.run(0x41C0D8, 0x41C2F5)
            staged = vm.capture_pool(blobs, "staged")
            assert vm.constructors == list(range(400)) + list(range(8))
            for slot, address in enumerate(vm.addresses):
                assert vm.u32(vm.world + 0x194 + slot * 4) == address
                assert vm.u32(address + 0x368) == vm.object
            assert bytes(vm.uc.mem_read(vm.world + 4, 400)) == b"\1" * 8 + b"\0" * 392
            cases.append(dict(label=f"{pattern}-{layout}", actorInitial=vm.actor_initial.hex(), worldInitial=vm.world_initial.hex(),
                              selector=selector, firstObjectWord90=word,
                              addresses=dict(world=vm.world, catalog=vm.catalog, object=vm.object, actors=vm.addresses),
                              checkpoints=[allocated, staged],
                              accesses=[dict(mode=m, region=r, offset=o, size=n, instruction=hex(pc))
                                        for m, r, o, n, pc in sorted(vm.accesses)]))
            print(f"{cases[-1]['label']}: 400 allocations, 408 constructors, masks preserved", flush=True)
    scope = "Loading-time pool 41c052..41c2f5, non-null allocations and supplied catalog[0]/Object+90; not match spawning or whole loader"
    doc = dict(exeSHA256=EXE_SHA256, scope=scope, cases=cases, blobs=blobs)
    output = ROOT / "build/original/bootstrap.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    subprocess.run(["swift", "build", "--package-path", str(ROOT / "native"), "-c", "release", "--product", "NTSDBootstrapCheck"], check=True)
    subprocess.run([str(ROOT / "native/.build/release/NTSDBootstrapCheck"), str(output)], check=True)
    # Keep an offline corpus without the repeated instruction-access metadata.
    fixture = dict(doc, cases=[{k: v for k, v in c.items() if k != "accesses"} for c in cases])
    fixture_path = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-bootstrap.json"
    fixture_path.write_text(json.dumps(fixture, separators=(",", ":")) + "\n")
    summary = dict(exeSHA256=EXE_SHA256, scope=scope,
                   corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                   fixtureSHA256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(), cases=len(cases), checkpoints=16,
                   records=16 * 401, actorConstructorOrder="slots 0..399, then 0..7",
                   activeAfterStaging=list(range(8)), nativeComparison="All record bytes and initialization masks; confirmed pointer fields normalized to non-null registry/slot ordinals")
    (ROOT / "docs/evidence/bootstrap.json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
