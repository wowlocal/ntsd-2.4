#!/usr/bin/env python3
"""Reproduce the pinned game's static application-timer instruction inventory.

Check llvm-objdump bytes against the original PE. This source/API audit recovers
clock/dispatch/sleep control flow; it is not emulation, device timing or native
equivalence. The actual timer decision is43d157..43d1ef; adjacent message and
loop-counter instructions are retained as context only.
"""
import json,re,subprocess
from datetime import datetime,timezone
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
from accept_initialized_gameplay import digest


def capture():
    path=DEFAULT_SOURCE/'NTSD 2.4.exe';raw=read_bytes(path);assert digest(raw)==EXE_SHA256;pe=PE(raw)
    assembly=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',str(path)],text=True)
    rows=[]
    for line in assembly.splitlines():
        match=re.match(r'\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)',line)
        if not match:continue
        address=int(match[1],16)
        if not 0x43d11d<=address<=0x43d20f:continue
        code=bytes.fromhex(match[2]);offset=pe.offset(address-pe.base);assert raw[offset:offset+len(code)]==code
        rows.append(dict(address=address,bytes=code.hex(),instruction=match[3].strip()))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,instructions=rows,nativeCompared=False,windowsVerified=False,
        updatedUTC=datetime.now(timezone.utc).isoformat())
    (ROOT/'build/research/application-timer-static-audit.json').write_text(json.dumps(doc,indent=2)+'\n');return doc


if __name__=='__main__':print(len(capture()['instructions']),'byte-checked static instructions')
