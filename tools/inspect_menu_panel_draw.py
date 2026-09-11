#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Static compatibility inventory of pinned NTSD menu panel423b00..4242db.
Read original EXE bytes to recover panel timer/draw/mouse control flow and
identify actual helper dependencies. No source execution, memory writes,
protection changes, external URLs, native expected-state inputs or Windows
behavior claims. See MENU_PANEL_DRAW_PLAN.md; static starts are not coverage.
"""
from pathlib import Path
import argparse,json,hashlib
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from inspect_original import PE
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 raw=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert hashlib.sha256(raw).hexdigest()==EXE_SHA256
 pe=PE(raw);start,end=0x423b00,0x4242dc;offset=pe.offset(start-pe.base);body=raw[offset:offset+end-start];cs=Cs(CS_ARCH_X86,CS_MODE_32)
 instructions=[dict(address=i.address,bytes=bytes(i.bytes).hex(),mnemonic=i.mnemonic,operands=i.op_str) for i in cs.disasm(body,start)]
 assert sum(len(bytes.fromhex(i['bytes'])) for i in instructions)==len(body) and instructions[-1]['mnemonic']=='jmp'
 assert [i['address'] for i in instructions if i['mnemonic']=='ret']==[0x4242b2]
 for i in instructions:
  if i['mnemonic'].startswith('j'):assert start<=int(i['operands'],16)<end,i
 d=dict(scope=__doc__,exeSHA256=EXE_SHA256,start=start,endExclusive=end,bodySHA256=hashlib.sha256(body).hexdigest(),instructions=instructions,calls=[i for i in instructions if i['mnemonic']=='call'],imports=pe.imports(),dynamicallyExecuted=False)
 a.output.write_text(json.dumps(d,indent=2)+'\n')
 print('Static instructions',len(instructions),'calls',len(d['calls']))
 for i in instructions:print(f"{i['address']:08x} {i['mnemonic']:8} {i['operands']}")
