#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Static ordinary-resource failure paths in NTSD War preparation.
Pinned original EXE/lib.dll are the compatibility reference. Decode the War
caller, arena layer loader/releaser, bitmap constructor/loader/copy, music and
replay-allocation prefix to choose a finite source/Native error comparison.
Addresses identify actual file instructions and null/result checks; no original
execution, memory/control/protection changes, host/Windows/device behavior or
dynamic branch coverage is claimed. Preserve all reference and accepted bytes.
"""
import argparse,datetime,hashlib,json
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

RANGES=[('war',0x43a21f,0x43a76e),('arena',0x40c030,0x40c15f),
        ('bitmap',0x43ed10,0x43ef42),('copy',0x4013d0,0x4014d2),
        ('music',0x401c90,0x4020f7),('recordingPrefix',0x43d2c0,0x43d3b0)]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists() and not a.output.with_suffix('.txt').exists()
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert hashlib.sha256(raw).hexdigest()==EXE_SHA256
 dll=(DEFAULT_SOURCE/'lib.dll').read_bytes();dllsha=hashlib.sha256(dll).hexdigest()
 assert dllsha=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
 pe=PE(raw);decoder=Cs(CS_ARCH_X86,CS_MODE_32);groups=[]
 for name,start,end in RANGES:
  offset=pe.offset(start-pe.base)
  rows=[dict(pc=i.address,bytes=i.bytes.hex(),mnemonic=i.mnemonic,operands=i.op_str) for i in decoder.disasm(raw[offset:offset+end-start],start)]
  groups.append(dict(name=name,start=start,end=end,instructions=rows))
 doc=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),exeSHA256=EXE_SHA256,libSHA256=dllsha,groups=groups,staticOnly=True,originalExecuted=False,nativeCompared=False)
 a.output.write_text(json.dumps(doc,indent=2)+'\n')
 a.output.with_suffix('.txt').write_text('\n'.join(f"{r['pc']:08x} {r['bytes']:22s} {r['mnemonic']:7s} {r['operands']}" for g in groups for r in g['instructions'])+'\n')
 print({g['name']:len(g['instructions']) for g in groups})

if __name__=='__main__':main()
