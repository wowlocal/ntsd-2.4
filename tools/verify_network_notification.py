#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Verify original NTSD handshake packets, live storage and bounded source traces.

Rebuild declared globals from PE/installer plus explicit inputs; independently
model packet/local reads and request/store order, compare raw CPU/API writes,
CRT memset, REP copy and unchanged cookie checks. This reads immutable artifacts;
it performs no network operation and is not Windows/peer/native evidence itself.
"""
import argparse,base64,hashlib,json,struct,zlib
from collections import Counter
from pathlib import Path
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
h=lambda b:hashlib.sha256(b).hexdigest()
BASE,COUNT=0x44d000,0xb440

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();b=ROOT/'build/research';w=json.loads((b/'network-notification-work.json').read_bytes());path=ROOT/'build/original/network-notification.json';raw=path.read_bytes();d=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(d['cases'])==415 and not d['limited']
    assert h((ROOT/'tools/oracle_network_notification.py').read_bytes())==h((b/'network-notification-source.py').read_bytes())==w['sourceToolSHA256']
    probe=json.loads((b/'network-notification-probe1.json').read_bytes());assert d['cases'][:8]==probe['cases'] and all(d['blobs'][k]==v for k,v in probe['blobs'].items())
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();assert h(parent)==json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())['sha256'];assert d['parent']==json.loads(parent)['cases'][0]
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes());assert h(pe.data)==d['exeSHA256']==EXE_SHA256 and h(crt.data)==d['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert h((DEFAULT_SOURCE/'lib.dll').read_bytes())==d['libSHA256']=='28d4f1b07992e058840bdac04d8ba44d6f037a248e29d962712bf44bcf90baba'
    initial=bytearray(COUNT)
    for s in pe.sections:
        start=pe.base+s['rva'];lo=max(BASE,start);hi=min(BASE+COUNT,start+s['fileSize'])
        if hi>lo:initial[lo-BASE:hi-BASE]=pe.data[s['fileOffset']+lo-start:s['fileOffset']+hi-start]
    for image in d['parent']['images']:
        if image['name']!='NTSD 2.4.exe':continue
        for change in image['changes']:
            a=change['address'];data=bytes.fromhex(change['after']);lo=max(a,BASE);hi=min(a+len(data),BASE+COUNT)
            if hi>lo:initial[lo-BASE:hi-BASE]=data[lo-a:hi-a]
    blobs={}
    for key,item in d['blobs'].items():
        data=base64.b64decode(item['base64'],validate=True);assert len(data)==item['count'] and h(data)==key;blobs[key]=data
    parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['completed']==415
    events=Counter();helpers=Counter();rawstores=Counter();semb=0;semn=0;rawb=0;reads=0;sendb=0;memsets=0;reps=0;accepted=0;failed=0;retained=0;pcs={};previous=None
    for c in d['cases']:
        saved=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(saved)==c
        if c['index']==414:assert h(saved)==checkpoint['lastCaseSHA256']
        spec=c['spec'];before=bytearray(initial)
        if spec.get('retain'):before=bytearray(previous);retained+=1
        else:
            for a,v in [(0x44f1b4,0x34560001),(0x44f46c,0x12340001)]+[(0x450b4c+4*i,100+i) for i in range(8)]:struct.pack_into('<I',before,a-BASE,v)
            before[0x44f1ae-BASE:0x44f1b0-BASE]=b'\x17\x21'
            names=bytes(spec.get('names',sum(([ord(str(i+1)),0]+[0xa5]*9 for i in range(8)),[])));assert len(names)==88;before[0x44fcc0-BASE:0x44fd18-BASE]=names
            before[0x44ff90-BASE:0x44ff90-BASE+3001]=bytes((i*17+21)&255 for i in range(3001))
        assert before==blobs[c['before']];assert c['frame']==0x2000ef3c and c['sp']==0x2000f014 and c['fpcw']==0x23f
        local=bytearray(((0xef3c+i)*spec.get('seed',17)+0xa5)&255 for i in range(160));assert local==blobs[c['localBefore']]
        # Raw instruction/API stores reconstruct both full regions and masks.
        rawg=bytearray(before);rawl=bytearray(local);gm=bytearray(COUNT);lm=bytearray(160)
        for s in c['writes']:
            data=bytes.fromhex(s['bytes']);region=s['region'];o=s['address']-(BASE if region=='globals' else c['frame']);target,mask=(rawg,gm) if region=='globals' else (rawl,lm)
            assert 0<=o<o+len(data)<=len(target);target[o:o+len(data)]=data;mask[o:o+len(data)]=b'\1'*len(data);rawstores[s['origin']]+=1;rawb+=len(data)
        assert rawg==blobs[c['after']] and rawl==blobs[c['localAfter']] and gm==blobs[c['globalWritten']] and lm==blobs[c['localWritten']]
        state=bytearray(before);actions=[];er=[]
        def put(region,o,data):
            data=bytes(data);target=state if region=='globals' else local;assert 0<=o<o+len(data)<=len(target);target[o:o+len(data)]=data;actions.append(dict(kind='store',region=region,offset=o,bytes=list(data)))
        def word(a):return struct.unpack_from('<I',state,a-BASE)[0]
        def putword(a,v):put('globals',a-BASE,struct.pack('<I',v&0xffffffff))
        def request(kind,arguments=(),payload=b'',result=0,output=None):
            response=dict(result=result)
            if output is not None:response['bytes']=list(output)
            event=dict(kind=kind,arguments=list(arguments),bytes=list(payload),response=response);actions.append(dict(kind='request',event=event))
        def message(text,caption):request('message',[0,0],text+b'\0'+caption+b'\0',spec.get('messageResult',1))
        def read(pc,a):
            value=state[a-BASE] if a>=BASE and a<BASE+COUNT else local[a-c['frame']];er.append(dict(pc=pc,address=a,bytes=bytes([value]).hex()));return value
        low=spec.get('lParam',8)&65535
        if low in (1,16,32):message({1:b'FD_READ',16:b'FD_CONNECT',32:b'FD_CLOSE'}[low],b'Handle Message')
        if low==8:
            listener=word(0x44f1b4);put('globals',0x44f1af-BASE,b'\2');result=spec.get('acceptResult',0x34560002);request('accept',[listener,0,0],result=result);putword(0x44f46c,result)
            if result==-1:
                failed+=1;message(b'Accpet() Error',b'Error')
                for a in (0x44f46c,0x44f1b4):request('closeSocket',[word(a)],result=spec.get('closeResult',-1))
            else:
                accepted+=1;request('closeSocket',[word(0x44f1b4)],result=spec.get('closeResult',-1));request('send',[word(0x44f46c),14,0],b'u can connect\0',spec.get('sendResult',14));put('local',0,bytes(77));request('sleep',[3000])
                received=bytes(spec.get('received',[]));assert len(received)<=77;request('receive',[word(0x44f46c),77,0],result=spec.get('receiveResult',len(received)),output=received)
                if received:put('local',0,received)
                request('sleep',[500]);template=b'1111'+b'0'*72+b'\0';o=pe.offset(0x4478b0-pe.base);assert pe.data[o:o+77]==template
                for i in range(0,76,4):put('local',0x50+i,template[i:i+4])
                put('local',0x9c,template[76:]);put('local',0x70,b'_'*45)
                for player in range(4):
                    i=0
                    while True:
                        value=read(0x402ff0,0x44fcc0+player*11+i);put('local',0x70+player*11+i,[value]);i+=1
                        if value==0:break
                for i in range(44):
                    if read(0x403006,c['frame']+0x70+i)==0:put('local',0x70+i,b'_')
                put('local',0x9c,b'\0');request('send',[word(0x44f46c),77,0],local[0x50:0x9d],spec.get('sendResult',77));request('sleep',[500]);request('send',[word(0x44f46c),3001,0],state[0x44ff90-BASE:0x44ff90-BASE+3001],spec.get('sendResult',3001))
                first=read(0x40305c,c['frame'])
                for i in range(4):putword(0x450b4c+i*4,i+1)
                if first==49:putword(0x450b4c,-1)
                for i,pc in enumerate((0x403091,0x40309d,0x4030a9,0x4030b5,0x4030c1,0x4030cd,0x4030d9),1):
                    if read(pc,c['frame']+i)==49:putword(0x450b4c+4*i,-1)
                for i in range(44):
                    value=read(0x4030f0,c['frame']+0x20+i);put('globals',0x44fcec-BASE+i,[value])
                    if value==95:put('globals',0x44fcec-BASE+i,b'\0')
                put('globals',0x44f1ae-BASE,b'\1')
                assert [(m['address']-c['frame'],m['value'],m['count']) for m in c['memsets']]==[(0,0,77),(0x70,95,45)];memsets+=2
                assert c['rep']['source']==0x4478b0 and c['rep']['destination']==c['frame']+0x50 and c['rep']['count']==19 and c['rep']['flags']&0x400==0 and bytes.fromhex(c['rep']['bytes'])==template[:76];reps+=1
        request('windowDefault',[spec.get('window',0x73000001),0x401,spec.get('wParam',0xabcdef12),spec.get('lParam',8)],result=spec.get('defaultResult',-123))
        assert actions==c['actions'] and er==c['reads'] and state==rawg and local==rawl
        assert c['events']==[a['event'] for a in actions if a['kind']=='request'] and c['result']==spec.get('defaultResult',-123)&0xffffffff
        assert len(c['cookies'])==1 and c['cookies'][0]['value']==c['cookies'][0]['expected']==word(0x44eea4)
        if not (low==8 and spec.get('acceptResult',0)!=-1):assert c['rep'] is None and not c['memsets']
        for e in c['events']:events[e['kind']]+=1;sendb+=len(e['bytes']) if e['kind']=='send' else 0
        for a in actions:
            if a['kind']=='store':semn+=1;semb+=len(a['bytes'])
        reads+=len(er)
        for x in c['helpers']:helpers[x['kind']]+=1
        for i in c['instructions']:
            a=i['address'];data=bytes.fromhex(i['bytes']);image=pe if a<0x70000000 else crt;o=image.offset(a-image.base);assert image.data[o:o+len(data)]==data
            if a in pcs:assert pcs[a]==data
            pcs[a]=data
        previous=state
    for key,item in d['blobs'].items():assert json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    cs=Cs(CS_ARCH_X86,CS_MODE_32);static={}
    for start,end in ((0x402ec0,0x40316f),(0x43b3d0,0x43bc41)):
        o=pe.offset(start-pe.base)
        for i in cs.disasm(pe.data[o:o+end-start],start):static[i.address]=dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str)
    union={a for a in pcs if 0x43b3d0<=a<0x43bc41};parents={}
    for name in ('window-input','window-lifecycle','graph-events'):
        prior_raw=(ROOT/('build/original/'+name+'.json')).read_bytes();e=json.loads((ROOT/('docs/evidence/'+name+'.json')).read_bytes());assert h(prior_raw)==e['rawSHA256'];parents[name]=h(prior_raw)
        for c in json.loads(prior_raw)['cases']:
            for i in c['instructions']:
                if 0x43b3d0<=i['address']<0x43bc41:assert static[i['address']]['bytes']==i['bytes'];union.add(i['address'])
    missing=[v for a,v in static.items() if a>=0x43b3d0 and a not in union];assert len(union)==574 and len(missing)==2
    report=dict(scope=__doc__,rawSHA256=h(raw),rawBytes=len(raw),cases=415,retainedCalls=retained,acceptedCalls=accepted,failedAcceptCalls=failed,blobs=len(blobs),events=dict(events),eventCount=sum(events.values()),sendBytes=sendb,semanticStores=semn,semanticStoreBytes=semb,rawStores=dict(rawstores),rawStoreCount=sum(rawstores.values()),rawStoreBytes=rawb,reads=reads,memsetCalls=memsets,completeREPs=reps,cookieChecks=415,helpers=dict(helpers),helperCount=sum(helpers.values()),comparedStorageBytes=415*(COUNT+160),originalEXEPCs=sum(a<0x70000000 for a in pcs),DLLPCs=sum(a>=0x70000000 for a in pcs),wndProcPCs=sum(0x43b3d0<=a<0x43bc41 for a in pcs),notificationPCs=sum(0x402ec0<=a<0x40316f for a in pcs),notificationMissing=[v for a,v in static.items() if a<0x40316f and a not in pcs],combinedWndProc=dict(executed=574,staticStarts=576,missing=missing,parents=parents,allBranchOutcomes=False),originalMemoryFaults=0,fullInstallerEqual=True,allAtomicCasesEqual=True,first8ProbeCasesUnchanged=True,declaredBeforeReconstructed=True,nativeCompared=False,windowsVerified=False)
    if args.artifacts:
        f=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-network-notification.json';packed=f.read_bytes();env=json.loads(packed);z=zlib.decompressobj(-15);payload=z.decompress(base64.b64decode(env['deflate'],validate=True))+z.flush();assert z.eof and not z.unused_data and payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==d
        prior=json.loads((b/'network-notification-prior-pins.json').read_bytes());pins=json.loads((b/'network-notification-fixture-pins.json').read_bytes());assert set(pins)==set(prior)|{f.name}
        for n,digest in pins.items():assert h((f.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        dest=Path(w['isolatedPackage']).parent;export=json.loads((b/'network-notification-final-export-pins.json').read_bytes())
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    target=b/('network-notification-artifact-verification.json' if args.artifacts else 'network-notification-source-verification.json');target.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='scope'},indent=2))
if __name__=='__main__':main()
