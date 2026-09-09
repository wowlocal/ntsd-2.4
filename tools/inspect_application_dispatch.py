#!/usr/bin/env python3
"""Audit the pinned application's outer dispatcher and its storage bindings.

Static PE-byte verification recovers the service-key scan, clear/screenshot,
editor/game routing and actual ret; it is not an execution or Windows claim.
The embedded World at458b00 and its initializer446300 must not be silently
identified with the earlier controlled initialized World at22000020.
"""
import json
import re
import subprocess
from datetime import datetime, timezone
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE
from accept_initialized_gameplay import digest


def capture():
    path=DEFAULT_SOURCE/'NTSD 2.4.exe';raw=read_bytes(path);assert digest(raw)==EXE_SHA256;pe=PE(raw)
    assembly=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',str(path)],text=True)
    regions={'clear':(0x401250,0x401281),'dispatcher':(0x43e9a0,0x43ed01),
        'screenshot':(0x43e8e0,0x43e934),'staticWorldInitializer':(0x446300,0x446305),
        'worldConstructor':(0x419e40,0x419e5f)}
    rows={name:[] for name in regions}
    for line in assembly.splitlines():
        m=re.match(r'\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)',line)
        if not m:continue
        address=int(m[1],16)
        for name,(start,end) in regions.items():
            if start<=address<=end:
                code=bytes.fromhex(m[2]);offset=pe.offset(address-pe.base);assert raw[offset:offset+len(code)]==code
                rows[name].append(dict(address=address,bytes=code.hex(),instruction=m[3].strip()))
    world=0x458b00;size=0x7d8
    section=next(s for s in pe.sections if pe.base+s['rva']<=world<pe.base+s['rva']+s['virtualSize'])
    offset=world-(pe.base+section['rva'])
    mapped=raw[section['fileOffset']:section['fileOffset']+section['fileSize']]
    mapped=mapped+bytes(max(0,section['virtualSize']-len(mapped)))
    initial=mapped[offset:offset+size];assert len(initial)==size
    initializerReferences=[]
    for s in pe.sections:
        data=raw[s['fileOffset']:s['fileOffset']+s['fileSize']]
        for i in range(0,len(data)-3,4):
            if int.from_bytes(data[i:i+4],'little')==0x446300:initializerReferences.append(pe.base+s['rva']+i)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,instructions=rows,
        embeddedWorld=dict(address=world,extent=size,section=section,sectionOffset=offset,
            initialBytesSHA256=digest(initial),allZero=not any(initial),initializerPointerLocations=initializerReferences),
        acceptedControlledWorld=0x22000020,sourceCompared=False,nativeCompared=False,windowsVerified=False,
        updatedUTC=datetime.now(timezone.utc).isoformat())
    (ROOT/'build/research/application-dispatch-static.json').write_text(json.dumps(doc,indent=2)+'\n');return doc


if __name__=='__main__':
    d=capture();print({name:len(rows) for name,rows in d['instructions'].items()});print(d['embeddedWorld'])
