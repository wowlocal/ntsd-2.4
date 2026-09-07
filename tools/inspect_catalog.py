#!/usr/bin/env python3
"""R02 catalog storage boundaries from the identified EXE; static evidence only."""
import hashlib
import json
import re
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE

# Each immediate has a concrete original instruction, not a native layout guess.
WITNESSES = {
    0x41BFEB: "push 0x4d823a8",
    0x4126A4: "mov dword ptr [ebp + 4*edx], eax",
    0x4126A8: "add dword ptr [ebp + 0x4d82380], 0x1",
    0x40C957: "lea eax, [ebx + 0x7d0]",
    0x40C95D: "mov ecx, 0x3c",
    0x40C962: "mov dword ptr [eax], 0xffffffff",
    0x40C968: "add eax, 0x149b08",
    0x40CB4E: "add ecx, 0x34c0",
    0x40CB54: "cmp ecx, 0x149b00",
    0x40CB33: "add eax, 0xe0",
    0x40CB38: "cmp eax, 0x3480",
    0x40CA0D: "mov dword ptr [edx + ebx + 0x7d8], eax",
    0x40CA51: "mov dword ptr [edi + ebx + 0x8bc], 0xffffffff",
    0x40C220: "imul ebx, ebx, 0x990",
    0x40C22F: "mov dword ptr [ebx + 0x4d45dcc], eax",
    0x41A2DD: "cmp dword ptr [ecx + edx + 0x4d45db0], 0x31a",
    0x41233B: "mov dword ptr [ebp + 0x4d81060], 0x960",
    0x412373: "mov dword ptr [ebp + 0x4d8142c], edx",
    0x4124FF: "mov dword ptr [ebp + 0x4d81dbc], ecx",
    0x41253D: "mov dword ptr [ebp + 0x4d82384], ebx",
    0x412543: "mov dword ptr [ebp + 0x4d82380], ebx",
    0x41252B: "lea edx, [ecx + 0x4d82388]",
    0x4127CD: "call 0x40c910",
}


def main():
    source = DEFAULT_SOURCE / "NTSD 2.4.exe"
    raw = read_bytes(source)
    assert hashlib.sha256(raw).hexdigest() == EXE_SHA256
    pe = PE(raw)
    assembly = subprocess.check_output(["xcrun", "llvm-objdump", "--disassemble", "--x86-asm-syntax=intel", str(source)], text=True)
    rows = {}
    for line in assembly.splitlines():
        m = re.match(r"\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)", line)
        if not m or int(m[1], 16) not in WITNESSES:
            continue
        address, code = int(m[1], 16), bytes.fromhex(m[2])
        text = " ".join(m[3].split()).split(" <", 1)[0]
        assert text == WITNESSES[address], (hex(address), text)
        offset = pe.offset(address - pe.base)
        assert raw[offset:offset + len(code)] == code
        rows[address] = dict(address=hex(address), bytes=code.hex(), instruction=text)
    assert set(rows) == set(WITNESSES)
    stage_base, stage_stride, stage_count = 0x7D0, 0x149B08, 60
    phase_stride, phase_count = 0x34C0, 0x149B00 // 0x34C0
    background_base = stage_base + stage_stride * stage_count
    background_stride, counters = 0x990, 0x4D82380
    background_count = (counters - background_base) // background_stride
    assert phase_count == 100 and stage_stride == 8 + phase_stride * phase_count
    assert background_base == 0x4D45DB0 and background_count == 101
    assert background_base + background_count * background_stride == counters
    assert background_base + 99 * background_stride == 0x4D81060
    assert background_base + 99 * background_stride + 0x3CC == 0x4D8142C
    assert background_base + 100 * background_stride + 0x3CC == 0x4D81DBC
    assert counters + 8 + 32 == 0x4D823A8
    data = read_bytes(DEFAULT_SOURCE / "data/data.txt")
    first = re.search(rb"id:\s*(-?\d+)\s+type:\s*(-?\d+)\s+file:\s*(\S+)", data)
    assert first
    report = dict(exeSHA256=EXE_SHA256, evidence="S: verified instruction bytes and layout arithmetic; no complete catalog execution",
        storageBytes=0x4D823A8,
        regions=[dict(name="object pointer table", start=0, end=stage_base, entryBytes=4,
                      inferredCapacity=stage_base // 4, limit="Capacity inferred from next region, not a demonstrated bounds check"),
                 dict(name="stages", start=stage_base, end=background_base, entries=stage_count, stride=stage_stride,
                      phaseStride=phase_stride, phaseIterations=phase_count, repeatedEntryStride=0xE0, repeatedEntryIterations=0x3480 // 0xE0,
                      limit="Repeated-entry stride is not proof of a standalone sizeof(entry); untouched gaps and field semantics remain open"),
                 dict(name="background records including special slots", start=background_base, end=counters,
                      inferredCapacity=background_count, stride=background_stride,
                      specialSlots={"99": "Lee On Road", "100": "Random name"}),
                 dict(name="loaded object count", start=counters, end=counters + 4),
                 dict(name="loaded background count", start=counters + 4, end=counters + 8),
                 dict(name="source filename", start=counters + 8, end=0x4D823A8,
                      limit="32-byte tail; original copy loop has no observed length check")],
        instructions=[rows[a] for a in sorted(rows)],
        registryFileSHA256=hashlib.sha256(data).hexdigest(),
        firstRegistryEntry=dict(id=int(first[1]), type=int(first[2]), file=first[3].decode("latin-1")),
        limits=["No implied defaults for unassigned bytes", "Loaded object/background counts are not capacities",
                "The full catalog, object/background/stage loaders and their CRT conversions still require execution witnesses"])
    (ROOT / "docs/evidence/catalog-layout.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Catalog: {report['storageBytes']} bytes; 60 stage regions, 101 background records; exact extent accounted for")


if __name__ == "__main__":
    main()
