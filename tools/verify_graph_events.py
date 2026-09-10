#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify original graph-loop bytes, locals and request order.

Reconstruct the full aligned frame from declared entry backing and partial API
writes; replay actual parameter reads, seek+0, FreeEventParams and exactE_ABORT
termination. Check immutable journals, original instruction bytes and installer
parent. This does not execute Windows/audio or invent source/native results.
"""
import argparse,base64,copy,hashlib,json,struct,zlib
from pathlib import Path
from collections import Counter
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
h=lambda b:hashlib.sha256(b).hexdigest()
BASE,COUNT=0x44d000,0xb440

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();b=ROOT/'build/research';w=json.loads((b/'graph-events-work.json').read_bytes());path=ROOT/'build/original/graph-events.json';raw=path.read_bytes();doc=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(doc['cases'])==375 and not doc['limited']
    assert h((ROOT/'tools/oracle_graph_events.py').read_bytes())==h((b/'graph-events-source.py').read_bytes())==w['sourceToolSHA256']
    probe=json.loads((b/'graph-events-probe1.json').read_bytes())
    assert doc['cases'][:8]==probe['cases']
    assert all(doc['blobs'][key]==value for key,value in probe['blobs'].items())
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();assert h(parent)==json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())['sha256'];assert doc['parent']==json.loads(parent)['cases'][0]
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());assert h(pe.data)==doc['exeSHA256']==EXE_SHA256
    assert doc['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
    blobs={}
    for key,item in doc['blobs'].items():
        data=base64.b64decode(item['base64'],validate=True);assert len(data)==item['count'] and h(data)==key;blobs[key]=data
    parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['incomplete'] and checkpoint['completed']==375
    events=Counter();methods=Counter();helpers=Counter();stores=Counter();store_bytes=0;reads=0;seeks=0;callbacks=0;initializers=0;retained=0;previous=None;pcs={};fpu=dict(control=0x23f,status=0,tag=0xffff)
    for c in doc['cases']:
        saved=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(saved)==c
        if c['index']==374:assert h(saved)==checkpoint['lastCaseSHA256']
        spec=c['spec'];state=bytearray(blobs[c['before']]);gm=bytearray(COUNT);lm=bytearray(64);local=bytearray(blobs[c['localBefore']]) if c['localBefore'] else None
        if spec.get('retain'):retained+=1;assert c['before']==previous
        expected_stores=[];actual_requests=[]
        for a in c['actions']:
            if a['kind']=='request':actual_requests.append(a['event']);continue
            data=bytes(a['bytes']);o=a['offset'];target,mask=(state,gm) if a['region']=='globals' else (local,lm)
            assert target is not None and 0<=o<o+len(data)<=len(target);target[o:o+len(data)]=data;mask[o:o+len(data)]=b'\1'*len(data)
            address=BASE+o if a['region']=='globals' else c['frame']+o;expected_stores.append((address,data.hex(),a['origin'],a['region']));stores[a['origin']]+=1;store_bytes+=len(data)
        assert expected_stores==[(x['address'],x['bytes'],x['origin'],x['region']) for x in c['writes']]
        assert actual_requests==c['events'];assert state==blobs[c['after']] and gm==blobs[c['globalWritten']] and lm==blobs[c['localWritten']]
        assert c['exitFPU']==fpu
        if spec.get('initialize'):
            initializers+=1;assert c['frame'] is None and not c['reads'] and not c['seeks'] and not any(lm)
            assert c['result']==(0xffffffff if spec.get('createResult',0)<0 else 0) and c['sp']==0x2000f004
            if spec.get('emptyGraph'):
                assert all(struct.unpack_from('<I',blobs[c['before']],a-BASE)[0]==0 for a in (0x44f040,0x44f044,0x44f048,0x44f04c))
            if c['result']==0:
                assert [e['kind'] for e in c['events']]==['createInstance','queryInterface','queryInterface','queryInterface','method','method']
                assert [struct.unpack_from('<I',state,a-BASE)[0] for a in (0x44f040,0x44f044,0x44f048,0x44f04c)]==[doc['tokens'][n] for n in ('graph','control','event','position')]
        else:
            callbacks+=1;assert c['frame']==0x2000ef80 and c['entryFPU']==fpu and c['sp']==0x2000f014
            assert local==blobs[c['localAfter']] and c['before']==c['after'] and not any(gm)
            initial=bytes(((0xef80+i)*spec.get('seed',17)+0xa5)&255 for i in range(64));assert initial==blobs[c['localBefore']]
            modeled=bytearray(initial);expected_events=[];expected_reads=[];expected_seeks=0
            for response in spec['queue']:
                expected_events.append(dict(kind='getEvent',arguments=[doc['tokens']['event'],0x20,0],strings=[],response=response))
                for name,offset in [('code',0x34),('first',0x3c),('second',0x38)]:
                    if name in response:struct.pack_into('<I',modeled,offset,response[name])
                if response['result']&0xffffffff==0x80004004:break
                code=struct.unpack_from('<I',modeled,0x34)[0];first=struct.unpack_from('<I',modeled,0x3c)[0];second=struct.unpack_from('<I',modeled,0x38)[0]
                for pc,offset in [(0x401ebe,0x34),(0x401edc,0x38),(0x401ee8,0x3c),(0x401eed,0x34)]:expected_reads.append(dict(pc=pc,offset=offset,count=4,bytes=modeled[offset:offset+4].hex()))
                if code==1:
                    expected_seeks+=1;expected_events.append(dict(kind='method',arguments=[doc['tokens']['position'],0x20,0,0],strings=[],response=dict(result=spec.get('methodResult',0))))
                expected_events.append(dict(kind='method',arguments=[doc['tokens']['event'],0x30,code,first,second],strings=[],response=dict(result=spec.get('methodResult',0))))
            expected_events.append(dict(kind='windowDefault',arguments=[spec.get('window',0x73000001),0x400,spec.get('wParam',0xaabbccdd),spec.get('lParam',0x11223344)],strings=[],response=dict(result=spec.get('defaultResult',-123))))
            assert expected_events==c['events'] and modeled==local and expected_reads==c['reads'] and expected_seeks==len(c['seeks'])
            assert all(x['bytes']=='0000000000000000' and x['fpu']==fpu and x['returnPC']==0x401edc for x in c['seeks'])
            assert c['result']==spec.get('defaultResult',-123)&0xffffffff
        for e in c['events']:
            events[e['kind']]+=1
            if e['kind']=='method':methods[hex(e['arguments'][1])]+=1
        for x in c['helpers']:helpers[x['kind']]+=1;assert x['fpu']==fpu
        reads+=len(c['reads']);seeks+=len(c['seeks'])
        for i in c['instructions']:
            a=i['address'];data=bytes.fromhex(i['bytes']);o=pe.offset(a-pe.base);assert pe.data[o:o+len(data)]==data
            if a in pcs:assert pcs[a]==data
            pcs[a]=data
        previous=c['after']
    assert (callbacks,initializers,retained)==(371,4,5)
    for key,item in doc['blobs'].items():assert json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    cs=Cs(CS_ARCH_X86,CS_MODE_32);static={}
    for start,end in [(0x401c90,0x401d27),(0x401e90,0x401f21),(0x43b3d0,0x43bc41)]:
        o=pe.offset(start-pe.base)
        for i in cs.disasm(pe.data[o:o+end-start],start):static[i.address]=dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str)
    assert set(pcs)<=set(static)
    assert all(a in pcs for a in static if a<0x401f21)
    report=dict(scope=__doc__,rawSHA256=h(raw),rawBytes=len(raw),cases=375,wholeCallbacks=callbacks,graphInitializations=initializers,ownRetainedCalls=retained,blobs=len(blobs),events=dict(events),methodOffsets=dict(methods),eventCount=sum(events.values()),helpers=dict(helpers),helperCount=sum(helpers.values()),stores=dict(stores),storeCount=sum(stores.values()),storeBytes=store_bytes,localReads=reads,seeks=seeks,comparedStorageBytes=375*COUNT+callbacks*64,originalEXEPCs=len(pcs),wndProcPCs=sum(a>=0x43b3d0 for a in pcs),drainPCs=sum(0x401e90<=a<0x401f21 for a in pcs),initializerPCs=sum(0x401c90<=a<0x401d27 for a in pcs),DLLPCs=0,sourceFPU=fpu,allSeekPositiveZero=True,fullInstallerEqual=True,allAtomicCasesEqual=True,ownProducerInitiallyZero=True,sourceToolSHA256=w['sourceToolSHA256'],nativeCompared=False,windowsVerified=False,originalMemoryFaults=0)
    report['first8ProbeCasesUnchanged']=True
    # The union is an instruction inventory across separate controlled corpora,
    # not a complete callback router, Windows delivery or all branch outcomes.
    union={a for a in pcs if a>=0x43b3d0};parents={}
    for name in ('window-input','window-lifecycle'):
        prior_raw=(ROOT/('build/original/'+name+'.json')).read_bytes()
        evidence=json.loads((ROOT/('docs/evidence/'+name+'.json')).read_bytes())
        assert h(prior_raw)==evidence['rawSHA256'];parents[name]=h(prior_raw)
        for c in json.loads(prior_raw)['cases']:
            for i in c['instructions']:
                a=i['address']
                if 0x43b3d0<=a<0x43bc41:
                    assert static[a]['bytes']==i['bytes'];union.add(a)
    wnd={a for a in static if a>=0x43b3d0};missing=sorted(wnd-union)
    assert len(wnd)==576 and len(union)==568 and len(missing)==8
    report['combinedWndProcInventory']=dict(executed=568,staticStarts=576,missing=[static[a] for a in missing],parents=parents,allBranchOutcomes=False)
    if args.artifacts:
        f=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-graph-events.json';packed=f.read_bytes();env=json.loads(packed);d=zlib.decompressobj(-15);payload=d.decompress(base64.b64decode(env['deflate'],validate=True))+d.flush();assert d.eof and not d.unused_data
        assert payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==doc
        prior=json.loads((b/'graph-events-prior-pins.json').read_bytes());pins=json.loads((b/'graph-events-fixture-pins.json').read_bytes());assert set(pins)==set(prior)|{f.name}
        for n,digest in pins.items():assert h((f.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        dest=Path(w['isolatedPackage']).parent;export=json.loads((b/'graph-events-final-export-pins.json').read_bytes())
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=b/('graph-events-artifact-verification.json' if args.artifacts else 'graph-events-source-verification.json');target.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='scope'},indent=2))
if __name__=='__main__':main()
