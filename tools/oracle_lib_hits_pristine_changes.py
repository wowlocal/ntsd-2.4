#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Recover exact pristine source bytes for164 library-changed whole hit calls.

Fresh pristine EXE/VC80 WorldHits VM, explicitly without library installation,
reexecutes only the164 inputs whose completed library results differ from
immutable pristine controls. Validate every old output hash/event/CRT result,
then retain full source pool/masks and exact deltas to library output. This
isolates the kind8 Z change using executed original bodies, not invented
expected bytes. No hook is removed from an installed VM, no source artifact
is edited, and neither control establishes an initialized Windows match.
"""
import base64,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT
from oracle_world_hits import WorldHits,digest
from oracle_world_control import WORLD,POOL,OBJECT
from oracle_state import WORLD_PREFIX,ACTOR_SIZE
from oracle_lib_world_hits import prior,packed
from unicorn.x86_const import UC_X86_REG_FPSW,UC_X86_REG_FPTAG

def main():
    output=ROOT/'build/original/lib-hits-pristine-changes.json';assert not output.exists()
    raw=(ROOT/'build/original/lib-world-hits.json').read_bytes();report=json.loads((ROOT/'build/research/lib-world-hits.json').read_bytes())
    assert digest(raw)==report['sha256'];library=json.loads(raw)
    controls=[]
    for name in ('world-hits','world-hits53'):controls.extend(prior(name)[0]['cases'])
    vm=WorldHits();rows=[];blobs={};by_precision=Counter()
    def blob(data):
        key=digest(data)
        if key not in blobs:blobs[key]=packed(data)
        return key
    for changed in library['cases']:
        if changed.get('pristineOutcomeEqual') is not False:continue
        n=changed['pristineIndex'];old=controls[n]
        vm.arithmetic_control_word=changed['fpcw'];vm.uc.reg_write(UC_X86_REG_FPSW,0);vm.uc.reg_write(UC_X86_REG_FPTAG,0xffff)
        result=vm.probe(old,n%7845)
        assert all(result[k]==old[k] for k in ('poolSHA256','maskSHA256','globalsSHA256','heapSHA256','crtAfter','events'))
        world=bytearray(vm.uc.mem_read(WORLD,WORLD_PREFIX));bindings=dict(old.get('aliases',[]))
        for i in range(400):struct.pack_into('<I',world,0x194+i*4,bindings.get(i,i))
        struct.pack_into('<I',world,0x7d4,0);pool=world;mask=vm.world_mask.copy()
        for i in range(400):
            a=bytearray(vm.uc.mem_read(POOL+i*0x500,ACTOR_SIZE));struct.pack_into('<I',a,0x368,(vm.u32(POOL+i*0x500+0x368)-OBJECT)//0x40000)
            pool+=a;mask+=vm.masks[i]
        assert blob(pool)==result['poolSHA256'] and blob(mask)==result['maskSHA256']
        item=library['blobs'][changed['poolSHA256']];new=zlib.decompress(base64.b64decode(item['deflate']),-15)
        assert len(new)==len(pool) and digest(new)==changed['poolSHA256']
        differing=[i for i,(a,b) in enumerate(zip(pool,new)) if a!=b];assert differing
        actors=sorted({(i-WORLD_PREFIX)//ACTOR_SIZE for i in differing})
        assert all(i>=WORLD_PREFIX and 0x68<=(i-WORLD_PREFIX)%ACTOR_SIZE<0x70 for i in differing)
        assert any(h['site']==0x430c8c and h['kind']==8 for h in changed['hooks'])
        assert all(result[k]==changed[k] for k in ('maskSHA256','globalsSHA256','heapSHA256','crtAfter','events'))
        rows.append(dict(pristineIndex=n,label=changed['label'],fpcw=changed['fpcw'],poolSHA256=result['poolSHA256'],maskSHA256=result['maskSHA256'],
            libraryPoolSHA256=changed['poolSHA256'],differingBytes=len(differing),
            zChanges=[dict(actor=a,pristine=pool[WORLD_PREFIX+a*ACTOR_SIZE+0x68:WORLD_PREFIX+a*ACTOR_SIZE+0x70].hex(),
                library=new[WORLD_PREFIX+a*ACTOR_SIZE+0x68:WORLD_PREFIX+a*ACTOR_SIZE+0x70].hex()) for a in actors],helpers=result['helpers']))
        by_precision[changed['fpcw']]+=1
    assert len(rows)==164
    doc=dict(scope=__doc__,libraryRawSHA256=digest(raw),cases=rows,blobs=blobs,instructions=sorted(vm.instructions),nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,separators=(',',':'))+'\n').encode();output.write_bytes(raw)
    report=dict(scope=__doc__,corpus=output.name,sha256=digest(raw),bytes=len(raw),cases=len(rows),precisions=dict(by_precision),blobs=len(blobs),
        differingBytes=sum(r['differingBytes'] for r in rows),zWords=sum(len(r['zChanges']) for r in rows),onlyBinaryZDiffers=True,
        helpers=sum(r['helpers'] for r in rows),instructions=len(vm.instructions),nativeCompared=False,windowsVerified=False)
    (ROOT/'build/research/lib-hits-pristine-changes.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
