#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify original window lifecycle and declared API boundaries.

Reconstruct globals/masks, frame fields, own retained states, resource releases
and allocation lifetime from immutable original stores/requests. Check actual
instruction bytes and original installer parent; distinguish static starts,
controlled callback delivery and unknown Windows/reentrant/device behavior.
No source execution, memory fault generation or expected-byte change occurs.
"""
import argparse,base64,copy,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
h=lambda b:hashlib.sha256(b).hexdigest()
BASE,COUNT,PTR=0x44d000,0xb440,0x4588a8

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();bp=ROOT/'build/research'
    w=json.loads((bp/'window-lifecycle-work.json').read_bytes());path=ROOT/'build/original/window-lifecycle.json';raw=path.read_bytes();doc=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(doc['cases'])==320 and not doc['limited']
    assert h((ROOT/'tools/oracle_window_lifecycle.py').read_bytes())==h((bp/'window-lifecycle-source.py').read_bytes())==w['sourceToolSHA256']
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();parent_report=json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes());assert h(parent)==parent_report['sha256']
    assert doc['parent']==json.loads(parent)['cases'][0] and doc['exeSHA256']==EXE_SHA256
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());assert h(pe.data)==EXE_SHA256
    assert doc['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
    blobs={}
    for key,item in doc['blobs'].items():
        b=base64.b64decode(item['base64'],validate=True);assert h(b)==key and len(b)==item['count'];blobs[key]=b
    parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['incomplete'] and checkpoint['completed']==320
    events=Counter();helpers=Counter();stores=Counter();store_bytes=0;total_bytes=0;retained=0;initializations=0;pcs={};previous=None;structures=Counter();structure_bytes=0;written_fields=0;ignored_recreation_zero=0;source_masks=0
    for c in doc['cases']:
        case_raw=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(case_raw)==c
        if c['index']==319:assert h(case_raw)==checkpoint['lastCaseSHA256']
        spec=c['spec'];before=c['before'];after=c['after'];state=bytearray(blobs[before['globals']]);pointers=bytearray(blobs[before['pointers']]);masks=[bytearray(COUNT),bytearray(8)]
        assert len(state)==COUNT and len(pointers)==8
        if spec.get('retain'):
            retained+=1;assert previous is not None
            prior=bytearray(blobs[previous['globals']])
            for a,v in spec.get('stimulus',[]):struct.pack_into('<I',prior,a-BASE,v&0xffffffff)
            assert state==prior and {k:v for k,v in before.items() if k!='globals'}=={k:v for k,v in previous.items() if k!='globals'}
        objects=copy.deepcopy(before['objects']);allocations=copy.deepcopy(before['allocations']);ordered=[]
        for action in c['actions']:
            if action['kind']=='store':
                a=action['address'];b=bytes(action['bytes']);region=1 if a>=PTR else 0;o=a-(PTR if region else BASE);target=pointers if region else state
                assert 0<=o<o+len(b)<=len(target);target[o:o+len(b)]=b;masks[region][o:o+len(b)]=b'\1'*len(b)
                stores[action['origin']]+=1;store_bytes+=len(b);ordered.append((a,b.hex(),action['origin']))
            else:
                assert action['kind']=='request';e=action['event'];q=e['request'];kind=q['kind'];r=e['response'];events[kind]+=1
                if kind in ('clientRect','screenPoint','setRect'):
                    address=q['words'][0] if kind=='setRect' else q['words'][1];n=8 if kind=='screenPoint' else 16
                    assert bytes(q['bytes'])==state[address-BASE:address-BASE+n] and all(q['defined'])
                if 'output' in r:
                    address=r['output'];assert not any(o['address']==address for o in objects)
                    objects.append(dict(address=address,family='draw' if kind=='directDrawCreate' else 'clipper' if kind=='createClipper' else 'surface',releases=[]))
                if kind=='release':next(o for o in objects if o['address']==q['words'][0])['releases'].append(dict(key=e['key'],result=r['result']&0xffffffff))
                if kind=='free':
                    a=next(a for a in allocations if a['address']==q['words'][0]);assert a['live'];a['live']=False
                if kind=='postQuit':assert q['words']==[0] and struct.unpack_from('<I',state,0x458434-BASE)[0]==0
                if kind=='windowDefault':assert q['words']==[spec.get('window',0x73000011),spec['message'],spec.get('wParam',0),spec.get('lParam',0)]
        assert [a['event'] for a in c['actions'] if a['kind']=='request']==c['events']
        assert sorted(ordered)==sorted((x['address'],x['bytes'],x['origin']) for x in c['writes'])
        assert state==blobs[after['globals']] and pointers==blobs[after['pointers']]
        assert objects==after['objects'] and allocations==after['allocations']
        assert [bytes(m) for m in masks]==[blobs[key] for key in c['writeMasks']]
        total_bytes+=COUNT+8+sum(a['count'] for a in allocations);source_masks+=sum(map(sum,masks))
        for a in allocations:assert len(blobs[a['bytes']])==a['count']
        helpers.update(x['kind'] for x in c['helpers'])
        for i in c['instructions']:
            a=i['address'];b=bytes.fromhex(i['bytes']);o=pe.offset(a-pe.base);assert pe.data[o:o+len(b)]==b
            if a in pcs:assert pcs[a]==b
            pcs[a]=b
        initialize=spec.get('initialize',False);initializations+=initialize
        assert c['sp']==(0x2000f004 if initialize else 0x2000f014) and c['fpcw']==0x23f
        if initialize:assert c['result']==1
        elif c['events'] and c['events'][-1]['request']['kind']=='windowDefault':assert c['result']==c['events'][-1]['response']['result']&0xffffffff
        else:assert c['result']==(1 if spec['message'] in (0x112,0x30f) else 0)
        if spec.get('message')==0x105 and any(x['kind']=='display' and x['eax']==0 for x in c['helpers']):
            ignored_recreation_zero+=1;assert any(e['request']['kind']=='showWindow' for e in c['events'])
            assert struct.unpack_from('<I',state,0x458434-BASE)[0]==0
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
        previous=after
    assert retained==18 and initializations==2 and helpers['callback']==318
    for key,item in doc['blobs'].items():assert json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    cs=Cs(CS_ARCH_X86,CS_MODE_32);static={}
    ranges=[(0x43b3d0,0x43bc41),(0x43bdd0,0x43beba),(0x43bec0,0x43bf03),(0x401000,0x40108e),(0x401090,0x40110b),(0x401110,0x4011cb),(0x4011d0,0x401246),(0x401250,0x401282),(0x401300,0x4013cf),(0x401b00,0x401be9),(0x401bf0,0x401c86),(0x43e8e0,0x43e935),(0x43f37e,0x43f384),(0x401a80,0x401ad7),(0x401ae0,0x401af6),(0x4019b0,0x401a27),(0x401d30,0x401d91),(0x43d280,0x43d2b8)]
    for a,b in ranges:
        o=pe.offset(a-pe.base)
        for i in cs.disasm(pe.data[o:o+b-a],a):static[i.address]=dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str)
    assert set(pcs)<=set(static),[hex(a) for a in set(pcs)-set(static)]
    prior=json.loads((ROOT/'docs/evidence/window-input.json').read_bytes());input_bytes=(ROOT/'build/original/window-input.json').read_bytes();assert h(input_bytes)==prior['rawSHA256']
    input_raw=json.loads(input_bytes);input_pcs={i['address'] for c in input_raw['cases'] for i in c['instructions'] if 0x43b3d0<=i['address']<0x43bc41}
    wnd={a for a in pcs if 0x43b3d0<=a<0x43bc41};missing=sorted(a for a in static if 0x43b3d0<=a<0x43bc41 and a not in wnd|input_pcs)
    report=dict(scope=__doc__,rawBytes=len(raw),rawSHA256=h(raw),cases=320,wholeCallbacks=318,initializations=2,retainedCalls=18,blobs=len(blobs),events=dict(events),eventCount=sum(events.values()),helpers=dict(helpers),helperCount=sum(helpers.values()),stores=dict(stores),storeCount=sum(stores.values()),storeBytes=store_bytes,comparedStorageBytes=total_bytes,uniqueWrittenBytes=source_masks,originalEXEPCs=len(pcs),wndProcPCs=len(wnd),DLLPCs=0,combinedWndProcPCs=len(wnd|input_pcs),remainingWndProcStatic=[static[a] for a in missing],structures=dict(structures),structureCount=sum(structures.values()),structureBytes=structure_bytes,writtenFieldBytes=written_fields,ignoredZeroRecreationReturns=ignored_recreation_zero,wholeInstallerEqual=True,allAtomicCasesEqual=True,allOwnBeforeEqual=True,sourceToolSHA256=w['sourceToolSHA256'],nativeCompared=False,windowsVerified=False,originalMemoryFaults=0)
    report.update(helperEntryBackings=sum(len(c['backings']) for c in doc['cases']),
                  rectanglePointRequests=events['clientRect']+events['screenPoint']+events['setRect'],
                  rectanglePointBytes=16*(events['clientRect']+events['setRect'])+8*events['screenPoint'])
    if args.artifacts:
        fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-window-lifecycle.json';packed=fixture.read_bytes();env=json.loads(packed);d=zlib.decompressobj(-15);payload=d.decompress(base64.b64decode(env['deflate'],validate=True))+d.flush();assert d.eof and not d.unused_data
        assert payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==doc
        prior=json.loads((bp/'window-lifecycle-prior-pins.json').read_bytes());pins=json.loads((bp/'window-lifecycle-fixture-pins.json').read_bytes());assert set(pins)==set(prior)|{fixture.name}
        for n,digest in pins.items():assert h((fixture.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        export=json.loads((bp/'window-lifecycle-final-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=bp/('window-lifecycle-artifact-verification.json' if args.artifacts else 'window-lifecycle-source-verification.json');target.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('scope','remainingWndProcStatic')},indent=2))
if __name__=='__main__':main()
