#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify whole original input callbacks and immutable journals.

Reconstruct full storage/written masks and allocation lifetime from actual
stores/API events; verify retained own outputs, original instruction bytes and
the unchanged installer parent. No Windows/native result is invented here.
"""
import argparse,base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

REGIONS=[(0x44d000,0xb440,'globals'),(0x458440,0x140,'local'),(0x4588a8,8,'pointers')]
digest=lambda b:hashlib.sha256(b).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--artifacts',action='store_true');args=parser.parse_args()
    research=ROOT/'build/research';work=json.loads((research/'window-input-work.json').read_text())
    path=ROOT/'build/original/window-input.json';raw=path.read_bytes();doc=json.loads(raw)
    assert digest(raw)==work['sourceRawSHA256'] and len(raw)==work['sourceBytes']
    assert digest((ROOT/'tools/oracle_window_input.py').read_bytes())==work['sourceToolSHA256']
    assert digest((research/'window-input-source.py').read_bytes())==work['sourceToolSHA256']
    assert not doc['limited'] and not doc['nativeCompared'] and not doc['windowsVerified']
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
    assert doc['parent']==json.loads((ROOT/'build/original/lib-initialization.json').read_bytes())['cases'][0]
    exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==EXE_SHA256;pe=PE(exe)
    blobs={}
    for h,item in doc['blobs'].items():
        packed=base64.b64decode(item['deflate'],validate=True);decoder=zlib.decompressobj();b=decoder.decompress(packed)+decoder.flush()
        assert decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail
        assert len(b)==item['count'] and digest(b)==h;blobs[h]=b
    previous=None;instructions={};events=Counter();helpers=Counter();stores=0;stored_bytes=0;compared_bytes=0;retained=0;callbacks=0;constructors=0
    aliases=[];own_aliases=[]
    parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes())
    assert checkpoint['incomplete'] and checkpoint['completed']==len(doc['cases'])==4372
    for index,c in enumerate(doc['cases']):
        spec=c['spec'];assert c['index']==index
        case_raw=(parts/('%06d.json'%index)).read_bytes();assert json.loads(case_raw)==c
        if index==len(doc['cases'])-1:assert digest(case_raw)==checkpoint['lastCaseSHA256']
        if spec.get('retain'):
            retained+=1;assert previous is not None
            for base,n,name in REGIONS:
                expected=bytearray(blobs[previous[name]])
                for address,value in spec.get('stimulus',[]):
                    if base<=address<base+n:expected[address-base:address-base+4]=struct.pack('<I',value&0xffffffff)
                assert bytes(expected)==blobs[c['before'][name]],(index,name,'retained own input')
            assert c['before']['allocations']==previous['allocations']
        snapshot={name:bytearray(blobs[c['before'][name]]) for _,_,name in REGIONS}
        masks=[bytearray(n) for _,n,_ in REGIONS]
        for base,n,name in REGIONS:assert len(snapshot[name])==n
        actions=[]
        for w in c['writes']:
            b=bytes.fromhex(w['bytes']);address=w['address'];matches=[]
            for region,(base,n,name) in enumerate(REGIONS):
                if base<=address and address+len(b)<=base+n:
                    offset=address-base;snapshot[name][offset:offset+len(b)]=b;masks[region][offset:offset+len(b)]=b'\1'*len(b);matches.append(region)
            assert len(matches)==1
            actions.append(dict(kind='store',address=address,bytes=list(b)));stores+=1;stored_bytes+=len(b)
            if address==0x458570 and b==b'\0' and w['pc']==0x40322b:
                aliases.append(index)
                if spec['label']=='own-text-key':own_aliases.append(index)
        assert [a for a in c['actions'] if a['kind']=='store']==actions
        assert [a['event'] for a in c['actions'] if a['kind']=='request']==c['events']
        assert len(c['actions'])==len(c['writes'])+len(c['events'])
        live={a['address']:a['live'] for a in c['before']['allocations']}
        for e in c['events']:
            events[e['kind']]+=1
            if e['kind']=='free':
                pointer=e['arguments'][0];assert live[pointer];live[pointer]=False
            if e['kind']=='postMessage':assert e['arguments']==[spec.get('window',0x72000001),0x10,0,0]
            if e['kind']=='message':assert e['arguments']==[spec.get('window',0x72000001),4] and e['strings']==[list(b'Are you sure to quit?'),list(b'LF2')]
            if e['kind']=='windowDefault':assert e['arguments']==[spec.get('window',0x72000001),spec['message'],spec.get('key',0),spec.get('lParam',0)]
        assert len(c['before']['allocations'])==len(c['after']['allocations'])
        for before,after in zip(c['before']['allocations'],c['after']['allocations']):
            assert after['live']==live[after['address']] and {k:v for k,v in before.items() if k!='live'}=={k:v for k,v in after.items() if k!='live'}
            assert len(blobs[after['bytes']])==after['count'];compared_bytes+=after['count']
        for i,(_,n,name) in enumerate(REGIONS):
            assert snapshot[name]==blobs[c['after'][name]] and masks[i]==blobs[c['writeMasks'][i]]
            compared_bytes+=n
        if spec.get('constructor'):
            constructors+=1;assert c['result']==0x458440 and c['sp']==0x2000f004
            assert [w['address'] for w in c['writes']]==[0x458440,0x458570,0x458574]
        else:
            callbacks+=1;assert c['sp']==0x2000f014
            expected=0 if spec['message']==0x100 and spec.get('key') in (27,0x90) else spec.get('defaultResult',spec.get('methodResult',0))&0xffffffff
            assert c['result']==expected,(index,'whole return')
        assert c['fpcw']==0x23f
        for h in c['helpers']:helpers[h['kind']]+=1
        for i in c['instructions']:
            address=i['address'];b=bytes.fromhex(i['bytes']);o=pe.offset(address-pe.base)
            assert exe[o:o+len(b)]==b and address not in (0x30000000,0x30006000)
            if address in instructions:assert instructions[address]==b
            instructions[address]=b
        previous=c['after']
    assert (callbacks,constructors,retained,stores)==(4369,3,385,23835)
    assert len(own_aliases)==2
    assert sum(events.values())==5908
    assert helpers['windowInput']==callbacks and helpers['textInitializer']==helpers['textConstructor']==3
    for h,item in doc['blobs'].items():assert json.loads((parts/'blobs'/(h+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    retained_text=[c for c in doc['cases'] if c['spec']['label']=='own-text-key']
    assert len(retained_text)==360
    assert struct.unpack_from('<I',blobs[retained_text[-1]['after']['local']],0x130)[0]==272
    assert struct.unpack_from('<I',blobs[retained_text[-1]['after']['local']],0x134)[0]==360
    # Correct the exploratory exclusive endpoint: ret16 at43bc3e is three
    # bytes. Keep that earlier incomplete inventory; this complete static
    # decode does not turn unselected WndProc messages into executed coverage.
    cs=Cs(CS_ARCH_X86,CS_MODE_32);start,end=0x43b3d0,0x43bc41;o=pe.offset(start-pe.base)
    static=list(cs.disasm(exe[o:o+end-start],start))
    assert static[-1].address==0x43bc3e and static[-1].bytes==b'\xc2\x10\0'
    assert sum(i.size for i in static)==end-start
    wnd_pcs={a for a in instructions if start<=a<end}
    assert wnd_pcs<={i.address for i in static}
    for i in static:
        if i.address in wnd_pcs:assert bytes(i.bytes)==instructions[i.address]
    (research/'window-callback-static-complete.txt').write_text(''.join('%08x %-20s %s %s\n'%(i.address,bytes(i.bytes).hex(),i.mnemonic,i.op_str) for i in static))
    report=dict(scope=__doc__,rawBytes=len(raw),rawSHA256=digest(raw),cases=len(doc['cases']),wholeInputCallbacks=callbacks,
                textConstructors=constructors,ownRetainedCalls=retained,blobs=len(blobs),events=dict(events),helpers=dict(helpers),
                originalPCs=len(instructions),wndProcPCs=sum(0x43b3d0<=a<=0x43bc40 for a in instructions),DLLPCs=0,
                sourceStores=stores,sourceStoreBytes=stored_bytes,comparedStorageBytes=compared_bytes,
                textIndexNULAliasCases=aliases,ownTextIndexNULAliasCases=own_aliases,
                sourceToolSHA256=work['sourceToolSHA256'],parentReproduced=True,atomicJournalVerified=True,
                windowsVerified=False,nativeCompared=False,originalMemoryFaults=0)
    report.update(wndProcStaticStarts=len(static),wndProcUnexecutedStatic=[i.address for i in static if i.address not in wnd_pcs],
                  fullWndProcMessagesCompared=False,staticInventorySHA256=digest((research/'window-callback-static-complete.txt').read_bytes()))
    if args.artifacts:
        fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-window-input.json';packed=fixture.read_bytes();transport=json.loads(packed)
        payload=zlib.decompress(base64.b64decode(transport['deflate'],validate=True),-15)
        assert len(payload)==transport['count'] and digest(payload)==transport['sha256'] and payload+b'\n'==raw and json.loads(payload)==doc
        prior=json.loads((research/'window-input-prior-pins.json').read_bytes())
        for n,h in prior.items():assert digest((fixture.parent/n).read_bytes())==h,n
        pins=json.loads((research/'window-input-fixture-pins.json').read_bytes())
        assert set(pins)==set(prior)|{fixture.name} and all(pins[n]==h for n,h in prior.items())
        for n,h in pins.items():assert digest((fixture.parent/n).read_bytes())==h,n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert digest((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        dest=Path(work['isolatedPackage']).parent;export=json.loads((research/'window-input-final-export-pins.json').read_bytes())
        for n,h in export.items():assert digest((dest/n).read_bytes())==h,n
        for n in work['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=digest(packed),unchangedPriorFixtures=len(prior),currentFixtures=len(pins),
                      vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=research/('window-input-artifact-verification.json' if args.artifacts else 'window-input-source-verification.json')
    target.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('textIndexNULAliasCases','scope','wndProcUnexecutedStatic')},indent=2))
if __name__=='__main__':main()
