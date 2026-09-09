#!/usr/bin/env python3
"""Independently verify bundled-library source installation and text evidence.

Rebuild mapped images from pinned PE files and declared import bindings,
replay actual instruction writes plus explicit RtlMoveMemory effects, and
check complete image digests/differences. Verify installed text instructions,
ordered observations, retained storage and lossless artifacts separately from
native comparisons. No Windows loader/raster or full-game claim is inferred.
"""
import argparse,base64,hashlib,json,struct,zlib
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256,read_bytes
from inspect_original import PE
LIB_SHA256='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
digest=lambda b:hashlib.sha256(b).hexdigest()


def initial_images():
    images={};n=0
    for name,sha in [('NTSD 2.4.exe',EXE_SHA256),('lib.dll',LIB_SHA256)]:
        raw=read_bytes(DEFAULT_SOURCE/name);assert digest(raw)==sha;pe=PE(raw)
        size=(max(s['rva']+max(s['fileSize'],s['virtualSize']) for s in pe.sections)+4095)&~4095;data=bytearray(size);data[:pe.sections[0]['fileOffset']]=raw[:pe.sections[0]['fileOffset']]
        for s in pe.sections:data[s['rva']:s['rva']+s['fileSize']]=raw[s['fileOffset']:s['fileOffset']+s['fileSize']]
        for item in pe.imports():
            offset=int(item['iatVA'],16)-pe.base;data[offset:offset+4]=(0x30001000+16*n).to_bytes(4,'little');n+=1
        images[name]=(pe.base,bytes(data))
    return images


def validate_installation(doc,templates):
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']==LIB_SHA256 and len(doc['cases'])==7
    all_pcs=set();patch_bytes=0;attach_count=0
    for c in doc['cases']:
        after={name:bytearray(b) for name,(_,b) in templates.items()}
        def put(address,raw):
            matches=[name for name,(base,b) in templates.items() if base<=address and address+len(raw)<=base+len(b)];assert len(matches)==1
            name=matches[0];offset=address-templates[name][0];after[name][offset:offset+len(raw)]=raw
        for w in c['writes']:put(w['address'],w['value'].to_bytes(w['size'],'little'))
        for p in c['patches']:
            offset=p['address']-0x400000;assert templates['NTSD 2.4.exe'][1][offset:offset+p['count']].hex()==p['before'];payload=bytes.fromhex(p['after']);assert len(payload)==p['count'];put(p['address'],payload);patch_bytes+=len(payload)
        assert [e for e in c['events'] if e['kind']=='RtlMoveMemory']==[dict(kind='RtlMoveMemory',image='lib.dll',**p) for p in c['patches']]
        attaching=c['reason'] is None or c['reason']==1
        if attaching:
            attach_count+=1;assert len(c['patches'])==13 and [x['count'] for x in c['allocations']]==[4000,20000]
            assert len([e for e in c['events'] if e['kind']=='VirtualProtect'])==26
            assert sum(p['count'] for p in c['patches'])==62
            for e in c['events']:
                if e['kind']=='VirtualProtect':assert e['result']==1 and e['oldProtection'] in (0x20,0x40)
            if c['reason'] is None:
                assert c['end']==dict(pc=0x445565,sp=0x2000f000,eax=0x10000000,fpcw=0x37f)
                assert [e['kind'] for e in c['events'][:6]]==['GetSystemTimeAsFileTime','GetCurrentProcessId','GetCurrentThreadId','GetTickCount','QueryPerformanceCounter','LoadLibraryA']
                assert c['events'][5]['path']=='lib.dll' and c['events'][-1]['kind']=='dllReturn' and c['events'][-1]['result']==1
        else:assert not c['patches'] and not c['allocations'] and not c['writes'] and not c['events'] and c['end']['eax']==c['reason']
        for record in c['images']:
            name=record['name'];base,before=templates[name];actual=bytes(after[name]);assert record['base']==base and record['count']==len(before)
            assert record['beforeSHA256']==digest(before) and record['afterSHA256']==digest(actual)
            restored=bytearray(before);covered=0
            for x in record['changes']:
                offset=x['address']-base;a=bytes.fromhex(x['before']);b=bytes.fromhex(x['after']);assert len(a)==len(b) and restored[offset:offset+len(a)]==a and all(x!=y for x,y in zip(a,b));restored[offset:offset+len(a)]=b;covered+=len(a)
            assert bytes(restored)==actual
        for ins in c['instructions']:
            all_pcs.add(ins['address']);matches=[(base,b) for base,b in templates.values() if base<=ins['address']<base+len(b)];assert len(matches)==1;base,b=matches[0];raw=bytes.fromhex(ins['bytes']);assert b[ins['address']-base:ins['address']-base+len(raw)]==raw
    return dict(sourceInstallations=attach_count,wholeEntryRuns=3,notificationControls=4,patchesPerAttach=13,bytesPatchedPerAttach=62,totalPatchCopyBytes=patch_bytes,actualInitializationInstructionStarts=len(all_pcs),actualInitializationEXEStarts=sum(p<0x10000000 for p in all_pcs),actualInitializationDLLStarts=sum(p>=0x10000000 for p in all_pcs),fullMappedImagesVerified=True)


def validate_text(doc,templates,install):
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']==LIB_SHA256 and doc['installation']==install['cases'][0]
    assert len(doc['cases'])==276 and doc['retainedChain']==list(range(270,276));events=0;pcs=set();stores=0
    patched=bytearray(templates['NTSD 2.4.exe'][1]);p=next(p for p in doc['installation']['patches'] if p['address']==0x401290);patched[0x1290:0x1295]=bytes.fromhex(p['after'])
    previous=None
    for c in doc['cases']:
        assert bytes(c['input']).split(b'\0')[0]==bytes(c['text']) and c['result']==c['dcResult'];assert len(c['before'])==len(c['after'])==161
        before=bytes(c['before']);assert int.from_bytes(before[0x6e:0x72],'little')==c['retainedDC'];expected=bytearray(before)
        for w in c['writes']:
            assert w['pc']==0x100012bd and w['address']==0x1000306e and w['size']==4 and w['value']==c['dc'];expected[0x6e:0x72]=w['value'].to_bytes(4,'little');stores+=1
        assert bytes(expected)==bytes(c['after']) and int.from_bytes(expected[0x6e:0x72],'little')==c['retainedDCAfter']
        if c['index'] in doc['retainedChain']:
            if previous is not None:assert c['retainedDC']==previous
            previous=c['retainedDCAfter']
        kinds=[e['kind'] for e in c['events']]
        if c['dcResult']<0:assert kinds==['getDC'] and not c['writes']
        else:
            assert kinds==['getDC','setBackgroundMode','setTextColor','stringLength','textOut','releaseDC'] and len(c['writes'])==1
            assert c['events'][1]['arguments']==[c['dc'],1]
        events+=len(kinds);assert c['end']==dict(pc=0x30000000,sp=0x2000f004,fpcw=0x37f)
        for ins in c['instructions']:
            pc=ins['address'];b=patched if pc==0x401290 else templates['lib.dll'][1];base=0x400000 if pc==0x401290 else 0x10000000;raw=bytes.fromhex(ins['bytes']);assert b[pc-base:pc-base+len(raw)]==raw;pcs.add(pc)
    return dict(textCalls=276,retainedTextCalls=6,textEvents=events,retainedDCStores=stores,libraryDataBytesCompared=276*161,textInstructionStarts=len(pcs),textEXEStarts=sum(p<0x10000000 for p in pcs),textDLLStarts=sum(p>=0x10000000 for p in pcs),nativeWholeApplicationCompared=False,otherLibraryHooksCompared=False,windowsVerified=False)


def validate_static(install_raw,install):
    raw=(ROOT/'build/research/lib-runtime-static.json').read_bytes();doc=json.loads(raw)
    assert doc['exeSHA256']==EXE_SHA256 and doc['libSHA256']==LIB_SHA256 and doc['sourceInstallationSHA256']==digest(install_raw)
    assert doc['entry']==0x10001b62 and doc['preferredBase']==0x10000000 and len(doc['instructions'])==690 and len(doc['indirectTransfers'])==43
    lib=PE(read_bytes(DEFAULT_SOURCE/'lib.dll'));exe=PE(read_bytes(DEFAULT_SOURCE/'NTSD 2.4.exe'))
    for image,rows in [(lib,doc['instructions']),(exe,doc['loaderInstructions'])]:
        for ins in rows:
            offset=image.offset(ins['address']-image.base);code=bytes.fromhex(ins['bytes']);assert image.data[offset:offset+len(code)]==code
    for hook,p in zip(doc['hooks'],install['cases'][0]['patches']):
        assert hook['address']==p['address'] and hook['originalBytes']==p['before'] and hook['installedBytes']==p['after']
        code=bytes.fromhex(p['after']);target=p['address']+5+int.from_bytes(code[1:],'little',signed=True) if len(code)==5 else None
        assert hook['destination']==target
    assert len(doc['hooks'])==13 and doc['imports']==lib.imports()
    return raw


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--packaged',action='store_true');a=p.parse_args();templates=initial_images()
    raw_install=(ROOT/'build/original/lib-initialization.json').read_bytes();install=json.loads(raw_install)
    raw_text=(ROOT/'build/original/lib-surface-text.json').read_bytes();text=json.loads(raw_text)
    result=validate_installation(install,templates);result.update(validate_text(text,templates,install));static_raw=validate_static(raw_install,install)
    for name,raw in [('lib-initialization',raw_install),('lib-surface-text',raw_text)]:
        report=json.loads((ROOT/'build/research'/(name+'.json')).read_bytes());assert report['bytes']==len(raw) and report['sha256']==digest(raw)
    if a.packaged:
        report=json.loads((ROOT/'docs/evidence/lib-surface-text.json').read_bytes());assert report['nativeCompared']
        assert (ROOT/'docs/evidence/lib-runtime-static.json').read_bytes()==static_raw
        for name,raw in [('lib-initialization',raw_install),('lib-surface-text',raw_text)]:
            path=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+name+'.json');packed=path.read_bytes();wrapper=json.loads(packed);restored=zlib.decompress(base64.b64decode(wrapper['deflate']),-15)
            assert restored+b'\n'==raw and json.loads(restored)==json.loads(raw) and wrapper['count']==len(restored) and wrapper['sha256']==digest(restored)
            pin=json.loads((ROOT/'docs/evidence'/(name+'.json')).read_bytes());assert pin['fixtureBytes']==len(packed) and pin['fixtureSHA256']==digest(packed)
        prior=json.loads((ROOT/'build/research/lib-runtime-prior-pins.json').read_bytes());assert all(digest((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/name).read_bytes())==sha for name,sha in prior.items())
        vendor=ROOT/'native/Sources/NTSDReplayCodec';upstream=json.loads((vendor/'upstream.json').read_bytes())
        for name,pin in upstream['files'].items():assert digest((vendor/'vendor'/name).read_bytes())==pin['vendoredSHA256']
        result.update(priorPinsUnchanged=len(prior),vendorHashesVerified=len(upstream['files']),completeTransportBytesJSONAndSHAVerified=True)
    (ROOT/'build/research/lib-runtime-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
