#!/usr/bin/env python3
"""Census installed contact-kind/state20 inputs in original loaded game DATs.

Read-only pinned137-DAT hashes and accepted full Object/Frame-allocation
bytes/masks. Resolve original ITR data references within accepted allocations,
without executing calls or supplying source after-state to Native. This proves
static data presence, not runtime reachability or a contact/damage outcome.
"""
import base64,bisect,hashlib,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,read_bytes

digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    report=json.loads((ROOT/'docs/evidence/loaded-catalog53.json').read_bytes())
    raw=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()
    assert digest(raw)==report['fixtureSHA256'];w=json.loads(raw)
    b=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert len(b)==w['count'] and digest(b)==w['sha256'] and digest(b+b'\n')==report['sha256']
    c=json.loads(b);cache={}
    def blob(key):
        if key not in cache:
            item=c['blobs'][key];value=zlib.decompress(base64.b64decode(item['deflate']),-15)
            assert digest(value)==key and len(value)==item['count'];cache[key]=value
        return cache[key]
    def storage(item):return blob(item['storage']['bytes']),blob(item['storage']['defined'])
    def word(data,mask,offset):
        assert 0<=offset and offset+4<=len(data)==len(mask) and all(mask[offset:offset+4]),offset
        return struct.unpack_from('<i',data,offset)[0]
    allocations=sorted(c['allocations'],key=lambda a:a['address']);addresses=[a['address'] for a in allocations]
    kinds=Counter();states=Counter();rows=[];objects=0;frames=0;present=0;interactions=0;unknown=[]
    affected={8,36,*range(80,90),*range(800,826)}
    for obj in c['children']:
        if obj['kind']!='object':continue
        objects+=1;path=(DEFAULT_SOURCE/obj['path'].replace('\\','/')).resolve()
        assert DEFAULT_SOURCE.resolve() in path.parents and digest(read_bytes(path))==obj['source']
        data,mask=storage(obj)
        for frame in range(400):
            frames+=1;start=0x7a4+frame*0x178;state=word(data,mask,start+8);states[state]+=1
            assert mask[start];live=data[start]!=0;present+=live
            count=word(data,mask,start+0x128);assert count>=0
            current=[]
            if count:
                pointer=word(data,mask,start+0x130)&0xffffffff
                index=bisect.bisect_right(addresses,pointer)-1;assert index>=0
                a=allocations[index];offset=pointer-a['address'];ad,am=storage(a)
                assert 0<=offset and offset+80*count<=a['size']==len(ad)==len(am)
                for n in range(count):
                    kind=word(ad,am,offset+80*n);kinds[kind]+=1;interactions+=1
                    if kind in affected:current.append(dict(index=n,kind=kind))
            if state==20 or current:
                rows.append(dict(object=obj['index'],id=obj['id'],type=obj['objectType'],path=obj['path'],sourceSHA256=obj['source'],
                    frame=frame,present=live,state=state,interactions=current))
    assert objects==137 and frames==54800 and not unknown
    result=dict(scope=__doc__,catalogFixture=report['fixture'],catalogFixtureSHA256=report['fixtureSHA256'],
        catalogRawSHA256=report['sha256'],originalDATsVerified=objects,frameSlots=frames,presentFrames=present,
        currentFrameInteractionRecords=interactions,allKinds=dict(sorted(kinds.items())),
        affectedKindsPresent={str(k):kinds[k] for k in sorted(affected) if kinds[k]},
        affectedKindsAbsent=sorted(affected-kinds.keys()),state20Frames=states[20],rows=rows,
        blobsVerified=len(cache),nativeCompared=False,staticDataOnly=True,windowsVerified=False)
    (ROOT/'docs/evidence/lib-contacts-catalog-inventory.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('scope','rows')},indent=2))
if __name__=='__main__':main()
