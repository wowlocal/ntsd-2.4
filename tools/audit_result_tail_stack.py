#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.6"]
# ///
"""Static CFG/ESP audit of421cdc..422994 from the pinned original EXE.

This is not execution evidence. Propagate ESP relative to the caller root across
both outcomes of every conditional branch, using explicitly checked callee ret
cleanup for normal returns. Indexed stack operands retain their unknown index.
The writer's exception/fault paths do not imply a normal return in this audit.
"""
import hashlib
import json
from collections import deque
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from capstone.x86 import X86_OP_REG, X86_OP_IMM, X86_OP_MEM, X86_REG_ESP, X86_REG_EDI
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE

START, END = 0x421cdc, 0x422994
# These are the exact normal-return instructions, not simulated helper bodies.
RETURNS = {0x43dd60: (0x43def8,0), 0x43df00: (0x43df93,0),
           0x43f010: (0x43f2fe,24), 0x401290: (0x4012fe,0), 0x41b390: (0x41b5cc,12)}


def main():
    raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert hashlib.sha256(raw).hexdigest()==EXE_SHA256
    pe=PE(raw);decoder=Cs(CS_ARCH_X86,CS_MODE_32);decoder.detail=True
    def decode(address,count):
        offset=pe.offset(address-pe.base);return list(decoder.disasm(raw[offset:offset+count],address))
    instructions=decode(START,END-START)
    assert sum(i.size for i in instructions)==END-START
    code={i.address:i for i in instructions};returns=[]
    for entry,(pc,pop) in RETURNS.items():
        i=decode(pc,8)[0]
        assert i.mnemonic=='ret' and (i.operands[0].imm if i.operands else 0)==pop,(hex(pc),i.mnemonic,i.op_str)
        returns.append(dict(entry=entry,returnPC=pc,pop=pop,bytes=i.bytes.hex()))
    pending=deque([(START,0)]);deltas={};operands=[];calls=[]
    while pending:
        pc,delta=pending.popleft()
        if pc in deltas:
            assert deltas[pc]==delta,('Inconsistent ESP at CFG join',hex(pc),deltas[pc],delta)
            continue
        deltas[pc]=delta
        if pc==END:continue
        assert pc in code,hex(pc)
        i=code[pc]
        for n,o in enumerate(i.operands):
            if o.type==X86_OP_MEM and o.mem.base==X86_REG_ESP:
                operands.append(dict(pc=pc,operation=i.mnemonic,operand=n,espDelta=delta,displacement=o.mem.disp,
                    rootOffset=delta+o.mem.disp,size=o.size,index=i.reg_name(o.mem.index) if o.mem.index else None,
                    scale=o.mem.scale,access=o.access,bytes=i.bytes.hex(),text=i.op_str))
        next_delta=delta
        if i.mnemonic=='push':next_delta-=4
        elif i.mnemonic=='pop':
            assert i.operands[0].type==X86_OP_REG and i.operands[0].reg!=X86_REG_ESP
            next_delta+=4
        elif i.mnemonic in ('add','sub') and i.operands[0].type==X86_OP_REG and i.operands[0].reg==X86_REG_ESP:
            assert i.operands[1].type==X86_OP_IMM
            next_delta+=(1 if i.mnemonic=='add' else -1)*i.operands[1].imm
        elif i.mnemonic=='lea' and i.operands[0].type==X86_OP_REG and i.operands[0].reg==X86_REG_ESP:
            m=i.operands[1].mem;assert m.base==X86_REG_ESP and not m.index;next_delta+=m.disp
        elif i.mnemonic=='call':
            o=i.operands[0]
            if o.type==X86_OP_IMM:
                assert o.imm in RETURNS,(hex(pc),hex(o.imm));pop=RETURNS[o.imm][1]
            else:
                # Both indirect forms are the original sprintf IAT binding;
                # EDI is loaded from447174 at422737/422846 before these calls.
                assert (o.type==X86_OP_MEM and not o.mem.base and not o.mem.index and o.mem.disp==0x447174) or (
                    o.type==X86_OP_REG and o.reg==X86_REG_EDI),(hex(pc),i.op_str)
                pop=0
            next_delta+=pop;calls.append(dict(pc=pc,target=i.op_str,espDeltaBeforeCall=delta,normalReturnPop=pop))
        elif i.mnemonic in ('ret','enter','leave','pusha','popa','pushal','popal'):raise AssertionError((hex(pc),i.mnemonic))
        else:
            # Every remaining instruction must leave ESP untouched. Capstone
            # reports the implicit stack write on call/push/pop above.
            assert X86_REG_ESP not in i.regs_access()[1],(hex(pc),i.mnemonic,i.op_str)
        if i.mnemonic.startswith('j'):
            assert len(i.operands)==1 and i.operands[0].type==X86_OP_IMM
            pending.append((i.operands[0].imm,next_delta))
            if i.mnemonic!='jmp':pending.append((pc+i.size,next_delta))
        else:pending.append((pc+i.size,next_delta))
    assert deltas[END]==0
    root64=[o for o in operands if o['index'] is None and o['rootOffset']<=0x64<o['rootOffset']+o['size']]
    assert [o['pc'] for o in sorted(root64,key=lambda o:o['pc'])]==[0x421eb1,0x422673]
    corrected=next(o for o in operands if o['pc']==0x4222ce)
    assert corrected['espDelta']==-24 and corrected['rootOffset']==0x4c and corrected['size']==4
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,start=START,end=END,decodedInstructions=len(code),
        reachedByStaticCFG=len(deltas)-1,unreachedInstructionStarts=sorted(set(code)-set(deltas)),
        calleeNormalReturns=returns,calls=calls,stackOperands=sorted(operands,key=lambda o:(o['pc'],o['operand'])),
        root64Operands=sorted(root64,key=lambda o:o['pc']),corrected4222ce=corrected,
        endESPDelta=deltas[END],dynamicExecution=False)
    path=ROOT/'build/research/result-tail-stack-static.json';path.write_text(json.dumps(doc,indent=2)+'\n')
    print('STATIC',len(code),'decoded;',len(deltas)-1,'CFG-reachable;',len(operands),'ESP operands; root64 reads',
        [hex(o['pc']) for o in root64],';4222ce root',hex(corrected['rootOffset']),';normal end delta',deltas[END])


if __name__=='__main__':main()
