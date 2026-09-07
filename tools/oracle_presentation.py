#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Capture original timer decisions and District bitmap draw calls, without a device."""
import json, struct
from oracle_movement import OriginalMovement, MOVEMENT_FRAMES, WORLD, BG
from oracle_frames import FRAME_RE, STACK, STOP, STUB
from import_ntsd import ROOT, EXE_SHA256
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP, UC_X86_REG_ESI, UC_X86_REG_EDI

def main():
    game=json.loads((ROOT/'build/imported/game.json').read_text())
    obj=next(x for x in game['objects'] if x['id']==2)
    vm=OriginalMovement(obj,[m[0] for m in FRAME_RE.finditer(obj['originalText']) if int(m[1]) in MOVEMENT_FRAMES])
    uc=vm.uc; current=0; ticks=0; draws=[]
    def hook(uc,addr,size,data):
        nonlocal ticks
        sp=uc.reg_read(UC_X86_REG_ESP); pop=4
        if addr==STUB+0x400: uc.reg_write(UC_X86_REG_EAX,current)
        elif addr==0x43e9a0:
            ticks+=1; uc.reg_write(UC_X86_REG_EAX,0)
        elif addr==0x43f010:
            values=struct.unpack('<6i',uc.mem_read(sp+4,24))
            draws.append(dict(layer=uc.reg_read(UC_X86_REG_ECX)-1,x=values[0],y=values[1],transparency=values[3])); pop+=24
        uc.reg_write(UC_X86_REG_ESP,sp+pop); uc.reg_write(UC_X86_REG_EIP,vm.u32(sp))
    for va in (STUB+0x400,0x43e9a0,0x43f010): uc.hook_add(UC_HOOK_CODE,hook,begin=va,end=va)
    vm.put(0x44d02c,1)
    times=[0,1,32,33,34,65,66,67,99,100,101,134,233,234,400,401,5000,5001]
    clock=[]
    for start in [0,0xfffffff0]:
        baseline=start
        for time in times:
            current=(time+start)&0xffffffff; ticks=0
            for _ in range(4):
                before=ticks
                uc.reg_write(UC_X86_REG_ESP,STACK+0xf000); uc.reg_write(UC_X86_REG_ESI,baseline); uc.reg_write(UC_X86_REG_EDI,STUB+0x400)
                vm.run(0x43d157,0x43d1df)
                baseline=uc.reg_read(UC_X86_REG_ESI)
                if ticks==before: break
            clock.append(dict(start=start,now=current,baseline=baseline,ticks=ticks))
    arena=game['backgrounds'][0]
    vm.put(BG+0x1c,len(arena['layers']))
    offsets={'transparency':0x4d4619c,'width':0x4d46214,'x':0x4d4628c,'y':0x4d46304,'cc':0x4d4655c,'c1':0x4d4646c,'c2':0x4d464e4}
    for i,layer in enumerate(arena['layers']):
        for key,off in offsets.items(): vm.put(BG+off-0x4d45db0+i*4,int(layer.get(key,0)))
        vm.put(BG+0x4d466c4-0x4d45db0+i*4,i+1)
    frames=[]
    for step in range(120):
        camera=(step*7)%167; vm.put(0x450bc4,camera); draws=[]
        vm.call(0x41a250,WORLD,(0,))
        frames.append(dict(camera=camera,draws=draws))
    doc=dict(exeSHA256=EXE_SHA256,clock=clock,layers=arena['layers'],background=frames)
    path=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-presentation.json'
    path.write_text(json.dumps(doc,separators=(',',':'))+'\n')
    print(f'Captured {len(clock)} timer samples and {len(frames)} original District draw lists: {path}')

if __name__=='__main__': main()
