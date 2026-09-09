#!/usr/bin/env python3
"""Byte-check the pinned game's complete43e9a0..43ed01 static dispatcher.

Recover service-key prefix, live surface/mode reads, fixed World identity,
loader calls and normal frame/return structure. No code is executed here;
this is not instruction coverage, initialized state or device evidence.
"""
import json,re,subprocess
from datetime import datetime,timezone
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
from accept_initialized_gameplay import digest


def capture():
    path=DEFAULT_SOURCE/'NTSD 2.4.exe';raw=read_bytes(path);assert digest(raw)==EXE_SHA256;pe=PE(raw)
    assembly=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',str(path)],text=True)
    rows=[];cursor=0x43e9a0
    for line in assembly.splitlines():
        match=re.match(r'\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)',line)
        if not match:continue
        address=int(match[1],16)
        if not 0x43e9a0<=address<=0x43ed01:continue
        code=bytes.fromhex(match[2]);offset=pe.offset(address-pe.base)
        assert address==cursor and raw[offset:offset+len(code)]==code;cursor+=len(code)
        rows.append(dict(address=address,bytes=code.hex(),instruction=match[3].strip()))
    assert cursor==0x43ed02 and len(rows)==236
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,instructions=rows,nativeCompared=False,windowsVerified=False,
        updatedUTC=datetime.now(timezone.utc).isoformat())
    (ROOT/'build/research/application-dispatcher-static-audit.json').write_text(json.dumps(doc,indent=2)+'\n');return doc


if __name__=='__main__':print(len(capture()['instructions']),'byte-checked static instructions')
