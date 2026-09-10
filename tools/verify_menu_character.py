#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify whole NTSD menu-character source compatibility evidence.

Rebuild PE/installer/Shift input globals, zero writes, exact ordered reads and
GetKeyState requests, AL and retained source EAX, actual PC bytes/returns. Native
compares caller-consumed AL; no Windows keyboard/layout/private ABI claim.
"""
import argparse,base64,hashlib,json,struct,zlib
from pathlib import Path
from collections import Counter
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
BASE,COUNT,SHIFT=0x44d000,0xb440,0x455388
h=lambda b:hashlib.sha256(b).hexdigest()

def check(c):
    s=c['spec'];k=s['key'];shift=s['shift'];events=[];cursor=0;eax=s.get('eax',0x12345678)&0xffffff00
    def sr(pc):events.append(dict(kind='shift',pc=pc,value=shift));return shift==100
    def caps(ret):
        nonlocal cursor,eax
        value=s['caps'][cursor];cursor+=1;events.append(dict(kind='keyState',argument=20,result=value,returnPC=ret));eax=value;v=value&0xffff;return v-65536 if v&0x8000 else v
    def convert():
        if k==32:return 32
        if 65<=k<=90:
            if sr(0x422f79) and caps(0x422f8c)==0:return k
            status=caps(0x422f95)
            if status<=0:return k+32
            return k+32 if sr(0x422f9e) else k
        if 96<=k<=105:return k-48
        if k in (107,109,106,111,110):return {107:43,109:45,106:42,111:47,110:46}[k]
        shifted=sr(0x423026)
        punctuation_keys=(189,187,219,221,186,222,220,188,190,191,192)
        punctuation=b'_+{}:"|<>?~' if shifted else b'-=[];\'\\,./`'
        if k in punctuation_keys:return punctuation[punctuation_keys.index(k)]
        if 48<=k<=57:return b')!@#$%^&*('[k-48] if shifted else k
        return {33:57,34:51,35:49,36:55,37:52,38:56,39:54,40:50,12:53,45:48}.get(k,0)
    byte=convert();assert c['events']==events and c['result']==byte and c['eax']==(eax&0xffffff00)|byte
    assert c['sp']==0x2000f004 and c['fpcw']==0x23f and c['saved']==[0x11223344,0x22334455,0x33445566,0x44556677]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');a=p.parse_args();b=ROOT/'build/research';w=json.loads((b/'menu-character-work.json').read_bytes());path=ROOT/'build/original/menu-character.json';raw=path.read_bytes();d=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(d['cases'])==10492 and not d['limited']
    assert h((ROOT/'tools/oracle_menu_character.py').read_bytes())==h((b/'menu-character-source.py').read_bytes())==w['sourceToolSHA256']
    probe=json.loads((b/'menu-character-probe1.json').read_bytes());assert d['cases'][:3]==probe['cases'] and all(d['blobs'][k]==v for k,v in probe['blobs'].items())
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();assert h(parent)==json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())['sha256'] and d['parent']==json.loads(parent)['cases'][0]
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());assert h(pe.data)==d['exeSHA256']==EXE_SHA256 and h((DEFAULT_SOURCE/'lib.dll').read_bytes())==d['libSHA256']
    initial=bytearray(COUNT)
    for s in pe.sections:
        start=pe.base+s['rva'];lo=max(BASE,start);hi=min(BASE+COUNT,start+s['fileSize'])
        if hi>lo:initial[lo-BASE:hi-BASE]=pe.data[s['fileOffset']+lo-start:s['fileOffset']+hi-start]
    for im in d['parent']['images']:
        if im['name']!='NTSD 2.4.exe':continue
        for c in im['changes']:
            address=c['address'];data=bytes.fromhex(c['after']);lo=max(address,BASE);hi=min(address+len(data),BASE+COUNT)
            if hi>lo:initial[lo-BASE:hi-BASE]=data[lo-address:hi-address]
    blobs={};parts=path.with_suffix('.parts')
    for key,item in d['blobs'].items():
        data=base64.b64decode(item['base64'],validate=True);assert len(data)==item['count'] and h(data)==key and json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item;blobs[key]=data
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs) and initial==blobs[d['initialGlobals']] and blobs[d['globalWritten']]==bytes(COUNT)
    checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['completed']==10492
    pcs={};events=Counter();kinds=Counter();results=Counter();call_counts=Counter()
    for c in d['cases']:
        check(c);before=bytearray(initial);before[SHIFT-BASE]=c['spec']['shift'];assert before==blobs[c['before']]==blobs[c['after']]
        saved=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(saved)==c
        if c['index']==10491:assert h(saved)==checkpoint['lastCaseSHA256']
        events.update(e['kind'] for e in c['events']);kinds[c['spec']['label']]+=1;results[c['result']]+=1;call_counts[sum(e['kind']=='keyState' for e in c['events'])]+=1
        for pc in c['instructions']:pcs[pc]=True
    assert set(pcs)=={i['address'] for i in d['instructions']}
    for i in d['instructions']:
        o=pe.offset(i['address']-pe.base);data=bytes.fromhex(i['bytes']);assert data==pe.data[o:o+len(data)]
    cs=Cs(CS_ARCH_X86,CS_MODE_32);o=pe.offset(0x422f60-pe.base);static=[dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str) for i in cs.disasm(pe.data[o:o+0x2c3],0x422f60)];missing=[i for i in static if i['address'] not in pcs]
    report=dict(scope=__doc__,rawSHA256=h(raw),rawBytes=len(raw),wholeCalls=10492,blobs=len(blobs),caseKinds=dict(kinds),events=dict(events),eventCount=sum(events.values()),keyboardCallCounts=dict(call_counts),resultBytes=len(results),globalBytesCompared=10492*COUNT,globalWrites=0,originalEXEPCs=len(pcs),DLLPCs=0,staticStarts=len(static),missing=missing,first3ProbeCasesUnchanged=True,fullInstallerEqual=True,declaredBeforeReconstructed=True,fullSourceEAXVerified=True,nativeCompared=False,nativeALOnly=True,windowsVerified=False,originalMemoryFaults=0)
    if a.artifacts:
        f=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-menu-character.json';packed=f.read_bytes();env=json.loads(packed);z=zlib.decompressobj(-15);payload=z.decompress(base64.b64decode(env['deflate'],validate=True))+z.flush();assert z.eof and not z.unused_data and payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==d
        prior=json.loads((b/'menu-character-prior-pins.json').read_bytes());pins=json.loads((b/'menu-character-fixture-pins.json').read_bytes());assert len(prior)==217 and set(pins)==set(prior)|{f.name}
        for n,digest in pins.items():assert h((f.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        export=json.loads((b/'menu-character-final-export-pins.json').read_bytes());dest=Path(w['isolatedPackage']).parent
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=b/('menu-character-artifact-verification.json' if a.artifacts else 'menu-character-source-verification.json');target.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
