#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.6"]
# ///
"""Research the original writer's actual MSVCP80 output-stream dependency.

Development tooling only. Actual pinned C++/CRT instructions run with declared
private allocator, thread/locks, open FILE and descriptor responses. Actual CRT
stdio performs buffering and flush/close. No Windows file is created.
The producer alone does not establish native equivalence or execute43dd60.
"""
import argparse
import base64
import hashlib
import io
import json
import struct
import subprocess
import tempfile
import zlib
from collections import deque
from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from import_ntsd import ROOT, read_bytes, DEFAULT_SOURCE, EXE_SHA256
from inspect_original import PE
from oracle_crt import CRT, prepare, PACKAGE_SHA256, DLL_SHA256, STACK, STOP, PTD
from oracle_replay_compression import exports
from unicorn import UC_HOOK_CODE, UC_HOOK_BLOCK
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EBP, UC_X86_REG_ESP, UC_X86_REG_EIP

CPP_NAME = 'msvcp80.dll.8.0.50727.6195.98CB24AD_52FB_DB5F_FF1F_C8B3B9A1E18E'
CPP_SHA256 = '372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2'
MEMORY, HEAP, API = 0x27000000, 0x28000000, STOP+0xc000
STREAM, FILE, PATH, PAYLOAD = MEMORY, MEMORY+0x1000, MEMORY+0x2000, 0x29000000
FD_TABLE = MEMORY+0xe0000
ENTRIES = {'construct':0x7c43a26c, 'write':0x7c4442e2, 'close':0x7c4336dc, 'destroy':0x7c43f756}
SAVED = [UC_X86_REG_EBX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_EBP]
digest = lambda value: hashlib.sha256(value).hexdigest()


def prepare_cpp():
    package = ROOT/'downloads/vcredist_x86_2005sp1.exe'
    assert digest(read_bytes(package)) == PACKAGE_SHA256
    destination = ROOT/'build/original/crt/msvcp80.dll'
    if destination.is_file():
        assert digest(destination.read_bytes()) == CPP_SHA256
        return destination
    import olefile
    msi = subprocess.run(['bsdtar','-xOf',str(package),'vcredist.msi'],check=True,capture_output=True).stdout
    with olefile.OleFileIO(io.BytesIO(msi)) as ole:
        for entry in ole.listdir():
            raw = ole.openstream(entry).read()
            if not raw.startswith(b'MSCF'): continue
            with tempfile.NamedTemporaryFile(suffix='.cab') as cab:
                cab.write(raw);cab.flush()
                names = subprocess.run(['bsdtar','-tf',cab.name],check=True,capture_output=True).stdout.decode().splitlines()
                if CPP_NAME not in names: continue
                data = subprocess.run(['bsdtar','-xOf',cab.name,CPP_NAME],check=True,capture_output=True).stdout
                assert digest(data) == CPP_SHA256
                destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data)
                return destination
    raise ValueError('Pinned MSVCP80 was not found in the original redistributable')


class ReplayStream(CRT):
    def __init__(self, open_failure=False, short_write=0, close_failure=False,
                 write_result=None, buffer_failure=False):
        self.cpp_boundaries = {}; self.blocks = set(); self.events = [];self.recent=deque(maxlen=50);self.executed=set()
        self.open_failure = open_failure;self.short_write = short_write;self.close_failure = close_failure
        self.write_result=write_result;self.buffer_failure=buffer_failure
        self.cursor = 0x100;self.allocations = {};self.write_count = 0
        super().__init__()
        pe = PE(prepare_cpp().read_bytes());self.cpp_pe = pe
        self.uc.mem_map(pe.base,0x100000)
        for s in pe.sections:
            self.uc.mem_write(pe.base+s['rva'],pe.data[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.crt_exports = exports(PE(prepare().read_bytes()));self.cpp_exports = exports(pe)
        original=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(original)==EXE_SHA256
        selected={int(item['iatVA'],16):self.cpp_exports[item['name']] for item in PE(original).imports()
                  if 0x4470d8<=int(item['iatVA'],16)<=0x4470e4}
        assert selected=={0x4470d8:ENTRIES['construct'],0x4470dc:ENTRIES['write'],
                          0x4470e0:ENTRIES['destroy'],0x4470e4:ENTRIES['close']}
        # Explicit _osplatform=2 research environment, consumed by the real
        # _get_osplatform. CRT startup producer78132179 is not executed here.
        self.put(0x781c37c0,2)
        for index,item in enumerate(pe.imports()):
            if item['dll'].lower() == 'msvcr80.dll': pointer = self.crt_exports[item['name']]
            else:
                pointer = API+16*index;self.cpp_boundaries[pointer] = item['name']
            self.put(int(item['iatVA'],16),pointer)
        for name in ('??2@YAPAXI@Z','??3@YAXPAX@Z','??_V@YAXPAX@Z','_malloc_crt','_calloc_crt','free',
                     '_fsopen','_wfsopen','_write','_close',
                     '_invalid_parameter_noinfo','_invoke_watson','_CxxThrowException'):
            pc = self.crt_exports[name];self.cpp_boundaries[pc] = name
            self.uc.hook_add(UC_HOOK_CODE,self.boundary,begin=pc,end=pc)
        # Same declared thread as the inherited _getptd boundary. The real
        # _getptd_noexit differs only in handling an unavailable thread block.
        self.cpp_boundaries[0x78132db2]='_getptd_noexit'
        self.uc.hook_add(UC_HOOK_CODE,self.boundary,begin=0x78132db2,end=0x78132db2)
        for address in (MEMORY, HEAP): self.uc.mem_map(address,0x100000)
        self.uc.mem_map(PAYLOAD,0x800000)
        # Supplied open response also owns descriptor3's binary, non-append
        # record. _flsbuf7813f088 reads this table even with _write intercepted.
        # Never let that read silently use the mapped zero/SEH page.
        self.put(0x781c4820,FD_TABLE)
        descriptor=bytearray(64);struct.pack_into('<I',descriptor,0,0x13572468);descriptor[4]=1
        self.uc.mem_write(FD_TABLE+3*64,bytes(descriptor))
        self.block_hook=self.uc.hook_add(UC_HOOK_BLOCK,self.block)
        for begin,end in ((0x78130000,0x7822ffff),(pe.base,pe.base+0xfffff)):
            self.uc.hook_add(UC_HOOK_CODE,self.instruction,begin=begin,end=end)
        self.decoder = Cs(CS_ARCH_X86,CS_MODE_32)
        self.uc.mem_write(STREAM,b'\xa5'*0x100)
        self.uc.mem_write(PATH,b'recording\\probe.lfr\0')
        self.put(0,0x12345678)

    def block(self, uc, pc, size, data):
        self.blocks.add((pc,size))
        if pc<STOP or pc>=STOP+0x10000:
            if not self.recent or self.recent[-1]!=(pc,size):self.recent.append((pc,size))

    def instruction(self,uc,pc,size,data):
        if pc not in self.cpp_boundaries and pc not in self.boundaries:self.executed.add(pc)

    def cstring(self, address, unit=1):
        result = bytearray()
        for i in range(4096):
            value = bytes(self.uc.mem_read(address+i*unit,unit))
            if not any(value):return bytes(result)
            result.extend(value)
        raise AssertionError(('Unterminated source string',hex(address)))

    def boundary(self, uc, pc, size, data):
        name = self.cpp_boundaries.get(pc)
        if name is None:
            if self.boundaries.get(pc) in ('InterlockedDecrement','TlsGetValue'):name=self.boundaries[pc]
            else:return super().boundary(uc,pc,size,data)
        sp = uc.reg_read(UC_X86_REG_ESP)
        arg = lambda i:self.u32(sp+4+4*i)
        event = dict(name=name,returnPC=self.u32(sp))
        if name=='_getptd_noexit':self.ret(PTD)
        elif name=='TlsGetValue':
            # Optional FLS/encoded-pointer extension discovery, matching the
            # inherited unavailable GetModuleHandleA response. PTD is separate.
            assert arg(0)==0xffffffff
            event.update(index=arg(0),result=0);self.ret(0,4)
        elif name in ('??2@YAPAXI@Z','_malloc_crt','_calloc_crt'):
            count = arg(0)*(arg(1) if name=='_calloc_crt' else 1)
            if name=='_malloc_crt' and count==4096 and self.buffer_failure:
                event.update(count=count,address=0);self.events.append(event);self.ret(0);return
            address = HEAP+self.cursor;self.cursor += (count+31)&~15
            assert count>0 and self.cursor<0x100000
            self.uc.mem_write(address,(b'\0' if name=='_calloc_crt' else b'\xa5')*count)
            self.allocations[address] = count;event.update(count=count,address=address)
            self.ret(address)
        elif name in ('??3@YAXPAX@Z','??_V@YAXPAX@Z','free'):
            address=arg(0)
            if address:assert address in self.allocations;del self.allocations[address]
            event.update(address=address);self.ret()
        elif name in ('EnterCriticalSection','LeaveCriticalSection','InitializeCriticalSection','DeleteCriticalSection'):
            event.update(address=arg(0));self.ret(0,4)
        elif name in ('InterlockedIncrement','InterlockedDecrement'):
            address=arg(0);value=(self.u32(address)+(1 if name=='InterlockedIncrement' else -1))&0xffffffff
            self.put(address,value);event.update(address=address,value=value);self.ret(value,4)
        elif name in ('_fsopen','_wfsopen'):
            unit=2 if name=='_wfsopen' else 1
            event.update(path=self.cstring(arg(0),unit).hex(),mode=self.cstring(arg(1),unit).hex(),share=arg(2),result=0 if self.open_failure else FILE)
            self.uc.mem_write(FILE,struct.pack('<8I',0,0,0,2,3,0,0,0))
            self.ret(0 if self.open_failure else FILE)
        elif name=='_write':
            self.write_count+=1;count=arg(2);assert arg(0)==3
            output=bytes(self.uc.mem_read(arg(1),count))
            result=(max(0,count-1) if self.write_result is None else self.write_result) if self.write_count==self.short_write else count
            event.update(count=count,bytes=output.hex(),result=result);self.ret(result)
        elif name=='_close':
            assert arg(0)==3;event.update(result=-1 if self.close_failure else 0);self.ret(event['result'])
        else:raise AssertionError(('Unimplemented explicit boundary',name,hex(self.u32(sp))))
        self.events.append(event)

    def invoke(self,name,args):
        sp=STACK+0xf000;self.uc.mem_write(sp,struct.pack('<'+'I'*(len(args)+1),STOP,*args))
        self.uc.reg_write(UC_X86_REG_ESP,sp);self.uc.reg_write(UC_X86_REG_ECX,STREAM)
        before=[self.uc.reg_read(r) for r in SAVED]
        self.uc.emu_start(ENTRIES[name],STOP,count=100_000_000)
        assert self.uc.reg_read(UC_X86_REG_EIP)==STOP
        assert self.uc.reg_read(UC_X86_REG_ESP)==sp+4+4*len(args)
        assert before==[self.uc.reg_read(r) for r in SAVED] and self.u32(0)==0x12345678
        stream=bytes(self.uc.mem_read(STREAM,0x88))
        return dict(name=name,entry=ENTRIES[name],entrySP=sp,returnSP=self.uc.reg_read(UC_X86_REG_ESP),
                    result=self.uc.reg_read(UC_X86_REG_EAX),stream=stream.hex(),
                    file=bytes(self.uc.mem_read(FILE,32)).hex(),state=int.from_bytes(stream[0x5c:0x60],'little'))

    def instructions(self):
        return sorted(self.executed)


def probe(label, payload, *, path=b'recording\\probe.lfr', open_failure=False,
          short_write=0, close_failure=False, write_result=None, buffer_failure=False):
    vm=ReplayStream(open_failure,short_write,close_failure,write_result,buffer_failure)
    vm.uc.mem_write(PATH,path+b'\0');calls=[]
    calls.append(vm.invoke('construct',[PATH,0x20,0x40,1]))
    for value in (struct.pack('<I',len(payload)),payload):
        if value:vm.uc.mem_write(PAYLOAD,value)
        calls.append(vm.invoke('write',[PAYLOAD,len(value)]))
    calls.append(vm.invoke('close',[]));calls.append(vm.invoke('destroy',[]))
    return dict(label=label,payload=payload.hex(),path=path.hex(),openFailure=open_failure,
        shortWrite=short_write,writeResult=write_result,closeFailure=close_failure,
        bufferFailure=buffer_failure,calls=calls,events=vm.events,
        instructions=vm.instructions(),liveAllocations=vm.allocations)


def capture_suite():
    cases=[]
    pattern=lambda n:(bytes(range(256))*((n+255)//256))[:n]
    for n in (0,1,7,4091,4092,4093,8191,8192,8193,10047):
        cases.append(probe(f'normal-{n}',pattern(n)))
    for n in (7,4093,8192):
        cases.append(probe(f'open-failure-{n}',pattern(n),open_failure=True))
        cases.append(probe(f'close-failure-{n}',pattern(n),close_failure=True))
        for ordinal in (1,2,3):
            for result in (None,0,-1):
                cases.append(probe(f'write-{ordinal}-result{result}-{n}',pattern(n),short_write=ordinal,write_result=result))
    for n in (0,1,7,31):
        cases.append(probe(f'buffer-failure-{n}',pattern(n),buffer_failure=True))
    for ordinal in (1,4,5,11):
        for result in (0,-1):
            cases.append(probe(f'unbuffered-write-{ordinal}-result{result}',pattern(7),
                buffer_failure=True,short_write=ordinal,write_result=result))
    for n in (255,258,259,260,261,512):
        cases.append(probe(f'path-length-{n}',pattern(7),path=b'x'*n))
    cases.append(probe('path-empty',pattern(7),path=b''))
    cases.append(probe('path-all-nonzero-bytes',pattern(7),path=bytes(range(1,256))))
    cases.append(probe('write-and-close-failure',pattern(8192),short_write=1,write_result=-1,close_failure=True))
    codec_report=json.loads((ROOT/'docs/evidence/replay-compression.json').read_bytes())
    codec_raw=(ROOT/'build/original'/codec_report['corpus']).read_bytes()
    assert digest(codec_raw)==codec_report['sha256']
    codec=json.loads(codec_raw);codec_inputs=[]
    for name in ('own-recording','full-random-recording-writer-capacity'):
        item=next(c for c in codec['cases'] if c['label']==name);key=item['output'];blob=codec['blobs'][key]
        data=zlib.decompress(base64.b64decode(blob['deflate']),-15)
        assert len(data)==blob['count'] and digest(data)==key
        data=data[:item['length']]
        cases.append(probe('codec-output-'+name,data))
        codec_inputs.append(dict(case=name,codecCorpusSHA256=codec_report['sha256'],
                                 outputBlobSHA256=key,payloadSHA256=digest(data),bytes=len(data),keyApplied=False))
    instructions=sorted({pc for c in cases for pc in c['instructions']})
    boundaries=sorted({e['name'] for c in cases for e in c['events']})
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,cppSHA256=CPP_SHA256,crtSHA256=DLL_SHA256,packageSHA256=PACKAGE_SHA256,
        platformWord=dict(address=0x781c37c0,value=2,producerExecuted=False),
        fileBacking=dict(address=FILE,fields=[0,0,0,2,3,0,0,0],openBoundary=True),
        descriptorBacking=dict(tablePointerAddress=0x781c4820,table=FD_TABLE,ordinal=3,
            recordBytes=64,osHandle=0x13572468,flags=1,remainingBytes=0,producerExecuted=False),
        cases=cases,instructions=instructions,declaredBoundaries=boundaries,codecInputs=codec_inputs,
        inheritedBoundaries=['_lock','_unlock','_getptd','EnterCriticalSection','LeaveCriticalSection','InterlockedIncrement','GetModuleHandleA'],
        nativeCompared=False,windowsVerified=False,wholeWriterExecuted=False,ownInitializedContinuation=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode()
    path=ROOT/'build/original/replay-stream.json';path.write_bytes(raw)
    report=dict(scope=__doc__,corpus=path.name,bytes=len(raw),sha256=digest(raw),
        exeSHA256=EXE_SHA256,cppSHA256=CPP_SHA256,crtSHA256=DLL_SHA256,packageSHA256=PACKAGE_SHA256,
        cases=len(cases),wholeStreamReturns=sum(len(c['calls']) for c in cases),
        instructions=len(instructions),cppInstructions=sum(0x7c420000<=pc<0x7c520000 for pc in instructions),
        crtInstructions=sum(0x78130000<=pc<0x78230000 for pc in instructions),
        descriptorWrites=sum(e['name']=='_write' for c in cases for e in c['events']),
        declaredBoundaries=boundaries,platformWord=doc['platformWord'],fileBacking=doc['fileBacking'],
        descriptorBacking=doc['descriptorBacking'],
        codecInputs=codec_inputs,
        nativeCompared=False,windowsVerified=False,wholeWriterExecuted=False,ownInitializedContinuation=False)
    (ROOT/'build/research/replay-stream.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--open-failure',action='store_true');parser.add_argument('--short-write',type=int,default=0)
    parser.add_argument('--suite',action='store_true')
    parser.add_argument('--close-failure',action='store_true');args=parser.parse_args()
    if args.suite:capture_suite();return
    vm=ReplayStream(args.open_failure,args.short_write,args.close_failure)
    calls=[]
    try:
        calls.append(vm.invoke('construct',[PATH,0x20,0x40,1]))
        for value in (struct.pack('<I',7),b'NTSD\0\xff\n'):
            vm.uc.mem_write(PAYLOAD,value);calls.append(vm.invoke('write',[PAYLOAD,len(value)]))
        calls.append(vm.invoke('close',[]));calls.append(vm.invoke('destroy',[]))
    except Exception:
        print(json.dumps(dict(events=vm.events,pc=hex(vm.uc.reg_read(UC_X86_REG_EIP)),sp=hex(vm.uc.reg_read(UC_X86_REG_ESP))),indent=2),flush=True)
        for pc,size in vm.recent:
            for i in vm.decoder.disasm(bytes(vm.uc.mem_read(pc,size)),pc):
                print(f'{i.address:08x} {i.mnemonic} {i.op_str}',flush=True)
        raise
    report=dict(scope=__doc__,cppSHA256=CPP_SHA256,crtSHA256=DLL_SHA256,calls=calls,events=vm.events,
        instructions=vm.instructions(),liveAllocations=vm.allocations,nativeCompared=False,windowsVerified=False)
    path=ROOT/'build/research/replay-stream-probe.json';path.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(calls=len(calls),events=len(vm.events),instructions=len(report['instructions']),artifact=str(path)),indent=2))

if __name__=='__main__':main()
