#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Recover bundled NTSD2.4 contact-kind and attacker-state20 team filtering.

Pinned EXE/lib.dll, actual relocated DLL installer and whole417400/419380/
41eed8 callers in Unicorn2.1.4, with declared constructor-backed400Actors,
four Objects and bounded ITR/BDY memory. Trace live pair stack/register
provenance and real helper/return order because patches resume inside loops.
Compare full storage/masks/globals and ordered events; no damage, arbitrary
pointer corruption, initialized match, Windows/device or native DLL execution.
Loader allocation/protection/copy responses and constructor memset are declared
research adapters. See LIB_WORLD_CONTACTS_PLAN for the finite input boundary.
"""
import base64,itertools,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT,EXE_SHA256
from oracle_world_contacts import WorldContacts,IDS,STATES,HEADER,paircase,itr,bdy,f,h,d,b,digest
from oracle_world_control import WORLD,POOL,OBJECT,BODY_SP
from oracle_actor_control import GLOBAL_BASE,GLOBAL_SIZE
from oracle_state import ACTOR_SIZE,WORLD_PREFIX
from oracle_lib_initialization import LIB_SHA256
from lib_runtime_loader import install_library,BASE
from unicorn.x86_const import UC_X86_REG_EBX,UC_X86_REG_EDX,UC_X86_REG_ESI,UC_X86_REG_EDI,UC_X86_REG_ESP,UC_X86_REG_FPCW,UC_X86_REG_FPSW,UC_X86_REG_FPTAG

OUT=ROOT/'build/original/lib-world-contacts.json'
def packed(raw):
    compressor=zlib.compressobj(9,zlib.DEFLATED,-15)
    return dict(count=len(raw),deflate=base64.b64encode(compressor.compress(raw)+compressor.flush()).decode())

def prior():
    path=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-world-contacts.json'
    raw=path.read_bytes();report=json.loads((ROOT/'docs/evidence/world-contacts.json').read_bytes())
    assert digest(raw)==report['fixtureSHA256']
    wrapper=json.loads(raw);data=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
    assert len(data)==wrapper['count'] and digest(data)==wrapper['sha256']
    assert digest(data+b'\n')==report['sha256']
    doc=json.loads(data);assert len(doc['cases'])==7925
    return doc,dict(fixture=path.name,fixtureSHA256=digest(raw),rawSHA256=digest(data+b'\n'))

class LibWorldContacts(WorldContacts):
    def __init__(self):
        super().__init__();self.installation=install_library(self.uc)
        assert len(self.installation['relocations'])==76 and len(self.installation['instructions'])==104
        self.dll_before=bytes(self.uc.mem_read(BASE,0x5000));self.blobs={};self.hook=None
    def blob(self,raw):
        key=digest(raw)
        if key not in self.blobs:self.blobs[key]=packed(raw)
        return key
    def code(self,u,pc,size,data):
        if self.running:
            self.case_pcs.add(pc)
            if self.hook is not None and not BASE<=pc<BASE+0x5000:
                entry=self.hook;sp=u.reg_read(UC_X86_REG_ESP)
                assert sp==entry['sp'] and u.reg_read(UC_X86_REG_EDX)==entry['kind']
                assert pc in ({0x4176cb,0x417f59} if entry['site']==0x4176ac else {0x4177ca,0x41780b,0x417866}),hex(pc)
                entry.update(continuation=pc,exitCW=u.reg_read(UC_X86_REG_FPCW),exitFPSW=u.reg_read(UC_X86_REG_FPSW),exitTag=u.reg_read(UC_X86_REG_FPTAG))
                assert (entry['cw'],entry['fpsw'],entry['tag'])==(entry['exitCW'],entry['exitFPSW'],entry['exitTag'])
                self.hook=None
            if pc in (0x4176ac,0x4177b9):
                parent=next(v for v in reversed(self.pending) if v['entry']==0x417400)
                attacker,defender=parent['args'][:2];sp=u.reg_read(UC_X86_REG_ESP)
                assert sp==parent['sp']-0x40 and self.u32(sp+0x44)==attacker and self.u32(sp+0x48)==defender
                assert u.reg_read(UC_X86_REG_ESI)==WORLD and u.reg_read(UC_X86_REG_EDI)==defender
                attack=self.u32(WORLD+0x194+4*attacker);defend=self.u32(WORLD+0x194+4*defender)
                if pc==0x4177b9:assert u.reg_read(UC_X86_REG_EBX)==defend
                assert self.hook is None
                self.hook=dict(site=pc,sp=sp,pairSP=parent['sp'],attacker=attacker,defender=defender,
                    attackAddress=attack,defendAddress=defend,kind=u.reg_read(UC_X86_REG_EDX),
                    attackFrame=self.u32(attack+0x70),attackState=self.u32(self.u32(attack+0x368)+0x7ac+self.u32(attack+0x70)*0x178),
                    attackTeam=self.u32(attack+0x364),defendTeam=self.u32(defend+0x364),defendType=self.u32(self.u32(defend+0x368)+0x6f8),
                    cw=u.reg_read(UC_X86_REG_FPCW),fpsw=u.reg_read(UC_X86_REG_FPSW),tag=u.reg_read(UC_X86_REG_FPTAG))
                self.hooks.append(self.hook)
            if BASE+0x1807<=pc<=BASE+0x1a94 or BASE+0x11b9<=pc<=BASE+0x1230:
                self.instructions.add(pc);return
        return super().code(u,pc,size,data)
    def probe(self,item,index):
        self.hooks=[];self.case_pcs=set();assert self.hook is None
        # Whole-call controlled FPU input; fresh Unicorn's default tags are
        # not an initialized game FPU environment. The parent sets CW037f.
        self.uc.reg_write(UC_X86_REG_FPSW,0);self.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        result=super().probe(item,index);assert self.hook is None
        assert bytes(self.uc.mem_read(BASE,0x5000))==self.dll_before
        # Retain every expected byte, not only the inherited full-storage hash.
        world=bytearray(self.uc.mem_read(WORLD,WORLD_PREFIX));bindings=dict(item.get('aliases',[]))
        for i in range(400):struct.pack_into('<I',world,0x194+4*i,bindings.get(i,i))
        struct.pack_into('<I',world,0x7d4,0);pool=world;mask=self.world_mask.copy()
        for i in range(400):
            raw=bytearray(self.uc.mem_read(POOL+0x500*i,ACTOR_SIZE));struct.pack_into('<I',raw,0x368,(self.u32(POOL+0x500*i+0x368)-OBJECT)//0x40000)
            pool+=raw;mask+=self.masks[i]
        assert digest(pool)==result['poolSHA256'] and digest(mask)==result['maskSHA256']
        glob=bytes(self.uc.mem_read(GLOBAL_BASE,GLOBAL_SIZE));assert digest(glob)==result['globalsSHA256']
        for raw in (pool,mask,glob):self.blob(raw)
        result.update(hooks=self.hooks,instructions=sorted(self.case_pcs & self.instructions),
            exitSP=self.uc.reg_read(UC_X86_REG_ESP),exitCW=self.uc.reg_read(UC_X86_REG_FPCW),
            exitFPSW=self.uc.reg_read(UC_X86_REG_FPSW),exitTag=self.uc.reg_read(UC_X86_REG_FPTAG))
        assert result['exitSP']==BODY_SP and result['exitCW']==0x37f and result['exitTag']==0xffff
        return result

def additional():
    kinds=[-1,0,3,4,7,8,9,14,35,36,37,79,*range(80,91),799,*range(800,827),2**31-1]
    for kind,typ,inv,rest in itertools.product(kinds,(-1,0,1,2,3,4,5,6,7),(0,1),(0,1)):
        yield paircase(f'library-kind-{kind}-{typ}-{inv}-{rest}','library-kind',interactions=[itr(kind,rest)],headers=[h(1,0x6f8,typ)],defender=[d(8,inv)])
    teams=[(0,0),(0,1),(1,0),(1,1),(1,2),(-1,1)]
    for kind,teams_,effect,typ in itertools.product((-1,0,1,2,3,6,9,10,11,15,16),teams,(0,21,22),(0,1,3)):
        a,d_=teams_
        yield paircase(f'library-team20-{kind}-{a}-{d_}-{effect}-{typ}','library-state20',interactions=[itr(kind,1,effect)],frames=[f(0,0,8,20)],headers=[h(1,0x6f8,typ)],attack=[d(0x364,a),b(0x80,1),b(0xd0,1),b(0xcf,1)],defender=[d(0x364,d_)])
    for state,teams_,effect,typ in itertools.product((3,18,21),teams,(0,21,22),(0,1,3)):
        a,d_=teams_
        yield paircase(f'library-team-control-{state}-{a}-{d_}-{effect}-{typ}','library-state-control',interactions=[itr(0,1,effect)],frames=[f(0,0,8,state)],headers=[h(1,0x6f8,typ)],attack=[d(0x364,a),b(0x80,1)],defender=[d(0x364,d_)])
    for state,teams_,kind in itertools.product((10,13),teams,(0,1,9,10,15)):
        a,d_=teams_
        yield paircase(f'library-defender-gate-{state}-{a}-{d_}-{kind}','library-defender-gate',interactions=[itr(kind,1)],frames=[f(0,0,8,20),f(1,0,8,state)],attack=[d(0x364,a)],defender=[d(0x364,d_)])
    for entry,slot,other,alias,rest in itertools.product((0x419380,0x41eed8),(0,19,199),(1,399),(False,True),(0,1)):
        c=paircase(f'library-loop-{entry}-{slot}-{other}-{alias}-{rest}','library-loop',entry=entry,
            interactions=[itr(80,rest),itr(86,rest),itr(802,rest),itr(810,rest),itr(817,rest)],bodies=[bdy(),bdy()],frames=[f(0,0,8,20)],attack=[d(0x2e8,0),d(0x2e4,0)])
        c['active']=[[slot,1],[other,1]];c['actors'][0][0]=slot;c['actors'][1][0]=other
        if alias:c['aliases']=[[other,slot]]
        # Both directions have actual ITR and BDY; alias sees its own live fields.
        c['boxes'][0][3]=[bdy(),bdy()];c['boxes'][1][2]=[itr(0,rest),itr(36,rest)]
        yield c

def main():
    assert not OUT.exists(), 'Never overwrite a completed source corpus'
    control,identity=prior();vm=LibWorldContacts();cases=[];matches=0
    inputs=[*control['cases'],*additional()]
    for i,item in enumerate(inputs):
        result=vm.probe(item,i)
        if i<len(control['cases']):
            # Preserve an actual changed result as such; never rewrite an old pin.
            result['pristineOutcomeEqual']=all(result[k]==item[k] for k in ('poolSHA256','maskSHA256','globalsSHA256','events'))
            matches+=result['pristineOutcomeEqual']
        cases.append(result)
        if (i+1)%250==0:print('LIB CONTACTS',i+1,'/',len(inputs),flush=True)
        if (i+1)%500==0:
            checkpoint=OUT.with_name('lib-world-contacts-incomplete.json')
            partial=(json.dumps(dict(incomplete=True,cases=cases,blobs=vm.blobs),separators=(',',':'))+'\n').encode()
            temporary=checkpoint.with_suffix('.tmp');temporary.write_bytes(partial);temporary.replace(checkpoint)
            checkpoint.with_suffix('.sha256').write_text(digest(partial)+'\n')
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,installation=vm.installation,
        prior=identity,ids=IDS,states=STATES,header=HEADER,baseActor=[d(0x31c,20)],fpcw=0x37f,entryFPSW=0,entryTag=0xffff,
        cases=cases,blobs=vm.blobs,instructions=sorted(vm.instructions),templates=vm.templates,
        nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();OUT.write_bytes(raw)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,corpus=OUT.name,bytes=len(raw),sha256=digest(raw),
        cases=len(cases),groups=dict(Counter(c['group'] for c in cases)),prior=identity,pristineOutcomesEqual=matches,
        helpers=sum(c['helpers'] for c in cases),events=sum(len(c['events']) for c in cases),hooks=sum(len(c['hooks']) for c in cases),
        instructions=len(vm.instructions),exeInstructions=sum(pc<BASE for pc in vm.instructions),
        dllInstructions=sum(pc>=BASE for pc in vm.instructions),blobs=len(vm.blobs),bundledLibInstalled=True,nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-world-contacts.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
