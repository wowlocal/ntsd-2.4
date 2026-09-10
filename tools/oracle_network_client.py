#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute original NTSD deferred client connection and controlled peer exchange.

Pinned EXE/lib installer and real VC80 memset on each Unicorn CPU. Original
4246b0 prologue produces EBX0/EBP19 and World/target locals; intervening UI is a
declared gap before428420. Stop at actual42873e/4287de, not a whole menu return.
Trace packets, unknown/partial local backing and read/write order. Socket/host/
Sleep/MessageBox responses and paired FIFO delivery are declared adapters;
no external endpoint, actual OS socket or security/control corruption is used.
See NETWORK_CLIENT_PLAN.md.402d70 is exit/cleanup, not this handshake.
"""
import argparse,base64,copy,json,os,struct,threading,queue
from pathlib import Path
from oracle_lib_initialization import LibInitialization,STACK,STOP,REGISTERS,LIB_SHA256,digest
from oracle_network_notification import NetworkNotification,exports
from oracle_crt import prepare,DLL_SHA256
from inspect_original import PE
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,COUNT=0x44d000,0xb440
BODY,ENTRY,WORLD,HOST,TARGET=STACK+0xe000,STACK+0xe424,0x32000000,0x33000000,0x34000000
LOCAL,LOCAL_COUNT=BODY+0x14,0x400
GREETING=b'u can connect\0'

class Client(LibInitialization):
    def __init__(self,peer=None):
        self.capturing=False;self.prologue=False;self.peer=peer;super().__init__(0);self.parent=super().run()
        raw=prepare().read_bytes();assert digest(raw)==DLL_SHA256;self.crt=PE(raw);self.u.mem_map(self.crt.base,0x100000)
        for s in self.crt.sections:self.u.mem_write(self.crt.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.memset=exports(self.crt)['memset'];self.put(0x447160,self.memset)
        self.u.mem_map(0,0x1000);self.u.mem_map(WORLD,0x1000);self.u.mem_map(HOST,0x1000)
        self.initial=bytes(self.u.mem_read(BASE,COUNT));self.images_before=[bytes(self.u.mem_read(a,n)) for a,n in ((0x400000,0x4d000),(0x10000000,0x5000),(self.crt.base,0x100000))]
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.changed);self.u.hook_add(UC_HOOK_MEM_READ,self.read);self.blobs={};self.new_blobs=[]
    def blob(self,b):
        b=bytes(b);key=digest(b)
        if key not in self.blobs:self.blobs[key]=dict(count=len(b),base64=base64.b64encode(b).decode());self.new_blobs.append(key)
        return key
    def record(self,a,b,origin):
        b=bytes(b)
        if BASE<=a<a+len(b)<=BASE+COUNT:region='globals';o=a-BASE;self.gm[o:o+len(b)]=b'\1'*len(b)
        elif LOCAL<=a<a+len(b)<=LOCAL+LOCAL_COUNT:region='local';o=a-LOCAL;self.lm[o:o+len(b)]=b'\1'*len(b)
        else:raise AssertionError(('Client storage write',hex(a),len(b)))
        self.writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=a,bytes=b.hex(),origin=origin,region=region))
        if not self.pending_memset:self.actions.append(dict(kind='store',region=region,offset=o,bytes=list(b)))
    def changed(self,u,access,a,n,value,data):
        if not self.capturing or self.prologue:return
        if BASE<=a<a+n<=BASE+COUNT or LOCAL<=a<a+n<=LOCAL+LOCAL_COUNT:self.record(a,(value&((1<<(8*n))-1)).to_bytes(n,'little'),'CPU')
        elif not STACK<=a<a+n<=STACK+0x10000:raise AssertionError(('Unexpected client write',hex(a),hex(u.reg_read(UC_X86_REG_EIP))))
    def read(self,u,access,a,n,value,data):
        if self.capturing and not self.prologue and (LOCAL<=a<a+n<=LOCAL+LOCAL_COUNT or 0x44fcc0<=a<a+n<=0x44fd18 or HOST<=a<a+n<HOST+0x1000):
            self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=a,bytes=bytes(u.mem_read(a,n)).hex()))
    def request(self,kind,arguments=(),payload=b'',result=0,output=None,address=None):
        response=dict(result=result)
        if output is not None:response['bytes']=list(output)
        if address is not None:response['hostAddress']=address
        e=dict(kind=kind,arguments=list(arguments),bytes=list(payload),response=response);self.events.append(e);self.actions.append(dict(kind='request',event=e));return e
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        if self.prologue:
            if pc==0x42709b:u.emu_stop();return
            assert 0x4246b0<=pc<=0x424774;self.prefix_instructions[pc]=bytes(u.mem_read(pc,size)).hex();return
        if self.pending_memset and pc==self.pending_memset['returnPC']:
            m=self.pending_memset;assert sp==m['sp']+4 and u.reg_read(UC_X86_REG_EAX)==m['address'];payload=bytes(u.mem_read(m['address'],m['count']));assert payload==b'_'*45
            self.actions.append(dict(kind='store',region='local',offset=m['address']-LOCAL,bytes=list(payload)));self.memsets.append(m);self.pending_memset=None
        if pc in (0x42873e,0x4287de):self.end=pc;u.emu_stop();return
        if pc==self.memset:
            a,v,n=[self.u32(sp+i) for i in (4,8,12)];assert (a,v,n)==(BODY+0xc4,95,45);self.pending_memset=dict(address=a,value=v,count=n,sp=sp,returnPC=self.u32(sp))
        if pc==0x428566:
            if self.compare is None:self.compare=dict(first=u.reg_read(UC_X86_REG_ESI),second=u.reg_read(UC_X86_REG_EDI),count=u.reg_read(UC_X86_REG_ECX));assert self.compare['count']==14
        if pc==0x428568:self.compare.update(remaining=u.reg_read(UC_X86_REG_ECX),firstAfter=u.reg_read(UC_X86_REG_ESI),secondAfter=u.reg_read(UC_X86_REG_EDI),flags=u.reg_read(UC_X86_REG_EFLAGS))
        if pc==0x42857c:
            if self.rep is None:self.rep=dict(source=u.reg_read(UC_X86_REG_ESI),destination=u.reg_read(UC_X86_REG_EDI),count=u.reg_read(UC_X86_REG_ECX),flags=u.reg_read(UC_X86_REG_EFLAGS));assert self.rep['count']==19
        if pc==0x42857e:
            assert self.rep and u.reg_read(UC_X86_REG_ECX)==0 and u.reg_read(UC_X86_REG_ESI)==self.rep['source']+76 and u.reg_read(UC_X86_REG_EDI)==self.rep['destination']+76
            self.rep['bytes']=bytes(u.mem_read(self.rep['destination'],76)).hex();assert bytes.fromhex(self.rep['bytes'])==bytes(u.mem_read(0x449788,76))
        if pc not in self.boundaries:
            assert 0x428420<=pc<0x42873e or 0x43f38a<=pc<0x43f3fc or pc==0x4450a0 or self.crt.base<=pc<self.crt.base+0x100000,('Client child',hex(pc))
            self.instructions_case[pc]=bytes(u.mem_read(pc,size)).hex();return
        _,name=self.boundaries[pc];arg=lambda i:self.u32(sp+4+4*i);s=self.spec
        if name=='ordinal:3':self.request('closeSocket',[arg(0)],result=s.get('closeResult',-1));self.ret(s.get('closeResult',-1),4)
        elif name=='ordinal:23':self.request('socket',[arg(i) for i in range(3)],result=s.get('socketResult',0x34560003));self.ret(s.get('socketResult',0x34560003),12)
        elif name in ('ordinal:52','ordinal:51'):
            result=HOST if s.get('hostSuccess' if name=='ordinal:52' else 'fallbackSuccess',True) else 0
            address=s.get('hostAddress',0x0100007f)
            if name=='ordinal:52':self.request('hostLookup',payload=self.string(arg(0)),result=result,address=address)
            else:assert [arg(1),arg(2)]==[4,2];self.request('hostByAddress',[4,2],u.mem_read(arg(0),4),result,address=address)
            self.put(HOST+12,HOST+0x100);self.put(HOST+0x100,HOST+0x200);self.put(HOST+0x200,address);self.ret(result,4 if name=='ordinal:52' else 12)
        elif name=='ordinal:10':self.request('addressWord',payload=self.string(arg(0)),result=s.get('addressWordResult',0x0100007f));self.ret(s.get('addressWordResult',0x0100007f),4)
        elif name=='ordinal:9':
            v=arg(0);result=int.from_bytes(struct.pack('>H',v&0xffff),'little');self.request('htons',[v],result=result);self.ret(result,4)
        elif name=='ordinal:4':
            assert arg(2)==16;self.request('connect',[arg(0),arg(2)],u.mem_read(arg(1),16),s.get('connectResult',0));self.ret(s.get('connectResult',0),12)
        elif name=='ordinal:19':
            payload=bytes(u.mem_read(arg(1),arg(2)));assert arg(2)==77
            if self.peer:self.peer.send('client',payload)
            self.request('send',[arg(0),arg(2),arg(3)],payload,s.get('sendResult',77));self.ret(s.get('sendResult',77),16)
        elif name=='ordinal:16':
            count=arg(2);assert count in (100,77,3001);index=self.receive_index;self.receive_index+=1
            r=copy.deepcopy(s['receives'][index]) if not self.peer else dict(bytes=list(self.peer.receive('client',count)),result=None)
            payload=bytes(r['bytes']);assert len(payload)<=count;result=len(payload) if r.get('result') is None else r['result']
            self.request('receive',[arg(0),count,arg(3)],result=result,output=payload)
            if payload:u.mem_write(arg(1),payload);self.record(arg(1),payload,'API')
            self.ret(result,16)
        elif name=='Sleep':self.request('sleep',[arg(0)]);self.ret(0,4)
        elif name=='MessageBoxA':self.request('message',[arg(0),arg(3)],self.string(arg(1))+b'\0'+self.string(arg(2))+b'\0',s.get('messageResult',1));self.ret(s.get('messageResult',1),16)
        else:raise AssertionError(('Client API',name,hex(pc)))
    def call(self,spec,index):
        self.spec=spec;self.new_blobs=[];self.u.mem_write(BASE,self.initial)
        for a,v in [(0x44d068,0),(0x4511f8,0),(0x4511b0,spec.get('pending',1)),(0x44d064,spec.get('menu',3)),(0x44f1b4,0x34560001),(0x44f46c,0x34560000)]+[(0x450b4c+4*i,100+i) for i in range(8)]:self.put(a,v)
        names=bytes(spec.get('names',sum(([ord(str(i+1)),0]+[0xa5]*9 for i in range(8)),[])));assert len(names)==88;self.u.mem_write(0x44fcc0,names)
        for i in range(4):assert i*11+len(self.string(0x44fcc0+i*11))<44
        self.u.mem_write(0x44ff90,bytes((i*17+21)&255 for i in range(3001)))
        world=bytearray((i*31+21)&255 for i in range(0x840));struct.pack_into('<I',world,0,0);hostname=bytes(spec.get('hostname',b'127.0.0.1'));assert len(hostname)<=50 and b'\0' not in hostname;world[0x7d8:0x7d8+len(hostname)+1]=hostname+b'\0';self.u.mem_write(WORLD,bytes(world))
        self.u.mem_write(STACK,bytes((i*spec.get('seed',17)+0xa5)&255 for i in range(0x10000)));self.put(0,0x12345678);self.put(ENTRY,STOP);self.put(ENTRY+4,TARGET);self.u.reg_write(UC_X86_REG_ESP,ENTRY);self.u.reg_write(UC_X86_REG_ECX,WORLD)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.reg_write(UC_X86_REG_FPCW,0x23f);self.u.reg_write(UC_X86_REG_EFLAGS,2);self.prefix_instructions={};self.prologue=True;self.capturing=True
        try:self.u.emu_start(0x4246b0,0,count=10000)
        finally:self.prologue=False;self.capturing=False
        assert self.u.reg_read(UC_X86_REG_EIP)==0x42709b and self.u.reg_read(UC_X86_REG_ESP)==BODY and self.u.reg_read(UC_X86_REG_EBP)==19 and self.u.reg_read(UC_X86_REG_EBX)==0
        assert self.u32(BODY+0x18)==WORLD and self.u32(BODY+0x20)==TARGET
        self.events=[];self.actions=[];self.writes=[];self.reads=[];self.instructions_case={};self.gm=bytearray(COUNT);self.lm=bytearray(LOCAL_COUNT);self.memsets=[];self.pending_memset=None;self.rep=None;self.compare=None;self.receive_index=0;self.end=None
        before=self.blob(self.u.mem_read(BASE,COUNT));local_before=self.blob(self.u.mem_read(LOCAL,LOCAL_COUNT));protected=bytes(self.u.mem_read(BODY,0x14))+bytes(self.u.mem_read(BODY+0x414,0x18));self.capturing=True
        try:self.u.emu_start(0x428420,0,count=500000)
        finally:self.capturing=False
        assert self.end in (0x42873e,0x4287de) and self.u.reg_read(UC_X86_REG_ESP)==BODY and self.pending_memset is None and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert protected==bytes(self.u.mem_read(BODY,0x14))+bytes(self.u.mem_read(BODY+0x414,0x18));assert bytes(self.u.mem_read(WORLD,0x840))==world
        assert self.images_before==[bytes(self.u.mem_read(a,n)) for a,n in ((0x400000,0x4d000),(0x10000000,0x5000),(self.crt.base,0x100000))]
        return dict(index=index,spec=spec,before=before,after=self.blob(self.u.mem_read(BASE,COUNT)),localBefore=local_before,localAfter=self.blob(self.u.mem_read(LOCAL,LOCAL_COUNT)),globalWritten=self.blob(self.gm),localWritten=self.blob(self.lm),world=self.blob(world),actions=self.actions,events=self.events,writes=self.writes,reads=self.reads,memsets=self.memsets,rep=self.rep,compare=self.compare,prefixInstructions=[dict(address=a,bytes=b) for a,b in sorted(self.prefix_instructions.items())],instructions=[dict(address=a,bytes=b) for a,b in sorted(self.instructions_case.items())],endPC=self.end,sp=BODY,ebp=self.u.reg_read(UC_X86_REG_EBP),fpcw=self.u.reg_read(UC_X86_REG_FPCW))

def response(payload):return dict(bytes=list(payload),result=len(payload))
def spec(label,**kw):return dict(label=label,receives=[response(GREETING),response(b'11110000'+b'0'*68+b'\0'),response(bytes((i*7+3)&255 for i in range(3001)))],**kw)
def specs():
    yield spec('normal')
    for pending in (0,2,0xffffffff):yield spec('pending',pending=pending)
    for value in (-1,0,1,0x7fffffff):yield spec('socket',socketResult=value)
    for first,second in ((False,False),(False,True),(True,True)):yield spec('lookup',hostSuccess=first,fallbackSuccess=second)
    yield spec('mode-one',menu=1)
    for value in (-1,0,1):yield spec('connect',connectResult=value)
    for i in range(14):
        s=spec('greeting-mismatch');g=bytearray(GREETING);g[i]^=0xff;s['receives'][0]=response(g);yield s
    for n in list(range(15))+[99,100]:
        s=spec('greeting-prefix');s['receives'][0]=response((GREETING+b'x'*86)[:n]);yield s
    for value in (-1,0,1,14):
        s=spec('receive-status');s['receives'][0]['result']=value;s['sendResult']=value;yield s
    for flags in range(256):
        s=spec('flags');s['receives'][1]=response(bytes(49 if flags&(1<<i) else 48 for i in range(8))+bytes(range(24))+bytes(range(44))+b'\0');yield s
    for n in range(78):
        s=spec('packet-prefix');s['receives'][1]=response(bytes((i*17+21)&255 for i in range(n)));yield s
    for n in (0,1,3000,3001):
        s=spec('rng-prefix');s['receives'][2]=response(bytes((i*13+7)&255 for i in range(n)));yield s
    for names in ([0]*88,list(range(1,44))+[0]+[0xa5]*44,list(b'A_B\0'+b'_'*7)*4+[0xa5]*44,list(b'abcdefghij\0')*8):yield spec('names',names=names)

class Peer:
    def __init__(self):self.queues={name:queue.Queue() for name in ('server','client')};self.deliveries=[];self.lock=threading.Lock()
    def send(self,name,payload):
        with self.lock:self.deliveries.append(dict(sender=name,bytes=list(payload)))
        self.queues['client' if name=='server' else 'server'].put(bytes(payload))
    def receive(self,name,count):
        payload=self.queues[name].get(timeout=30);assert len(payload)<=count;return payload
class Server(NetworkNotification):
    def __init__(self,peer):self.peer=peer;super().__init__()
    def code(self,u,pc,size,data):
        if self.capturing and pc in self.boundaries:
            _,name=self.boundaries[pc];sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
            if name=='ordinal:19':self.peer.send('server',u.mem_read(arg(1),arg(2)))
            if name=='ordinal:16':payload=self.peer.receive('server',arg(2));self.spec['received']=list(payload);self.spec['receiveResult']=len(payload)
        return super().code(u,pc,size,data)
def paired(index):
    peer=Peer();server=Server(peer);client=Client(peer);results={};errors=[]
    def run(name,vm,s):
        try:results[name]=vm.call(s,0)
        except BaseException as e:errors.append((name,repr(e)))
    server_spec=dict(label='paired-server',names=list(b'Naruto____\0Sasuke____\0Sakura____\0Kakashi___\0')+[0xa5]*44)
    client_spec=spec('paired-client',names=list(b'Neji______\0RockLee___\0Gaara_____\0Temari____\0')+[0xa5]*44)
    threads=[threading.Thread(target=run,args=('server',server,server_spec)),threading.Thread(target=run,args=('client',client,client_spec))]
    for t in threads:t.start()
    for t in threads:t.join(40)
    assert not errors and all(not t.is_alive() for t in threads),(errors,[t.is_alive() for t in threads]);assert all(q.empty() for q in peer.queues.values())
    return dict(index=index,client=results['client'],server=results['server'],deliveries=peer.deliveries,clientBlobs=client.blobs,serverBlobs=server.blobs)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir();vm=Client();cases=[]
    for s in specs():
        if a.limit is not None and len(cases)>=a.limit:break
        try:c=vm.call(s,len(cases))
        except Exception as e:
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(error=repr(e),completed=len(cases),spec=s,pc=vm.u.reg_read(UC_X86_REG_EIP),events=getattr(vm,'events',[])),indent=2)+'\n');raise
        cases.append(c)
        for key in vm.new_blobs:(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();t=parts/('%06d.json'%c['index']);tmp=t.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,t)
        cp=path.with_suffix('.incomplete.json');tmp=cp.with_suffix('.tmp');tmp.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(tmp,cp)
        if len(cases)%50==0:print('Completed',len(cases),flush=True)
    pairs=[] if a.limit is not None else [paired(0)]
    d=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,parent=vm.parent,cases=cases,pairs=pairs,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(d,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw);r=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),pairs=len(pairs),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()));path.with_suffix('.report.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
