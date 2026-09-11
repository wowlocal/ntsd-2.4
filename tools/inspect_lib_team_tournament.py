#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Read-only recovery of original Team Tournament434ab0..437220 menu rules.
Pinned NTSD EXE/lib.dll are compatibility references; Capstone decodes original
file bytes, not a running application. Branches, helpers, strings and operand
addresses guide the finite native-port comparison. This is static evidence,
not dynamic coverage, Windows behavior or a shipping DLL dependency. No input
execution, memory/control/protection changes, fault continuation or unrelated
target is involved. Dynamic acceptance must separately execute complete callers
and compare their produced state. Preserve original files and prior fixtures.
"""
from pathlib import Path
import argparse,json,hashlib
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert hashlib.sha256(raw).hexdigest()==EXE_SHA256;pe=PE(raw)
 dll=(DEFAULT_SOURCE/'lib.dll').read_bytes();assert hashlib.sha256(dll).hexdigest()=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
 start,end=0x434ab0,0x437220;offset=pe.offset(start-pe.base);rows=[]
 for i in Cs(CS_ARCH_X86,CS_MODE_32).disasm(raw[offset:offset+end-start],start):rows.append(dict(pc=i.address,bytes=i.bytes.hex(),mnemonic=i.mnemonic,operands=i.op_str))
 calls=sorted({r['operands'] for r in rows if r['mnemonic']=='call'})
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=hashlib.sha256(dll).hexdigest(),start=start,end=end,instructions=rows,staticCalls=calls,staticOnly=True,nativeCompared=False)
 a.output.write_text(json.dumps(d,indent=2)+'\n');a.output.with_suffix('.txt').write_text('\n'.join(f"{r['pc']:08x} {r['bytes']:22s} {r['mnemonic']:7s} {r['operands']}" for r in rows)+'\n')
 print(dict(instructionStarts=len(rows),calls=calls,returns=[hex(r['pc']) for r in rows if r['mnemonic'].startswith('ret')]))

if __name__=='__main__':main()
