#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""R02.1 byte-preserving snapshots of the R01.1 synthetic world.

Keeps unknown fields and inactive Actors, unlike the old selected-field snapshots.
Pointer annotations are restricted to proven pointer fields; opaque bytes remain
verbatim. This does not establish initialization provenance or a complete portable
match snapshot. Catalog holes and inherited platform boundaries remain explicit.
"""
import hashlib
import json

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from oracle_frames import HEAP
from oracle_movement import ACTOR, BG
from oracle_state import ACTOR_SIZE, WORLD_PREFIX, ranges
from oracle_tick_trace import GLOBAL_FIELDS, MATCH, TickTrace
from unicorn import UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EIP

OBJECT_SIZE = 0x25360  # 0x412660, passed to operator new at 0x412665.
CATALOG_SIZE = 0x4D823A8  # 0x41bfeb/0x41bff0; sparse fixture, NOT fully loaded.


class StateTrace(TickTrace):
    def __init__(self, **options):
        super().__init__(**options)
        pe = PE(read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe"))
        data = next(s for s in pe.sections if s["name"] == ".data")
        catalog = self.u32(MATCH + 0x7D4)
        self.regions = [("globals", pe.base + data["rva"], data["virtualSize"])]
        self.regions += [(f"actor:{i}", self.u32(MATCH + 0x194 + i * 4), ACTOR_SIZE) for i in range(400)]
        self.regions += [(f"object:{i}", base, OBJECT_SIZE) for i, base in enumerate(self.bases.values())]
        self.regions += [("heap", HEAP, self.alloc - HEAP),
                         ("catalog:low", catalog, 0x1000 - catalog % 0x1000),
                         ("catalog:background", BG, catalog + CATALOG_SIZE - BG)]
        self.catalog_holes = [[hex((catalog + 0xFFF) & ~0xFFF), hex(BG)]]
        ordered = sorted(self.regions, key=lambda r: r[1])
        assert all(a[1] + a[2] <= b[1] for a, b in zip(ordered, ordered[1:]))
        self.accesses = set()
        # One hook interval covers all Actor slots; allocation padding is excluded.
        intervals = [(ACTOR, 399 * 0x500 + ACTOR_SIZE)] + [
            (a, n) for name, a, n in self.regions if not name.startswith("actor:")
        ]
        for event, mode in [(UC_HOOK_MEM_READ, "read"), (UC_HOOK_MEM_WRITE, "write")]:
            for start, length in intervals:
                if length:
                    self.uc.hook_add(event, self.access, user_data=mode, begin=start, end=start + length - 1)

    def locate(self, address, size=1):
        if ACTOR <= address < ACTOR + 400 * 0x500:
            slot, offset = divmod(address - ACTOR, 0x500)
            if offset + size <= ACTOR_SIZE:
                return f"actor:{slot}", offset
            raise ValueError(f"Access to Actor allocation padding: {address:#x}, {size}")
        for name, start, length in self.regions:
            if start <= address and address + size <= start + length:
                return name, address - start
        return None

    def access(self, uc, access, address, size, value, mode):
        where = self.locate(address, size)
        if where is None:
            raise ValueError(f"Access crosses captured storage boundary: {address:#x}, {size}")
        self.accesses.add((mode, *where, size, uc.reg_read(UC_X86_REG_EIP)))

    def pointer(self, name, offset, value):
        target = self.locate(value) if value else None
        return dict(region=name, offset=offset, raw=hex(value),
                    target=(dict(region=target[0], offset=target[1]) if target else
                            {"null": True} if value == 0 else {"unresolved": hex(value)}))

    def capture_state(self, blobs):
        assert self.alloc - HEAP == next(n for k, a, n in self.regions if k == "heap"), "New allocation needs a region update"
        records, pointers = [], []
        for name, address, size in self.regions:
            raw = bytes(self.uc.mem_read(address, size))
            digest = hashlib.sha256(raw).hexdigest()
            blobs.setdefault(digest, raw.hex())
            records.append(dict(region=name, address=hex(address), size=size, blob=digest))
            if name.startswith("actor:"):
                pointers.append(self.pointer(name, 0x368, int.from_bytes(raw[0x368:0x36C], "little")))
            elif name.startswith("object:"):
                for frame in range(400):
                    base = 0x7A4 + frame * 0x178
                    # Pointer slots at 0x130/134 can be untouched when their count is zero.
                    for field, count in [(0x130, 0x128), (0x134, 0x12C), (0x170, None)]:
                        if count is not None and int.from_bytes(raw[base + count:base + count + 4], "little", signed=True) <= 0:
                            continue
                        offset = base + field
                        value = int.from_bytes(raw[offset:offset + 4], "little")
                        if value:
                            pointers.append(self.pointer(name, offset, value))
        global_base = self.regions[0][1]
        for i in range(400):
            field = MATCH + 0x194 + i * 4
            pointers.append(self.pointer("globals", field - global_base, self.u32(field)))
        pointers.append(self.pointer("globals", MATCH + 0x7D4 - global_base, self.u32(MATCH + 0x7D4)))
        for i in range(len(self.bases)):
            pointers.append(self.pointer("catalog:low", i * 4, self.u32(self.u32(MATCH + 0x7D4) + i * 4)))
        # Every annotated non-null pointer in these fixtures must resolve, without
        # rewriting any unknown dword that happens to resemble a memory address.
        assert not any("unresolved" in p["target"] for p in pointers)
        return dict(records=records, pointers=pointers, summary=self.state_summary())


def raw_record(snapshot, name, blobs):
    return bytes.fromhex(blobs[next(r["blob"] for r in snapshot["records"] if r["region"] == name)])


def main():
    blobs, cases = {}, []
    reference = json.loads((ROOT / "docs/evidence/tick-trace.json").read_text())
    assert reference["exeSHA256"] == EXE_SHA256
    for name, options, length in [("ordinary", {}, 4), ("paused", {"pause": True}, 4),
                                  ("single-step-command", {"pause": True}, 4),
                                  ("resource-recovery", {"refill": True}, 12),
                                  ("type-three-pass", {"projectile": True}, 2),
                                  ("timer-through-dispatch", {}, 0)]:
        vm = StateTrace(**options)
        if name == "single-step-command":
            vm.call(0x416DF0, MATCH, (0x44D020,))
        snapshots = [vm.capture_state(blobs)]
        for now in ([None] * length if length else [0, 33, 34, 66, 67, 100]):
            vm.dispatch(now)
            snapshots.append(vm.capture_state(blobs))
        assert snapshots[-1]["summary"] == next(c["finalState"] for c in reference["cases"] if c["name"] == name)
        # Cross-check the raw representation against the earlier selected-field reader.
        for snapshot in snapshots:
            data = raw_record(snapshot, "globals", blobs)
            for field, address in GLOBAL_FIELDS.items():
                offset = address - vm.regions[0][1]
                assert int.from_bytes(data[offset:offset + 4], "little") == snapshot["summary"]["globals"][field]
            for actor in snapshot["summary"]["actors"]:
                raw = raw_record(snapshot, f"actor:{actor['slot']}", blobs)
                for field, offset in [("frame", 0x70), ("hp", 0x2FC), ("mp", 0x308)]:
                    assert int.from_bytes(raw[offset:offset + 4], "little") == actor[field]
        changes = []
        for region, _, _ in vm.regions:
            first = raw_record(snapshots[0], region, blobs)
            last = raw_record(snapshots[-1], region, blobs)
            changed = ranges([a != b for a, b in zip(first, last)])
            if changed:
                changes.append(dict(region=region, changedByteRanges=changed))
        accesses = [dict(mode=m, region=r, offset=o, size=n, instruction=hex(pc))
                    for m, r, o, n, pc in sorted(vm.accesses)]
        cases.append(dict(name=name, options=options, snapshots=snapshots, accesses=accesses,
                          changes=changes, catalogHoles=vm.catalog_holes))
        print(f"{name}: {len(snapshots)} snapshots, {len(vm.regions)} regions, {len(accesses)} distinct accesses", flush=True)
    # Verify blob hashes/sizes after serialization, including preserved opaque bytes.
    scope = "Raw fixture storage and partial pointer annotations; not complete initialization, portable state equivalence or Windows validation"
    doc = dict(exeSHA256=EXE_SHA256, scope=scope, cases=cases, blobs=blobs,
               limits=["Synthetic initialization inherited from TickTrace, no complete defined-byte provenance",
                       "Whole Actor allocations, Object allocations and PE .data; only mapped catalog slices and allocated fixture heap prefix",
                       "Pointer annotations cover World, Actor.Object, catalog entries, live frame boxes and sound paths only; other bytes stay opaque",
                       "No stack, registers, immutable PE sections, platform device state or host boundary bookkeeping",
                       "Access inventory covers the declared regions after fixture initialization; host writes from CRT/platform boundaries are not hooked"])
    output = ROOT / "build/original/state-trace.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    restored = json.loads(output.read_text())
    for digest, value in restored["blobs"].items():
        assert hashlib.sha256(bytes.fromhex(value)).hexdigest() == digest
    for case in restored["cases"]:
        for snapshot in case["snapshots"]:
            for record in snapshot["records"]:
                assert len(bytes.fromhex(restored["blobs"][record["blob"]])) == record["size"]
    # Persist the global access inventory even when the larger raw corpus is not checked in.
    global_accesses = sorted({(a["mode"], a["offset"] + vm.regions[0][1], a["size"], a["instruction"])
                              for c in cases for a in c["accesses"] if a["region"] == "globals"})
    world_arrays, other_globals = {}, []
    for mode, address, size, pc in global_accesses:
        offset = address - MATCH
        if 4 <= offset < 0x194:
            assert size == 1
            field, base, stride, index = "activity", 4, 1, offset - 4
        elif 0x194 <= offset < WORLD_PREFIX - 4:
            assert size == 4 and (offset - 0x194) % 4 == 0
            field, base, stride, index = "actorPointers", 0x194, 4, (offset - 0x194) // 4
        else:
            # Retain scalar World fields in the ordinary address list.
            other_globals.append(dict(mode=mode, address=hex(address), size=size, instruction=pc))
            continue
        world_arrays.setdefault((field, base, stride, mode, size, pc), set()).add(index)
    inventory_path = ROOT / "docs/evidence/state-global-accesses.json"
    inventory_path.write_text(json.dumps(dict(
        exeSHA256=EXE_SHA256, scope="Observed reads/writes after synthetic initialization in the six R01.1 cases; not all reachable globals",
        corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
        accesses=other_globals,
        worldArrays=[dict(field=f, base=hex(MATCH + b), stride=s, mode=m, size=n, instruction=pc,
                          indexRanges=ranges([i in indices for i in range(400)]))
                     for (f, b, s, m, n, pc), indices in sorted(world_arrays.items())]), indent=2) + "\n")
    inventory = json.loads(inventory_path.read_text())
    expanded = {(a["mode"], int(a["address"], 16), a["size"], a["instruction"]) for a in inventory["accesses"]}
    for a in inventory["worldArrays"]:
        for start, end in a["indexRanges"]:
            expanded.update((a["mode"], int(a["base"], 16) + i * a["stride"], a["size"], a["instruction"])
                            for i in range(start, end))
    assert expanded == set(global_accesses), "Compact inventory lost an observed global access"
    report = dict(exeSHA256=EXE_SHA256, scope=scope, limits=doc["limits"],
                  corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(), blobs=len(blobs),
                  cases=[dict(name=c["name"], snapshots=len(c["snapshots"]),
                              regions=len(c["snapshots"][0]["records"]),
                              bytesPerSnapshot=sum(r["size"] for r in c["snapshots"][0]["records"]),
                              distinctAccesses=len(c["accesses"]), changes=c["changes"],
                              catalogHoles=c["catalogHoles"], finalState=c["snapshots"][-1]["summary"])
                         for c in cases])
    (ROOT / "docs/evidence/state-trace.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Saved byte-preserving state: {output}")


if __name__ == "__main__":
    main()
