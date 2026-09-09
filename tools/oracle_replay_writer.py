#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47", "capstone==5.0.6"]
# ///
"""Execute whole original43dd60 with actual compression, C++ streams and CRT.

Controlled original recording/key/name, allocator and file-descriptor responses.
No host codec output is injected. Not an own initialized match or Windows IO.
"""
import argparse
import base64
import json
import random
import zlib
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE
from oracle_crt import STACK, STOP, DLL_SHA256
from oracle_replay_stream import ReplayStream, ENTRIES, CPP_SHA256, PACKAGE_SHA256, SAVED
from oracle_replay_compression import ReplayCompression, HELPERS, SOURCE, DESTINATION, HEAP, recording_inputs, digest, signed
from unicorn import UcError, UC_HOOK_BLOCK, UC_HOOK_CODE, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_HOOK_MEM_INVALID
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_EIP, UC_X86_REG_ESP, UC_X86_REG_FPCW

ENTRY, SP, CAPACITY, SOURCE_COUNT = 0x43dd60, STACK+0xf000, 0x631200, 0x630e18
BODY_SP, NAME, KEY, POINTER, WRITER_API = SP-0x2a8, 0x44fd98, 0x44d7a0, 0x4588a8, STOP+0x8000
GLOBAL, GLOBAL_COUNT = 0x44d000, 0xb440


class ReplayWriter(ReplayStream):
    def __init__(self, *, allocation_failure=0, null_source=False, **file_options):
        self.writer_imports={}
        super().__init__(**file_options)
        self.uc.hook_del(self.block_hook)
        self.codec_blocks=set()
        self.uc.hook_add(UC_HOOK_BLOCK,self.codec_block,begin=0x43f400,end=0x445fff)
        raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(raw)==EXE_SHA256
        pe=PE(raw);self.uc.mem_map(pe.base,0x100000)
        for s in pe.sections:
            if s['name']!='.rsrc':self.uc.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        for index,item in enumerate(pe.imports()):
            name=item['name'];pointer=WRITER_API+16*index
            if item['dll'].lower()=='msvcp80.dll':pointer=self.cpp_exports[name]
            elif item['dll'].lower()=='msvcr80.dll' and name not in ('calloc','free'):pointer=self.crt_exports[name]
            else:self.writer_imports[pointer]=name
            self.put(int(item['iatVA'],16),pointer)
        for address in (SOURCE,DESTINATION):self.uc.mem_map(address,0x800000)
        self.uc.mem_map(HEAP,0x100000)
        self.writer_events=[];self.writer_allocations=[]
        self.heap_cursor=0x100;self.fail_at=allocation_failure;self.null_source=null_source
        self.capacity=CAPACITY;self.mask=bytearray(CAPACITY);self.rep_mask=bytearray(CAPACITY)
        self.rep_pending=None;self.copies=[];self.running=True;self.pending=[];self.helpers=[];self.return_hooks=set()
        self.writer_pcs=set();self.pc_hooks={};self.stages=[];self.stream_calls=[];self.stream_pending=[]
        self.codec_result=None;self.compressed=None;self.fault=None;self.formatted=None
        self.searches=0;self.processor_signatures=[];self.selector_writes=[]
        begin=pe.offset(ENTRY-pe.base)
        for instruction in self.decoder.disasm(raw[begin:begin+0x199],ENTRY):
            pc=instruction.address
            self.pc_hooks[pc]=self.uc.hook_add(UC_HOOK_CODE,self.writer_pc,begin=pc,end=pc)
        for pc in HELPERS:self.uc.hook_add(UC_HOOK_CODE,self.helper,begin=pc,end=pc)
        for pc in (0x43f5c3,0x43f5c5,0x43f5ca,0x43f5cc):
            self.uc.hook_add(UC_HOOK_CODE,self.rep_copy,begin=pc,end=pc)
        for pc in (0x43ddb3,0x43dde4,0x43de4f,0x43ded1,0x4450b2):
            self.uc.hook_add(UC_HOOK_CODE,self.stage,begin=pc,end=pc)
        for pc in ENTRIES.values():self.uc.hook_add(UC_HOOK_CODE,self.stream_call,begin=pc,end=pc)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.output_write,begin=DESTINATION,end=DESTINATION+0x7fffff)
        for kind in (UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE):
            self.uc.hook_add(kind,self.null_access,begin=0,end=0xfff)
        self.uc.hook_add(UC_HOOK_MEM_INVALID,self.unmapped_access)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.pointer_write,begin=POINTER,end=POINTER+3)
        self.uc.hook_add(UC_HOOK_CODE,self.search,begin=0x4428b0,end=0x4428b0)
        self.uc.hook_add(UC_HOOK_CODE,self.processor,begin=0x443aef,end=0x443aef)
        self.uc.hook_add(UC_HOOK_MEM_WRITE,self.selector_write,begin=0x44dd50,end=0x44dd53)

    def cstring(self,address,unit=1):
        if address!=KEY or unit!=1:return super().cstring(address,unit)
        # The stream probe's4096-unit path bound is not the writer key's
        # extent. Read only mapped original globals and require its real NUL.
        raw=bytes(self.uc.mem_read(KEY,GLOBAL+GLOBAL_COUNT-KEY))
        end=raw.find(b'\0')
        assert end>=0,'Unterminated key in supplied global backing'
        return raw[:end]

    def search(self,uc,pc,size,data):self.searches+=1
    def processor(self,uc,pc,size,data):self.processor_signatures.append(uc.reg_read(UC_X86_REG_EAX))
    def selector_write(self,uc,access,address,size,value,data):
        self.selector_writes.append(dict(pc=uc.reg_read(UC_X86_REG_EIP),address=address,size=size,value=value&0xffffffff))

    def writer_pc(self,uc,pc,size,data):
        self.writer_pcs.add(pc)
        # Observe each actual instruction start once without a Python callback
        # for every repeated strlen iteration. No game instruction is replaced.
        uc.hook_del(self.pc_hooks.pop(pc))

    def codec_block(self,uc,pc,size,data):self.codec_blocks.add((pc,size))
    def helper(self,*args):return ReplayCompression.helper(self,*args)
    def rep_copy(self,*args):return ReplayCompression.rep_copy(self,*args)

    def output_write(self,uc,access,address,size,value,data):
        assert DESTINATION<=address<address+size<=DESTINATION+CAPACITY
        if self.codec_result is None:
            start=address-DESTINATION;self.mask[start:start+size]=b'\1'*size

    def pointer_write(self,uc,access,address,size,value,data):
        self.writer_events.append(dict(kind='pointer',address=address,size=size,value=value&0xffffffff))

    def null_access(self,uc,access,address,size,value,data):
        pc=uc.reg_read(UC_X86_REG_EIP)
        instruction=next(self.decoder.disasm(bytes(uc.mem_read(pc,15)),pc))
        if 'fs:' in instruction.op_str:return
        self.fault=dict(kind='nullBacking',pc=pc,address=address,size=size,access=access)
        uc.emu_stop()

    def unmapped_access(self,uc,access,address,size,value,data):
        self.fault=dict(kind='unmappedBacking',pc=uc.reg_read(UC_X86_REG_EIP),address=address,size=size,access=access)
        return False

    def boundary(self,uc,pc,size,data):
        if self.cpp_boundaries.get(pc)=='_invoke_watson':
            sp=uc.reg_read(UC_X86_REG_ESP)
            self.fault=dict(kind='crtInvalidParameter',pc=pc,returnPC=self.u32(sp),
                            arguments=[self.u32(sp+4+4*i) for i in range(5)])
            # The actual CRT validation/handler selection ran; Watson's
            # platform diagnostics/termination are an explicit stopped boundary.
            uc.emu_stop();return
        if pc not in self.writer_imports:
            start=len(self.events)
            super().boundary(uc,pc,size,data)
            for event in self.events[start:]:
                if event['name'] in ('_wfsopen','_write','_close'):
                    self.writer_events.append(dict(kind='file',**event))
            return
        name=self.writer_imports[pc];sp=uc.reg_read(UC_X86_REG_ESP)
        if name=='calloc':
            count,amount=self.u32(sp+4),self.u32(sp+8);ordinal=len(self.writer_allocations)+1
            address=0 if ordinal==self.fail_at else DESTINATION if ordinal==1 else HEAP+self.heap_cursor
            event=dict(kind='calloc',count=count,size=amount,address=address,ordinal=ordinal,live=address!=0)
            self.writer_allocations.append(event.copy());self.writer_events.append({k:v for k,v in event.items() if k!='live'})
            if address:
                assert count*amount<=CAPACITY if ordinal==1 else count*amount<0x100000-self.heap_cursor
                uc.mem_write(address,b'\0'*(count*amount))
                if ordinal!=1:self.heap_cursor+=(count*amount+31)&~15
            self.ret(address)
        elif name=='free':
            address=self.u32(sp+4)
            if address==SOURCE:
                assert not self.source_freed;self.source_freed=True
            elif address:
                allocation=next(a for a in self.writer_allocations if a['address']==address)
                assert allocation['live'];allocation['live']=False
            self.writer_events.append(dict(kind='free',address=address));self.ret()
        else:raise AssertionError(('Unexpected writer import',name,hex(self.u32(sp))))

    def stage(self,uc,pc,size,data):
        if pc==0x43ddb3:
            self.formatted=self.cstring(BODY_SP+0xa4)
            self.writer_events.append(dict(kind='format',bytes=self.formatted.hex()))
        elif pc==0x43dde4:
            self.codec_result=signed(uc.reg_read(UC_X86_REG_EAX))
            self.length=self.u32(BODY_SP+0x14)
            self.compressed=bytes(uc.mem_read(DESTINATION,CAPACITY))
            assert self.rep_pending is None
            self.writer_events.append(dict(kind='compressed',status=self.codec_result,length=self.length))
        elif pc==0x43de4f:
            self.adjusted=bytes(uc.mem_read(DESTINATION,CAPACITY))
            self.writer_events.append(dict(kind='adjusted'))
        elif pc==0x4450b2:
            expected=self.u32(0x44eea4);actual=uc.reg_read(UC_X86_REG_ECX)
            if actual!=expected:
                self.fault=dict(kind='cookie',pc=pc,expected=expected,actual=actual)
                # Continue the actual comparison/branch, stopping at the failure
                # helper rather than treating this as a successful return.
                self.uc.hook_add(UC_HOOK_CODE,self.cookie_failure,begin=0x44556a,end=0x44556a)
        self.stages.append(dict(pc=pc,sp=uc.reg_read(UC_X86_REG_ESP),recording=self.u32(POINTER)))

    def cookie_failure(self,uc,pc,size,data):
        assert self.fault and self.fault['kind']=='cookie';self.fault['stopPC']=pc;uc.emu_stop()

    def stream_call(self,uc,pc,size,data):
        sp=uc.reg_read(UC_X86_REG_ESP)
        if self.stream_pending and pc==self.stream_pending[-1]['returnPC']:
            item=self.stream_pending.pop();assert sp==item['entrySP']+4+item['pop']
            assert item.pop('saved')==[uc.reg_read(r) for r in SAVED]
            item.update(returnSP=sp,state=self.u32(item['object']+0x5c))
            self.stream_calls.append(item);self.writer_events.append(dict(kind='streamReturn',name=item['name'],state=item['state']))
        if pc in ENTRIES.values():
            name=next(n for n,p in ENTRIES.items() if p==pc);ret=self.u32(sp)
            item=dict(name=name,entrySP=sp,returnPC=ret,object=uc.reg_read(UC_X86_REG_ECX),
                      saved=[uc.reg_read(r) for r in SAVED],pop={'construct':16,'write':8,'close':0,'destroy':0}[name])
            self.stream_pending.append(item)
            self.uc.hook_add(UC_HOOK_CODE,self.stream_call,begin=ret,end=ret)

    def execute(self,source,name,key=None,selector=None):
        assert len(source)==SOURCE_COUNT and b'\0' not in name
        self.source_freed=False
        self.uc.mem_write(SOURCE,source+b'\x96'*16)
        self.uc.mem_write(DESTINATION,b'\xa5'*CAPACITY+b'\x69'*16)
        self.uc.mem_write(NAME,name+b'\0')
        if key is not None:self.uc.mem_write(KEY,key+b'\0')
        if selector is not None:self.put(0x44dd50,selector)
        self.key=self.cstring(KEY);self.put(POINTER,0 if self.null_source else SOURCE)
        self.globals_before=bytes(self.uc.mem_read(GLOBAL,GLOBAL_COUNT))
        self.uc.mem_write(SP-0x800,b'\xa5'*0x800);self.put(SP,STOP)
        self.uc.reg_write(UC_X86_REG_ESP,SP);self.uc.reg_write(UC_X86_REG_FPCW,0x23f)
        saved=[self.uc.reg_read(r) for r in SAVED]
        try:self.uc.emu_start(ENTRY,STOP,count=2_000_000_000)
        except UcError:
            if not self.fault:raise
        pc=self.uc.reg_read(UC_X86_REG_EIP)
        if not self.fault:
            assert pc==STOP and self.uc.reg_read(UC_X86_REG_ESP)==SP+4
            assert saved==[self.uc.reg_read(r) for r in SAVED] and self.u32(0)==0x12345678
            assert self.source_freed==(not self.null_source) and self.u32(POINTER)==0
            assert not self.pending and not self.stream_pending
        assert bytes(self.uc.mem_read(SOURCE,SOURCE_COUNT+16))==source+b'\x96'*16
        assert bytes(self.uc.mem_read(DESTINATION+CAPACITY,16))==b'\x69'*16
        globals_after=bytes(self.uc.mem_read(GLOBAL,GLOBAL_COUNT))
        differences=[dict(address=GLOBAL+i,before=a,after=b) for i,(a,b) in enumerate(zip(self.globals_before,globals_after)) if a!=b]
        assert all(0x44dd50<=d['address']<0x44dd54 for d in differences)
        expected_globals=bytearray(self.globals_before)
        for event in self.selector_writes:
            offset=event['address']-GLOBAL
            expected_globals[offset:offset+event['size']]=event['value'].to_bytes(event['size'],'little')
        assert bytes(expected_globals)==globals_after
        assert all(not raw or rep for raw,rep in zip(self.mask,self.rep_mask))
        codec_pcs=set()
        for address,size in self.codec_blocks:
            codec_pcs.update(i.address for i in self.decoder.disasm(bytes(self.uc.mem_read(address,size)),address))
        return dict(source=source.hex(),name=name.hex(),key=self.key.hex(),globals=self.globals_before.hex(),globalsAfter=globals_after.hex(),
            nullSource=self.null_source,allocationFailure=self.fail_at,codecStatus=self.codec_result,
            length=getattr(self,'length',None),compressed=self.compressed.hex() if self.compressed is not None else None,
            adjusted=getattr(self,'adjusted',b'').hex(),formatted=self.formatted.hex() if self.formatted is not None else None,
            writerEvents=self.writer_events,libraryEvents=self.events,allocations=self.writer_allocations,
            sourceFreed=self.source_freed,recordingPointer=self.u32(POINTER),helpers=self.helpers,streams=self.stream_calls,
            stages=self.stages,copies=self.copies,codecWritten=self.rep_mask.hex(),rawHookWritten=self.mask.hex(),
            fault=self.fault,end=dict(pc=pc,sp=self.uc.reg_read(UC_X86_REG_ESP)),
            longestMatchCalls=self.searches,processorSignatures=self.processor_signatures,selectorWrites=self.selector_writes,
            writerPCs=sorted(self.writer_pcs-({pc} if self.fault and self.fault['kind']=='nullBacking' else set())),
            observedWriterPCs=sorted(self.writer_pcs),helperBlockInstructionStarts=sorted(codec_pcs),libraryPCs=self.instructions())


def suite(resume=False):
    provenance,source=next(recording_inputs())
    cases=[];blobs={}
    def document():
        return dict(exeSHA256=EXE_SHA256,crtSHA256=DLL_SHA256,cppSHA256=CPP_SHA256,packageSHA256=PACKAGE_SHA256,
            sourceCount=SOURCE_COUNT,capacity=CAPACITY,cases=cases,blobs=blobs,recordingInput=provenance,blobEncoding='zlib',
            scope='Controlled whole43dd60. Actual EXE/CRT/C++ instructions; declared allocator, thread and file descriptor responses. No own continuation or Windows run.',
            instructionCounting='writerPCs exclude stopped NULL-read instructions; observedWriterPCs retain them. helperBlockInstructionStarts are decoded observed blocks, not per-instruction execution evidence; stopped failure blocks can contain unexecuted instructions. libraryPCs use inherited actual code hooks.')
    def intern(raw):
        key=digest(raw)
        if key not in blobs:blobs[key]=dict(count=len(raw),deflate=base64.b64encode(zlib.compress(raw,9)).decode())
        return key
    if resume:
        # Only use after the earlier process is confirmed terminal. Completed
        # cases retain their actual captured bytes; no CPU is resumed/rebuilt
        # from an expected after-state. Each remaining call gets a fresh CPU.
        old=json.loads((ROOT/'build/research/replay-writer-progress.json').read_bytes())
        assert old['recordingInput']==provenance and old['exeSHA256']==EXE_SHA256 and old['blobEncoding']=='zlib'
        for key,item in old['blobs'].items():
            raw=zlib.decompress(base64.b64decode(item['deflate']))
            assert len(raw)==item['count'] and digest(raw)==key
        cases.extend(old['cases']);blobs.update(old['blobs'])
        print('RETAIN',len(cases),'completed source cases from terminal capture',flush=True)
    probes=[
        ('original',{}), ('empty-key',dict(key=b'')),
        *[(f'selector-{n}',dict(selector=n)) for n in (0,1,3)],
        ('key-byte-ramp',dict(key=bytes(range(1,256)))),
        ('zero-long-key',dict(source=bytes(SOURCE_COUNT),key=b'1'*6500)),
        ('random-capacity',dict(source=random.Random(0x43dd60).randbytes(SOURCE_COUNT))),
        ('null-source',dict(null_source=True)),
        ('null-source-empty-key',dict(null_source=True,key=b'')),
        *[(f'allocation-{n}',dict(allocation_failure=n)) for n in range(1,7)],
        ('null-destination-empty-key',dict(allocation_failure=1,key=b'')),
        ('null-destination-open-failure',dict(allocation_failure=1,key=b'',open_failure=True)),
        *[(f'name-{n}',dict(name=b'x'*n,null_source=True,key=b'')) for n in (489,490,491)],
        ('open-failure',dict(open_failure=True)),
        ('short-write',dict(short_write=1,write_result=0)),
        ('write-and-close-failure',dict(short_write=1,write_result=-1,close_failure=True)),
        ('close-failure',dict(close_failure=True)),
        ('buffer-failure',dict(buffer_failure=True)),
    ]
    assert [c['label'] for c in cases]==[label for label,_ in probes[:len(cases)]]
    for label,options in probes[len(cases):]:
        print('START',label,flush=True)
        supplied=options.pop('source',source);name=options.pop('name',b'probe.lfr')
        key=options.pop('key',None);selector=options.pop('selector',None)
        vm=ReplayWriter(**options)
        case=vm.execute(supplied,name,key,selector)
        case.update(label=label,bufferFailure=vm.buffer_failure,openFailure=vm.open_failure)
        for field in ('source','globals','globalsAfter','compressed','adjusted','codecWritten','rawHookWritten'):
            if case[field] is not None:case[field]=intern(bytes.fromhex(case[field]))
        for event in case['writerEvents']+case['libraryEvents']:
            if 'bytes' in event:
                event['bytes']=intern(bytes.fromhex(event['bytes']))
        cases.append(case)
        checkpoint=ROOT/'build/research/replay-writer-progress.json'
        temporary=checkpoint.with_suffix('.tmp')
        temporary.write_text(json.dumps(document(),separators=(',',':'))+'\n');temporary.replace(checkpoint)
        print('DONE',label,'status',case['codecStatus'],'length',case['length'],'searches',case['longestMatchCalls'],
              'fault',case['fault'],'writerPCs',len(case['writerPCs']),flush=True)
        del vm
    doc=document()
    path=ROOT/'build/original/replay-writer.json';raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    print('CORPUS',len(cases),'bytes',len(raw),'sha256',digest(raw),'blobs',len(blobs),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite',action='store_true')
    parser.add_argument('--resume',action='store_true')
    parser.add_argument('--null-source',action='store_true');parser.add_argument('--allocation-failure',type=int,default=0)
    parser.add_argument('--empty-key',action='store_true');parser.add_argument('--name-length',type=int)
    parser.add_argument('--open-failure',action='store_true');parser.add_argument('--selector',type=lambda s:int(s,0))
    parser.add_argument('--label',default='probe')
    args=parser.parse_args()
    if args.suite:return suite(args.resume)
    vm=ReplayWriter(null_source=args.null_source,allocation_failure=args.allocation_failure,
                                          open_failure=args.open_failure)
    source=next(recording_inputs())[1]
    name=b'probe.lfr' if args.name_length is None else b'x'*args.name_length
    try:case=vm.execute(source,name,b'' if args.empty_key else None,args.selector)
    except Exception:
        print('STOP',hex(vm.uc.reg_read(UC_X86_REG_EIP)),json.dumps(vm.writer_events[-8:]),flush=True);raise
    assert all(c.isalnum() or c=='-' for c in args.label)
    path=ROOT/'build/research'/('replay-writer-'+args.label+'.json');path.write_text(json.dumps(case,separators=(',',':'))+'\n')
    print(json.dumps(dict(end=case['end'],fault=case['fault'],codecStatus=case['codecStatus'],length=case['length'],
        helpers=len(case['helpers']),streams=len(case['streams']),writerPCs=len(case['writerPCs']),
        helperBlockInstructionStarts=len(case['helperBlockInstructionStarts']),libraryPCs=len(case['libraryPCs']),longestMatchCalls=case['longestMatchCalls'],
        processorSignatures=case['processorSignatures']),indent=2),flush=True)

if __name__=='__main__':main()
