#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Verify original NTSD exit payload, cleanup order and own client provenance.

Reconstruct declared inputs, every recorded read/semantic store, raw after bytes
and masks, actual cookie returns/PC bytes and retained state. The accepted client
verifier independently checks its own producer. No Windows/network execution.
"""
import argparse,base64,json,struct,zlib
from pathlib import Path
from collections import Counter
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from verify_network_client import h,decode,reconstruct,verify_client,BASE,COUNT
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
FRAME=0x2000eefc

def check_exit(c,blobs,initial,retained):
    s=c['spec'];before=bytearray(retained if s.get('retain') else initial)
    if not s.get('retain'):
        for a,v in [(0x44f1b4,s.get('listener',0x34560001)),(0x44f1b0,s.get('active',1)),(0x44f46c,0x34560003),(0x44f208,s.get('address',0x0100007f))]:struct.pack_into('<I',before,a-BASE,v)
        before[0x44f58c-BASE:0x44f59c-BASE]=bytes(s.get('sockaddr',[(i*13+7)&255 for i in range(16)]))
    local=bytearray(((FRAME&0xffff)+i)*s.get('seed',17)+0xa5 &255 for i in range(256))
    assert before==blobs[c['before']] and local==blobs[c['localBefore']]
    state=bytearray(before);actions=[];reads=[]
    def put(region,o,data):
        data=bytes(data);target=state if region=='globals' else local;target[o:o+len(data)]=data;actions.append(dict(kind='store',region=region,offset=o,bytes=list(data)))
    def read(pc,a,n):
        target,o=(state,a-BASE) if BASE<=a<BASE+COUNT else (local,a-FRAME);data=target[o:o+n];assert len(data)==n;reads.append(dict(pc=pc,address=a,bytes=data.hex()));return int.from_bytes(data,'little')
    def request(kind,arguments=(),payload=b'',result=0):actions.append(dict(kind='request',event=dict(kind=kind,arguments=list(arguments),bytes=list(payload),response=dict(result=result))))
    listener=read(0x402d85,0x44f1b4,4);send=False;failed=False;length=None
    if listener!=0 and read(0x402d93,0x44f1b0,4)!=0:
        send=True;put('local',0,bytes(256));literal=b'Client want to EXIT.';assert len(literal)==20
        for i in (0,8,12):put('local',i,literal[i:i+4])
        address={i:read(pc,0x44f208+i,1) for i,pc in [(0,0x402ddb),(2,0x402de6),(1,0x402dfb),(3,0x402e05)]}
        put('local',20,b'\0')
        for i in (4,16):put('local',i,literal[i:i+4])
        for i in (0,2,1,3):put('local',20+i,[address[i]])
        length=0
        while read(0x402e22,FRAME+length,1)!=0:length+=1
        assert 20<=length<=24
        sent=s.get('sendResult',length);request('sendTo',[listener,length,0,16],local[:length]+state[0x44f58c-BASE:0x44f59c-BASE],sent)
        failed=sent==-1
        if failed:request('message',[0,0],b'sendto()\0Error\0',s.get('messageResult',1))
        listener=read(0x402e5b if failed else 0x402e7c,0x44f1b4,4)
    request('closeSocket',[listener],result=s.get('closeResult',-1))
    if failed:result=s.get('closeResult',-1);ret=0x402e7b
    else:
        put('globals',0x44f1b4-BASE,bytes(4));put('globals',0x44f1b0-BASE,bytes(4));result=s.get('cleanupResult',0);request('cleanup',result=result);ret=0x402eb6
    assert c['actions']==actions and c['reads']==reads and c['result']==result&0xffffffff and c['returnPC']==ret
    final,flocal=reconstruct(c,blobs,FRAME);assert state==final and local==flocal
    assert c['sp']==0x2000f004 and c['frame']==FRAME and c['fpcw']==0x23f
    cookie=struct.unpack_from('<I',before,0x44eea4-BASE)[0];assert c['cookies']==[dict(value=cookie,expected=cookie)]
    assert [x['kind'] for x in c['helpers']]==['cookieCheck','exit'] and all(x['eax']==result&0xffffffff for x in c['helpers'])
    assert len(c['memsets'])==int(send)
    for m in c['memsets']:assert (m['address'],m['value'],m['count'])==(FRAME,0,256)
    return final,length

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();b=ROOT/'build/research';w=json.loads((b/'network-exit-work.json').read_bytes());path=ROOT/'build/original/network-exit.json';raw=path.read_bytes();d=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(d['cases'])==56 and len(d['clientParents'])==1 and not d['limited']
    assert h((ROOT/'tools/oracle_network_exit.py').read_bytes())==h((b/'network-exit-source.py').read_bytes())==w['sourceToolSHA256']
    probe=json.loads((b/'network-exit-probe1.json').read_bytes());assert d['cases'][:3]==probe['cases'] and all(d['blobs'][k]==v for k,v in probe['blobs'].items())
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();assert h(parent)==json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())['sha256'];assert d['parent']==json.loads(parent)['cases'][0]
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes());assert h(pe.data)==d['exeSHA256']==EXE_SHA256 and h(crt.data)==d['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d' and h((DEFAULT_SOURCE/'lib.dll').read_bytes())==d['libSHA256']
    initial=bytearray(COUNT)
    for s in pe.sections:
        start=pe.base+s['rva'];lo=max(BASE,start);hi=min(BASE+COUNT,start+s['fileSize'])
        if hi>lo:initial[lo-BASE:hi-BASE]=pe.data[s['fileOffset']+lo-start:s['fileOffset']+hi-start]
    for im in d['parent']['images']:
        if im['name']!='NTSD 2.4.exe':continue
        for c in im['changes']:
            a=c['address'];data=bytes.fromhex(c['after']);lo=max(a,BASE);hi=min(a+len(data),BASE+COUNT)
            if hi>lo:initial[lo-BASE:hi-BASE]=data[lo-a:hi-a]
    blobs=decode(d['blobs']);retained=None;lengths=Counter();parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['completed']==56
    for c in d['clientParents']:assert verify_client(c,blobs,initial)
    for c in d['cases']:
        saved=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(saved)==c
        if c['index']==55:assert h(saved)==checkpoint['lastCaseSHA256']
        if 'parentClient' in c['spec']:retained=blobs[d['clientParents'][c['spec']['parentClient']]['after']]
        retained,n=check_exit(c,blobs,initial,retained)
        if n is not None:lengths[n]+=1
    for key,item in d['blobs'].items():assert json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    pcs={};events=Counter();rawstores=Counter();rawbytes=semantics=sembytes=readcount=sendbytes=0
    for c in d['cases']+d['clientParents']:
        for i in c['instructions']+c.get('prefixInstructions',[]):
            a=i['address'];data=bytes.fromhex(i['bytes']);im=pe if a<0x70000000 else crt;o=im.offset(a-im.base);assert im.data[o:o+len(data)]==data;pcs[a]=data
        for e in c['events']:
            events[e['kind']]+=1
            if e['kind'] in ('sendTo','send'):sendbytes+=e['arguments'][1]
        for x in c['writes']:rawstores[x['origin']]+=1;rawbytes+=len(bytes.fromhex(x['bytes']))
        for x in c['actions']:
            if x['kind']=='store':semantics+=1;sembytes+=len(x['bytes'])
        readcount+=len(c['reads'])
    cs=Cs(CS_ARCH_X86,CS_MODE_32);o=pe.offset(0x402d70-pe.base);static=[dict(address=i.address,instruction=i.mnemonic+' '+i.op_str) for i in cs.disasm(pe.data[o:o+0x147],0x402d70)];missing=[i for i in static if i['address'] not in pcs]
    assert rawbytes==sembytes
    report=dict(scope=__doc__,rawSHA256=h(raw),rawBytes=len(raw),wholeExits=56,clientProducers=1,blobs=len(blobs),transmitLengths=dict(lengths),earlyErrorReturns=sum(c['returnPC']==0x402e7b for c in d['cases']),normalReturns=sum(c['returnPC']==0x402eb6 for c in d['cases']),events=dict(events),eventCount=sum(events.values()),sendBytes=sendbytes,semanticStores=semantics,semanticStoreBytes=sembytes,rawStores=dict(rawstores),rawStoreCount=sum(rawstores.values()),rawStoreBytes=rawbytes,reads=readcount,memsetCalls=sum(len(c['memsets']) for c in d['cases']),cookieChecks=sum(len(c['cookies']) for c in d['cases']),helperReturns=sum(len(c['helpers']) for c in d['cases']),originalEXEPCs=sum(a<0x70000000 for a in pcs),DLLPCs=sum(a>=0x70000000 for a in pcs),exitPCs=sum(0x402d70<=a<=0x402eb6 for a in pcs),exitStaticStarts=len(static),exitMissing=missing,comparedStorageBytes=56*(COUNT+256)+(COUNT+1024+2112),first3ProbeCasesUnchanged=True,fullInstallerEqual=True,ownClientBeforeReconstructed=True,declaredBeforeReconstructed=True,allAtomicCasesEqual=True,originalMemoryFaults=0,nativeCompared=False,windowsVerified=False)
    if args.artifacts:
        f=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-network-exit.json';packed=f.read_bytes();env=json.loads(packed);z=zlib.decompressobj(-15);payload=z.decompress(base64.b64decode(env['deflate'],validate=True))+z.flush();assert z.eof and not z.unused_data and payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==d
        prior=json.loads((b/'network-exit-prior-pins.json').read_bytes());pins=json.loads((b/'network-exit-fixture-pins.json').read_bytes());assert len(prior)==216 and set(pins)==set(prior)|{f.name}
        for n,digest in pins.items():assert h((f.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        dest=Path(w['isolatedPackage']).parent;export=json.loads((b/'network-exit-final-export-pins.json').read_bytes())
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=b/('network-exit-artifact-verification.json' if args.artifacts else 'network-exit-source-verification.json');target.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
