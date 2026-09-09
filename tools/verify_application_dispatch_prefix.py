#!/usr/bin/env python3
"""Independently verify dispatcher prerequisites and their evidence transport.

Replay observed source stores, compare PE zero-fill provenance, and verify
complete bytes/masks/JSON/SHA. This does not execute the whole dispatcher,
its initialized World, the CRT initialization table, or a Windows device.
"""
import argparse
import base64
import hashlib
import json
import zlib
from import_ntsd import ROOT, DEFAULT_SOURCE, EXE_SHA256, read_bytes
from inspect_original import PE

digest=lambda b:hashlib.sha256(b).hexdigest()


def validate(doc):
    assert doc['exeSHA256']==EXE_SHA256 and doc['globalAddress']==0x44d000
    assert doc['globalSize']==0xc3a8 and doc['ordinaryGlobalSize']==0xb440
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    raw=read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe');assert digest(raw)==EXE_SHA256;pe=PE(raw)
    s=next(s for s in pe.sections if s['name']=='.data');assert pe.base+s['rva']==doc['globalAddress']
    image=raw[s['fileOffset']:s['fileOffset']+s['fileSize']]+bytes(s['virtualSize']-s['fileSize'])
    template=blobs[doc['globalTemplate']];assert template==image[:doc['globalSize']]
    audit=json.loads((ROOT/'build/research/application-dispatch-static.json').read_bytes())
    static=audit['instructions'];observed={k:set(v) for k,v in doc['instructions'].items()}
    assert audit['exeSHA256']==EXE_SHA256
    assert {k:len(v) for k,v in static.items()}==dict(clear=17,dispatcher=236,screenshot=26,staticWorldInitializer=2,worldConstructor=12)
    for rows in static.values():
        previous_end=None
        for row in rows:
            code=bytes.fromhex(row['bytes']);offset=pe.offset(row['address']-pe.base)
            assert raw[offset:offset+len(code)]==code
            assert previous_end is None or previous_end==row['address']
            previous_end=row['address']+len(code)
    embedded=audit['embeddedWorld'];world_offset=0x458b00-doc['globalAddress']
    assert embedded['address']==0x458b00 and embedded['extent']==0x7d8 and embedded['section']==s
    assert embedded['sectionOffset']==world_offset and world_offset>=s['fileSize']
    assert image[world_offset:world_offset+0x7d8]==bytes(0x7d8)
    assert embedded['initialBytesSHA256']==digest(bytes(0x7d8)) and embedded['initializerPointerLocations']==[0x4472d0]
    assert observed['keys']=={r['address'] for r in static['dispatcher'] if 0x43e9db<=r['address']<0x43ea95}
    assert observed['clear']=={r['address'] for r in static['clear']}
    assert observed['world']=={r['address'] for name in ('staticWorldInitializer','worldConstructor') for r in static[name]}
    assert [len(observed[k]) for k in ('keys','clear','world')]==[57,17,14]
    def put(data,address,value):
        offset=address-doc['globalAddress'];data[offset:offset+4]=(value&0xffffffff).to_bytes(4,'little')
    assert len(doc['keys'])==4348;stores=0;prefix_pcs=set()
    for index,c in enumerate(doc['keys']):
        assert c['index']==index and c['end']==dict(pc=0x43ea95,sp=0x1000f000) and c['fpcw']==0x23f
        before=bytearray(template);keys=blobs[c['keys']];assert len(keys)==300
        before[0x455378-0x44d000:0x455378-0x44d000+300]=keys
        for address,key in ((0x4593a4,'sequence'),(0x450bec,'enabled'),(0x4593a0,'mode')):put(before,address,c[key])
        assert bytes(before)==blobs[c['before']]
        expected=bytearray(before)
        for write in c['writes']:
            assert write['pc'] in (0x43ea4a,0x43ea50,0x43ea5f,0x43ea72,0x43ea85) and write['size']==4
            assert write['address'] in (0x450bec,0x4593a4,0x4593a0)
            put(expected,write['address'],write['value']);stores+=1
        assert bytes(expected)==blobs[c['after']]
        assert [w['pc'] for w in c['writes'][:2]]==[0x43ea4a,0x43ea50]
        for address,key in ((0x4593a4,'sequenceAfter'),(0x450bec,'enabledAfter'),(0x4593a0,'modeAfter')):
            assert int.from_bytes(expected[address-0x44d000:address-0x44d000+4],'little',signed=True)==c[key]
        prefix_pcs.update(c['instructions'])
    assert prefix_pcs==observed['keys']
    assert len(doc['clears'])==420;clear_pcs=set()
    for index,c in enumerate(doc['clears']):
        assert c['index']==index and c['end']==dict(pc=0x30000000,sp=0x1000f004) and c['fpcw']==0x23f
        expected=bytearray(c['backing']);assert len(expected)==100
        expected[:4]=(100).to_bytes(4,'little');expected[0x50:0x54]=c['color'].to_bytes(4,'little')
        mask=[int(i<4 or 0x50<=i<0x54) for i in range(100)]
        assert c['effectsAfter']==list(expected) and c['mask']==mask and c['result']==c['response']
        assert c['request']==dict(target=c['target'],flags=0x1000400,effects=list(expected),defined=[bool(x) for x in mask])
        clear_pcs.update(c['instructions'])
    assert clear_pcs==observed['clear']
    w=doc['staticWorld'];assert w['address']==0x458b00 and w['initializer']==0x446300 and w['pointerSlot']==0x4472d0
    assert w['end']==dict(pc=0x30000000,sp=0x1000f004) and w['fpcw']==0x23f
    assert pe.offset(w['pointerSlot']-pe.base)>=0
    offset=pe.offset(w['pointerSlot']-pe.base);assert int.from_bytes(raw[offset:offset+4],'little')==w['initializer']
    assert blobs[w['before']]==blobs[w['after']]==bytes(0x7d8)
    assert blobs[w['mask']]==bytes([1]*404+[0]*(0x7d8-404))
    assert w['writes']==[dict(pc=0x419e4e,address=0x458b00,size=4,value=0)]
    assert w['memset']==dict(entry=0x4450a0,address=0x458b04,count=400,value=0)
    assert set(w['instructions'])==observed['world']
    return dict(keyPrefixes=4348,keyStorageBytesCompared=4348*doc['globalSize'],sourceGlobalStores=stores,
        clearReturns=420,clearEffectsBytesCompared=420*100,retainedEffectBytesPerCall=92,
        instructionStarts={k:len(v) for k,v in observed.items()},blobs=len(blobs),
        staticInstructionStarts={k:len(v) for k,v in static.items()},
        staticWorldPEZeroFillVerified=True,staticWorldConstructorWrites=404,
        wholeApplicationDispatcherCompared=False,CRTStartupTableExecuted=False,ownInitializedApplicationCompared=False,windowsVerified=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--packaged',action='store_true');a=p.parse_args()
    raw=(ROOT/'build/original/application-dispatch-prefix.json').read_bytes();doc=json.loads(raw);result=validate(doc)
    report=json.loads((ROOT/'build/research/application-dispatch-prefix.json').read_bytes());assert report['bytes']==len(raw) and report['sha256']==digest(raw)
    if a.packaged:
        report=json.loads((ROOT/'docs/evidence/application-dispatch-prefix.json').read_bytes());assert report['nativeCompared']
        static_raw=(ROOT/'docs/evidence'/report['staticAudit']).read_bytes()
        assert digest(static_raw)==report['staticAuditSHA256']
        saved_audit=json.loads(static_raw);current_audit=json.loads((ROOT/'build/research/application-dispatch-static.json').read_bytes())
        for audit in (saved_audit,current_audit):audit.pop('updatedUTC',None)
        assert saved_audit==current_audit
        packed=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes();wrapper=json.loads(packed)
        restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
        assert restored+b'\n'==raw and json.loads(restored)==doc and wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
        assert report['fixtureSHA256']==digest(packed) and report['fixtureBytes']==len(packed)
        pins=json.loads((ROOT/'build/research/application-dispatch-prefix-prior-pins.json').read_bytes())
        assert all(digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/name).read_bytes())==sha for name,sha in pins.items())
        vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
        for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
        result.update(priorPinsUnchanged=len(pins),vendorHashesVerified=len(upstream['files']),fullRawAndPackedBytesEqual=True,completeJSONEqual=True)
    (ROOT/'build/research/application-dispatch-prefix-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))


if __name__=='__main__':main()
