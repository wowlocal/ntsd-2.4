#!/usr/bin/env python3
"""Read-only verification of full library hit source storage and provenance.

Verify completed whole-call blobs, immutable pristine identities, exact164
paired byte changes, installed hook coverage, target-buffer read/write order
and original0xb2 Object reads reconstructed from declared inputs. This is not
another native/Windows run and does not fill unknown loaded-catalog bytes.
"""
import base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
digest=lambda b:hashlib.sha256(b).hexdigest()
BASE=0x36000000
def signed(x):return (x+2**31)%2**32-2**31
def decode(w):
    b=zlib.decompress(base64.b64decode(w['deflate']),-15);assert len(b)==w['count']
    if 'sha256' in w:assert digest(b)==w['sha256']
    return b
def fixture(name):
    b=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/name).read_bytes();return json.loads(decode(json.loads(b))),digest(b)
def read_raw(name):
    b=(ROOT/'build/original'/(name+'.json')).read_bytes();r=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes())
    assert len(b)==r['bytes'] and digest(b)==r['sha256'];return json.loads(b),r

def object_bytes(doc,c,which):
    raw=bytearray(0x40000)
    def patch(offset,value):raw[offset:offset+len(bytes.fromhex(value))]=bytes.fromhex(value)
    for offset,b in doc['header']:patch(offset,b)
    struct.pack_into('<ii',raw,0x6f4,doc['ids'][which],0)
    for n in range(400):
        start=0x7a4+n*0x178;raw[start]=1;struct.pack_into('<i',raw,start+8,doc['states'].get(str(n),3))
        if n in (60,65,80,85,90):struct.pack_into('<i',raw,start+0x4c,100)
    cursor=0x51000000
    for obj in range(4):
        for owner,frame,itr,bdy in c.get('boxes',[]):
            if owner!=obj:continue
            for values,countoff,ptroff,boundoff,stride in [(itr,0x128,0x130,0x138,20),(bdy,0x12c,0x134,0x148,10)]:
                start=0x7a4+frame*0x178
                if obj==which:struct.pack_into('<i',raw,start+countoff,len(values))
                if not values:continue
                if obj==which:
                    struct.pack_into('<I',raw,start+ptroff,cursor)
                    x=min(v[1] for v in values);y=min(v[2] for v in values)
                    right=max(signed(v[1]+v[3]) for v in values);bottom=max(signed(v[2]+v[4]) for v in values)
                    struct.pack_into('<iiii',raw,start+boundoff,x,y,signed(right-x),signed(bottom-y))
                cursor+=5*stride*4
    for obj,offset,b in c.get('headers',[]):
        if obj==which:patch(offset,b)
    for obj,frame,offset,b in c.get('frames',[]):
        if obj==which:patch(0x7a4+frame*0x178+offset,b)
    return raw

def main():
    doc,report=read_raw('lib-world-hits');paired,pr=read_raw('lib-hits-pristine-changes')
    assert len(doc['cases'])==18137 and doc['zAddend']=='087a4400cb764100' and doc['entryFPSW']==0 and doc['entryTag']==0xffff
    old=[]
    for p in doc['priors']:
        c,sha=fixture(p['fixture']);assert sha==p['fixtureSHA256'];old.extend(c['cases'])
    assert len(old)==15690
    installed=doc['installation'];init,_=fixture('original-lib-initialization.json');ref=init['cases'][0]
    assert len(installed['relocations'])==76 and len(installed['instructions'])==104
    assert {p-BASE for p in installed['instructions']}=={p['address']-0x10000000 for p in ref['instructions'] if 0x10000000<=p['address']<0x10005000}
    for a,b in zip(installed['patches'],ref['patches']):
        assert (a['address'],a['before'],a['count'])==(b['address'],b['before'],b['count'])
        na,nb=bytes.fromhex(a['after']),bytes.fromhex(b['after'])
        if len(na)==2:assert na==nb==b'\x90\x90'
        else:assert na[0]==nb[0]==0xe9 and (int.from_bytes(na[1:],'little')-int.from_bytes(nb[1:],'little'))%2**32==BASE-0x10000000
    assert Counter(e['name'] for e in installed['events'])=={'VirtualAlloc':2,'VirtualProtect':26,'RtlMoveMemory':13}
    blobs={}
    for key,w in doc['blobs'].items():
        b=decode(w);assert digest(b)==key;blobs[key]=b
    paired_blobs={}
    for key,w in paired['blobs'].items():
        b=decode(w);assert digest(b)==key;paired_blobs[key]=b
    assert paired['libraryRawSHA256']==report['sha256'] and len(paired['cases'])==164
    differences={c['pristineIndex']:c for c in paired['cases']}
    pcs=set();sites=Counter();exits=Counter();precisions=Counter();stride_offsets=set();stride_reads=0;frame_writes=0;target_accesses=0;target_writes=0;retained=0
    previous_library=bytes(20000)
    for i,c in enumerate(doc['cases']):
        pool,mask,glob,heap=[blobs[c[k+'SHA256']] for k in ('pool','mask','globals','heap')]
        assert len(pool)==len(mask)==424408 and len(glob)==46144 and len(heap)==0x40000 and set(mask)<={0,1}
        assert c['exitSP']==0x1000e000 and c['exitFPU']['tag']==0xffff and (c['exitFPU']['sw']>>11)&7==0
        assert c['exitFPU']['cw']==c['fpcw'] in (0x37f,0x27f,0x23f);precisions[c['fpcw']]+=1;pcs.update(c['instructions'])
        if i<15690:
            before=old[i];extra={'label','poolSHA256','maskSHA256','globalsSHA256','heapSHA256','crtAfter','events','helpers'}
            assert all(c[k]==v for k,v in before.items() if k not in extra)
            same=all(c[k]==before[k] for k in ('poolSHA256','maskSHA256','globalsSHA256','heapSHA256','crtAfter','events'))
            assert same==c['pristineOutcomeEqual']
            if not same:
                p=differences[i];prior_pool=paired_blobs[p['poolSHA256']]
                assert digest(prior_pool)==before['poolSHA256'] and p['libraryPoolSHA256']==c['poolSHA256']
                changed=[j for j,(a,b) in enumerate(zip(prior_pool,pool)) if a!=b]
                assert len(changed)==p['differingBytes'] and all(j>=2008 and 0x68<=(j-2008)%1056<0x70 for j in changed)
                assert all(c[k]==before[k] for k in ('maskSHA256','globalsSHA256','heapSHA256','crtAfter','events'))
        target=bytearray(previous_library if c.get('retainLibrary') else bytes(20000));retained+=bool(c.get('retainLibrary'))
        for offset,b in c.get('libraryPatches',[]):target[offset:offset+len(bytes.fromhex(b))]=bytes.fromhex(b)
        assert bytes(target)==blobs[c['libraryBefore']]
        for event in c['targetAccesses']:
            at=event['offset'];value=bytes.fromhex(event['bytes']);assert 0<=at<3200 and at%8==0 and len(value)==event['size']==4
            target_accesses+=1
            if event['access']==16:assert target[at:at+4]==value and event['pc']==BASE+0x177c
            else:
                assert event['access']==17 and event['pc']==BASE+0x1798;target[at:at+4]=value;target_writes+=1
        assert bytes(target)==blobs[c['libraryAfter']];previous_library=bytes(target)
        objects={}
        for h in c['hooks']:
            sites[h['site']]+=1;exits[(h['site'],h['continuation'])]+=1
            assert h['callerSP']-h['sp']==128 and h['fpu']['cw']==h['afterFPU']['cw']==c['fpcw']
            assert h['fpu']['tag']==h['afterFPU']['tag']==0x7fff and h['fpu']['sw']==h['afterFPU']['sw']
            assert (h['fpu']['sw']>>11)&7==7 and h['fpu']['registers'][7]==h['afterFPU']['registers'][7]==[0,0]
            if 'strideRead' in h:
                r=h['strideRead'];obj=(r['objectAddress']-0x50000000)//0x40000
                assert 0<=obj<4 and r['objectAddress']==0x50000000+obj*0x40000
                assert r['offset']==0x7ac+r['previous']*0xb2 and r['address']==r['objectAddress']+r['offset']
                if obj not in objects:objects[obj]=object_bytes(doc,c,obj)
                assert bytes(objects[obj][r['offset']:r['offset']+4]).hex()==r['bytes']
                stride_reads+=1;stride_offsets.add(r['previous'])
            if h['site']==0x42fcb1:
                effect=signed(h['effect']);assert h['continuation']==(0x42fcbb if effect in (3,30) else 0x42fd1d)
                assert len(h['writes'])<=1
                if h['writes']:
                    w=h['writes'][0];assert 'strideRead' in h and w['pc']==BASE+0x1388
                    assert bytes.fromhex(w['bytes'])==struct.pack('<i',effect-6000);frame_writes+=1
            else:assert h['site']==0x430c8c and h['continuation'] in (0x430ceb,0x43187a)
    static=json.loads((ROOT/'docs/evidence/lib-runtime-static.json').read_bytes())
    hookpcs={r['address']-0x10000000+BASE for r in static['instructions'] if 0x10001322<=r['address']<=0x10001801}
    unreachable={r['address']-0x10000000+BASE for r in static['instructions'] if 0x1000138d<=r['address']<=0x100013cb}
    assert len(unreachable)==12 and pcs&hookpcs==hookpcs-unreachable and pcs==set(doc['instructions'])
    assert stride_offsets==set(range(400)) and len(blobs)==4334 and len(paired_blobs)==13
    result=dict(cases=18137,pristineEqual=15526,pristineChanged=164,pairedPristineWholeCalls=164,onlyChangedPristineBinaryZ=True,
        rawBytes=report['bytes'],rawSHA256=report['sha256'],wholePoolBytes=18137*424408,wholeMaskBytes=18137*424408,
        globalsBytes=18137*46144,heapBytes=18137*0x40000,libraryBytes=18137*20000,blobs=len(blobs),pairedBlobs=len(paired_blobs),
        actualEXEPCs=sum(p<BASE for p in pcs),actualLibraryPCs=238,staticLibraryPCs=len(hookpcs),unreachableMPPCs=12,
        sites={hex(k):v for k,v in sites.items()},continuations={f'{a:x}->{b:x}':n for (a,b),n in exits.items()},precisions=dict(precisions),
        strideReads=stride_reads,previousFrameIndices=len(stride_offsets),effectFrameStores=frame_writes,targetAccesses=target_accesses,targetStores=target_writes,
        retainedTargetCalls=retained,liveFPUZeroRetained=True,allHelperReturns=report['helpers'],events=report['events'],windowsVerified=False)
    (ROOT/'build/research/lib-world-hits-source-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
