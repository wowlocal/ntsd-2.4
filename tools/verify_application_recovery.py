#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Verify whole43e890 original recovery at declared COM/Win32/local boundaries.
Reconstruct all global/stack stores, structures, owned object lifetime and actual
instruction bytes. Preserve null-back read after failed creation separately;
no source execution or fault generation, Windows/device or full-app claim.
"""
import argparse,base64,copy,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
h=lambda b:hashlib.sha256(b).hexdigest()
BASE,COUNT,PTR=0x44d000,0xb440,0x4588a8

def validate(path):
    raw=path.read_bytes();doc=json.loads(raw);assert len(doc['cases'])==322 and not doc['limited']
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());assert h(pe.data)==EXE_SHA256
    parent_raw=(ROOT/'build/original/lib-initialization.json').read_bytes();parent_report=json.load(open(ROOT/'docs/evidence/lib-initialization.json'))
    assert h(parent_raw)==parent_report['sha256'] and doc['parent']==json.loads(parent_raw)['cases'][0]
    blobs={}
    for key,b in doc['blobs'].items():
        v=base64.b64decode(b['base64'],validate=True);assert len(v)==b['count'] and h(v)==key;blobs[key]=v
    section=next(s for s in pe.sections if s['name']=='.data');image=pe.data[section['fileOffset']:section['fileOffset']+section['fileSize']]+bytes(section['virtualSize']-section['fileSize'])
    initial=bytearray(image[:COUNT]);parent_stores=[w for w in doc['parent']['writes'] if BASE<=w['address']<BASE+COUNT]
    assert [w['address'] for w in parent_stores]==[0x44eea4,0x44eea8]
    for w in parent_stores:
        assert w['size']==4
        struct.pack_into('<I',initial,w['address']-BASE,w['value'])
    assert blobs[doc['initialGlobals']]==initial
    events=Counter();helpers=Counter();stores=Counter();structures=Counter();structure_bytes=written_fields=0;pcs={};previous=None;retained=0;stack_stores=0;rejected=0
    assert doc['stackAddress']==0x2000ee00 and doc['stackCount']==576
    for c in doc['cases']:
        assert json.loads(path.with_suffix('.parts').joinpath(f'{c["index"]:04d}.json').read_bytes())==c
        before=c['before'];after=c['after'];spec=c['spec']
        if spec.get('retain'):
            retained+=1;assert before==previous['after'] and c['stackBefore']==previous['stackAfter']
        else:
            g=bytearray(blobs[doc['initialGlobals']]);objects=[]
            for a,v in [(0x458430,spec.get('mode',0)),(0x458434,spec.get('changing',0)),(0x44d794,1),(0x4554c0,0x400000),(0x44d78c,794),(0x44d790,550),(0x4546f4,spec.get('oldWindow',0x73000011)),(0x455634,0),(0x455608,0),(0x457578,0)]:struct.pack_into('<I',g,a-BASE,v&0xffffffff)
            for bit,a,f in [(1,0x457578,'draw'),(2,0x455608,'surface'),(4,0x455634,'surface')]:
                if spec.get('resources',0 if spec.get('initialize') else 7)&bit:
                    pointer=0x31000000+0x1000*(len(objects)+1);objects.append(dict(address=pointer,family=f,releases=[]));struct.pack_into('<I',g,a-BASE,pointer)
            assert g==blobs[before['globals']] and objects==before['objects']
        state=bytearray(blobs[before['globals']]);mask=bytearray(COUNT);objects=copy.deepcopy(before['objects']);ordered=[]
        assert before['allocations']==after['allocations']==[] and blobs[before['pointers']]==blobs[after['pointers']]==bytes(8)
        for action in c['actions']:
            if action['kind']=='store':
                address=action['address'];b=bytes(action['bytes']);o=address-BASE;assert 0<=o<o+len(b)<=COUNT
                state[o:o+len(b)]=b;mask[o:o+len(b)]=b'\1'*len(b);stores[action['origin']]+=1;ordered.append((address,b.hex(),action['origin']))
            else:
                assert action['kind']=='request';e=action['event'];q=e['request'];kind=q['kind'];r=e['response'];events[kind]+=1
                if 'output' in r:
                    address=r['output'];assert not any(o['address']==address for o in objects)
                    objects.append(dict(address=address,family='draw' if kind=='directDrawCreate' else 'clipper' if kind=='createClipper' else 'surface',releases=[]))
                if kind=='release':next(o for o in objects if o['address']==q['words'][0])['releases'].append(dict(key=e['key'],result=r['result']&0xffffffff))
                if kind=='restore':assert q['words'][0] in [o['address'] for o in objects if o['family']=='surface']
                if kind=='showWindow':assert q['words']==[struct.unpack_from('<I',state,0x4546f4-BASE)[0],5]
        assert [a['event'] for a in c['actions'] if a['kind']=='request']==c['events']
        assert ordered==[(x['address'],x['bytes'],x['origin']) for x in c['writes']]
        assert state==blobs[after['globals']] and mask==blobs[c['writeMasks'][0]] and blobs[c['writeMasks'][1]]==bytes(8) and objects==after['objects']
        stack=bytearray(blobs[c['stackBefore']]);assert len(stack)==576
        for w in c['stackWrites']:
            o=w['address']-doc['stackAddress'];b=bytes.fromhex(w['bytes']);assert 0<=o<o+len(b)<=576
            stack[o:o+len(b)]=b;stack_stores+=1
        assert stack==blobs[c['stackAfter']]
        helpers.update(x['kind'] for x in c['helpers'])
        for i in c['instructions']:
            a=i['address'];b=bytes.fromhex(i['bytes']);o=pe.offset(a-pe.base);assert pe.data[o:o+len(b)]==b
            if a in pcs:assert pcs[a]==b
            pcs[a]=b
        assert c['fpcw']==0x23f
        if not c['completed']:
            rejected+=1;assert c['index']==321 and spec['allowNullBackFault'] and c['error']=='Invalid memory read (UC_ERR_READ_UNMAPPED)'
            assert c['faults']==[dict(access=19,address=0,count=4,pc=0x43e876,value=0)]
            assert struct.unpack_from('<I',blobs[before['globals']],0x455608-BASE)[0]==0 and previous['spec']['results']['createWindow#1']==0
        else:
            assert not c['faults'] and c['error'] is None and c['sp']==0x2000f004
            if spec.get('initialize'):assert c['result']==1
            else:
                restore=next(x for x in c['helpers'] if x['kind']=='restoreSurfaces');back=[e for e in c['events'] if e['request']['kind']=='restore'][-1]['response']['result'];normal=back>=0 or (back&0xffffffff)==0x8876024c
                assert restore['eax']==(0 if normal else back&0xffffffff)
                if normal:assert c['result']==0 and all(e['request']['kind']=='restore' for e in c['events'])
                else:
                    assert c['events'][-1]['request']['kind']=='showWindow' and c['result']==c['events'][-1]['response']['result']&0xffffffff
                    assert struct.unpack_from('<I',state,0x458434-BASE)[0]==0
            for helper in c['helpers']:
                if helper['kind']=='display':assert helper['eax'] in (0,1)
        frame=0;description=description_mask=None
        width=struct.unpack_from('<I',blobs[before['globals']],0x44d78c-BASE)[0]
        height=struct.unpack_from('<I',blobs[before['globals']],0x44d790-BASE)[0]
        instance=struct.unpack_from('<I',blobs[before['globals']],0x4554c0-BASE)[0]
        def take(kind,n):
            nonlocal frame
            b=c['backings'][frame];frame+=1;assert b['kind']==kind and len(b['bytes'])==n;return bytearray(b['bytes']),bytearray(n)
        def put(b,m,o,v):struct.pack_into('<I',b,o,v&0xffffffff);m[o:o+4]=b'\1'*4
        for e in c['events']:
            q=e['request'];kind=q['kind'];data=mask=None
            if kind=='registerClass':
                data,mask=take('windowClass',40)
                # Icon/cursor calls precede this request; the actual helper
                # entry identifies fullscreen without importing expected fields.
                full=c['backings'][frame-1]['entry']==0x401bf0
                for o,v in {0:3,4:0x43b3d0,8:0,12:0,16:instance,20:icon,28:0,32:0x447634,36:0x447634}.items():put(data,mask,o,v)
                if not full:put(data,mask,24,cursor)
            elif kind=='icon':icon=e['response']['result']&0xffffffff
            elif kind=='cursor':cursor=e['response']['result']&0xffffffff
            elif kind=='createSurface':
                if e['returnPC']==0x4010e0:
                    data,mask=take('surfaceDescription',108)
                    swaps=sum(1 for x in c['events'][:c['events'].index(e)+1] if x['request']['kind']=='createSurface' and x['returnPC']==0x4010e0)
                    for o,v in {0:108,4:0x21,8:height,12:width,20:3-swaps,104:0x4218}.items():put(data,mask,o,v)
                elif e['returnPC']==0x401148:
                    description,description_mask=take('surfaceDescription',108)
                    for o,v in {0:108,4:1,104:0x200}.items():put(description,description_mask,o,v)
                    data,mask=description,description_mask
                else:
                    assert e['returnPC']==0x40119f and description is not None
                    for o,v in {4:7,8:height,12:width,104:0x40}.items():put(description,description_mask,o,v)
                    data,mask=description,description_mask
            elif kind=='pixelFormat':data,mask=take('pixelFormat',32);put(data,mask,0,32)
            elif kind=='blt':data,mask=take('fillEffects',100);put(data,mask,0,100);put(data,mask,80,0)
            if data is not None:
                assert list(data)==q['bytes'] and [bool(b) for b in mask]==q['defined'],(c['index'],e['key']);structures[kind]+=1;structure_bytes+=len(data);written_fields+=sum(mask)
        assert frame==len(c['backings'])
        previous=c
    assert retained==14 and rejected==1 and helpers['wrapper']==3 and helpers['recovery']==318
    parts=path.with_suffix('.parts')/'blobs'
    for k,v in doc['blobs'].items():assert json.loads((parts/(k+'.json')).read_bytes())==v
    assert len(list(parts.glob('*.json')))==len(blobs)
    cs=Cs(CS_ARCH_X86,CS_MODE_32);static={}
    for start,end in [(0x43e860,0x43e88c),(0x43e890,0x43e8d5)]:
        offset=pe.offset(start-pe.base)
        for i in cs.disasm(pe.data[offset:offset+end-start],start):static[i.address]=dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str)
    observed={a for a in pcs if 0x43e860<=a<=0x43e8d4};assert set(static)-observed=={0x43e8b1,0x43e8b6} and len(observed)==32
    return dict(rawBytes=len(raw),rawSHA256=h(raw),wholeRecoveryReturns=318,ownInitializations=3,sourceFaultRejections=1,cases=322,retainedCalls=14,
        events=dict(events),eventCount=sum(events.values()),helpers=dict(helpers),helperCount=sum(helpers.values()),stores=dict(stores),storeCount=sum(stores.values()),
        comparedGlobalBytes=322*COUNT,sourceStackStores=stack_stores,structures=dict(structures),structureCount=sum(structures.values()),structureBytes=structure_bytes,
        originalEXEPCs=len(pcs),newRecoveryPCs=len(observed),newStaticPCs=len(static),unexecutedRecoveryStarts=[static[a] for a in sorted(set(static)-observed)],
        DLLPCs=0,blobs=len(blobs),atomicCases=322,installerParentExact=True,ownBeforeAndStackRetained=True,nativeCompared=False,windowsVerified=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--packaged',action='store_true');a=p.parse_args();path=ROOT/a.raw;result=validate(path)
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-recovery-prior-pins.json'))
    for n,v in pins.items():assert h((fixtures/n).read_bytes())==v,n
    result['priorPinsUnchanged']=len(pins)
    vendor=ROOT/'native/Sources/NTSDReplayCodec';up=json.load(open(vendor/'upstream.json'))
    for n,v in up['files'].items():assert h((vendor/'vendor'/n).read_bytes())==v['vendoredSHA256']
    result['vendorHashesVerified']=len(up['files'])
    if a.packaged:
        packed=(fixtures/'original-application-recovery.json').read_bytes();w=json.loads(packed);restored=zlib.decompress(base64.b64decode(w['deflate']),-15)
        assert restored+b'\n'==path.read_bytes() and json.loads(restored)==json.loads(path.read_bytes()) and len(restored)==w['count'] and h(restored)==w['sha256']
        evidence=json.load(open(ROOT/'docs/evidence/application-recovery.json'));assert evidence['rawSHA256']==h(path.read_bytes()) and evidence['fixtureSHA256']==h(packed)
        result.update(fullRawPackedBytesEqual=True,completeJSONEqual=True,fixtureBytes=len(packed),fixtureSHA256=h(packed))
    out=ROOT/'build/research/application-recovery-verification.json';out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
