#!/usr/bin/env python3
"""Census original ITR effects and library0xb2-stride Object data provenance.

Read-only pinned137-DAT hashes and accepted full Object/ITR bytes/masks.
Identify actual5000/6000-range effects and classify every type0 Object word at
Object+7ac+previousFrame*0xb2 for previousFrame0..<400. Unknown bytes remain
unknown. This is static loaded-data evidence, not hit execution, runtime
reachability, Windows allocation provenance or native damage equivalence.
"""
import base64,bisect,hashlib,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,read_bytes

digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    report=json.loads((ROOT/'docs/evidence/loaded-catalog53.json').read_bytes())
    packed=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes()
    assert digest(packed)==report['fixtureSHA256'];w=json.loads(packed)
    raw=zlib.decompress(base64.b64decode(w['deflate']),-15)
    assert len(raw)==w['count'] and digest(raw)==w['sha256'] and digest(raw+b'\n')==report['sha256']
    c=json.loads(raw);cache={}
    def blob(key):
        if key not in cache:
            item=c['blobs'][key];b=zlib.decompress(base64.b64decode(item['deflate']),-15)
            assert len(b)==item['count'] and digest(b)==key;cache[key]=b
        return cache[key]
    def storage(item):return blob(item['storage']['bytes']),blob(item['storage']['defined'])
    def word(data,mask,offset):
        assert 0<=offset and offset+4<=len(data)==len(mask) and all(mask[offset:offset+4])
        return struct.unpack_from('<i',data,offset)[0]
    allocations=sorted(c['allocations'],key=lambda a:a['address']);addresses=[a['address'] for a in allocations]
    effects=Counter();high=[];types=[];objects=0;stride_words=Counter()
    for obj in c['children']:
        if obj['kind']!='object':continue
        objects+=1;path=(DEFAULT_SOURCE/obj['path'].replace('\\','/')).resolve()
        assert DEFAULT_SOURCE.resolve() in path.parents and digest(read_bytes(path))==obj['source']
        data,mask=storage(obj)
        if obj['objectType']==0:
            rows=[]
            for previous in range(400):
                offset=0x7ac+previous*0xb2;known=all(mask[offset:offset+4])
                frame,within=divmod(offset-0x7a4,0x178)
                crossing=within+4>0x178
                stride_words['defined' if known else 'undefined']+=1;stride_words['crossFrame']+=crossing
                rows.append(dict(previous=previous,offset=offset,frame=frame,frameOffset=within,crossFrame=crossing,
                    defined=known,value=word(data,mask,offset) if known else None,rawBytes=data[offset:offset+4].hex(),mask=mask[offset:offset+4].hex()))
            types.append(dict(object=obj['index'],id=obj['id'],path=obj['path'],sourceSHA256=obj['source'],
                objectBytesSHA256=obj['storage']['bytes'],objectMaskSHA256=obj['storage']['defined'],words=rows))
        for frame in range(400):
            start=0x7a4+frame*0x178;count=word(data,mask,start+0x128);assert count>=0
            if not count:continue
            pointer=word(data,mask,start+0x130)&0xffffffff;index=bisect.bisect_right(addresses,pointer)-1;assert index>=0
            allocation=allocations[index];ad,am=storage(allocation);offset=pointer-allocation['address']
            assert 0<=offset and offset+80*count<=len(ad)==allocation['size']
            for n in range(count):
                at=offset+80*n;effect=word(ad,am,at+0x2c);effects[effect]+=1
                if effect>=5000:
                    high.append(dict(object=obj['index'],id=obj['id'],type=obj['objectType'],path=obj['path'],sourceSHA256=obj['source'],
                        frame=frame,itr=n,effect=effect,targetFrame=effect-6000 if effect>=6000 else None,
                        bytes=ad[at:at+80].hex(),mask=am[at:at+80].hex(),allocationBytesSHA256=allocation['storage']['bytes']))
    assert objects==137 and len(types)==42 and sum(effects.values())==4384
    result=dict(scope=__doc__,catalogFixture=report['fixture'],catalogFixtureSHA256=report['fixtureSHA256'],catalogRawSHA256=report['sha256'],
        DATsVerified=objects,interactions=sum(effects.values()),effects=dict(sorted(effects.items())),highEffects=high,type0Objects=types,
        strideWords=dict(stride_words),blobsVerified=len(cache),staticDataOnly=True,windowsVerified=False)
    path=ROOT/'docs/evidence/lib-hit-effects-catalog.json';path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(DATs=objects,interactions=sum(effects.values()),effects=dict(sorted(effects.items())),
        highEffectRecords=len(high),type0Objects=len(types),strideWords=dict(stride_words),blobs=len(cache)),indent=2))
if __name__=='__main__':main()
