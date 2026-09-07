#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute the catalog parent 4122f0, with explicit opaque child-loader boundaries.

This checks registry ordering and parent-owned storage, NOT loaded Object/BG/Stage
contents. fscanf is a restricted C-locale, in-range integer boundary, not MSVCR80.
No original asset is written. All files are supplied immutable byte streams.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE
from oracle_state import Constructors, STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP

REGIONS = {0: 0x7D0, 0x4D81060: 0x990, 0x4D819F0: 0x990, 0x4D82380: 0x28}
SPACE = b" \t\r\n\v\f"
STUB = 0x30000100


class Catalog(Constructors):
    def __init__(self, source, filename, pattern, layout, checksum):
        super().__init__()
        assert source and b"\0" not in source and b"\x1a" not in source
        assert 0 < len(filename) < 32 and b"\0" not in filename
        self.source, self.filename = source, filename
        # Text-mode CRLF conversion at the CRT boundary. No DOS EOF in this domain.
        self.stream, self.pos, self.eof = source.replace(b"\r\n", b"\n"), 0, False
        self.closed, self.opened = False, False
        self.layout = layout
        self.catalog = [0x23000020, 0x27000340][layout]
        self.events, self.allocations, self.object_addresses, self.bitmap_addresses = [], [], [], []
        self.outer_tokens, self.scans, self.accesses = [], [], set()
        self.initial, self.masks = {}, {}
        self.uc.mem_map(0, 0x1000)  # SEH FS:0, not a simulated Windows thread.
        for base, size in [(self.catalog & ~0xFFF, 0x1000),
                           ((self.catalog + 0x4D81060) & ~0xFFF, 0x2000)]:
            self.uc.mem_map(base, size)
            self.uc.hook_add(UC_HOOK_MEM_READ, self.read_catalog, begin=base, end=base + size - 1)
            self.uc.hook_add(UC_HOOK_MEM_WRITE, self.write_catalog, begin=base, end=base + size - 1)
        for offset, size in REGIONS.items():
            initial = bytes([pattern]) * size if pattern is not None else bytes(i & 255 for i in range(size))
            self.initial[offset], self.masks[offset] = initial, bytearray(size)
            self.uc.mem_write(self.catalog + offset, initial)
        self.put(0x44F620, checksum)
        self.put(0x4511C0, 0)
        self.lookup = {}
        for item in PE(read_bytes(DEFAULT_SOURCE / "NTSD 2.4.exe")).imports():
            if item["name"] in {"fopen", "fclose", "feof", "fscanf", "timeGetTime", "Sleep"}:
                target = STUB + 16 * len(self.lookup)
                self.lookup[target] = item["name"]
                self.put(int(item["iatVA"], 16), target)
        self.uc.hook_add(UC_HOOK_CODE, self.code)

    def put(self, address, value):
        self.uc.mem_write(address, struct.pack("<I", value & 0xFFFFFFFF))

    def cstr(self, address):
        result = bytearray()
        for i in range(4096):
            value = self.uc.mem_read(address + i, 1)[0]
            if not value:
                return bytes(result)
            result.append(value)
        raise ValueError("Unterminated C string")

    def locate(self, address, size):
        offset = address - self.catalog
        for start, count in REGIONS.items():
            if start <= offset and offset + size <= start + count:
                return start, offset - start
        raise ValueError(f"Parent accessed an unclaimed catalog field: {offset:x}/{size}")

    def read_catalog(self, uc, access, address, size, value, data):
        start, offset = self.locate(address, size)
        assert all(self.masks[start][offset:offset + size]), ("Undefined catalog read", hex(address), hex(uc.reg_read(UC_X86_REG_EIP)))
        self.accesses.add(("read", start, offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def write_catalog(self, uc, access, address, size, value, data):
        start, offset = self.locate(address, size)
        self.masks[start][offset:offset + size] = b"\1" * size
        self.accesses.add(("write", start, offset, size, uc.reg_read(UC_X86_REG_EIP)))

    def ret(self, result=0, pop=0):
        sp = self.uc.reg_read(UC_X86_REG_ESP)
        self.uc.reg_write(UC_X86_REG_EAX, result & 0xFFFFFFFF)
        self.uc.reg_write(UC_X86_REG_EIP, self.u32(sp))
        self.uc.reg_write(UC_X86_REG_ESP, sp + 4 + pop)

    def scan(self, args, caller):
        assert args[0] == 1 and self.opened and not self.closed
        fmt = self.cstr(args[1])
        assert fmt in (b"%s", b"%d %s %d %s %s", b"%d %s %s"), fmt
        count, before = 0, self.pos
        for i, spec in enumerate(fmt.split()):
            while self.pos < len(self.stream) and self.stream[self.pos] in SPACE:
                self.pos += 1
            if self.pos == len(self.stream):
                self.eof = True
                break
            if spec == b"%s":
                end = self.pos
                while end < len(self.stream) and self.stream[end] not in SPACE:
                    end += 1
                token = self.stream[self.pos:end]
                # Token/Object scratch spans 200 bytes; the last BG path has
                # only 180 bytes before the security cookie at local +0x26c.
                limit = 180 if fmt == b"%d %s %s" and i == 2 else 200
                assert len(token) < limit, "String outside bounded catalog domain"
                self.uc.mem_write(args[2 + i], token + b"\0")
                self.pos = end
            else:
                match = re.match(rb"[+-]?[0-9]+", self.stream[self.pos:])
                assert match, "Malformed entry is outside this registry corpus"
                number = int(match[0])
                assert -(2**31) <= number < 2**31, "Unverified MSVCR80 overflow"
                self.put(args[2 + i], number)
                self.pos += len(match[0])
            count += 1
            if self.pos == len(self.stream):
                self.eof = True
        assert count == len(fmt.split()) or (fmt == b"%s" and caller == 0x412580), "Truncated section/entry"
        self.scans.append(dict(caller=hex(caller), format=fmt.decode(), before=before, after=self.pos,
                               assignments=count, eof=self.eof))
        return count if count else -1

    def code(self, uc, address, size, data):
        sp = uc.reg_read(UC_X86_REG_ESP)
        if address == 0x412580:
            token = self.cstr(sp + 0x34)
            self.outer_tokens.append(token.hex())
        if address == 0x4242E0:
            assert self.u32(sp) == 0x412660
            self.events.append(dict(kind="progress", path=self.cstr(self.u32(sp + 4)).decode("latin-1")))
            # Execute the original loading-progress function, with a frozen clock.
            return
        if address == 0x4450AC:
            count, caller = self.u32(sp + 4), self.u32(sp)
            assert (count == 0x1F50 and caller in (0x4123B8, 0x412414, 0x41246F, 0x4124CA)) or (count == 0x25360 and caller == 0x41266A)
            n = len(self.allocations)
            target = 0x31000000 + (n if self.layout == 0 else 503 - n) * 0x40000
            self.allocations.append(dict(address=target, size=count, caller=hex(caller)))
            self.ret(target)
            return
        if address == 0x43EE50:
            target = uc.reg_read(UC_X86_REG_ECX)
            assert self.u32(sp + 4) == 64 and self.u32(sp + 12) == 0
            assert target == self.allocations[-1]["address"]
            self.events.append(dict(kind="bitmap", index=len(self.bitmap_addresses), path=self.cstr(self.u32(sp + 8)).decode("latin-1")))
            self.bitmap_addresses.append(target)
            self.ret(target, 12)
            return
        if address == 0x40EF70:
            target = uc.reg_read(UC_X86_REG_ECX)
            assert target == self.allocations[-1]["address"] and self.u32(sp + 16) == 0x13572468
            assert self.u32(self.catalog + 0x4D82380) == len(self.object_addresses)
            self.events.append(dict(kind="object", index=len(self.object_addresses),
                                   id=struct.unpack("<i", uc.mem_read(sp + 4, 4))[0],
                                   objectType=struct.unpack("<i", uc.mem_read(sp + 8, 4))[0],
                                   path=self.cstr(self.u32(sp + 12)).decode("latin-1")))
            self.object_addresses.append(target)
            self.ret(target, 16)
            return
        if address == 0x40C160:
            assert uc.reg_read(UC_X86_REG_ECX) == self.catalog
            index = self.u32(sp + 4)
            assert index == self.u32(self.catalog + 0x4D82384)
            self.events.append(dict(kind="background", index=index,
                                   id=struct.unpack("<i", uc.mem_read(sp + 8, 4))[0],
                                   path=self.cstr(self.u32(sp + 12)).decode("latin-1")))
            self.ret(0, 12)
            return
        if address == 0x40C910:
            assert uc.reg_read(UC_X86_REG_ECX) == self.catalog and self.closed
            self.events.append(dict(kind="stages"))
            self.ret()
            return
        name = self.lookup.get(address)
        if name:
            args = [self.u32(sp + 4 + i * 4) for i in range(7)]
            if name == "timeGetTime":
                self.ret(100)
            elif name == "Sleep":
                assert args[0] == 5
                self.ret(0, 4)
            elif name == "fopen":
                assert self.cstr(args[0]) == self.filename and self.cstr(args[1]) == b"r" and not self.opened
                self.opened = True
                self.ret(1)
            elif name == "fclose":
                assert args[0] == 1 and self.opened and not self.closed
                self.closed = True
                self.ret()
            elif name == "feof":
                assert args[0] == 1 and self.opened and not self.closed
                self.ret(int(self.eof))
            elif name == "fscanf":
                self.ret(self.scan(args, self.u32(sp)))
            return
        assert (0x4122F0 <= address <= 0x4127FB or 0x4242E0 <= address <= 0x4246AD
                or address in (0x4450B2, 0x4450B8, 0x4450BA)), ("Unexpected code", hex(address))

    def execute(self):
        self.uc.mem_write(STACK + 0x100, self.filename + b"\0")
        sp = STACK + 0xF000
        self.uc.mem_write(sp, struct.pack("<III", STOP, STACK + 0x100, 0x13572468))
        self.uc.reg_write(UC_X86_REG_ESP, sp)
        self.uc.reg_write(UC_X86_REG_ECX, self.catalog)
        self.uc.emu_start(0x4122F0, STOP, timeout=15_000_000, count=2_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP, "Catalog instruction/time limit"
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp + 12 and self.uc.reg_read(UC_X86_REG_EAX) == self.catalog
        assert self.closed and self.pos == len(self.stream)
        records = []
        for offset, size in REGIONS.items():
            raw = bytes(self.uc.mem_read(self.catalog + offset, size))
            assert all(flag or raw[i] == self.initial[offset][i] for i, flag in enumerate(self.masks[offset]))
            records.append(dict(offset=offset, initial=self.initial[offset].hex(), bytes=raw.hex(), defined=bytes(self.masks[offset]).hex()))
        return dict(records=records, checksum=self.u32(0x44F620), events=self.events,
                    outerTokens=self.outer_tokens, scans=self.scans, allocations=self.allocations,
                    objectAddresses=self.object_addresses, bitmapAddresses=self.bitmap_addresses,
                    accesses=[dict(mode=m, region=r, offset=o, size=n, instruction=hex(pc)) for m, r, o, n, pc in sorted(self.accesses)])


def cases():
    baseline = read_bytes(DEFAULT_SOURCE / "data/data.txt")
    yield "baseline", baseline, b"data\\data.txt"
    # Same tokens, different EOF position: exposes the original stale-token checksum.
    yield "baseline-no-trailing-space", baseline.rstrip(SPACE), b"data\\data.txt"
    yield "repeated-sections-and-ids", (b"ignored\n<object> id: 7 not_type: -3 not_file: a.dat id: 7 t: 6 f: b.dat <object_end>\n"
        b"<background> id: 4 bogus: four.dat id: 2 file: two.dat <background_end>\n"
        b"<object> #ignored id: -2147483648 x +2147483647 y c.dat <object_end>\n"
        b"<background> id: 4 anything again.dat <background_end>\n"), b"data\\probe.txt"
    yield "signed-checksum-and-numeric-prefix", (b"ab\xff\x80 <object> id: 12suffix -2unused a.dat <object_end> "
        b"<background> id: +3label b.dat <background_end> tail"), b"1234567890123456789012345678901"
    yield "empty-sections", b"<object> <object_end> <background> <background_end>\r\n", b"x"
    yield "registry-capacities", (b"<object>\n" + b"".join(f"id: {i % 13} type: {i % 7} file: o{i}.dat\n".encode() for i in range(500))
        + b"<object_end> <background>\n" + b"".join(f"id: {98-i} file: b{i}.dat\n".encode() for i in range(99))
        + b"<background_end>\n"), b"data\\capacity.txt"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-only", action="store_true", help="Write an unaccepted build corpus, without native checks or evidence updates")
    args = parser.parse_args()
    output = ROOT / "build/original/catalog-registry.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    captured = []
    for label, source, filename in cases():
        for layout, pattern, checksum in [(0, 0xA5, 0), (1, None, 0xFFFFF123)]:
            vm = Catalog(source, filename, pattern, layout, checksum)
            captured.append(dict(label=f"{label}-{layout}", source=source.hex(), fileName=filename.hex(),
                                 initialChecksum=checksum, **vm.execute()))
            print(f"{captured[-1]['label']}: {len(vm.object_addresses)} objects, {sum(e['kind'] == 'background' for e in vm.events)} backgrounds", flush=True)
    scope = "Catalog parent 4122f0 registry, bootstrap writes and child-call order; opaque Object/BG/Stage/bitmap children, bounded CRT scanner and frozen clock; not whole-file loading"
    doc = dict(exeSHA256=EXE_SHA256, scope=scope, cases=captured)
    output.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    if args.capture_only:
        return
    subprocess.run(["swift", "build", "--package-path", str(ROOT / "native"), "-c", "release", "--product", "NTSDCatalogCheck"], check=True)
    subprocess.run([str(ROOT / "native/.build/release/NTSDCatalogCheck"), str(output)], check=True)
    fixture = dict(doc, cases=[{k: v for k, v in c.items() if k not in ("accesses", "scans", "allocations")} for c in captured])
    fixture_path = ROOT / "native/Tests/NTSDCoreTests/Fixtures/original-catalog-registry.json"
    fixture_path.write_text(json.dumps(fixture, separators=(",", ":")) + "\n")
    report = dict(exeSHA256=EXE_SHA256, scope=scope, corpusSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                  fixtureSHA256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
                  sourceSHA256=hashlib.sha256(read_bytes(DEFAULT_SOURCE / "data/data.txt")).hexdigest(),
                  cases=len(captured), comparedBytes=sum(REGIONS.values()) * len(captured),
                  casesSummary=[dict(label=c["label"], objects=len(c["objectAddresses"]),
                                     backgrounds=sum(e["kind"] == "background" for e in c["events"]),
                                     checksum=c["checksum"], definedBytes=sum(sum(bytes.fromhex(r["defined"])) for r in c["records"])) for c in captured],
                  boundaries=["fopen/fclose/feof/fscanf: in-memory text stream, C-locale ASCII whitespace, successful in-range %d/%s",
                              "timeGetTime=100, Sleep(5) no wait; original 4242e0 fast path executes",
                              "4450ac: successful opaque allocation tokens, varied addresses",
                              "43ee50: bitmap constructor returns this without device/storage writes",
                              "40ef70: captures Object id/type/path/surface and returns this, no child writes",
                              "40c160: captures BG ordinal/id/path, no child writes",
                              "40c910: records final Stage loader call, no child writes"],
                  accesses=captured[0]["accesses"])
    (ROOT / "docs/evidence/catalog-registry.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
