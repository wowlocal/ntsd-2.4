#!/usr/bin/env python3
"""Independently reconstruct whole43e8e0 records, observed stores and transport.
Pinned EXE/Unicorn evidence has declared COM/debug callbacks and local backing;
this checks complete bytes and masks, not Windows output or full dispatch.
"""
import argparse,base64,hashlib,json,zlib
from pathlib import Path
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

digest=lambda b:hashlib.sha256(b).hexdigest()

def validate(path):
    raw=Path(path).read_bytes();d=json.loads(raw);assert d['exeSHA256']==EXE_SHA256
    blobs={}
    for k,b in d['blobs'].items():
        v=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(v)==b['count'] and digest(v)==k;blobs[k]=v
    exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(exe)==EXE_SHA256;pe=PE(exe)
    section=next(s for s in pe.sections if s['name']=='.data');image=exe[section['fileOffset']:section['fileOffset']+section['fileSize']]+bytes(section['virtualSize']-section['fileSize'])
    assert d['globalAddress']==0x44d000 and d['globalSize']==0xc3a8 and blobs[d['globalTemplate']]==image[:0xc3a8]
    static=json.load(open(ROOT/'docs/evidence/application-dispatch-static.json'))['instructions'];pcs=set()
    for key in ('screenshot','clear'):
        for r in static[key]:
            off=pe.offset(r['address']-pe.base);b=bytes.fromhex(r['bytes']);assert exe[off:off+len(b)]==b;pcs.add(r['address'])
    assert pcs==set(d['instructions']) and len(pcs)==43
    assert len(d['cases'])==231;stackbase=d['stackAddress'];assert stackbase==0x1000ef00
    allpcs=set();stores=api=0;previous=None
    for i,c in enumerate(d['cases']):
        s=c['spec'];assert s['index']==i;before=c['before'];after=c['after']
        if s['continued']:
            for k in ('globals','query','queryMask','clear','clearMask'):assert before[k]==previous[k],(i,k)
        else:
            g=bytearray(blobs[d['globalTemplate']])
            for address,v in ((0x455634,s['querySurface']),(0x455608,s['initialTarget'])):g[address-0x44d000:address-0x44d000+4]=v.to_bytes(4,'little')
            assert g==blobs[before['globals']];assert before['query']==s['queryBacking'] and before['clear']==s['clearBacking']
            assert not any(before['queryMask']) and not any(before['clearMask'])
        stack=bytearray(blobs[before['stack']]);g=bytearray(blobs[before['globals']]);qm=before['queryMask'].copy();cm=before['clearMask'].copy()
        assert len(stack)==272 and len(g)==0xc3a8
        events={e['storeCount']:e for e in c['events']};assert len(events)==3
        assert [e['kind'] for e in c['events']]==['query','clear','debug']
        def event(index):
            e=events.get(index)
            if e is None:return
            assert g==blobs[e['globals']]
            if e['kind']=='query':
                assert e['target']==int.from_bytes(g[0x8634:0x8638],'little') and e['response']==s['queryResult']
                assert e['bytes']==list(stack[224:256]) and e['defined']==[bool(x) for x in qm]
                assert stack[224:228]==(32).to_bytes(4,'little')
            elif e['kind']=='clear':
                assert e['target']==int.from_bytes(g[0x8608:0x860c],'little') and e['response']==s['clearResult'] and e['flags']==0x1000400
                assert e['bytes']==list(stack[112:212]) and e['defined']==[bool(x) for x in cm]
                assert stack[112:116]==(100).to_bytes(4,'little') and stack[192:196]==bytes(4)
            else:
                address=0x44a19c if s['clearResult']<0 else 0x44a180;off=pe.offset(address-pe.base)
                assert e['address']==address and e['bytes']==list(exe[off:].split(b'\0')[0]) and e['response']==s['debugResult']
        for n,w in enumerate(c['stores']):
            event(n);p=w['address'];b=bytes(w['bytes'])
            if stackbase<=p<p+len(b)<=stackbase+272:
                stack[p-stackbase:p-stackbase+len(b)]=b
                for addr,mask in ((0x1000efe0,qm),(0x1000ef70,cm)):
                    if addr<=p<p+len(b)<=addr+len(mask):mask[p-addr:p-addr+len(b)]=[1]*len(b)
            else:
                assert w['adapter'] and p==0x455608 and len(b)==4;g[p-0x44d000:p-0x44d000+4]=b
            if w['adapter']:assert w['pc'] in (0x30000110,0x30000100);api+=1
            else:assert w['pc'] in pcs;stores+=1
        event(len(c['stores']))
        assert stack==blobs[after['stack']] and g==blobs[after['globals']]
        assert after['query']==list(stack[224:256]) and after['queryMask']==qm
        assert after['clear']==list(stack[112:212]) and after['clearMask']==cm
        assert after['result']==int(s['clearResult']>=0) and after['sp']==0x1000f004 and after['pc']==0x30000000 and after['fpcw']==0x23f
        assert set(c['instructions'])<=pcs;allpcs.update(c['instructions']);previous=after
        part=json.loads(Path(path).with_suffix('.parts').joinpath(f'{i:04d}.json').read_bytes());assert part['case']==c
        for k,b in part['blobs'].items():assert d['blobs'][k]==b
    assert allpcs==pcs
    return dict(cases=231,independentCalls=225,retainedCalls=6,events=693,actualInstructionStarts=43,helperStarts=26,clearStarts=17,
        sourceStackStores=stores,adapterStores=api,globalBytesCompared=231*0xc3a8,queryBytesCompared=231*32,clearBytesCompared=231*100,
        blobs=len(blobs),atomicParts=231,bytes=len(raw),sha256=digest(raw),fullDispatcherCompared=False,windowsVerified=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--raw',required=True);p.add_argument('--packaged',action='store_true');a=p.parse_args()
    result=validate(a.raw);raw=Path(a.raw).read_bytes()
    fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';pins=json.load(open(ROOT/'build/research/application-art-setup-prior-pins.json'))
    for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
    result['priorPinsUnchanged']=len(pins)
    vendor=ROOT/'native/Sources/NTSDReplayCodec';up=json.load(open(vendor/'upstream.json'))
    for n,h in up['files'].items():assert digest((vendor/'vendor'/n).read_bytes())==h['vendoredSHA256']
    result['vendorHashesVerified']=len(up['files'])
    if a.packaged:
        path=fixtures/'original-application-art-setup.json';packed=path.read_bytes();w=json.loads(packed);restored=zlib.decompress(base64.b64decode(w['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw) and len(restored)==w['count'] and digest(restored)==w['sha256']
        evidence=json.load(open(ROOT/'docs/evidence/application-art-setup.json'))
        assert evidence['sha256']==digest(raw) and evidence['fixtureSHA256']==digest(packed)
        result.update(fullRawPackedBytesEqual=True,completeJSONEqual=True,fixtureBytes=len(packed),fixtureSHA256=digest(packed))
    (ROOT/'build/research/application-art-setup-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
