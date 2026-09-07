#!/usr/bin/env python3
"""Reproduce the R01.1 address index from the identified EXE, not saved assembly.

This is a linear static index with explicit function boundaries recovered in
TICK_PIPELINE.md. It does not infer feasibility of branches or resolve callees.
"""
import hashlib
import json
import re
import subprocess

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT, read_bytes
from inspect_original import PE

FUNCTIONS = {
    "outerLoop": (0x43CF40, 0x43D222),
    "dispatcher": (0x43E9A0, 0x43ED02),
    "modeDispatcher": (0x4246B0, 0x428808),
    "match": (0x41BC90, 0x422ABB),
}


def main():
    source = DEFAULT_SOURCE / "NTSD 2.4.exe"
    data = read_bytes(source)
    if hashlib.sha256(data).hexdigest() != EXE_SHA256:
        raise ValueError("Unidentified Windows EXE")
    pe = PE(data)
    assembly = subprocess.check_output(
        ["xcrun", "llvm-objdump", "--disassemble", "--x86-asm-syntax=intel", str(source)],
        text=True,
    )
    rows = {}
    for line in assembly.splitlines():
        match = re.match(r"\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)", line)
        if match:
            address = int(match[1], 16)
            raw = bytes.fromhex(match[2])
            # Prove that the index describes the identified file's actual bytes.
            off = pe.offset(address - pe.base)
            if data[off:off + len(raw)] != raw:
                raise ValueError(f"Disassembly bytes differ at {address:#x}")
            rows[address] = (raw, match[3].strip())
    report = {"exeSHA256": EXE_SHA256, "evidence": "S: static address index", "functions": {}}
    for name, (start, end) in FUNCTIONS.items():
        selected = [(a, raw, text) for a, (raw, text) in rows.items() if start <= a < end]
        cursor = start
        calls, branches, returns = [], [], []
        for address, raw, text in selected:
            if address != cursor:
                raise ValueError(f"Non-contiguous function index at {cursor:#x}")
            cursor += len(raw)
            opcode, *rest = text.split(maxsplit=1)
            operand = rest[0] if rest else ""
            item = {"address": hex(address), "instruction": text}
            target = re.fullmatch(r"0x([0-9a-f]+)(?:\s+<[^>]+>)?", operand)
            if target and (opcode == "call" or opcode.startswith("j") or opcode.startswith("loop")):
                item["target"] = hex(int(target[1], 16))
            if opcode == "call":
                calls.append(item)
            elif opcode.startswith("j") or opcode.startswith("loop"):
                branches.append(item)
                if name == "match" and (not target or not start <= int(target[1], 16) < end):
                    raise ValueError("Match has an unresolved or outward jump; review its boundary")
                if name == "match" and int(target[1], 16) not in rows:
                    raise ValueError("Match branch is not an indexed instruction")
            elif opcode == "ret":
                returns.append(item)
        if cursor != end or not returns:
            raise ValueError(f"Incomplete function index: {name}")
        report["functions"][name] = dict(
            start=hex(start), endExclusive=hex(end), instructions=len(selected),
            bytesSHA256=hashlib.sha256(b"".join(r for _, r, _ in selected)).hexdigest(),
            calls=calls, branches=branches, returns=returns,
            directCallers=[hex(a) for a, (_, text) in rows.items()
                           if re.match(rf"call\s+0x{start:x}(?:\s|$)", text)],
        )
    output = ROOT / "build/research/tick-address-index.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    summary = dict(exeSHA256=EXE_SHA256, evidence=report["evidence"],
                   indexSHA256=hashlib.sha256(output.read_bytes()).hexdigest(),
                   functions={name: {k: v for k, v in item.items() if k not in ("calls", "branches")}
                              | dict(callSites=len(item["calls"]), branches=len(item["branches"]))
                              for name, item in report["functions"].items()})
    (ROOT / "docs/evidence/tick-address-index.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Indexed four original functions: {output}")
    match = report["functions"]["match"]
    print(f"Match: {match['instructions']} instructions; {len(match['returns'])} return; "
          f"{len(match['branches'])} direct internal branches")


if __name__ == "__main__":
    main()
