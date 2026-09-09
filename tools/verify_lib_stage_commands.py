#!/usr/bin/env python3
"""Independent installation, source corpus and lossless artifact verification.

Native equivalence is established separately by the public Swift APIs and
full-state comparisons. This verifier preserves every prior fixture, checks
all HIGHLOW relocations, installed destinations, retained pristine results,
whole joined storage blobs and explicitly undefined BG99 perspective reads.
"""
import argparse,base64,hashlib,json,struct,zlib
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
LIB_SHA='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
NAMES=('lib-stage-commands','lib-match-preparation','lib-match-preparation-ramp')
digest=lambda b:hashlib.sha256(b).hexdigest()

def installation(item):
    assert item['libSHA256']==LIB_SHA and item['preferredBase']==0x10000000 and item['base']==0x36000000 and item['result']==1
    libraw=read_bytes(DEFAULT_SOURCE/'lib.dll');assert digest(libraw)==LIB_SHA;pe=PE(libraw);delta=item['base']-pe.base
    cursor,size=pe.directories[5];finish=cursor+size;rows=[]
    while cursor<finish:
        offset=pe.offset(cursor);page,length=struct.unpack_from('<II',libraw,offset);assert length>=8 and length%2==0
        for i in range(offset+8,offset+length,2):
            tag=struct.unpack_from('<H',libraw,i)[0]
            if tag>>12==0:continue
            assert tag>>12==3;where=page+(tag&0xfff);before=pe.u32(pe.offset(where));rows.append(dict(offset=where,before=before,after=(before+delta)&0xffffffff))
        cursor+=length
    assert cursor==finish and rows==item['relocations']
    pristine=json.loads((ROOT/'build/original/lib-initialization.json').read_bytes())['cases'][0]
    assert len(item['patches'])==13 and sum(p['count'] for p in item['patches'])==62
    for actual,old in zip(item['patches'],pristine['patches']):
        assert all(actual[k]==old[k] for k in ('address','count','before'))
        payload=bytes.fromhex(actual['after']);before=bytes.fromhex(old['after']);assert len(payload)==actual['count']
        if len(payload)==5:
            assert payload[0]==before[0]==0xe9
            assert (int.from_bytes(payload[1:],'little',signed=True)-int.from_bytes(before[1:],'little',signed=True))&0xffffffff==delta
        else:assert payload==before==b'\x90\x90'
    assert Counter(e['name'] for e in item['events'])==dict(VirtualAlloc=2,VirtualProtect=26,RtlMoveMemory=13)
    assert [a['count'] for a in item['allocations']]==[4000,20000]
    static={x['address'] for x in json.loads((ROOT/'docs/evidence/lib-runtime-static.json').read_bytes())['instructions']}
    assert all(p-delta in static for p in item['instructions'])
    return dict(relocations=len(rows),installerDLLStarts=len(item['instructions']),installedPatches=13,installedBytes=62)

def source(name,doc):
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']==LIB_SHA and not doc['nativeCompared'] and not doc['windowsVerified']
    result=installation(doc['installation']);assert doc['fpcw']==0x27f
    pcs=set(doc['instructions']);assert len(pcs)==len(doc['instructions'])
    if name=='lib-stage-commands':
        assert len(doc['cases'])==4330 and len(pcs)==573
        old=json.loads((ROOT/'build/original/postdraw-commands.json').read_bytes())
        for before,after in zip(old['cases'],doc['cases']):
            item=dict(after);item.pop('requestedID');reads=item.pop('requestedReads');assert before==item
        assert len(old['cases'])==3898
        for c in doc['cases']:
            assert c['endPC']==0x421a15
            for r in c['requestedReads']:
                assert r['access']==16 and r['size']==4 and r['address']==0x459ff8 and r['value']==c['requestedID']&0xffffffff
        events=Counter(e['kind'] for c in doc['cases'] for e in c['events']);assert sum(events.values())==6361
        result.update(cases=4330,retainedPristineWholeResults=3898,events=dict(events),helperReturns=sum(c['helpers'] for c in doc['cases']),requestedReads=sum(len(c['requestedReads']) for c in doc['cases']),actualEXEStarts=sum(p<0x36000000 for p in pcs),actualDLLStarts=sum(p>=0x36000000 for p in pcs))
    else:
        assert len(doc['cases'])==35 and len(pcs)==1094 and not doc['readsBeforeWrites']
        assert doc['initialRequestedID']==0x12345678 and doc['staged']['requestedID']==0x12345678
        assert doc['uninitializedPerspective']['background']==99 and doc['uninitializedPerspective']['bytes']=='a5a5a5a5'
        for r in doc['undefinedPerspectiveReads']:
            assert r['address']==doc['catalogAddress']+0x4d45db0+99*0x990+0xc and r['size']==4 and r['value']==0xa5a5a5a5 and r['pc'] in (0x36001b2e,0x36001b4f)
        cache={}
        for sha,b in doc['blobs'].items():
            raw=zlib.decompress(base64.b64decode(b['deflate']),-15);assert digest(raw)==sha and len(raw)==b['count'];cache[sha]=raw
        def check_record(r):
            raw,mask,initial=(cache[r[k]] for k in ('bytes','defined','initial'))
            assert len(raw)==len(mask)==len(initial) and set(mask)<={0,1} and all(flag or raw[i]==initial[i] for i,flag in enumerate(mask))
        def snapshot(s):
            assert len(s['actors'])==400 and len(s['backgrounds'])==101
            for r in [s['world'],*s['actors'],*s['backgrounds']]:check_record(r)
            assert len(cache[s['globals']])==0xb440
            r=s['backgrounds'][99];assert cache[r['bytes']][0xc:0x10]==b'\xa5'*4 and cache[r['defined']][0xc:0x10]==bytes(4)
        snapshot(doc['staged']);prior=doc['initialRequestedID']
        for c in doc['cases']:
            for s in (c['before'],c['after'],c['commands']['after']):snapshot(s)
            assert c['before']['requestedID']==prior and c['after']['requestedID']==c['commands']['after']['requestedID'];prior=c['after']['requestedID']
            for b in c['bitmaps']:check_record(b['storage'])
            writes=[r for r in c['libraryAccesses'] if r['write']]
            assert all(r['pc'] in (0x36001b35,0x36001b56) and r['size']==4 for r in writes)
            if writes:assert c['after']['requestedID']&0xffffffff==writes[-1]['value']
            else:assert c['after']['requestedID']==c['before']['requestedID']
            scratch=c['commands']['scratch'];written=[r for r in scratch if r['write']]
            assert not scratch or scratch[0]['write']
            assert c['commands']['retainedAfter']==(written[-1]['value'] if written else None)
            flags=cache[c['after']['globals']][0x450bb8-0x44d000:0x450bbc-0x44d000];before=cache[c['before']['globals']][0x450bb8-0x44d000:0x450bbc-0x44d000]
            assert flags==b'\3'+before[1:]
        events=Counter(e['kind'] for c in doc['cases'] for e in c['commands']['events'])
        assert events==dict(random=16,reconstruct=4)
        adapters={0x4450a0,0x4450ac,0x43ed10};assert adapters<=pcs
        result.update(cases=35,blobs=len(cache),undefinedPerspectiveReadEvents=len(doc['undefinedPerspectiveReads']),commandEvents=dict(events),commandHelperReturns=sum(c['commands']['helpers'] for c in doc['cases']),observedPCs=len(pcs),excludedAdapters=sorted(adapters),actualEXEStarts=sum(p<0x36000000 for p in pcs-adapters),actualDLLStarts=sum(p>=0x36000000 for p in pcs-adapters),libraryAccesses=sum(len(c['libraryAccesses']) for c in doc['cases']))
    return result

def verify(packaged=False):
    result={};fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures'
    for name in NAMES:
        raw=(ROOT/'build/original'/(name+'.json')).read_bytes();doc=json.loads(raw);report=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes())
        assert report['bytes']==len(raw) and report['sha256']==digest(raw)
        result[name]=dict(source(name,doc),rawBytes=len(raw),rawSHA256=digest(raw))
        if packaged:
            packed=(fixtures/('original-'+name+'.json')).read_bytes();wrapper=json.loads(packed);restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
            assert restored+b'\n'==raw and json.loads(restored)==doc and wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
            pin=json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes());assert pin['nativeCompared'] and pin['fixtureBytes']==len(packed) and pin['fixtureSHA256']==digest(packed)
            result[name].update(packedBytes=len(packed),packedSHA256=digest(packed))
    prior=json.loads((ROOT/'build/research/lib-stage-commands-prior-pins.json').read_bytes());assert all(digest((fixtures/name).read_bytes())==sha for name,sha in prior.items())
    vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
    for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
    result.update(priorFixturePinsUnchanged=len(prior),vendorHashesVerified=len(upstream['files']),packaged=packaged)
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--packaged',action='store_true');a=p.parse_args();r=verify(a.packaged)
    (ROOT/'build/research/lib-stage-commands-verification.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
