#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.6"]
# ///
"""Execute whole original43f4b0/43f400 compression and their actual children.

The EXE executes compression, including its inlined REP memory copies. VC80
resolves memory imports if reached. Only calloc/free are declared allocator
boundaries, with ordered requests, failure ordinal and zero backing.
Controlled inputs/capacities; no host compression result feeds the source CPU.
This is not43dd60/file IO, an own match continuation or Windows execution.
"""
import argparse
import base64
import hashlib
import json
import random
import struct
import zlib
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE
from oracle_crt import CRT, DLL_SHA256, prepare, STOP, STACK
from unicorn import UC_HOOK_BLOCK, UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EBP, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW, UC_X86_REG_ECX, UC_X86_REG_EFLAGS

SOURCE, DESTINATION, HEAP = 0x24000000, 0x25000000, 0x26000000
LENGTH, API = STOP+0x8000, STOP+0x9000
REGISTERS = [UC_X86_REG_EBX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EBP]
HELPERS = {0x43f4b0:16,0x43f400:20,0x440640:16,0x440420:32,0x43f610:8,0x43f8a0:4,0x442730:0,0x442750:0}
digest = lambda value: hashlib.sha256(value).hexdigest()
signed = lambda value: (value+0x80000000)%0x100000000-0x80000000


def exports(pe):
    entry = pe.offset(pe.directories[0][0])
    count, functions, names, ordinals = [pe.u32(entry+n) for n in (24,28,32,36)]
    return {pe.string(pe.u32(pe.offset(names)+4*i)): pe.base+pe.u32(pe.offset(functions)+4*pe.u16(pe.offset(ordinals)+2*i)) for i in range(count)}


class ReplayCompression(CRT):
    def boundary(self,uc,address,size,data):
        if address in getattr(self,'imported',{}): return
        return super().boundary(uc,address,size,data)

    def __init__(self):
        super().__init__()
        raw = read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe'); assert digest(raw) == EXE_SHA256
        pe = PE(raw); self.uc.mem_map(pe.base, 0x100000)
        for s in pe.sections:
            if s['name'] != '.rsrc': self.uc.mem_write(pe.base+s['rva'], raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        dll_exports = exports(PE(prepare().read_bytes()))
        self.imported = {}
        for index, item in enumerate(pe.imports()):
            name = item['name']; pointer = API+16*index
            if name in ('memcpy','memmove','memset','memcmp'): pointer = dll_exports[name]
            else: self.imported[pointer] = name
            self.put(int(item['iatVA'],16),pointer)
        self.uc.hook_add(UC_HOOK_CODE,self.allocator,begin=API,end=API+0xfff)
        for address in (SOURCE,DESTINATION): self.uc.mem_map(address,0x800000)
        self.uc.mem_map(HEAP,0x100000)
        self.uc.hook_add(UC_HOOK_BLOCK,self.block)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.output_write,begin=DESTINATION,end=DESTINATION+0x7fffff)
        self.blocks = set(); self.running = False
        self.decoder = Cs(CS_ARCH_X86,CS_MODE_32)
        self.return_hooks = set()
        for pc in (0x43f5c3,0x43f5c5,0x43f5ca,0x43f5cc):
            self.uc.hook_add(UC_HOOK_CODE,self.rep_copy,begin=pc,end=pc)
        for pc in HELPERS: self.uc.hook_add(UC_HOOK_CODE,self.helper,begin=pc,end=pc)

    def helper(self,uc,pc,size,data):
        if not self.running: return
        sp = uc.reg_read(UC_X86_REG_ESP)
        while self.pending and pc == self.pending[-1]['returnPC']:
            item = self.pending.pop()
            assert sp == item['entrySP']+4+item['pop']
            assert item['saved'] == [uc.reg_read(r) for r in REGISTERS]
            item.update(returnSP=sp,result=signed(uc.reg_read(UC_X86_REG_EAX)))
            self.helpers.append(item)
        if pc in HELPERS:
            return_pc = self.u32(sp)
            self.pending.append(dict(entry=pc,entrySP=sp,returnPC=return_pc,pop=HELPERS[pc],saved=[uc.reg_read(r) for r in REGISTERS]))
            if return_pc not in self.return_hooks and return_pc not in HELPERS:
                self.return_hooks.add(return_pc)
                self.uc.hook_add(UC_HOOK_CODE,self.helper,begin=return_pc,end=return_pc)

    def block(self,uc,pc,size,data):
        if self.running: self.blocks.add((pc,size))

    def allocator(self,uc,pc,size,data):
        name = self.imported[pc]; sp = uc.reg_read(UC_X86_REG_ESP)
        if name == 'calloc':
            count,size = self.u32(sp+4),self.u32(sp+8)
            ordinal = len(self.allocations)+1
            fail = ordinal == self.fail_at
            address = 0 if fail else HEAP+self.heap_cursor
            self.allocations.append(dict(count=count,size=size,address=address,live=not fail))
            self.events.append(dict(kind='calloc',count=count,size=size,address=address))
            if not fail:
                assert 0 < count*size < 0x100000-self.heap_cursor
                self.uc.mem_write(address,b'\0'*(count*size)); self.heap_cursor += (count*size+31)&~15
            self.ret(address)
        elif name == 'free':
            address = self.u32(sp+4)
            if address:
                allocation = next(a for a in self.allocations if a['address'] == address)
                assert allocation['live']; allocation['live'] = False
            self.events.append(dict(kind='free',address=address)); self.ret()
        else: raise AssertionError(('Unexpected EXE import',name,hex(self.u32(sp))))

    def rep_copy(self,uc,pc,size,data):
        if not self.running:return
        if pc in (0x43f5c3,0x43f5ca):
            if self.rep_pending is not None:return  # Repeated instruction callbacks.
            unit=4 if pc==0x43f5c3 else 1
            count=uc.reg_read(UC_X86_REG_ECX)*unit
            source,destination=uc.reg_read(UC_X86_REG_ESI),uc.reg_read(UC_X86_REG_EDI)
            assert uc.reg_read(UC_X86_REG_EFLAGS)&0x400==0
            assert DESTINATION<=destination<=destination+count<=DESTINATION+self.capacity
            self.rep_pending=dict(pc=pc,source=source,destination=destination,count=count,
                bytes=bytes(uc.mem_read(source,count)) if count else b'')
        else:
            item=self.rep_pending;assert item is not None
            assert pc=={0x43f5c3:0x43f5c5,0x43f5ca:0x43f5cc}[item['pc']]
            count=item['count'];start=item['destination']-DESTINATION
            assert uc.reg_read(UC_X86_REG_ECX)==0
            assert uc.reg_read(UC_X86_REG_ESI)==item['source']+count
            assert uc.reg_read(UC_X86_REG_EDI)==item['destination']+count
            after=bytes(uc.mem_read(item['destination'],count)) if count else b''
            assert after==item.pop('bytes')
            self.rep_mask[start:start+count]=b'\1'*count
            item.update(sha256=digest(after),memoryHookWrites=sum(self.mask[start:start+count]))
            self.copies.append(item);self.rep_pending=None

    def output_write(self,uc,access,address,size,value,data):
        if not self.running: return
        assert DESTINATION <= address < address+size <= DESTINATION+self.capacity, (hex(uc.reg_read(UC_X86_REG_EIP)),size,self.capacity)
        start = address-DESTINATION; self.mask[start:start+size] = b'\1'*size

    def probe(self,label,raw,capacity,level=None,fail_at=0):
        assert len(raw) < 0x7fffe0 and 0 <= capacity < 0x7fffe0
        self.capacity = capacity; self.fail_at = fail_at
        self.heap_cursor = 0x100; self.allocations = []; self.events = []; self.mask = bytearray(capacity); self.rep_mask = bytearray(capacity); self.rep_pending = None
        self.pending = []; self.helpers = []; self.copies = []
        self.uc.mem_write(SOURCE,raw+b'\x96'*16)
        self.uc.mem_write(DESTINATION,b'\xa5'*capacity+b'\x69'*16)
        assert bytes(self.uc.mem_read(DESTINATION,capacity+16))==b'\xa5'*capacity+b'\x69'*16
        self.put(LENGTH,capacity)
        arguments = [DESTINATION,LENGTH,SOURCE,len(raw)]
        entry = 0x43f4b0 if level is None else 0x43f400
        if level is not None: arguments.append(level & 0xffffffff)
        sp = STACK+0xf000
        self.uc.mem_write(sp,struct.pack('<'+'I'*(len(arguments)+1),STOP,*arguments))
        self.uc.reg_write(UC_X86_REG_ESP,sp); self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        saved = [self.uc.reg_read(r) for r in REGISTERS]
        self.running = True
        try: self.uc.emu_start(entry,STOP,count=2_000_000_000)
        finally: self.running = False
        assert self.uc.reg_read(UC_X86_REG_EIP) == STOP, hex(self.uc.reg_read(UC_X86_REG_EIP))
        # Unicorn stops before executing STOP or firing its code hook.
        assert len(self.pending) == 1 and self.pending[0]['entry'] == entry and self.pending[0]['returnPC'] == STOP
        outer = self.pending.pop(); outer.update(returnSP=self.uc.reg_read(UC_X86_REG_ESP),result=signed(self.uc.reg_read(UC_X86_REG_EAX)))
        self.helpers.append(outer)
        assert self.uc.reg_read(UC_X86_REG_ESP) == sp+4+4*len(arguments)
        assert saved == [self.uc.reg_read(r) for r in REGISTERS]
        assert self.uc.reg_read(UC_X86_REG_FPCW) == 0x23f
        assert bytes(self.uc.mem_read(SOURCE,len(raw)+16)) == raw+b'\x96'*16
        assert bytes(self.uc.mem_read(DESTINATION+capacity,16)) == b'\x69'*16
        output = bytes(self.uc.mem_read(DESTINATION,capacity))
        assert self.rep_pending is None
        assert all(not flag or self.rep_mask[i] for i,flag in enumerate(self.mask))
        unobserved=[i for i,(value,flag) in enumerate(zip(output,self.rep_mask)) if not flag and value != 0xa5]
        if unobserved:
            (ROOT/'build/research/replay-compression-write-failure.json').write_text(json.dumps(dict(label=label,unobserved=len(unobserved),first=unobserved[:32],observed=sum(self.mask),capacity=capacity,maskLength=len(self.mask),repObserved=sum(self.rep_mask),copies=self.copies),indent=2)+'\n')
        assert not unobserved, (label,len(unobserved),unobserved[:32],sum(self.mask),capacity)
        return dict(label=label,input=raw.hex(),capacity=capacity,level=level,failAt=fail_at,
            result=signed(self.uc.reg_read(UC_X86_REG_EAX)),length=self.u32(LENGTH),output=output.hex(),
            written=self.rep_mask.hex(),memoryHookWritten=self.mask.hex(),copies=self.copies,events=self.events,allocations=self.allocations,helpers=self.helpers)

    def instructions(self):
        result = set()
        for pc,size in self.blocks:
            if not (0x401000 <= pc < 0x446000 or 0x78130000 <= pc < 0x78230000): continue
            decoded = list(self.decoder.disasm(bytes(self.uc.mem_read(pc,size)),pc))
            assert sum(i.size for i in decoded) == size
            result.update(i.address for i in decoded)
        return sorted(result)


def probes(sample=False):
    rng = random.Random(0x43f4b0)  # Controlled stimulus only.
    payloads = [('empty',b''),('byte',b'N'),('text',b'NTSD 2.4 replay\0'*31),
                ('all-bytes',bytes(range(256))*4),('varied',rng.randbytes(8192))]
    if sample: return [(name,raw,len(raw)+128,None,0) for name,raw in payloads]
    cases = []
    for name,raw in payloads:
        for level in (None,*range(-2,11)):
            for capacity in sorted({0,1,2,5,8,len(raw)//2,len(raw),len(raw)+128}):
                cases.append((f'{name}-level{level}-capacity{capacity}',raw,capacity,level,0))
        for fail in range(1,6): cases.append((f'{name}-allocation{fail}',raw,len(raw)+128,None,fail))
    for size in (261,262,263,16383,16384,16385,32767,32768,32769,65273,65274,65535,65536,65537,131072,262144,524288):
        for kind in ('repeated','random'):
            raw = (b'NTSD 2.4\0'*((size+8)//9))[:size] if kind == 'repeated' else rng.randbytes(size)
            cases.append((f'{kind}-{size}',raw,size+1024,None,0))
    recorded=set()
    for provenance,raw in recording_inputs():
        if digest(raw) in recorded: continue  # Both first-tick recordings are identical.
        recorded.add(digest(raw))
        cases.append(('own-recording',raw,0x631200,None,0))
    cases.append(('full-zero-recording',bytes(0x630e18),0x631200,None,0))
    noisy=rng.randbytes(0x630e18)
    cases.append(('full-random-recording-writer-capacity',noisy,0x631200,None,0))
    cases.append(('full-random-recording-larger-capacity',noisy,0x640000,None,0))
    return cases


def recording_inputs():
    for suffix in ('','-control'):
        name='gameplay-notices'+suffix
        evidence=json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes())
        parent_raw=(ROOT/'build/original'/evidence['corpus']).read_bytes()
        assert digest(parent_raw)==evidence['sha256'] and len(parent_raw)==evidence['bytes']
        assert digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/evidence['fixture']).read_bytes())==evidence['fixtureSHA256']
        parent=json.loads(parent_raw)
        key=parent['cases'][0]['before']['state']['memory'][0]['bytes']; blob=parent['blobs'][key]
        raw=zlib.decompress(base64.b64decode(blob['deflate']),-15)
        assert len(raw)==blob['count']==0x630e18 and digest(raw)==key
        yield dict(fixture=evidence['fixture'],fixtureSHA256=evidence['fixtureSHA256'],recordingSHA256=key),raw


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--sample',action='store_true'); parser.add_argument('--case'); args=parser.parse_args()
    vm=ReplayCompression(); cases=[]; edges={}; seen=set()
    for name,raw,capacity,level,fail in probes(args.sample):
        if args.case and name != args.case: continue
        result=vm.probe(name,raw,capacity,level,fail);cases.append(result)
        key=(digest(raw),capacity,level,fail); assert key not in seen; seen.add(key)
        if not args.sample and result['result']==0 and len(raw)<200000:
            for cap in (result['length']-1,result['length'],result['length']+1):
                edges[(digest(raw),cap,level,0)]=(f'{name}-exact{cap}',raw,cap,level,0)
        print(name,'status',result['result'],'length',result['length'],'allocations',sum(e['kind']=='calloc' for e in result['events']),flush=True)
    for key,item in edges.items():
        if key in seen: continue
        seen.add(key);result=vm.probe(*item);cases.append(result)
        print(item[0],'status',result['result'],'length',result['length'],flush=True)
    blobs={}
    for c in cases:
        for field in ('input','output','written','memoryHookWritten'):
            value=bytes.fromhex(c[field]);key=digest(value)
            if key not in blobs: blobs[key]=dict(count=len(value),deflate=base64.b64encode(zlib.compress(value,9,wbits=-15)).decode())
            c[field]=key
    doc=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,cases=cases,instructions=vm.instructions(),blobs=blobs,
        recordingInputs=[] if args.sample else [p for p,_ in recording_inputs()])
    name='replay-compression'+('-sample' if args.sample else '-single' if args.case else '')
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();(ROOT/'build/original'/(name+'.json')).write_bytes(raw)
    report=dict(exeSHA256=EXE_SHA256,dllSHA256=DLL_SHA256,scope=__doc__,corpus=name+'.json',sha256=digest(raw),bytes=len(raw),cases=len(cases),instructions=len(doc['instructions']),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research'/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__': main()
