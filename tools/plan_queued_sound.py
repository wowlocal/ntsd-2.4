#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.6"]
# ///
"""Static inputs for the game's pending native sound-queue consumer.

Disassemble the pinned original game to identify update order, volume/pan
arithmetic and COM request boundaries. This is compatibility planning, not
executed instruction coverage, a sound-device observation or native acceptance.
"""
import hashlib
import json
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import DEFAULT_SOURCE,EXE_SHA256,ROOT,read_bytes
from inspect_original import PE


def main():
    raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert hashlib.sha256(raw).hexdigest()==EXE_SHA256
    pe=PE(raw);decoder=Cs(CS_ARCH_X86,CS_MODE_32);groups=[]
    for name,start,end,count in [('queue',0x419e60,0x41a044,145),('play',0x401a30,0x401a72,30),('gameplay-output-caller',0x422994,0x4229cc,15)]:
        offset=pe.offset(start-pe.base);code=list(decoder.disasm(raw[offset:offset+end-start],start))
        assert len(code)==count and sum(i.size for i in code)==end-start
        groups.append(dict(name=name,start=start,end=end,instructions=[dict(pc=i.address,bytes=i.bytes.hex(),mnemonic=i.mnemonic,operands=i.op_str) for i in code]))
        print(name,len(code),'decoded starts')
    doc=dict(exeSHA256=EXE_SHA256,scope=__doc__,dynamicExecution=False,groups=groups)
    (ROOT/'build/research/queued-sound-static.json').write_text(json.dumps(doc,indent=2)+'\n')


if __name__=='__main__':main()
