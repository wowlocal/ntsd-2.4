#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Inventory bundled NTSD lib.dll hooks from recovered source installation.

Pinned file bytes and a recursive instruction inventory identify native port
work. Embedded pointer data is not decoded as straight-line instructions.
This static inventory is separate from actual installation/body execution.
The DLL is research input only; no game process or source file is patched.
"""
import json,hashlib
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE

LIB_SHA256='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
digest=lambda b:hashlib.sha256(b).hexdigest()

def main():
    raw=read_bytes(DEFAULT_SOURCE/'lib.dll');assert digest(raw)==LIB_SHA256;pe=PE(raw)
    exe=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(exe)==EXE_SHA256;ep=PE(exe)
    source_raw=(ROOT/'build/original/lib-initialization.json').read_bytes();source=json.loads(source_raw);patches=source['cases'][0]['patches']
    hooks=[]
    for p in patches:
        b=bytes.fromhex(p['after']);destination=p['address']+5+int.from_bytes(b[1:],'little',signed=True) if len(b)==5 and b[0]==0xe9 else None
        assert bytes.fromhex(p['before'])==exe[ep.offset(p['address']-ep.base):ep.offset(p['address']-ep.base)+p['count']]
        hooks.append(dict(address=p['address'],destination=destination,originalBytes=p['before'],installedBytes=p['after']))
    imports={int(i['iatVA'],16):i for i in pe.imports()};decoder=Cs(CS_ARCH_X86,CS_MODE_32)
    pending=[pe.entry]+[h['destination'] for h in hooks if h['destination'] is not None];instructions={};indirect=[]
    while pending:
        pc=pending.pop()
        while 0x10001000<=pc<0x10001c96 and pc not in instructions:
            offset=pe.offset(pc-pe.base);ins=next(decoder.disasm(raw[offset:offset+15],pc,count=1));assert ins.address==pc
            assert ins.mnemonic not in ('int3','ud2'),hex(pc)
            instructions[pc]=dict(address=pc,bytes=bytes(ins.bytes).hex(),instruction=ins.mnemonic+' '+ins.op_str)
            following=pc+ins.size
            if ins.mnemonic.startswith('ret'):break
            if ins.mnemonic in ('call','jmp') or ins.mnemonic.startswith('j'):
                if ins.op_str.startswith('0x'):
                    target=int(ins.op_str,16)
                    if 0x10001000<=target<0x10001c96:pending.append(target)
                elif ins.mnemonic=='jmp' and ins.op_str.startswith('dword ptr [0x'):
                    slot=int(ins.op_str[len('dword ptr ['):-1],16)
                    if slot in imports:indirect.append(dict(pc=pc,slot=slot,kind='import',name=imports[slot]['name']))
                    else:
                        off=pe.offset(slot-pe.base);target=int.from_bytes(raw[off:off+4],'little');indirect.append(dict(pc=pc,slot=slot,kind='storedContinuation',target=target))
                        if 0x10001000<=target<0x10001c96:pending.append(target)
                if ins.mnemonic=='jmp':break
            pc=following
    data=next(s for s in pe.sections if s['name']=='.data')
    loader=[]
    for pc,amount in [(0x445560,10),(0x4464c4,17)]:
        off=ep.offset(pc-ep.base)
        for ins in decoder.disasm(exe[off:off+amount],pc):loader.append(dict(address=ins.address,bytes=bytes(ins.bytes).hex(),instruction=ins.mnemonic+' '+ins.op_str))
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,sourceInstallationSHA256=digest(source_raw),entry=pe.entry,preferredBase=pe.base,imports=pe.imports(),loaderInstructions=loader,
        hooks=hooks,instructions=[instructions[k] for k in sorted(instructions)],indirectTransfers=sorted(indirect,key=lambda x:x['pc']),initialData=raw[data['fileOffset']:data['fileOffset']+data['virtualSize']].hex(),staticOnly=True,nativeCompared=False,windowsVerified=False)
    path=ROOT/'build/research/lib-runtime-static.json';path.write_text(json.dumps(doc,indent=2)+'\n');print('Hooks',len(hooks),'static instruction starts',len(instructions),'indirect transfers',len(indirect))
if __name__=='__main__':main()
