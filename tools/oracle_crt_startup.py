#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Trace original CRT process attach and game PE entry through WinMain43cf40.

Compatibility research only: pinned MSVCR80/EXE/lib.dll instructions execute on
one Unicorn2.1.4 CPU. Synthetic Windows loader, TEB, clock, heap, command line,
environment and API responses are explicit inputs. Original callbacks, FPU
setup and constructors are never replaced by expected successes. Unknown APIs
stop with partial evidence; actual memory faults remain failures. No native,
Windows loader/device, full game or private CRT ABI equivalence is claimed.
See docs/research/CRT_STARTUP_PLAN.md. No security/control corruption stimulus.
"""
import argparse,hashlib,json,struct
from collections import deque
from pathlib import Path
from oracle_lib_initialization import LibInitialization,STACK,SP,STOP,LIB_SHA256
from oracle_crt import prepare,DLL_SHA256
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from unicorn.x86_const import *

CRT_RETURN=STOP+0x200
OS_DATA=0x27000000

def digest(raw):return hashlib.sha256(raw).hexdigest()

def exports(pe):
    o=pe.offset(pe.directories[0][0]);n,fn,names,ords=[pe.u32(o+i) for i in (24,28,32,36)]
    return {pe.string(pe.u32(pe.offset(names)+4*i)):pe.base+pe.u32(pe.offset(fn)+4*pe.u16(pe.offset(ords)+2*i)) for i in range(n)}

class CRTStartup(LibInitialization):
    def __init__(self,command=b'"C:\\NTSD 2.4\\NTSD 2.4.exe"',show_flags=0,show=10,kernel_available=True):
        self.phase='setup';self.recent=deque(maxlen=48);self.sequence=[];self.game_initializers=[];self.checkpoints=[];self.allocs={};self.tls={};self.next_heap=0x28000000
        self.command=command;self.show_flags=show_flags;self.show=show;self.kernel_available=kernel_available
        super().__init__(0)
        self.u.mem_map(0,0x1000);self.u.mem_map(OS_DATA,0x10000)
        self.put(0,0xffffffff);self.put(0x18,OS_DATA+0x100);self.put(OS_DATA+0x104,STACK+0x10000);self.put(OS_DATA+0x108,STACK)
        self.u.mem_write(OS_DATA+0x1000,command+b'\0')
        self.u.mem_write(OS_DATA+0x2000,b'\0\0\0\0');self.u.mem_write(OS_DATA+0x3000,command.decode('ascii').encode('utf-16le')+b'\0\0')
        raw=prepare().read_bytes();self.crt_pe=pe=PE(raw);assert digest(raw)==DLL_SHA256
        self.u.mem_map(pe.base,0x100000);self.u.mem_write(pe.base,raw[:pe.sections[0]['fileOffset']])
        for s in pe.sections:self.u.mem_write(pe.base+s['rva'],raw[s['fileOffset']:s['fileOffset']+s['fileSize']])
        self.crt_exports=exports(pe)
        for i,item in enumerate(pe.imports()):
            a=STOP+0x4000+i*16;assert a<STOP+0x10000;self.boundaries[a]=('msvcr80.dll',item['name']);self.put(int(item['iatVA'],16),a)
        for item in self.images['NTSD 2.4.exe'][0].imports():
            if item['dll'].lower()=='msvcr80.dll':self.put(int(item['iatVA'],16),self.crt_exports[item['name']])
        self.phase='ready'
    def code(self,u,pc,size,data):
        self.recent.append(pc)
        if pc==CRT_RETURN:
            assert self.phase=='crtAttach';self.crt_result=u.reg_read(UC_X86_REG_EAX);self.finished=True;u.emu_stop();return
        if pc==0x43cf40:
            self.finished=True;u.emu_stop();return
        if pc==0x445565:
            assert len(self.patches)==13 and sum(p['count'] for p in self.patches)==62
            self.checkpoint('libInstalled');self.instructions.add(pc);self.instruction_bytes[pc]=bytes(u.mem_read(pc,size)).hex();return
        if pc in (0x44547e,0x44571e,0x44576f,0x445254,0x4462e0,0x4462f0,0x446300):
            self.game_initializers.append(dict(address=pc,returnPC=self.u32(u.reg_read(UC_X86_REG_ESP)),fpcw=u.reg_read(UC_X86_REG_FPCW)))
        if pc not in self.boundaries:return super().code(u,pc,size,data)
        image,name=self.boundaries[pc]
        if image!='msvcr80.dll' and name in ('GetSystemTimeAsFileTime','GetCurrentProcessId','GetCurrentThreadId','GetTickCount','QueryPerformanceCounter','LoadLibraryA','VirtualAlloc','VirtualProtect','RtlMoveMemory'):
            return super().code(u,pc,size,data)
        sp=u.reg_read(UC_X86_REG_ESP);arg=lambda i:self.u32(sp+4+4*i)
        event=dict(kind=name,image=image,phase=self.phase,pc=pc,returnPC=self.u32(sp));self.events.append(event)
        def done(value=0,pop=0,args=()):
            event.update(arguments=list(args),result=value&0xffffffff);self.ret(value,pop)
        if name in ('GetCurrentProcessId','GetCurrentThreadId','GetTickCount'):done({'GetCurrentProcessId':0x1234,'GetCurrentThreadId':0x5678,'GetTickCount':0x11223344}[name])
        elif name=='GetSystemTimeAsFileTime':u.mem_write(arg(0),(0x0123456789abcdef).to_bytes(8,'little'));done(0,4,[arg(0)])
        elif name=='QueryPerformanceCounter':u.mem_write(arg(0),(0x55667788).to_bytes(8,'little'));done(1,4,[arg(0)])
        elif name in ('GetModuleHandleA','GetModuleHandleW'):
            event['requested']=self.string(arg(0)).hex() if arg(0) and name.endswith('A') else arg(0);done((0x70000001 if self.kernel_available and name=='GetModuleHandleA' and self.string(arg(0)).lower()==b'kernel32.dll' else 0) if arg(0) else 0x400000,4,[arg(0)])
        elif name=='GetProcAddress':
            event['symbol']=self.string(arg(1)).decode('ascii');done(0,8,[arg(0),arg(1)])
        elif name=='HeapDestroy':done(1,4,[arg(0)])
        elif name in ('TlsFree','FlsFree'):done(1,4,[arg(0)])
        elif name=='GetVersionExA':
            a=arg(0);n=self.u32(a);assert n in (148,156);u.mem_write(a+4,struct.pack('<4I',5,1,2600,2)+bytes(n-20));event['version']=[5,1,2600,2];done(1,4,[a])
        elif name=='GetVersion':done(0x0a280105)
        elif name=='GetStartupInfoA':
            a=arg(0);payload=bytearray(68);struct.pack_into('<I',payload,0,68);struct.pack_into('<I',payload,44,self.show_flags);struct.pack_into('<H',payload,48,self.show);u.mem_write(a,bytes(payload));event['bytes']=payload.hex();done(0,4,[a])
        elif name in ('TlsAlloc','FlsAlloc'):
            n=len(self.tls);self.tls[n]=0;done(n,4 if name=='FlsAlloc' else 0)
        elif name in ('TlsGetValue','FlsGetValue'):done(self.tls.get(arg(0),0),4,[arg(0)])
        elif name in ('TlsSetValue','FlsSetValue'):self.tls[arg(0)]=arg(1);done(1,8,[arg(0),arg(1)])
        elif name=='GetProcessHeap':done(0x71000002)
        elif name=='HeapCreate':done(0x71000001,12,[arg(i) for i in range(3)])
        elif name=='HeapAlloc':
            h,flags,n=[arg(i) for i in range(3)];assert h in (0x71000001,0x71000002) and n<0x1000000
            a=self.next_heap;extent=(max(n,1)+4095)&~4095;self.next_heap+=extent+4096;u.mem_map(a,extent);u.mem_write(a,(b'\0' if flags&8 else b'\xa5')*extent);self.allocs[a]=dict(address=a,count=n,mapped=extent,live=True,flags=flags);done(a,12,[h,flags,n])
        elif name=='HeapSize':
            h,flags,a=[arg(i) for i in range(3)];assert self.allocs[a]['live'];done(self.allocs[a]['count'],12,[h,flags,a])
        elif name=='HeapFree':
            h,flags,a=[arg(i) for i in range(3)];assert self.allocs[a]['live'];self.allocs[a]['live']=False;done(1,12,[h,flags,a])
        elif name in ('InitializeCriticalSection','EnterCriticalSection','LeaveCriticalSection','DeleteCriticalSection'):done(0,4,[arg(0)])
        elif name=='InitializeCriticalSectionAndSpinCount':done(1,8,[arg(0),arg(1)])
        elif name in ('InterlockedIncrement','InterlockedDecrement'):
            a=arg(0);v=(self.u32(a)+(1 if name.endswith('Increment') else -1))&0xffffffff;self.put(a,v);done(v,4,[a])
        elif name=='InterlockedCompareExchange':
            a,v,c=[arg(i) for i in range(3)];old=self.u32(a)
            if old==c:self.put(a,v)
            done(old,12,[a,v,c])
        elif name=='InterlockedExchange':a,v=arg(0),arg(1);old=self.u32(a);self.put(a,v);done(old,8,[a,v])
        elif name=='GetCommandLineW':done(OS_DATA+0x3000)
        elif name=='WideCharToMultiByte':
            cp,flags,src,n,dst,capacity,default,used=[arg(i) for i in range(8)];assert cp==flags==default==used==0 and n==1 and bytes(u.mem_read(src,2))==b'\0\0'
            if dst:assert capacity>=1;u.mem_write(dst,b'\0')
            done(1,32,[cp,flags,src,n,dst,capacity,default,used])
        elif name=='GetCommandLineA':done(OS_DATA+0x1000)
        elif name=='GetEnvironmentStringsW':done(OS_DATA+0x2000)
        elif name=='FreeEnvironmentStringsW':done(1,4,[arg(0)])
        elif name=='GetModuleFileNameA':
            h,a,n=[arg(i) for i in range(3)];s=b'C:\\NTSD 2.4\\NTSD 2.4.exe';assert n>len(s);u.mem_write(a,s+b'\0');done(len(s),12,[h,a,n])
        elif name=='SetUnhandledExceptionFilter':done(0,4,[arg(0)])
        elif name=='GetEnvironmentVariableA':
            event['nameBytes']=self.string(arg(0)).hex();done(0,12,[arg(0),arg(1),arg(2)])
        elif name=='SetHandleCount':done(arg(0),4,[arg(0)])
        elif name=='IsValidCodePage':assert arg(0)==1252;done(1,4,[arg(0)])
        elif name=='GetACP':done(1252)
        elif name=='GetOEMCP':done(437)
        elif name=='GetCPInfo':
            cp,dst=arg(0),arg(1);assert cp==1252;u.mem_write(dst,struct.pack('<I',1)+b'?\0'+bytes(14));done(1,8,[cp,dst])
        elif name=='GetStdHandle':done(0xffffffff,4,[arg(0)])
        elif name=='GetLastError':done(0)
        elif name=='SetLastError':done(0,4,[arg(0)])
        else:
            if name=='GetStringTypeW':
                kind,src,n,dst=[arg(i) for i in range(4)];assert n<4096 or n==0xffffffff
                count=n if n!=0xffffffff else 1
                event.update(arguments=[kind,src,n,dst],sourceBytes=bytes(u.mem_read(src,count*2)).hex(),destinationBefore=bytes(u.mem_read(dst,count*2)).hex())
            raise RuntimeError(('unsupportedAPI',name,hex(pc),hex(self.u32(sp))))
    def checkpoint(self,label):
        self.checkpoints.append(dict(label=label,phase=self.phase,pc=self.u.reg_read(UC_X86_REG_EIP),sp=self.u.reg_read(UC_X86_REG_ESP),fpcw=self.u.reg_read(UC_X86_REG_FPCW),fpsw=self.u.reg_read(UC_X86_REG_FPSW),globalSHA256=digest(bytes(self.u.mem_read(0x44d000,0xd000)))))
    def run(self):
        self.active=True;self.phase='crtAttach';self.finished=False
        for i,v in enumerate((CRT_RETURN,self.crt_pe.base,1,0)):self.put(SP+4*i,v)
        self.u.emu_start(self.crt_pe.entry,0,count=2000000)
        assert self.finished and self.u.reg_read(UC_X86_REG_ESP)==SP+16
        if self.crt_result==0:self.phase='crtRejected';self.active=False;return
        self.checkpoint('crtAttached');self.phase='exeEntry';self.finished=False;self.put(SP,STOP);self.u.reg_write(UC_X86_REG_ESP,SP)
        self.u.emu_start(0x445560,0,count=2000000)
        assert self.finished;self.checkpoint('winMainEntry');self.active=False

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--missing-kernel',action='store_true');a=p.parse_args();path=ROOT/a.output;assert not path.exists(),path
    vm=CRTStartup(kernel_available=not a.missing_kernel);failure=None
    try:vm.run()
    except Exception as e:failure=repr(e)
    report=dict(scope=__doc__,exeSHA256=EXE_SHA256,libSHA256=LIB_SHA256,crtSHA256=DLL_SHA256,phase=vm.phase,finished=getattr(vm,'finished',False),failure=failure,commandLine=vm.command.hex(),showFlags=vm.show_flags,show=vm.show,
        end=dict(pc=vm.u.reg_read(UC_X86_REG_EIP),sp=vm.u.reg_read(UC_X86_REG_ESP),fpcw=vm.u.reg_read(UC_X86_REG_FPCW)),recent=list(vm.recent),events=vm.events,writes=vm.writes,allocations=list(vm.allocs.values()),patches=vm.patches,initializers=vm.game_initializers,checkpoints=vm.checkpoints,
        instructions=[dict(address=x,bytes=vm.instruction_bytes[x]) for x in sorted(vm.instructions)],nativeCompared=False,windowsVerified=False)
    raw=(json.dumps(report,sort_keys=True,separators=(',',':'))+'\n').encode();path.write_bytes(raw)
    print(json.dumps(dict(path=str(path.relative_to(ROOT)),sha256=digest(raw),bytes=len(raw),failure=failure,phase=vm.phase,**report['end'],initializers=vm.game_initializers,events=len(vm.events),instructions=len(vm.instructions)),indent=2))
    if failure:raise SystemExit(1)
if __name__=='__main__':main()
