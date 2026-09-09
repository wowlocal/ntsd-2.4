"""Install the pinned game library into an existing research-only source VM.

PE HIGHLOW relocation and import binding are declared Windows-loader effects.
The actual DLL entry builds and installs every game patch. VirtualAlloc,
VirtualProtect and RtlMoveMemory are explicit successful API boundaries.
Neither expected patch bytes nor helper success returns replace DLL execution.
Caller game/CRT initialization and actual Windows protection remain separate.
"""
import struct
from import_ntsd import DEFAULT_SOURCE,read_bytes
from inspect_original import PE
from oracle_lib_initialization import LIB_SHA256,digest
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX,UC_X86_REG_EIP,UC_X86_REG_ESP

BASE,API,HEAP,STACK=0x36000000,0x36010000,0x36020000,0x360f0000


def install_library(uc):
    raw=read_bytes(DEFAULT_SOURCE/'lib.dll');assert digest(raw)==LIB_SHA256;pe=PE(raw)
    mapped=bytearray(0x5000);mapped[:0x400]=raw[:0x400]
    for s in pe.sections:mapped[s['rva']:s['rva']+s['fileSize']]=raw[s['fileOffset']:s['fileOffset']+s['fileSize']]
    cursor,length=pe.directories[5];end=cursor+length;relocations=[]
    while cursor<end:
        page,size=struct.unpack_from('<II',mapped,cursor);assert size>=8 and size%2==0 and cursor+size<=end
        for at in range(cursor+8,cursor+size,2):
            entry=struct.unpack_from('<H',mapped,at)[0];kind,offset=entry>>12,entry&0xfff
            if kind==0:continue
            assert kind==3;where=page+offset;before=struct.unpack_from('<I',mapped,where)[0];after=(before+BASE-pe.base)&0xffffffff
            struct.pack_into('<I',mapped,where,after);relocations.append(dict(offset=where,before=before,after=after))
        cursor+=size
    uc.mem_map(BASE,0x5000);uc.mem_write(BASE,bytes(mapped));uc.mem_map(API,0x1000);uc.mem_map(HEAP,0x20000);uc.mem_map(STACK,0x10000)
    imports={}
    for i,item in enumerate(pe.imports()):
        pc=API+16*i;imports[pc]=item['name'];offset=int(item['iatVA'],16)-pe.base;uc.mem_write(BASE+offset,struct.pack('<I',pc))
    events=[];patches=[];allocations=[];instructions=set();finished=False;protections={}
    def word(a):return int.from_bytes(uc.mem_read(a,4),'little')
    def put(a,n):uc.mem_write(a,struct.pack('<I',n&0xffffffff))
    def ret(value,pop):
        sp=uc.reg_read(UC_X86_REG_ESP);uc.reg_write(UC_X86_REG_EAX,value&0xffffffff);uc.reg_write(UC_X86_REG_EIP,word(sp));uc.reg_write(UC_X86_REG_ESP,sp+4+pop)
    stop=API+0x800
    uc.mem_write(stop,b"\xcc")
    def code(u,pc,size,data):
        nonlocal finished
        if pc==stop:finished=True;u.emu_stop();return
        if pc not in imports:
            assert BASE+0x1000<=pc<BASE+0x1c96,hex(pc);instructions.add(pc);return
        sp=u.reg_read(UC_X86_REG_ESP);args=lambda n:[word(sp+4+4*i) for i in range(n)];name=imports[pc];event=dict(name=name,returnPC=word(sp));events.append(event)
        if name=='VirtualAlloc':
            values=args(4);assert values in ([0,4000,0x1000,4],[0,20000,0x1000,4]);address=HEAP+len(allocations)*0x10000;assert len(allocations)<2
            allocations.append(dict(address=address,count=values[1]));event.update(arguments=values,result=address);ret(address,16)
        elif name=='VirtualProtect':
            values=args(4);target,count,protection,out=values;assert 0x400000<=target<target+count<0x446000 and count in (2,5)
            page=target&~4095;old=protections.get(page,0x20);protections[page]=protection;put(out,old);event.update(arguments=values,oldProtection=old,result=1);ret(1,16)
        elif name=='RtlMoveMemory':
            target,source,count=args(3);before=bytes(u.mem_read(target,count));payload=bytes(u.mem_read(source,count));u.mem_write(target,payload)
            patch=dict(address=target,before=before.hex(),after=payload.hex(),source=source,count=count);patches.append(patch);event.update(patch);ret(target,12)
        else:raise AssertionError(name)
    sp=STACK+0xf000
    for i,n in enumerate((stop,BASE,1,0)):put(sp+4*i,n)
    uc.reg_write(UC_X86_REG_ESP,sp);hook=uc.hook_add(UC_HOOK_CODE,code)
    try:uc.emu_start(BASE+pe.entry-pe.base,0,count=100000)
    except Exception:
        print("INSTALL FAILED", hex(uc.reg_read(UC_X86_REG_EIP)), "SP", hex(uc.reg_read(UC_X86_REG_ESP)), "PCs", [hex(x) for x in sorted(instructions)], "events", events, flush=True)
        raise
    finally:uc.hook_del(hook)
    assert finished and uc.reg_read(UC_X86_REG_ESP)==sp+16 and uc.reg_read(UC_X86_REG_EAX)==1 and len(patches)==13
    return dict(libSHA256=LIB_SHA256,base=BASE,preferredBase=pe.base,relocations=relocations,events=events,allocations=allocations,patches=patches,instructions=sorted(instructions),result=1)
