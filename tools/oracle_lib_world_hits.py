#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Whole NTSD hit resolution with both actual installed library hooks.

Pinned EXE/lib.dll/VC80 in controlled Unicorn2.1.4:42e100/ret4 and the full
41eefb..41f2ac caller, including actual effect42fcb1 and movement430c8c hooks.
Trace live effect/kind/defender provenance,0xb2 Object reads, frame/target
stores and FPU history. Preserve complete400Actors/World/masks/globals/mutable
ITR heap/CRT/20000-byte library target storage and real helper event order.
Storage derives from original constructors plus declared bounded inputs;
loader APIs, constructor memset and CRT IAT/PTD bridge are research boundaries.
No arbitrary control-pointer corruption, forced unreachable MP branch, runtime
DLL/emulation, initialized match or actual Windows/device behavior is claimed.
See LIB_HIT_EFFECTS_PLAN for the finite matrix and unknown-backing boundary.
"""
import base64,itertools,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_world_hits import WorldHits,hitcase,IDS,STATES,HEADER,d,b,q,f,h,HEAP,DLL_SHA256
from oracle_world_control import WORLD,POOL,OBJECT,BODY_SP
from oracle_actor_control import GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX
from oracle_lib_initialization import LIB_SHA256,digest
from lib_runtime_loader import install_library,BASE
from unicorn import UC_MEM_READ,UC_MEM_WRITE
from unicorn.x86_const import (UC_X86_REG_EAX,UC_X86_REG_EBX,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_EDI,
    UC_X86_REG_EIP,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG,
    UC_X86_REG_FP0,UC_X86_REG_FP1,UC_X86_REG_FP2,UC_X86_REG_FP3,UC_X86_REG_FP4,UC_X86_REG_FP5,UC_X86_REG_FP6,UC_X86_REG_FP7)

OUT=ROOT/'build/original/lib-world-hits.json'
FPREGS=(UC_X86_REG_FP0,UC_X86_REG_FP1,UC_X86_REG_FP2,UC_X86_REG_FP3,UC_X86_REG_FP4,UC_X86_REG_FP5,UC_X86_REG_FP6,UC_X86_REG_FP7)
def packed(raw):
    compressor=zlib.compressobj(9,zlib.DEFLATED,-15)
    return dict(count=len(raw),deflate=base64.b64encode(compressor.compress(raw)+compressor.flush()).decode())
def prior(name):
    path=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+name+'.json')
    raw=path.read_bytes();report=json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes())
    assert digest(raw)==report['fixtureSHA256'];w=json.loads(raw)
    b=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert len(b)==w['count'] and digest(b)==w['sha256'] and digest(b+b'\n')==report['sha256']
    doc=json.loads(b);assert len(doc['cases'])==7845
    return doc,dict(fixture=path.name,fixtureSHA256=digest(raw),rawSHA256=digest(b+b'\n'))

class LibWorldHits(WorldHits):
    def __init__(self):
        super().__init__();self.installation=install_library(self.uc)
        self.target_address=self.u32(BASE+0x3096);self.unused_address=self.u32(BASE+0x3092)
        assert bytes(self.uc.mem_read(self.target_address,20000))==bytes(20000)
        assert bytes(self.uc.mem_read(self.unused_address,4000))==bytes(4000)
        self.dll_before=bytes(self.uc.mem_read(BASE,0x5000));self.blobs={};self.hook=None
        self.z_addend=bytes(self.uc.mem_read(BASE+0x3014,8));assert self.z_addend.hex()=='087a4400cb764100'
    def blob(self,raw):
        key=digest(raw)
        if key not in self.blobs:self.blobs[key]=packed(raw)
        return key
    def fpu(self):
        return dict(cw=self.uc.reg_read(UC_X86_REG_FPCW),sw=self.uc.reg_read(UC_X86_REG_FPSW),tag=self.uc.reg_read(UC_X86_REG_FPTAG),registers=[self.uc.reg_read(r) for r in FPREGS])
    def access(self,u,access,address,size,value,data):
        if self.running:
            pc=u.reg_read(UC_X86_REG_EIP)
            if pc==BASE+0x1373:
                assert access==UC_MEM_READ and size==4 and self.hook and self.hook['site']==0x42fcb1
                defender=self.hook['defender'];actor=self.u32(WORLD+0x194+4*defender)
                obj=self.u32(actor+0x368);previous=self.u32(actor+0x78)
                assert address==(obj+0x7ac+previous*0xb2)&0xffffffff
                assert obj<=address<address+4<=obj+0x25360
                self.hook['strideRead']=dict(pc=pc,address=address,objectAddress=obj,previous=previous,offset=address-obj,bytes=bytes(u.mem_read(address,4)).hex())
            if BASE+0x1322<=pc<=BASE+0x1801 and access==UC_MEM_WRITE:
                assert self.hook is not None
                raw=(value&((1<<(size*8))-1)).to_bytes(size,'little')
                self.hook['writes'].append(dict(pc=pc,address=address,bytes=raw.hex()))
            if self.target_address<=address<self.target_address+20000:
                assert address+size<=self.target_address+20000 and BASE+0x176f<=pc<=BASE+0x1798
                self.target_accesses.append(dict(pc=pc,access=access,address=address,offset=address-self.target_address,size=size,
                    bytes=(bytes(u.mem_read(address,size)) if access==UC_MEM_READ else (value&((1<<(8*size))-1)).to_bytes(size,'little')).hex()))
        return super().access(u,access,address,size,value,data)
    def code(self,u,pc,size,data):
        if self.running:
            self.case_pcs.add(pc)
            if self.hook is not None and not BASE<=pc<BASE+0x5000:
                before=self.hook;assert u.reg_read(UC_X86_REG_ESP)==before['sp']
                assert u.reg_read(UC_X86_REG_ESI)==WORLD and u.reg_read(UC_X86_REG_EBX)==before['attacker'] and u.reg_read(UC_X86_REG_EDI)==before['defender']
                assert pc in ({0x42fcbb,0x42fd1d} if before['site']==0x42fcb1 else {0x430ceb,0x43187a})
                after=self.fpu();assert after['cw']==before['fpu']['cw'] and (after['sw']>>11)&7==(before['fpu']['sw']>>11)&7
                before.update(continuation=pc,afterFPU=after);self.hook=None
            if pc in (0x42fcb1,0x430c8c):
                parent=next(v for v in reversed(self.pending) if v['entry']==0x42e100)
                attacker=u.reg_read(UC_X86_REG_EBX);defender=u.reg_read(UC_X86_REG_EDI);sp=u.reg_read(UC_X86_REG_ESP)
                assert attacker==parent['args'][0] and 0<=attacker<400 and 0<=defender<400 and u.reg_read(UC_X86_REG_ESI)==WORLD
                pointer=self.u32(sp+0xc);kind=self.u32(pointer);effect=self.u32(pointer+0x2c)
                assert u.reg_read(UC_X86_REG_EAX if pc==0x42fcb1 else UC_X86_REG_EDX)==(effect if pc==0x42fcb1 else kind)
                assert self.hook is None
                self.hook=dict(site=pc,sp=sp,callerSP=parent['sp'],attacker=attacker,defender=defender,itr=pointer,kind=kind,effect=effect,fpu=self.fpu(),writes=[])
                self.hooks.append(self.hook)
            if BASE+0x1322<=pc<=BASE+0x1801:
                self.instructions.add(pc);return
        return super().code(u,pc,size,data)
    def probe(self,item,index):
        self.hooks=[];self.case_pcs=set();self.target_accesses=[];assert self.hook is None
        self.arithmetic_control_word=item['fpcw']
        self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        if not item.get('retainLibrary',False):self.uc.mem_write(self.target_address,bytes(20000))
        for offset,raw in item.get('libraryPatches',[]):
            value=bytes.fromhex(raw);assert 0<=offset<offset+len(value)<=20000;self.uc.mem_write(self.target_address+offset,value)
        before=self.blob(bytes(self.uc.mem_read(self.target_address,20000)))
        result=super().probe(item,item.get('templateIndex',index));assert self.hook is None
        assert bytes(self.uc.mem_read(BASE,0x5000))==self.dll_before and bytes(self.uc.mem_read(self.unused_address,4000))==bytes(4000)
        world=bytearray(self.uc.mem_read(WORLD,WORLD_PREFIX));bindings=dict(item.get('aliases',[]))
        for i in range(400):struct.pack_into('<I',world,0x194+4*i,bindings.get(i,i))
        struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
        for i in range(400):
            raw=bytearray(self.uc.mem_read(POOL+0x500*i,ACTOR_SIZE));struct.pack_into('<I',raw,0x368,(self.u32(POOL+0x500*i+0x368)-OBJECT)//0x40000)
            pool+=raw;mask+=self.masks[i]
        glob=bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE));heap=bytes(self.uc.mem_read(HEAP,0x40000))
        for name,raw in [('pool',pool),('mask',mask),('globals',glob),('heap',heap)]:assert self.blob(raw)==result[name+'SHA256']
        result.update(hooks=self.hooks,instructions=sorted(self.case_pcs&self.instructions),libraryBefore=before,
            libraryAfter=self.blob(bytes(self.uc.mem_read(self.target_address,20000))),targetAccesses=self.target_accesses,
            exitSP=self.uc.reg_read(UC_X86_REG_ESP),exitFPU=self.fpu())
        assert result['exitSP']==BODY_SP and result['exitFPU']['tag']==0xffff
        return result

def additional():
    inventory=json.loads((ROOT/'docs/evidence/lib-hit-effects-catalog.json').read_bytes())
    high=sorted({x['effect'] for x in inventory['highEffects'] if x['effect']>=6000})
    for previous,cw in itertools.product(range(400),(0x37f,0x27f)):
        yield hitcase(f'lib-stride-{previous}-{cw}','library-stride',effect=6067,defender=[d(0x78,previous)],fpcw=cw)
    effects=sorted(set([-2**31,-1,0,3,30,4999,5000,5005,5045,5080,5500,5999,6000,*high]))
    for n,(effect,typ,previous) in enumerate(itertools.product(effects,(0,1,2,3,4,6),(0,1,95,188,283,399))):
        yield hitcase(f'lib-effect-{effect}-{typ}-{previous}','library-effects',effect=effect,headers=[h(1,0x6f8,typ)],defender=[d(0x78,previous)],fpcw=0x27f if n%2 else 0x37f)
    for previous,effect in itertools.product((0,188,376),(6000,6067,6399,6400,6800,2**31-1)):
        mapped=(8+previous*0xb2)//0x178
        yield hitcase(f'lib-equal-{previous}-{effect}','library-stride-equality',effect=effect,defender=[d(0x78,previous)],frames=[f(1,mapped,8,effect)],fpcw=0x23f)
    for previous in (95,283):
        yield hitcase(f'lib-cross-equal-{previous}','library-cross-equality',effect=65536,defender=[d(0x78,previous)],fpcw=0x23f)
    for effect,typ in itertools.product((6400,6799,6800,2**31-1),(1,2,3,4,6)):
        yield hitcase(f'lib-high-bypass-{effect}-{typ}','library-high-bypass',effect=effect,headers=[h(1,0x6f8,typ)],fpcw=0x23f)
    kinds=[8,35,36,79,*range(80,91),799,*range(800,827),-1,2**31-1]
    tiny=struct.unpack('<d',bytes.fromhex('087a4400cb764100'))[0]
    for n,(kind,alias,z) in enumerate(itertools.product(kinds,(False,True),(-1.,-0.,0.,1.,tiny,-tiny,2.**53))):
        target=(0,41,399)[n%3];injury=(-1001,0,2**31-1)[n%3]
        yield hitcase(f'lib-movement-{n}-{kind}-{alias}-{z.hex()}','library-movement',kind=kind,dvx=target,injury=injury,
            attack=[q(0x58,-37.5),q(0x60,18.25)],defender=[q(0x58,73.25),q(0x60,-9.5),q(0x68,z)],
            aliases=[[1,0]] if alias else [],libraryPatches=[d(0,777)],fpcw=0x27f if n%2 else 0x37f)
    for n,(kind,attacker,defender,prior_target) in enumerate(itertools.product((824,825),(0,19,399),(0,1,398),(0,1,777,399))):
        c=hitcase(f'lib-target-{kind}-{attacker}-{defender}-{prior_target}','library-target',kind=kind,dvx=41,attacker=attacker,
            libraryPatches=[d(attacker*8,prior_target),d(attacker*8+4,0x12345678),d(19996,0x10203040)],fpcw=0x23f)
        c['active']=[[attacker,1],[defender,1]];c['actors'][0][0]=attacker;c['actors'][1][0]=defender
        # Distinct slots can alias, but each constructor allocation is bound once.
        if attacker==defender:
            c['actors']=c['actors'][:1];c['active']=[[attacker,1]];c['boxes'][0][3]=c['boxes'][1][3]
        c['actors'][0][1].append(d(0x280,defender));yield c
    for i,defender in enumerate((1,2,1,0,1)):
        c=hitcase(f'lib-retained-{i}-{defender}','library-retained',kind=824,dvx=41,fpcw=0x23f,retainLibrary=i>0,
            libraryPatches=[d(0,777)] if i==0 else [])
        c['actors'][0][1].append(d(0x280,defender))
        if defender==2:c['actors'][1][0]=2;c['active'][1][0]=2
        if defender==0:c['actors']=c['actors'][:1];c['active']=[[0,1]];c['boxes'][0][3]=c['boxes'][1][3]
        yield c

def main():
    assert not OUT.exists(),'Never overwrite completed source evidence'
    vm=LibWorldHits();inputs=[];priors=[];controls=[]
    for name in ('world-hits','world-hits53'):
        doc,identity=prior(name);priors.append(identity);controls.extend(doc['cases'])
        inputs.extend(dict(c,label=name+':'+c['label'],fpcw=doc['fpcw'],templateIndex=i,pristineIndex=len(controls)-7845+i) for i,c in enumerate(doc['cases']))
    inputs.extend(additional());cases=[];comparisons=Counter()
    print('LIB HITS PLANNED',len(inputs),flush=True)
    for i,item in enumerate(inputs):
        result=vm.probe(item,i)
        if i<len(controls):
            old=controls[i];equal=all(result[k]==old[k] for k in ('poolSHA256','maskSHA256','globalsSHA256','heapSHA256','crtAfter','events'))
            result['pristineOutcomeEqual']=equal;comparisons['equal' if equal else 'changed']+=1
        cases.append(result)
        if (i+1)%250==0:print('LIB HITS',i+1,'/',len(inputs),flush=True)
        if (i+1)%500==0:
            path=OUT.with_name('lib-world-hits-incomplete.json');tmp=path.with_suffix('.tmp')
            b=(json.dumps(dict(incomplete=True,cases=cases,blobs=vm.blobs),separators=(',',':'))+'\n').encode();tmp.write_bytes(b);tmp.replace(path);path.with_suffix('.sha256').write_text(digest(b)+'\n')
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,installation=vm.installation,
        zAddend=vm.z_addend.hex(),priors=priors,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions),templates=vm.templates,entryFPSW=0,entryTag=0xffff,
        nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();OUT.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,corpus=OUT.name,bytes=len(raw),sha256=digest(raw),
        cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),pristineComparisons=dict(comparisons),
        helpers=sum(c['helpers'] for c in cases),events=sum(len(c['events']) for c in cases),hooks=sum(len(c['hooks']) for c in cases),
        instructions=len(vm.instructions),exeInstructions=sum(pc<BASE for pc in vm.instructions),dllInstructions=sum(pc>=BASE for pc in vm.instructions),
        blobs=len(vm.blobs),bundledLibInstalled=True,nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-world-hits.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
