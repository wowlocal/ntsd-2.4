#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify whole controlled loading evidence and original bytes.

Decode the pinned EXE plus actual installed patches and relocated DLL image.
Rebuild all global/DC stores, full immutable resources, message records and
retained-call state. Verify every blob and actual PC inventory, separating
bypassed/alignment instructions from executed coverage. No source execution,
Windows/device output, expected-byte editing or native-fault reclassification.
"""
import base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE

digest=lambda b:hashlib.sha256(b).hexdigest()
def main():
    raw=(ROOT/'build/original/lib-loading.json').read_bytes();report=json.loads((ROOT/'build/research/lib-loading.json').read_bytes());doc=json.loads(raw)
    assert digest(raw)==report['sha256'] and len(raw)==report['bytes'] and doc['exeSHA256']==EXE_SHA256
    blobs={}
    for h,b in doc['blobs'].items():
        data=zlib.decompress(base64.b64decode(b['deflate']));assert len(data)==b['count'] and digest(data)==h;blobs[h]=data
    def word(b,p):return int.from_bytes(b[p:p+4],'little')
    original=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert digest(original)==EXE_SHA256;pe=PE(original);patched=bytearray(original)
    install=doc['installation'];assert len(install['relocations'])==76 and len(install['instructions'])==104 and len(install['patches'])==13
    assert Counter(e['name'] for e in install['events'])==dict(VirtualAlloc=2,VirtualProtect=26,RtlMoveMemory=13)
    for p in install['patches']:
        offset=pe.offset(p['address']-pe.base);assert original[offset:offset+p['count']].hex()==p['before'];patched[offset:offset+p['count']]=bytes.fromhex(p['after'])
    assert sum(p['count'] for p in install['patches'])==62
    lp=PE((DEFAULT_SOURCE/'lib.dll').read_bytes());assert digest(lp.data)==doc['libSHA256']
    mapped=bytearray(0x5000);mapped[:0x400]=lp.data[:0x400]
    for s in lp.sections:mapped[s['rva']:s['rva']+s['fileSize']]=lp.data[s['fileOffset']:s['fileOffset']+s['fileSize']]
    for r in install['relocations']:
        assert word(mapped,r['offset'])==r['before'];struct.pack_into('<I',mapped,r['offset'],r['after'])
    for n,i in enumerate(lp.imports()):struct.pack_into('<I',mapped,int(i['iatVA'],16)-lp.base,0x36010000+16*n)
    # Installer-generated jump scratch and allocated-pointer fields are already
    # proven by its accepted104-PC producer. All later changes must be DC-only.
    for offset,a in zip((0x3092,0x3096),install['allocations']):struct.pack_into('<I',mapped,offset,a['address'])
    last=install['patches'][-1];offset=last['source']-0x36000000
    assert offset==0x309c; mapped[offset:offset+last['count']]=bytes.fromhex(last['after'])
    prior_globals=None;prior_dc=None;events=Counter();pcs=set();writes=0;library_writes=0;labels=0;helpers=0;retained=0
    for c in doc['cases']:
        before=blobs[c['globals']];after=blobs[c['globalsAfter']];assert len(before)==len(after)==0xb440
        rebuilt=bytearray(before);mask=bytearray(len(before))
        for w in c['writes']:
            n=w['address']-0x44d000;s=w['size'];assert 0<=n<n+s<=len(before) and s in (1,2,4)
            rebuilt[n:n+s]=w['value'].to_bytes(s,'little');mask[n:n+s]=b'\1'*s
        assert bytes(rebuilt)==after and bytes(mask)==blobs[c['written']];writes+=len(c['writes'])
        lb=blobs[c['libraryBefore']];la=blobs[c['libraryAfter']];assert len(lb)==len(la)==0x5000
        assert all(a==b or 0x306e<=i<0x3072 for i,(a,b) in enumerate(zip(lb,mapped)))
        lr=bytearray(lb)
        for w in c['libraryWrites']:
            assert w['address']==0x3600306e and w['size']==4 and w['pc']==0x360012bd
            struct.pack_into('<I',lr,0x306e,w['value'])
        assert bytes(lr)==la;library_writes+=len(c['libraryWrites'])
        if c['spec'].get('chain'):
            if prior_globals is not None:
                for p in (0x4511c0,0x4511bc,0x4511b8,0x457580):assert word(before,p-0x44d000)==word(prior_globals,p-0x44d000)
                assert word(lb,0x306e)==prior_dc;retained+=1
            prior_globals=after;prior_dc=word(la,0x306e)
        for b in c['bitmaps']:assert len(blobs[b['bytes']])==len(blobs[b['defined']])==0x1f50 and set(blobs[b['defined']])<={0,1}
        for h in c['helpers']:assert h['returnSP']==h['sp']+4+h['pop']
        abi=c['abi'];assert abi['entrySP']==0x1000f000 and abi['returnSP']==0x1000f004 and abi['fpcw']==0x23f and abi['sw']==0 and abi['tag']==0xffff
        for h in c['labelEntries']:
            assert h['sp']==abi['entrySP']-16 and h['esi']==0x22003000 and h['stackArguments']==[0x25004920,0x22003000]
            assert h['phase']==(lambda n:-(abs(n)%10) if n<0 else n%10)((word(before,0x4511bc-0x44d000)+1+0x80000000)%0x100000000-0x80000000)
        for m in c['messageCalls']:assert m['pointer']==abi['entrySP']-28
        fills=[e['fill'] for e in c['events'] if e['kind']=='fill'];assert len(fills)==len(c['fillBacking'])
        for fill,backing in zip(fills,c['fillBacking']):
            expected=bytearray.fromhex(backing);struct.pack_into('<I',expected,0,100);struct.pack_into('<I',expected,80,0xffffff)
            assert bytes(expected)==bytes(fill['effects']) and fill['flags']==0x1000400
            assert fill['defined']==[n<4 or 80<=n<84 for n in range(100)]
        msg=[e for e in c['events'] if e['kind'] in ('PeekMessageA','GetMessageA','TranslateMessage','DispatchMessageA')]
        kinds=[e['kind'] for e in msg]
        if kinds:
            expected=['PeekMessageA']
            if c['spec'].get('peek',0):
                expected+=['GetMessageA']
                if c['spec'].get('get',0):expected+=['TranslateMessage','DispatchMessageA']
            assert kinds==expected
            for e in msg:
                if e['strings']:assert e['strings']==[list(bytes.fromhex(c['spec'].get('message','00112233445566778899aabbccddeeff102132435465768798a9bacb')))]
        assert len(c['labelEntries'])==(1 if msg else 0)
        events.update(e['kind'] for e in c['events']);pcs.update(c['instructions']);labels+=len(c['labelEntries']);helpers+=len(c['helpers'])
    assert pcs==set(doc['instructions']) and len(doc['cases'])==318 and retained==5
    decoder=Cs(CS_ARCH_X86,CS_MODE_32);decoded=[];at=pe.offset(0x4242e0-pe.base)
    for i in decoder.disasm(patched[at:at+0x3ce],0x4242e0):decoded.append(dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str))
    missing=[i for i in decoded if i['address'] not in pcs]
    assert len(decoded)==282 and len(missing)==29
    assert {i['address'] for i in missing if not 0x424357<=i['address']<0x4243b1}=={0x4243ed}
    static=json.loads((ROOT/'docs/evidence/lib-runtime-static.json').read_bytes())
    hook={i['address']-0x10000000+0x36000000 for i in static['instructions'] if 0x10001236<=i['address']<=0x10001309}
    assert hook<=pcs and len(hook)==76
    groups=dict(exe=sum(0x400000<=p<0x446500 for p in pcs),lib=sum(0x36000000<=p<0x36005000 for p in pcs),crt=sum(0x78130000<=p<0x78230000 for p in pcs))
    assert sum(groups.values())==len(pcs)
    crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes());assert digest(crt.data)==doc['crtSHA256']
    instruction_bytes={}
    for pc in sorted(pcs):
        if pc<0x446500:
            offset=pe.offset(pc-pe.base);code=patched[offset:offset+15]
        elif 0x36000000<=pc<0x36005000:code=mapped[pc-0x36000000:pc-0x36000000+15]
        else:
            offset=crt.offset(pc-crt.base);code=crt.data[offset:offset+15]
        ins=next(decoder.disasm(code,pc,count=1));assert ins.address==pc and ins.mnemonic not in ('int3','ud2')
        instruction_bytes[hex(pc)]=bytes(ins.bytes).hex()
    result=dict(rawBytes=len(raw),rawSHA256=digest(raw),cases=318,globalsBytes=318*0xb440,blobs=len(blobs),globalWrites=writes,libraryDCWrites=library_writes,
        labels=labels,retainedCarryCalls=retained,events=dict(events),totalEvents=sum(events.values()),helpers=helpers,instructions=groups,
        callerActual=253,callerStatic=282,callerBypassedOrAlignment=missing,libraryBodyStarts=76,
        pinnedBytesAtExecutedPCs=instruction_bytes,actualWindows=False)
    (ROOT/'build/research/lib-loading-source-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
