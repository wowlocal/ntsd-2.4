#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Verify immutable controlled startup-storage and incomplete CRT evidence.

Read-only reconstruction checks exact original instruction bytes, complete
constructor bytes/masks, retained own state and the accepted whole installer.
CRT process attach stops at an unresolved Windows NLS boundary; this verifier
neither supplies that output nor counts it as a native/Windows success.
"""
import argparse,base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

def digest(b):return hashlib.sha256(b).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args()
    bp=ROOT/'build/research';raw=(ROOT/'build/original/startup-storage.json').read_bytes();doc=json.loads(raw)
    assert digest(raw)=='1d8551f96f8bc81591ef5aba24ab2333d8d89d590fc5b4a906f6b6834e1b91eb'
    parent_raw=(ROOT/'build/original/lib-initialization.json').read_bytes();pr=json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())
    assert digest(parent_raw)==pr['sha256'] and doc['parent']==json.loads(parent_raw)['cases'][0]
    exe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes())
    assert digest(exe.data)==EXE_SHA256==doc['exeSHA256'] and digest(crt.data)==doc['crtSHA256']
    cs=Cs(CS_ARCH_X86,CS_MODE_32);pcs={};stores=written=0
    for c in doc['cases']:
        before=bytes(c['before']);after=bytes(c['after']);mask=bytearray(doc['count']);rebuilt=bytearray(before)
        assert len(before)==len(after)==doc['count']==0x854
        for w in c['writes']:
            offset=w['address']-doc['base'];n=w['size'];payload=bytes.fromhex(w['bytes']);assert n==len(payload) and 0<=offset<offset+n<=len(before)
            rebuilt[offset:offset+n]=payload;mask[offset:offset+n]=b'\1'*n
        assert bytes(rebuilt)==after and list(mask)==c['writeMask']
        assert c['afterDefined']==[bool(a or b) for a,b in zip(c['beforeDefined'],mask)]
        assert c['entries']==[0x4462e0,0x4462f0,0x446300]
        assert [r['initializer'] for r in c['returns']]==c['entries'] and [r['eax'] for r in c['returns']]==[0x458440,0x458af8,0x458b00]
        assert c['fpcw']==0x37f and c['sp']==0x2000f004
        for i in c['instructions']:
            a=i['address'];payload=bytes.fromhex(i['bytes']);pe=exe if a<0x10000000 else crt;off=pe.offset(a-pe.base)
            assert pe.data[off:off+len(payload)]==payload
            decoded=list(cs.disasm(payload,a));assert len(decoded)==1 and decoded[0].size==len(payload)
            pcs[a]=dict(**i,instruction=decoded[0].mnemonic+' '+decoded[0].op_str)
        stores+=len(c['writes']);written+=sum(mask)
    for left,right in zip(doc['retainedChain'],doc['retainedChain'][1:]):
        assert doc['cases'][left]['after']==doc['cases'][right]['before'] and doc['cases'][left]['afterDefined']==doc['cases'][right]['beforeDefined']
    prefix_raw=(bp/'crt-startup-probe11.json').read_bytes();prefix=json.loads(prefix_raw)
    assert digest(prefix_raw)=='fe2617f95fd8f878ea2604daa6c6d7cb8af472c47329c336f69b4c5fc793ca58'
    assert prefix['phase']=='crtAttach' and not prefix['finished'] and prefix['initializers']==[] and prefix['patches']==[]
    last=prefix['events'][-1];assert last['kind']=='GetStringTypeW' and last['returnPC']==0x7813b3b5 and last['sourceBytes']=='0000' and last['arguments'][0:3:2]==[1,1]
    assert 'result' not in last and prefix['nativeCompared'] is prefix['windowsVerified'] is False
    for i in prefix['instructions']:
        payload=bytes.fromhex(i['bytes']);off=crt.offset(i['address']-crt.base);assert crt.data[off:off+len(payload)]==payload
        decoded=list(cs.disasm(payload,i['address']));assert len(decoded)==1 and decoded[0].size==len(payload)
    # The OS input pointer is produced by actual DLL store781321d9, not injected
    # into _acmdln. Its backing is a separately declared GetCommandLineA result.
    command=[e for e in prefix['events'] if e['kind']=='GetCommandLineA'];assert len(command)==1
    stores_cmd=[w for w in prefix['writes'] if w['address']==0x781c3b24];assert stores_cmd==[dict(address=0x781c3b24,pc=0x781321d9,size=4,value=command[0]['result'])]
    rejection_raw=(bp/'crt-startup-probe4.json').read_bytes();rejection=json.loads(rejection_raw)
    assert digest(rejection_raw)=='6afbc8c51606a5f49719eec4b677ec832994e561b68f08c1cf2c91ea01937b81'
    assert rejection['phase']=='crtRejected' and rejection['failure'] is None and rejection['initializers']==[] and rejection['events'][-1]['kind']=='HeapDestroy'
    for i in rejection['instructions']:
        payload=bytes.fromhex(i['bytes']);off=crt.offset(i['address']-crt.base);assert crt.data[off:off+len(payload)]==payload
    table=[]
    for address,count,kind in [(0x4472d8,4,'C'),(0x4472c0,6,'C++')]:
        off=exe.offset(address-exe.base);table.append(dict(kind=kind,address=address,pointers=list(struct.unpack('<'+'I'*count,exe.data[off:off+4*count]))))
    result=dict(rawSHA256=digest(raw),rawBytes=len(raw),cases=len(doc['cases']),storageBytes=len(doc['cases'])*doc['count'],stores=stores,writtenBytes=written,actualEXEPCs=sum(a<0x10000000 for a in pcs),actualCRTPCs=sum(a>=0x10000000 for a in pcs),callbacks=36,retainedCarries=3,wholeInstallerEqual=True,initializerTablesStatic=table,
        incompleteCRT=dict(rawSHA256=digest(prefix_raw),rawBytes=len(prefix_raw),actualCRTPCs=len(prefix['instructions']),apiEvents=len(prefix['events']),cpuStores=len(prefix['writes']),cpuStoreBytes=sum(w['size'] for w in prefix['writes']),boundary=last,commandLineProducer=stores_cmd[0]),
        rejectedCRT=dict(rawSHA256=digest(rejection_raw),rawBytes=len(rejection_raw),actualCRTPCs=len(rejection['instructions']),apiEvents=len(rejection['events'])),windowsVerified=False,fullCRTStartupCompared=False)
    (bp/'startup-storage-source-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.artifacts:
        checked=[]
        for name in ('startup-storage','crt-startup-prefix'):
            report=json.loads((ROOT/'docs/evidence'/f'{name}.json').read_bytes());original=(ROOT/'build/original'/report['corpus']).read_bytes()
            packed=(ROOT/'native/Tests/NTSDCoreTests/Fixtures'/report['fixture']).read_bytes();envelope=json.loads(packed);decoded=zlib.decompress(base64.b64decode(envelope['deflate']),-15)
            assert len(original)==report['rawBytes'] and digest(original)==report['rawSHA256'] and len(packed)==report['fixtureBytes'] and digest(packed)==report['fixtureSHA256']
            assert decoded+b'\n'==original and len(decoded)==envelope['count'] and digest(decoded)==envelope['sha256'] and json.loads(decoded)==json.loads(original)
            checked.append(dict(corpus=name,rawBytes=len(original),packedBytes=len(packed),rawSHA256=digest(original),packedSHA256=digest(packed)))
            if name=='crt-startup-prefix':
                for capture in json.loads(original)['captures']:
                    data=capture['rawJSON'].encode();assert data==(bp/capture['name']).read_bytes() and len(data)==capture['count'] and digest(data)==capture['sha256']
        fixtures=ROOT/'native/Tests/NTSDCoreTests/Fixtures';prior=json.loads((bp/'startup-storage-prior-pins.json').read_bytes());pins=json.loads((bp/'startup-storage-fixture-pins.json').read_bytes())
        assert all(pins[n]==h for n,h in prior.items())
        for n,h in pins.items():assert digest((fixtures/n).read_bytes())==h,n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,entry in vendor.items():assert digest((meta.parent/'vendor'/n).read_bytes())==entry['vendoredSHA256'],n
        work=json.loads((bp/'startup-storage-work.json').read_bytes());exported=Path(work['isolatedPackage']).parent;export_pins=json.loads((bp/'startup-storage-final-export-pins.json').read_bytes())
        for n,h in export_pins.items():assert digest((exported/n).read_bytes())==h,n
        for n in work['ownedNativeFiles']:assert digest((ROOT/n).read_bytes())==export_pins[n],n
        verification=dict(corpora=checked,embeddedCRTOriginalCaptures=2,priorUnchanged=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),exportFiles=len(export_pins),fullCRTStartupCompared=False,windowsVerified=False)
        (bp/'startup-storage-artifact-verification.json').write_text(json.dumps(verification,indent=2)+'\n');result['artifactVerification']=verification
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
