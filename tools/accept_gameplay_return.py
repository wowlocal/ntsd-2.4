#!/usr/bin/env python3
"""Accept both initialized first-tick output and actual match/dispatcher returns.

Pinned original EXE/VC80 on one initialized Unicorn CPU, with declared COM/GDI
responses. Independently reconstruct game globals from source stores, check
owned bitmap reads, complete unchanged storage, parent identity, FPU and both
normal saved-frame restorations. No source stack state seeds native storage;
this establishes neither Windows/device output nor a continuous full match.
"""
import argparse
import base64
import copy
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical, publish
from accept_gameplay_output import CALLER, EPILOGUE, STAGES

OUTER_EPILOGUE={0x4287de,0x4287e5,0x4287ec,0x4287ed,0x4287ee,0x4287ef,0x4287f0,0x4287f1,0x4287f8,0x4287fa,0x4287ff,0x428805}


def validate_captures():
    captures=[]
    for suffix in ('','-control'):
        name='gameplay-return'+suffix;report,raw,doc=capture(name)
        parent_report,parent=historical('gameplay-result-layout'+suffix)
        assert doc['parent']==report['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
        assert doc['control']==bool(suffix) and len(doc['cases'])==1
        for key in ('worldAddress','actorAddresses','objectAddresses'):assert doc[key]==parent[key]
        blobs={}
        for key,b in doc['blobs'].items():
            value=zlib.decompress(base64.b64decode(b['deflate']),-15)
            assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
        c=doc['cases'][0];n=c['gameplayReturn'];before,after=c['before'],c['after']
        assert c['label']=='gameplay-return' and before==parent['cases'][0]['after']
        assert c['end']==report['end']==dict(pc=0x30000000,sp=0x1000f42c) and c['checkpoints']==[]
        assert before['state']['globals']==before['early']['globals'] and after['state']['globals']==after['early']['globals']
        expected=copy.deepcopy(before)
        expected['state']['globals']=expected['early']['globals']=after['state']['globals']
        assert expected==after, 'Every non-global byte, mask and ownership record must survive'
        value=bytearray(blobs[before['state']['globals']]);assert len(value)==0xb440
        original=bytes(value);written=bytearray(len(value));stores=Counter()
        for w in n['writes']:
            offset=w['address']-0x44d000;size=w['size']
            assert size in (1,2,4) and 0<=offset<offset+size<=len(value)
            value[offset:offset+size]=w['value'].to_bytes(size,'little')
            written[offset:offset+size]=b'\1'*size;stores[hex(w['pc'])]+=1
        assert bytes(value)==blobs[after['state']['globals']]
        assert n['writes'][-1]==dict(pc=0x424746,address=0x457580,size=4,value=0)
        def u32(address):return int.from_bytes(original[address-0x44d000:address-0x44d000+4],'little')
        assert u32(0x44eecc)!=0 and n['input']['targetSurface']==u32(0x455608)
        buffers=sorted({u32(base+4*i) for count,base in ((400,0x452948),(80,0x451db0),(5,0x45560c)) for i in range(count)}-{0})
        assert n['loadedSoundBuffers']==buffers
        methods={0x40:2,0x3c:2,0x48:1,0x34:2,0x30:4}
        tables={b['table'] for b in n['methodBindings']};assert tables
        assert {(b['table'],b['offset']) for b in n['methodBindings']}=={(table,offset) for table in tables for offset in methods}
        for b in n['methodBindings']:
            assert b['argumentCount']==methods[b['offset']] and b['after']==0x33006000+16*list(methods).index(b['offset'])
        records={r['address']:r['storage'] for r in before['bitmaps']+before['menuBitmaps']+before['early']['records']}
        fonts={u32(a) for a in (0x44faf4,0x44f888,0x44fcbc)}
        assert set(n['resourceSurfaces'])=={str(p) for p in fonts}
        for p in fonts:assert n['resourceSurfaces'][str(p)]==int.from_bytes(blobs[records[p]['bytes']][:4],'little')
        bitmap=None;events=Counter();undefined=0;event_writes=[]
        for e in n['events']:
            kind=e['kind'];events[kind]+=1
            if kind=='draw':
                bitmap=e['arguments'][0];assert bitmap in records
            elif kind=='read':
                assert bitmap is not None;r=e['read'];b=records[bitmap];offset=r['offset'];assert 0<=offset<=0x1f50-4
                assert r['value']==int.from_bytes(blobs[b['bytes']][offset:offset+4],'little')
                assert r['defined']==all(blobs[b['defined']][offset:offset+4]);undefined+=not r['defined']
            elif kind=='blit':
                assert bitmap is not None;b=e['blit']
                assert b['targetSurface']==u32(0x455608) and b['effects'] is None
                assert b['sourceSurface']==int.from_bytes(blobs[records[bitmap]['bytes']][:4],'little')
            elif kind=='labelWrite':event_writes.append(tuple(e['arguments']))
            elif kind=='stringWrite':event_writes.append((0x450c38+e['arguments'][0],1,0))
            elif kind in ('queueWrite','dispatcherWrite'):event_writes.append((e['arguments'][0],4,0))
            elif kind=='method' and e['arguments'][1] in methods:
                assert e['arguments'][0] in buffers and len(e['arguments'])==methods[e['arguments'][1]]+1
        assert event_writes==[(w['address'],w['size'],w['value']) for w in n['writes'] if not 0x402810<=w['pc']<0x402a60]
        assert dict(events)==report['events']
        assert [e['arguments'][0] for e in n['events'] if e['kind']=='stage']==STAGES
        assert n['events'][-1]==dict(kind='dispatcherWrite',arguments=[0x457580,0],strings=[])
        pcs=set(c['instructions']);assert len(pcs)==report['instructions']
        assert CALLER|EPILOGUE|OUTER_EPILOGUE|{0x424746,0x424750,0x4287de,0x428805,0x4450b2}<=pcs
        assert 0x30000000 not in pcs and all(0x400000<=p<0x500000 or 0x78130000<=p<0x78230000 for p in pcs)
        helpers=Counter(h['entry'] for h in c['helpers'])
        assert len(c['helpers'])==report['helpers'] and helpers[0x4450b2]==3
        assert all(helpers[stage]==1 for stage in STAGES)
        for h in c['helpers']:assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4
        assert len(n['entryObservations'])==2 and len(n['returnObservations'])==4
        outer,inner=n['entryObservations'];ret=n['returnObservations']
        assert outer==dict(pc=0x4246b0,sp=0x1000f424,returnPC=0x30000000,argument=u32(0x455608),saved=[0x11223344,0x22334455,0x33445566,0x44556677],seh=0x12345678)
        assert inner['pc']==0x41bc90 and inner['sp']==0x1000eff8 and inner['returnPC']==0x424746 and inner['argument']==u32(0x455608)
        assert [(r['pc'],r['sp']) for r in ret]==[(0x422a95,0x1000e9bc),(0x424746,0x1000f000),(0x4287de,0x1000f000),(0x30000000,0x1000f42c)]
        assert all((r['saved'],r['seh'])==(inner['saved'],inner['seh']) for r in ret[1:3])
        assert (ret[-1]['saved'],ret[-1]['seh'])==(outer['saved'],outer['seh'])
        audit,old=doc['fpu'],parent['fpu']
        for field in ('initialization','transitions','watchedInstructions'):assert audit[field]==old[field]
        assert len(old['checkpoints'])==1606 and audit['checkpoints'][:-8]==old['checkpoints']
        assert len(audit['checkpoints'])==report['fpuCheckpoints']==1614
        points=[0x422994,*STAGES,0x422a95,0x424746,0x4287de]
        sps=[0x1000e9bc,0x1000e9b0,0x1000e9b4,0x1000e9b0,0x1000e9b8,0x1000e9bc,0x1000f000,0x1000f000]
        assert audit['checkpoints'][-8:]==[dict(pc=p,sp=sp,fpcw=0x23f,fpsw=0x4000) for p,sp in zip(points,sps)]
        assert n['fpcw']==0x23f and n['fpswBefore']==n['fpswAfter']==0x4000 and n['fptagBefore']==n['fptagAfter']==0xffff
        assert c['readsBeforeWrites']==report['readsBeforeWrites']
        report.update(initializedParentReproduced=True,parentSHA256=parent_report['sha256'],blobs=len(blobs),
            unchangedStorageExceptGlobals=True,sourceGlobalsReconstructedFromStores=True,sourceWrittenByteCount=sum(written),
            changedGlobalBytes=sum(a!=b for a,b in zip(original,value)),sourceGlobalStorePCs=dict(stores),
            bitmapReadBytesAndMasksVerified=True,undefinedBitmapReadEvents=undefined,ownedSoundBuffers=len(buffers),
            helperReturns={hex(k):v for k,v in sorted(helpers.items())},
            exeInstructions=sum(p<0x70000000 for p in pcs),crtInstructions=sum(p>=0x70000000 for p in pcs),
            innerAndOuterSavedFramesRestored=True,originalNormalCookieChecks=3,sourceStackBytesImportedToNative=False,
            firstInitializedTickReturned=True,continuousTicksCompared=False,fullMatchCompared=False,pixelsCompared=False,audioDeviceCompared=False)
        captures.append((name,report,raw))
    return captures


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--verify-only',action='store_true');parser.add_argument('--scratch-path');args=parser.parse_args()
    captures=validate_captures()
    for name,report,raw in captures:
        print(name,'full source/parent/storage/events/FPU/return verification passed',len(raw),'bytes',report['sha256'],flush=True)
        (ROOT/'build/research'/(name+'-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
    if args.verify_only:return
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    accepted=json.loads((ROOT/'build/research/gameplay-result-layout-fixture-pins.json').read_bytes())
    assert len(accepted)==186 and all(pins[n]==sha for n,sha in accepted.items())
    command=['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalGameplayReturnTests|OriginalGameplayOutputTests']
    if args.scratch_path:command.extend(['--scratch-path',str(ROOT/args.scratch_path)])
    subprocess.run(command,env=dict(os.environ,NTSD_GAMEPLAY_RETURN_DIRECTORY=str(ROOT/'build/original')),check=True)
    for _,report,_ in captures:
        report['nativeComparison']='Full own reconstructed state and masks before/after, exact ordered output/sound/dispatcher events, owned loaded resources, complete inherited FPU history. Late dispatcher observer verifies atomic native output rollback. Original machine frames establish source restoration only; no stack snapshot is imported.'
    publish(captures,pins,pin_name='gameplay-return-fixture-pins.json')


if __name__=='__main__':main()
