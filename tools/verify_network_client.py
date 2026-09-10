#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.7"]
# ///
"""Independently verify NTSD client action and source-peer packet provenance.

Rebuild declared PE/installer/prologue inputs, raw/semantic stores, actual reads,
greeting REPE and packet REP. Verify paired outputs feed the opposite peer,
without actual network operations or a whole-menu/Windows claim.
"""
import argparse,base64,hashlib,json,struct,zlib
from pathlib import Path
from collections import Counter
from capstone import Cs,CS_ARCH_X86,CS_MODE_32
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
h=lambda b:hashlib.sha256(b).hexdigest()
BASE,COUNT=0x44d000,0xb440
BODY,LOCAL,LC,WORLD,HOST,TARGET=0x2000e000,0x2000e014,0x400,0x32000000,0x33000000,0x34000000

def decode(items):
    out={}
    for key,item in items.items():
        data=base64.b64decode(item['base64'],validate=True);assert len(data)==item['count'] and h(data)==key;out[key]=data
    return out
def reconstruct(c,blobs,localbase):
    before=blobs[c['before']];old=blobs[c['localBefore']];state=bytearray(before);local=bytearray(old);gm=bytearray(len(state));lm=bytearray(len(local))
    for w in c['writes']:
        data=bytes.fromhex(w['bytes']);o=w['address']-(BASE if w['region']=='globals' else localbase);target,mask=(state,gm) if w['region']=='globals' else (local,lm)
        assert 0<=o<o+len(data)<=len(target);target[o:o+len(data)]=data;mask[o:o+len(data)]=b'\1'*len(data)
    assert state==blobs[c['after']] and local==blobs[c['localAfter']] and gm==blobs[c['globalWritten']] and lm==blobs[c['localWritten']]
    state=bytearray(before);local=bytearray(old);sg=bytearray(len(state));sl=bytearray(len(local))
    for a in c['actions']:
        if a['kind']!='store':continue
        data=bytes(a['bytes']);o=a['offset'];target,mask=(state,sg) if a['region']=='globals' else (local,sl);assert 0<=o<o+len(data)<=len(target);target[o:o+len(data)]=data;mask[o:o+len(data)]=b'\1'*len(data)
    assert state==blobs[c['after']] and local==blobs[c['localAfter']] and sg==gm and sl==lm
    assert c['events']==[a['event'] for a in c['actions'] if a['kind']=='request']
    return state,local

def verify_client(c,blobs,initial,peer_inputs=None):
    s=c['spec'];before=bytearray(initial)
    for a,v in [(0x44d068,0),(0x4511f8,1),(0x4511b0,s.get('pending',1)),(0x44d064,s.get('menu',3)),(0x44f1b4,0x34560001),(0x44f46c,0x34560000)]+[(0x450b4c+4*i,100+i) for i in range(8)]:struct.pack_into('<I',before,a-BASE,v)
    names=bytes(s.get('names',sum(([ord(str(i+1)),0]+[0xa5]*9 for i in range(8)),[])));assert len(names)==88;before[0x44fcc0-BASE:0x44fd18-BASE]=names
    before[0x44ff90-BASE:0x44ff90-BASE+3001]=bytes((i*17+21)&255 for i in range(3001));assert before==blobs[c['before']]
    world=bytearray((i*31+21)&255 for i in range(0x840));struct.pack_into('<I',world,0,0);hostname=bytes(s.get('hostname',b'127.0.0.1'));world[0x7d8:0x7d8+len(hostname)+1]=hostname+b'\0';assert world==blobs[c['world']]
    local=bytearray(((0xe014+i)*s.get('seed',17)+0xa5)&255 for i in range(LC));struct.pack_into('<I',local,4,WORLD);struct.pack_into('<I',local,12,TARGET);assert local==blobs[c['localBefore']]
    assert c['sp']==BODY and c['ebp']==19 and c['fpcw']==0x23f
    final,flocal=reconstruct(c,blobs,LOCAL);state=bytearray(before);actions=[];reads=[];receive_index=0;matched=False;comparison=None
    def put(region,o,data):
        data=bytes(data);t=state if region=='globals' else local;assert 0<=o<o+len(data)<=len(t);t[o:o+len(data)]=data;actions.append(dict(kind='store',region=region,offset=o,bytes=list(data)))
    def word(a):return struct.unpack_from('<I',state,a-BASE)[0]
    def putword(a,v):put('globals',a-BASE,struct.pack('<I',v&0xffffffff))
    def request(kind,arguments=(),payload=b'',result=0,output=None,address=None):
        r=dict(result=result)
        if output is not None:r['bytes']=list(output)
        if address is not None:r['hostAddress']=address
        actions.append(dict(kind='request',event=dict(kind=kind,arguments=list(arguments),bytes=list(payload),response=r)))
    def message(text,caption):request('message',[0,0],text+b'\0'+caption+b'\0',s.get('messageResult',1))
    def read(pc,a,n=1,raw=None):
        data=bytes(raw) if raw is not None else bytes(state[a-BASE:a-BASE+n] if BASE<=a<BASE+COUNT else local[a-LOCAL:a-LOCAL+n]);assert len(data)==n;reads.append(dict(pc=pc,address=a,bytes=data.hex()));return int.from_bytes(data,'little')
    def receive(count,region,o):
        nonlocal receive_index
        r=s['receives'][receive_index] if peer_inputs is None else dict(bytes=peer_inputs[receive_index],result=len(peer_inputs[receive_index]));receive_index+=1;payload=bytes(r['bytes']);assert len(payload)<=count
        request('receive',[word(0x44f46c),count,0],result=r['result'],output=payload)
        if payload:put(region,o,payload)
    def run():
        nonlocal matched,comparison
        if word(0x4511b0)!=1:return 0x42873e
        old=word(0x44f46c);putword(0x4511b0,0);request('closeSocket',[old],result=s.get('closeResult',-1))
        socket=s.get('socketResult',0x34560003);request('socket',[2,1,6],result=socket);putword(0x44f46c,socket)
        if socket==-1:message(b'socket()',b'Client Error');return 0x4287de
        assert read(0x42846b,BODY+0x18,4)==WORLD
        host=HOST if s.get('hostSuccess',True) else 0;address=s.get('hostAddress',0x0100007f);request('hostLookup',payload=hostname,result=host,address=address);putword(0x44f2d4,host)
        if host==0:
            v=s.get('addressWordResult',0x0100007f);request('addressWord',payload=hostname,result=v);put('local',0,struct.pack('<I',v&0xffffffff))
            host=HOST if s.get('fallbackSuccess',True) else 0;request('hostByAddress',[4,2],local[:4],host,address=address);putword(0x44f2d4,host)
            if host==0:message(b"Can't get the Server",b'Error');putword(0x44d064,1);return 0x42873e
        if word(0x44d064)==1:return 0x42873e
        put('globals',0x44f58c-BASE,b'\2\0')
        for pc,a,v in [(0x4284dc,HOST+12,HOST+0x100),(0x4284df,HOST+0x100,HOST+0x200),(0x4284e1,HOST+0x200,address)]:read(pc,a,4,struct.pack('<I',v))
        putword(0x44f590,address);request('htons',[12345],result=0x3930);put('globals',0x44f58e-BASE,b'09')
        connected=s.get('connectResult',0);request('connect',[word(0x44f46c),16],state[0x44f58c-BASE:0x44f59c-BASE],connected)
        if connected==-1:message(b"Can't connect to server",b'Error');request('closeSocket',[word(0x44f1b4)],result=s.get('closeResult',-1));putword(0x44d064,1);return 0x4287de
        receive(100,'local',0x270);count=0;equal=True
        for i,value in enumerate(b'u can connect\0'):
            count+=1
            if read(0x428566,BODY+0x284+i)!=value:equal=False;break
        comparison=(count,equal)
        if not equal:read(0x42873a,BODY+0x20,4);return 0x42873e
        matched=True;template=b'00001111'+b'0'*68+b'\0'
        for i in range(0,76,4):put('local',0x90+i,template[i:i+4])
        for i in range(4):putword(0x450b5c+4*i,i+1)
        put('local',0xdc,b'\0');put('local',0xb0,b'_'*45)
        for player in range(4):
            i=0
            while True:
                value=read(0x4285d2,0x44fcc0+player*11+i);put('globals',0x44fcec-BASE+player*11+i,[value]);i+=1
                if value==0:break
            i=0
            while True:
                value=read(0x4285f0,0x44fcc0+player*11+i);put('local',0xb0+player*11+i,[value]);i+=1
                if value==0:break
        for i in range(44):
            if read(0x428606,BODY+0xc4+i)==0:put('local',0xb0+i,b'_')
        put('local',0xdc,b'\0');put('globals',0x44f1af-BASE,b'\1');request('send',[word(0x44f46c),77,0],local[0x90:0xdd],s.get('sendResult',77))
        request('sleep',[500]);receive(77,'local',0xf4);request('sleep',[500]);receive(3001,'globals',0x44ff90-BASE)
        for i,pc in enumerate((0x428687,0x428696,0x4286a5,0x4286b4,0x4286c3,0x4286d2,0x4286e1,0x4286f0)):
            if read(pc,BODY+0x108+i)==49:putword(0x450b4c+4*i,-1)
        for i in range(44):
            value=read(0x428710,BODY+0x128+i);put('globals',0x44fcc0-BASE+i,[value])
            if value==95:put('globals',0x44fcc0-BASE+i,b'\0')
        putword(0x44d064,4);read(0x42873a,BODY+0x20,4);return 0x42873e
    assert run()==c['endPC'] and actions==c['actions'] and reads==c['reads'] and state==final and local==flocal
    if comparison:
        n,equal=comparison;q=c['compare'];assert q['count']==14 and q['remaining']==14-n and q['first']==BODY+0x284 and q['firstAfter']==q['first']+n and q['second']==0x447900 and q['secondAfter']==0x447900+n and bool(q['flags']&0x40)==equal
    else:assert c['compare'] is None
    if matched:
        assert len(c['memsets'])==1 and (c['memsets'][0]['address'],c['memsets'][0]['value'],c['memsets'][0]['count'])==(BODY+0xc4,95,45)
        assert c['rep']['source']==0x449788 and c['rep']['destination']==BODY+0xa4 and c['rep']['count']==19 and c['rep']['flags']&0x400==0 and bytes.fromhex(c['rep']['bytes'])==b'00001111'+b'0'*68
    else:assert not c['memsets'] and c['rep'] is None
    return matched

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifacts',action='store_true');args=p.parse_args();b=ROOT/'build/research';w=json.loads((b/'network-client-work.json').read_bytes());path=ROOT/'build/original/network-client.json';raw=path.read_bytes();d=json.loads(raw)
    assert h(raw)==w['sourceRawSHA256'] and len(raw)==w['sourceBytes'] and len(d['cases'])==392 and len(d['pairs'])==1 and not d['limited']
    assert h((ROOT/'tools/oracle_network_client.py').read_bytes())==h((b/'network-client-source.py').read_bytes())==w['sourceToolSHA256']
    probe=json.loads((b/'network-client-probe1.json').read_bytes());assert d['cases'][:6]==probe['cases'] and all(d['blobs'][k]==v for k,v in probe['blobs'].items());assert d['pairs'][0]==json.loads((b/'network-client-peer-probe1.json').read_bytes())
    parent=(ROOT/'build/original/lib-initialization.json').read_bytes();assert h(parent)==json.loads((ROOT/'docs/evidence/lib-initialization.json').read_bytes())['sha256'];assert d['parent']==json.loads(parent)['cases'][0]
    pe=PE((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes());crt=PE((ROOT/'build/original/crt/msvcr80.dll').read_bytes());assert h(pe.data)==d['exeSHA256']==EXE_SHA256 and h(crt.data)==d['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d';assert h((DEFAULT_SOURCE/'lib.dll').read_bytes())==d['libSHA256']
    initial=bytearray(COUNT)
    for s in pe.sections:
        start=pe.base+s['rva'];lo=max(BASE,start);hi=min(BASE+COUNT,start+s['fileSize'])
        if hi>lo:initial[lo-BASE:hi-BASE]=pe.data[s['fileOffset']+lo-start:s['fileOffset']+hi-start]
    for image in d['parent']['images']:
        if image['name']!='NTSD 2.4.exe':continue
        for change in image['changes']:
            a=change['address'];data=bytes.fromhex(change['after']);lo=max(a,BASE);hi=min(a+len(data),BASE+COUNT)
            if hi>lo:initial[lo-BASE:hi-BASE]=data[lo-a:hi-a]
    blobs=decode(d['blobs']);parts=path.with_suffix('.parts');checkpoint=json.loads(path.with_suffix('.incomplete.json').read_bytes());assert checkpoint['completed']==392;all_cases=[];success=0
    for c in d['cases']:
        saved=(parts/('%06d.json'%c['index'])).read_bytes();assert json.loads(saved)==c
        if c['index']==391:assert h(saved)==checkpoint['lastCaseSHA256']
        success+=verify_client(c,blobs,initial);all_cases.append(('client',c))
    for key,item in d['blobs'].items():assert json.loads((parts/'blobs'/(key+'.json')).read_bytes())==item
    assert len(list((parts/'blobs').glob('*.json')))==len(blobs)
    pair=d['pairs'][0];cb=decode(pair['clientBlobs']);sb=decode(pair['serverBlobs']);server_packets=[e['bytes'] for e in pair['server']['events'] if e['kind']=='send'];client_packets=[e['bytes'] for e in pair['client']['events'] if e['kind']=='send']
    assert [len(x) for x in server_packets]==[14,77,3001] and [len(x) for x in client_packets]==[77]
    assert [e['response']['bytes'] for e in pair['client']['events'] if e['kind']=='receive']==server_packets and [e['response']['bytes'] for e in pair['server']['events'] if e['kind']=='receive']==client_packets
    assert pair['deliveries']==[dict(sender='server',bytes=server_packets[0]),dict(sender='client',bytes=client_packets[0]),dict(sender='server',bytes=server_packets[1]),dict(sender='server',bytes=server_packets[2])]
    assert verify_client(pair['client'],cb,initial,server_packets);reconstruct(pair['server'],sb,pair['server']['frame']);all_cases.extend([('client',pair['client']),('server',pair['server'])])
    for client,server in [(cb[pair['client']['after']],sb[pair['server']['after']])]:
        assert client[0x44ff90-BASE:0x44ff90-BASE+3001]==server[0x44ff90-BASE:0x44ff90-BASE+3001]
        # Each peer decodes received underscores only. Own name bytes retain
        # underscores, so the two complete banks intentionally differ here.
        decode_names=lambda packet:bytes(0 if x==95 else x for x in packet[32:76])
        client_own=bytes(pair['client']['spec']['names'][:44]);server_own=bytes(pair['server']['spec']['names'][:44])
        assert client[0x44fcc0-BASE:0x44fd18-BASE]==decode_names(server_packets[1])+client_own
        assert server[0x44fcc0-BASE:0x44fd18-BASE]==server_own+decode_names(client_packets[0])
    pcs={};prefix={};events=Counter();rawstores=Counter();rawbytes=semantics=sembytes=readcount=sendbytes=memsets=reps=compares=0;exits=Counter()
    for role,c in all_cases:
        for i in c.get('prefixInstructions',[]):
            a=i['address'];data=bytes.fromhex(i['bytes']);o=pe.offset(a-pe.base);assert pe.data[o:o+len(data)]==data;prefix[a]=data
        for i in c['instructions']:
            a=i['address'];data=bytes.fromhex(i['bytes']);image=pe if a<0x70000000 else crt;o=image.offset(a-image.base);assert image.data[o:o+len(data)]==data
            if a in pcs:assert pcs[a]==data
            pcs[a]=data
        for e in c['events']:events[e['kind']]+=1;sendbytes+=len(e['bytes']) if e['kind']=='send' else 0
        for x in c['writes']:rawstores[x['origin']]+=1;rawbytes+=len(bytes.fromhex(x['bytes']))
        for a in c['actions']:
            if a['kind']=='store':semantics+=1;sembytes+=len(a['bytes'])
        readcount+=len(c['reads']);memsets+=len(c['memsets']);reps+=c['rep'] is not None;compares+=c.get('compare') is not None
        if role=='client':exits[hex(c['endPC'])]+=1
    cs=Cs(CS_ARCH_X86,CS_MODE_32);o=pe.offset(0x428420-pe.base);static=[dict(address=i.address,bytes=bytes(i.bytes).hex(),instruction=i.mnemonic+' '+i.op_str) for i in cs.disasm(pe.data[o:o+0x31e],0x428420)];missing=[i for i in static if i['address'] not in pcs]
    assert len(prefix)==34 and rawbytes==sembytes
    report=dict(scope=__doc__,rawSHA256=h(raw),rawBytes=len(raw),standaloneClients=392,standaloneHandshakeSuccesses=success,pairedClients=1,pairedServers=1,peerDeliveries=4,peerBytes=3169,blobs=len(blobs),pairClientBlobs=len(cb),pairServerBlobs=len(sb),events=dict(events),eventCount=sum(events.values()),sendBytes=sendbytes,semanticStores=semantics,semanticStoreBytes=sembytes,rawStores=dict(rawstores),rawStoreCount=sum(rawstores.values()),rawStoreBytes=rawbytes,reads=readcount,memsetCalls=memsets,completeREPs=reps,greetingComparisons=compares,exits=dict(exits),prologuePCs=len(prefix),originalEXEPCs=sum(a<0x70000000 for a in pcs),DLLPCs=sum(a>=0x70000000 for a in pcs),clientPCs=sum(0x428420<=a<0x42873e for a in pcs),clientStaticStarts=len(static),clientMissing=missing,comparedStorageBytes=393*(COUNT+LC+0x840)+COUNT+160,first6ProbeCasesUnchanged=True,peerProbeUnchanged=True,fullInstallerEqual=True,declaredBeforeReconstructed=True,allAtomicCasesEqual=True,originalMemoryFaults=0,nativeCompared=False,windowsVerified=False)
    if args.artifacts:
        f=ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-network-client.json';packed=f.read_bytes();env=json.loads(packed);z=zlib.decompressobj(-15);payload=z.decompress(base64.b64decode(env['deflate'],validate=True))+z.flush();assert z.eof and not z.unused_data and payload+b'\n'==raw and h(payload)==env['sha256'] and len(payload)==env['count'] and json.loads(payload)==d
        prior=json.loads((b/'network-client-prior-pins.json').read_bytes());pins=json.loads((b/'network-client-fixture-pins.json').read_bytes());assert set(pins)==set(prior)|{f.name}
        for n,digest in pins.items():assert h((f.parent/n).read_bytes())==digest and (n not in prior or prior[n]==digest),n
        meta=ROOT/'native/Sources/NTSDReplayCodec/upstream.json';vendor=json.loads(meta.read_bytes())['files']
        for n,e in vendor.items():assert h((meta.parent/'vendor'/n).read_bytes())==e['vendoredSHA256'],n
        dest=Path(w['isolatedPackage']).parent;export=json.loads((b/'network-client-final-export-pins.json').read_bytes())
        for n,digest in export.items():assert h((dest/n).read_bytes())==digest,n
        for n in w['ownedNativeFiles']:assert h((ROOT/n).read_bytes())==export[n],n
        report.update(packedBytes=len(packed),packedSHA256=h(packed),priorFixtures=len(prior),currentFixtures=len(pins),vendorFiles=len(vendor),isolatedFiles=len(export),fullJSONEqual=True)
    t=b/('network-client-artifact-verification.json' if args.artifacts else 'network-client-source-verification.json');t.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='scope'},indent=2))
if __name__=='__main__':main()
