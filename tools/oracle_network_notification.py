#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute NTSD's whole network acceptance notification and original packet code.

Pinned EXE/lib installer and VC80 memset on one Unicorn CPU. Socket/Win32/clock
responses and bounded name/local backing are declared adapters, not actual
Windows, peer sessions or timing. Trace full packets, partial recv and original
cookie checks without corrupting control/security storage or manufacturing a
memory fault. No real network operation. NETWORK_NOTIFICATION_PLAN.md.
"""
import argparse,base64,json,os,struct
from pathlib import Path
from oracle_lib_initialization import LibInitialization,SP,STOP,STACK,REGISTERS,LIB_SHA256,digest
from oracle_crt import prepare,DLL_SHA256
from inspect_original import PE
from import_ntsd import ROOT,EXE_SHA256
from unicorn import UC_HOOK_MEM_WRITE,UC_HOOK_MEM_READ
from unicorn.x86_const import *
BASE,COUNT=0x44d000,0xb440
HELPERS={0x43b3d0:('callback',16),0x402ec0:('notification',0),0x4450b2:('cookieCheck',0)}

def exports(pe):
    e=pe.offset(pe.directories[0][0]);count,functions,names,ordinals=[pe.u32(e+n) for n in (24,28,32,36)]
    return {pe.string(pe.u32(pe.offset(names)+4*i)):pe.base+pe.u32(pe.offset(functions)+4*pe.u16(pe.offset(ordinals)+2*i)) for i in range(count)}

class NetworkNotification(LibInitialization):
    def __init__(self):
        self.capturing=False;super().__init__(0);self.parent=super().run()
        raw=prepare().read_bytes();assert digest(raw)==DLL_SHA256;pe=PE(raw);self.crt=pe;self.u.mem_map(pe.base,0x100000)
        for s in pe.sections:self.u.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.memset=exports(pe)['memset'];self.put(0x447160,self.memset)
        self.initial=bytes(self.u.mem_read(BASE,COUNT));self.code_before=bytes(self.u.mem_read(0x400000,0x4d000));self.lib_before=bytes(self.u.mem_read(0x10000000,0x5000))
        self.crt_before=bytes(self.u.mem_read(pe.base,0x100000))
        self.u.hook_add(UC_HOOK_MEM_WRITE,self.changed);self.u.hook_add(UC_HOOK_MEM_READ,self.read)
        self.blobs={};self.new_blobs=[]
    def blob(self,b):
        b=bytes(b);key=digest(b)
        if key not in self.blobs:self.blobs[key]=dict(count=len(b),base64=base64.b64encode(b).decode());self.new_blobs.append(key)
        return key
    def record(self,a,b,origin):
        b=bytes(b)
        if BASE<=a and a+len(b)<=BASE+COUNT:region='globals';o=a-BASE;self.gm[o:o+len(b)]=b'\1'*len(b)
        elif self.frame is not None and self.frame<=a and a+len(b)<=self.frame+160:region='local';o=a-self.frame;self.lm[o:o+len(b)]=b'\1'*len(b)
        else:raise AssertionError(('Unexpected network write',hex(a),len(b)))
        self.writes.append(dict(pc=self.u.reg_read(UC_X86_REG_EIP),address=a,bytes=b.hex(),origin=origin,region=region))
        if not self.pending_memset:self.actions.append(dict(kind='store',region=region,offset=o,bytes=list(b)))
    def changed(self,u,access,a,n,value,data):
        if not self.capturing:return
        if BASE<=a<BASE+COUNT or self.frame is not None and self.frame<=a<a+n<=self.frame+160:self.record(a,(value&((1<<(8*n))-1)).to_bytes(n,'little'),'CPU')
        elif not STACK<=a<a+n<=STACK+0x10000:raise AssertionError(('Store outside declared network storage',hex(a),hex(u.reg_read(UC_X86_REG_EIP))))
    def read(self,u,access,a,n,value,data):
        if self.capturing and ((self.frame is not None and self.frame<=a<a+n<=self.frame+160) or 0x44fcc0<=a<a+n<=0x44fd18):
            self.reads.append(dict(pc=u.reg_read(UC_X86_REG_EIP),address=a,bytes=bytes(u.mem_read(a,n)).hex()))
    def request(self,kind,arguments=(),bytes_=(),response=None):
        e=dict(kind=kind,arguments=list(arguments),bytes=list(bytes_),response=response or dict(result=0));self.events.append(e);self.actions.append(dict(kind='request',event=e));return e
    def code(self,u,pc,size,data):
        if not self.capturing:return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP)
        if self.pending_memset and pc==self.pending_memset['returnPC']:
            m=self.pending_memset;assert sp==m['sp']+4 and u.reg_read(UC_X86_REG_EAX)==m['address']
            b=bytes(u.mem_read(m['address'],m['count']));assert b==bytes([m['value']])*m['count']
            self.actions.append(dict(kind='store',region='local',offset=m['address']-self.frame,bytes=list(b)))
            self.memsets.append(m);self.pending_memset=None
        for item in list(reversed(self.pending_helpers)):
            if item['returnPC']==pc and sp==item['sp']+4+item['pop']:
                self.returns.append(dict(**item,eax=u.reg_read(UC_X86_REG_EAX)));self.pending_helpers.remove(item)
        if pc==STOP:self.finished=True;u.emu_stop();return
        if pc in HELPERS:
            name,pop=HELPERS[pc];self.pending_helpers.append(dict(address=pc,kind=name,sp=sp,returnPC=self.u32(sp),pop=pop))
        if pc==0x402ec0:
            self.frame=sp-0xa4;self.local_before=self.blob(u.mem_read(self.frame,160));assert [self.u32(sp+i) for i in (4,8,12)]==[self.spec.get('window',0x73000001),self.spec.get('wParam',0xabcdef12),self.spec.get('lParam',8)]
        if pc==0x4450b2:
            self.cookies.append(dict(pc=pc,value=u.reg_read(UC_X86_REG_ECX),expected=self.u32(0x44eea4)));assert self.cookies[-1]['value']==self.cookies[-1]['expected']
        if pc==self.memset:
            a,v,n=[self.u32(sp+i) for i in (4,8,12)];assert (a-self.frame,v,n) in [(0,0,77),(0x70,0x5f,45)]
            assert self.pending_memset is None;self.pending_memset=dict(address=a,value=v,count=n,sp=sp,returnPC=self.u32(sp))
        if pc==0x402fc3:
            if self.rep is None:self.rep=dict(source=u.reg_read(UC_X86_REG_ESI),destination=u.reg_read(UC_X86_REG_EDI),count=u.reg_read(UC_X86_REG_ECX),flags=u.reg_read(UC_X86_REG_EFLAGS));assert self.rep['count']==19
        if pc==0x402fc5:
            assert self.rep and u.reg_read(UC_X86_REG_ECX)==0 and u.reg_read(UC_X86_REG_ESI)==self.rep['source']+76 and u.reg_read(UC_X86_REG_EDI)==self.rep['destination']+76
            self.rep['bytes']=bytes(u.mem_read(self.rep['destination'],76)).hex();assert bytes.fromhex(self.rep['bytes'])==bytes(u.mem_read(0x4478b0,76))
        if pc not in self.boundaries:
            allowed=0x43b3d0<=pc<=0x43bc40 or 0x402ec0<=pc<=0x40316e or pc in (0x43f3b4,0x43f3c6,0x43f3cc,0x43f3d2,0x4450a0,0x4450b2,0x4450b8,0x4450ba) or self.crt.base<=pc<self.crt.base+0x100000
            assert allowed,('Unexpected network child',hex(pc));self.instructions_case[pc]=bytes(u.mem_read(pc,size)).hex();return
        _,name=self.boundaries[pc];arg=lambda i:self.u32(sp+4+4*i)
        if name=='ordinal:1':
            r=dict(result=self.spec.get('acceptResult',0x34560002));self.request('accept',[arg(i) for i in range(3)],response=r);self.ret(r['result'],12)
        elif name=='ordinal:3':
            self.request('closeSocket',[arg(0)],response=dict(result=self.spec.get('closeResult',-1)));self.ret(self.spec.get('closeResult',-1),4)
        elif name=='ordinal:19':
            n=arg(2);assert n in (14,77,3001);result=self.spec.get('sendResult',n)
            self.request('send',[arg(0),n,arg(3)],u.mem_read(arg(1),n),dict(result=result));self.ret(result,16)
        elif name=='ordinal:16':
            assert [arg(2),arg(3)]==[77,0] and arg(1)==self.frame
            payload=bytes(self.spec.get('received',[]));assert len(payload)<=77
            r=dict(result=self.spec.get('receiveResult',len(payload)),bytes=list(payload));self.request('receive',[arg(0),arg(2),arg(3)],response=r)
            if payload:u.mem_write(arg(1),payload);self.record(arg(1),payload,'API')
            self.ret(r['result'],16)
        elif name=='Sleep':self.request('sleep',[arg(0)]);self.ret(0,4)
        elif name=='MessageBoxA':
            result=self.spec.get('messageResult',1);self.request('message',[arg(0),arg(3)],self.string(arg(1))+b'\0'+self.string(arg(2))+b'\0',dict(result=result));self.ret(result,16)
        elif name=='DefWindowProcA':
            result=self.spec.get('defaultResult',-123);self.request('windowDefault',[arg(i) for i in range(4)],response=dict(result=result));self.ret(result,16)
        else:raise AssertionError(('Unsupported network API',name,hex(pc)))
    def call(self,spec,index):
        self.spec=spec;self.new_blobs=[]
        if not spec.get('retain'):
            self.u.mem_write(BASE,self.initial)
            for a,v in [(0x44f1b4,0x34560001),(0x44f46c,0x12340001)]+[(0x450b4c+4*i,100+i) for i in range(8)]:self.put(a,v)
            self.u.mem_write(0x44f1ae,b'\x17\x21');self.u.mem_write(0x44fcc0,bytes(spec.get('names',sum(([ord(str(i+1)),0]+[0xa5]*9 for i in range(8)),[]))));self.u.mem_write(0x44ff90,bytes((i*17+21)&255 for i in range(3001)))
        # Preserve all source string bytes and prove the selected copies do not
        # reach cookie/saved control storage. This is a corpus boundary only.
        for i in range(4):assert 0x70+i*11+len(self.string(0x44fcc0+i*11))+1<=0xa0
        self.u.mem_write(STACK,bytes((i*spec.get('seed',17)+0xa5)&255 for i in range(0x10000)))
        self.u.mem_write(SP,struct.pack('<5I',STOP,spec.get('window',0x73000001),0x401,spec.get('wParam',0xabcdef12),spec.get('lParam',8)));self.u.reg_write(UC_X86_REG_ESP,SP)
        for r,v in zip(REGISTERS,(0x11223344,0x22334455,0x33445566,0x44556677)):self.u.reg_write(r,v)
        self.u.reg_write(UC_X86_REG_FPCW,0x23f);self.u.reg_write(UC_X86_REG_EFLAGS,2)
        self.events=[];self.actions=[];self.writes=[];self.reads=[];self.cookies=[];self.pending_helpers=[];self.returns=[];self.instructions_case={};self.frame=None;self.local_before=None;self.pending_memset=None;self.memsets=[];self.rep=None;self.gm=bytearray(COUNT);self.lm=bytearray(160);self.finished=False
        before=self.blob(self.u.mem_read(BASE,COUNT));self.capturing=True
        try:self.u.emu_start(0x43b3d0,0,count=200000)
        finally:self.capturing=False
        assert self.finished and not self.pending_helpers and self.pending_memset is None and self.u.reg_read(UC_X86_REG_ESP)==SP+20
        assert [self.u.reg_read(r) for r in REGISTERS]==[0x11223344,0x22334455,0x33445566,0x44556677] and self.u.reg_read(UC_X86_REG_FPCW)==0x23f
        assert bytes(self.u.mem_read(0x400000,0x4d000))==self.code_before and bytes(self.u.mem_read(0x10000000,0x5000))==self.lib_before and bytes(self.u.mem_read(self.crt.base,0x100000))==self.crt_before
        return dict(index=index,spec=spec,before=before,after=self.blob(self.u.mem_read(BASE,COUNT)),globalWritten=self.blob(self.gm),localBefore=self.local_before,localAfter=self.blob(self.u.mem_read(self.frame,160)),localWritten=self.blob(self.lm),frame=self.frame,actions=self.actions,events=self.events,writes=self.writes,reads=self.reads,memsets=self.memsets,rep=self.rep,cookies=self.cookies,helpers=self.returns,instructions=[dict(address=a,bytes=b) for a,b in sorted(self.instructions_case.items())],result=self.u.reg_read(UC_X86_REG_EAX),sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW))

def specs():
    yield dict(label='accept-default',received=list(b'11110000'+b'0'*24+b'Naruto_____Sasuke_____Sakura_____Kakashi____'+b'\0'))
    for low in range(34):yield dict(label='dispatch',lParam=low)
    for high in (1,0x8000,0xffff):
        for low in (0,1,8,16,32,0xffff):yield dict(label='highword',lParam=high<<16|low)
    for result in (-1,0,1,0x7fffffff):yield dict(label='accept-status',acceptResult=result)
    for flags in range(256):yield dict(label='seat-flags',received=[49 if flags&(1<<i) else 48 for i in range(8)]+[0]*24+list(range(44))+[0])
    for count in range(78):yield dict(label='partial-receive',received=[0x31 if i<8 else (i*37)&255 for i in range(count)])
    for status in (-1,0,1,76,77):
        for count in (0,7,77):yield dict(label='numeric-errors',receiveResult=status,sendResult=status,received=[0x31]*count)
    for names in ([0]*88,[i%255+1 for i in range(43)]+[0]+[0xa5]*44,list(b'A_B\0'+b'_'*7)*4+[0xa5]*44,list(b'abcdefghij\0')*8):yield dict(label='name-backing',names=names)
    yield dict(label='own-accept',received=list(b'11110000'+b'0'*24+b'Naruto_____Sasuke_____Sakura_____Kakashi____'+b'\0'))
    for low in (1,16,32,0):yield dict(label='own-retained-notice',lParam=low,retain=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--limit',type=int);a=p.parse_args();path=ROOT/a.output;assert not path.exists();parts=path.with_suffix('.parts');assert not parts.exists();parts.mkdir();(parts/'blobs').mkdir();vm=NetworkNotification();cases=[]
    for spec in specs():
        if a.limit is not None and len(cases)>=a.limit:break
        try:c=vm.call(spec,len(cases))
        except Exception as e:
            f=path.with_suffix('.failure.json');assert not f.exists();f.write_text(json.dumps(dict(error=repr(e),spec=spec,completed=len(cases),pc=vm.u.reg_read(UC_X86_REG_EIP),events=vm.events,writes=vm.writes),indent=2)+'\n');raise
        cases.append(c)
        for key in vm.new_blobs:(parts/'blobs'/(key+'.json')).write_text(json.dumps(vm.blobs[key],separators=(',',':'))+'\n')
        raw=(json.dumps(c,sort_keys=True,separators=(',',':'))+'\n').encode();target=parts/('%06d.json'%c['index']);tmp=target.with_suffix('.tmp');tmp.write_bytes(raw);os.replace(tmp,target)
        checkpoint=path.with_suffix('.incomplete.json');tmp=checkpoint.with_suffix('.tmp');tmp.write_text(json.dumps(dict(incomplete=True,completed=len(cases),lastCaseSHA256=digest(raw)))+'\n');os.replace(tmp,checkpoint)
        if len(cases)%50==0:print('Completed',len(cases),flush=True)
    doc=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,memsetAddress=vm.memset,parent=vm.parent,cases=cases,blobs=vm.blobs,limited=a.limit is not None,nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(doc,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw);report=dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),cases=len(cases),blobs=len(vm.blobs),sourceSHA256=digest(Path(__file__).read_bytes()));path.with_suffix('.report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
