#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Execute only our new collector on synthetic APIs, never Windows or the game.

Reuses the retained NLS test's byte/string primitives; PE loading and the finite
cursor API stimuli are explicit here. Artificial resource/palette/storage bytes
must never become source/Native expected results. Every partial result is kept.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
from build_windows_cursor_bitmap_probe import IMPORTS
from build_windows_nls_probe import inspect_pe
from test_windows_nls_probe import CollectorTest, API_BASE, STACK
from verify_windows_cursor_bitmap_capture import verify_raw
from unicorn import Uc, UC_ARCH_X86, UC_ARCH_ARM64, UC_MODE_32, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ESP, UC_X86_REG_EAX, UC_X86_REG_EIP
from unicorn.arm64_const import UC_ARM64_REG_SP, UC_ARM64_REG_PC, UC_ARM64_REG_LR, UC_ARM64_REG_X0

RESOURCE = b'SYNTHETIC RESOURCE; NOT NTSD OR WINDOWS\x00'
DATA = 0x50000000
DYNAMIC = {'IsWow64Process2': 3, 'LoadImageA': 6, 'GetObjectW': 3,
           'CreateCompatibleDC': 1, 'SelectObject': 2, 'GetDIBColorTable': 4,
           'DeleteDC': 1, 'DeleteObject': 1, 'GetDeviceCaps': 2}
STIMULI = ('complete', 'short-write', 'module-failure', 'resource-failure',
           'resource-size-boundary', 'resource-load-failure', 'resource-lock-failure',
           'system-module-failure', 'missing-function', 'bitmap-failure',
           'query-failure', 'descriptor-boundary', 'null-bits', 'top-down',
           'dc-failure', 'selection-failure', 'palette-failure', 'partial-palette',
           'palette-coverage', 'restore-failure', 'cleanup-failure', 'storage-change',
           'existing', 'write-failure', 'write-zero', 'flush-failure', 'close-failure')


class CursorCollectorTest(CollectorTest):
    def __init__(self, exe, machine, stimulus):
        self.machine, self.stimulus = machine, stimulus
        self.raw = bytearray(); self.exit = None; self.error = 0; self.requests = []
        self.write_count = 0; self.load_count = 0; self.selected = {}
        self.width = 4 if machine == 0x14c else 8
        self.meta = inspect_pe(exe, machine, IMPORTS)
        self.u = Uc(UC_ARCH_X86, UC_MODE_32) if self.width == 4 else Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        b = exe.read_bytes(); pe = struct.unpack_from('<I', b, 0x3c)[0]; opt = pe + 24
        base = int.from_bytes(b[opt + (28 if self.width == 4 else 24):][:self.width], 'little')
        extent = struct.unpack_from('<I', b, opt + 56)[0]
        self.u.mem_map(base, extent); self.u.mem_write(base, b[:0x400])
        for s in self.meta['sections']:
            if s['rawSize']: self.u.mem_write(base+s['rva'], b[s['rawOffset']:s['rawOffset']+s['rawSize']])
        self.u.mem_map(API_BASE, 0x1000); self.u.mem_map(STACK, 0x100000)
        self.u.mem_map(DATA, 0x10000); self.u.mem_write(DATA, RESOURCE)
        self.u.reg_write(UC_X86_REG_ESP if self.width == 4 else UC_ARM64_REG_SP, STACK+0xff000)
        directories = opt+(96 if self.width == 4 else 112)
        iat = struct.unpack_from('<I', b, directories+12*8)[0]
        self.boundaries = {}
        for i, item in enumerate(self.meta['imports']):
            pc = API_BASE+i*16; self.boundaries[pc]=(item['name'], IMPORTS[item['name']]//4)
            self.u.mem_write(base+iat+i*self.width, pc.to_bytes(self.width, 'little'))
        self.symbols = {name: API_BASE+(64+i)*16 for i, name in enumerate(DYNAMIC)}
        for name, pc in self.symbols.items(): self.boundaries[pc]=(name, DYNAMIC[name])
        self.u.hook_add(UC_HOOK_CODE, self.api, begin=API_BASE, end=API_BASE+0xfff)
        self.entry=base+self.meta['entryRVA']

    def api(self, u, pc, size, data):
        name, argc = self.boundaries[pc]
        sp = u.reg_read(UC_X86_REG_ESP if self.width == 4 else UC_ARM64_REG_SP)
        a = [self.integer(sp+4+i*4) if self.width == 4 else u.reg_read(UC_ARM64_REG_X0+i) for i in range(argc)]
        if name != 'WriteFile': self.requests.append(dict(api=name, arguments=a))
        r = 1
        if name == 'ExitProcess': self.exit=a[0]; u.emu_stop(); return
        elif name == 'SetLastError': self.error=a[0]; r=0
        elif name == 'GetLastError': r=self.error
        elif name == 'CreateFileW':
            assert self.string(a[0], True)=='cursor.json' and a[1:]==[0x40000000,0,0,1,0x80,0]
            r=(1 << (self.width*8))-1 if self.stimulus=='existing' else 0x1234
        elif name == 'WriteFile':
            h,p,n,w,overlap=a; assert h==0x1234 and not overlap; self.write_count+=1
            if self.stimulus in ('write-failure','write-zero') and self.write_count==8:
                self.put(w,0);r=int(self.stimulus=='write-zero')
            else:
                n=min(n,7) if self.stimulus=='short-write' else n
                self.raw.extend(u.mem_read(p,n));self.put(w,n)
        elif name in ('FlushFileBuffers','CloseHandle'):
            assert a==[0x1234]
            r=int(not (self.stimulus=='flush-failure' and name=='FlushFileBuffers')
                  and not (self.stimulus=='close-failure' and name=='CloseHandle'))
        elif name == 'LoadLibraryExW':
            path=self.string(a[0],True);assert a[1]==0
            assert a[2]==(0x60 if path=='.\\reference.exe' else 0x800)
            r={'user32.dll':0x1100,'gdi32.dll':0x1200,'.\\reference.exe':0x1301}[path]
            if (self.stimulus=='module-failure' and path=='.\\reference.exe') or (self.stimulus=='system-module-failure' and path=='user32.dll'):r=0
        elif name == 'FreeLibrary': assert a[0] in (0x1100,0x1200,0x1301)
        elif name == 'GetModuleHandleW': assert self.string(a[0],True)=='kernel32.dll';r=0x1000
        elif name == 'GetProcAddress':
            symbol=self.string(a[1]);assert symbol in DYNAMIC
            assert a[0]==(0x1000 if symbol=='IsWow64Process2' else 0x1100 if symbol=='LoadImageA' else 0x1200)
            r=0 if self.stimulus=='missing-function' and symbol=='GetObjectW' else self.symbols[symbol]
        elif name == 'GetModuleFileNameW':
            assert a[0] in (0x1000,0x1100,0x1200) and a[2]==1024
            path='C:\\SYNTHETIC-NOT-WINDOWS\\'+{0x1000:'kernel32',0x1100:'user32',0x1200:'gdi32'}[a[0]]+'.dll'
            u.mem_write(a[1],(path+'\0').encode('utf-16le'));r=len(path)
        elif name in ('GetACP','GetOEMCP'):r=0xf001
        elif name == 'GetCurrentProcess':r=(1 << (self.width*8))-1
        elif name == 'IsWow64Process2':self.put(a[1],0x14c if self.width==4 else 0,2);self.put(a[2],0xaa64,2)
        elif name == 'FindResourceA':
            assert a[0]==0x1301 and self.string(a[1])=='LF2_CURSOR' and a[2]==2
            r=0 if self.stimulus=='resource-failure' else 0x1400
        elif name == 'SizeofResource':assert a==[0x1301,0x1400];r=70000 if self.stimulus=='resource-size-boundary' else len(RESOURCE)
        elif name == 'LoadResource':assert a==[0x1301,0x1400];r=0 if self.stimulus=='resource-load-failure' else 0x1500
        elif name == 'LockResource':assert a==[0x1500];r=0 if self.stimulus=='resource-lock-failure' else DATA
        elif name == 'LoadImageA':
            assert a[0]==0x1301 and self.string(a[1])=='LF2_CURSOR' and a[2:]==[0,0,0,0x2000]
            self.load_count+=1;r=0 if self.stimulus=='bitmap-failure' else 0x2000+self.load_count
            u.mem_write(DATA+0x1000*self.load_count,bytes((i+(self.load_count-1)*5)%16 for i in range(228)))
        elif name == 'GetObjectW':
            handle,capacity,dest=a;assert handle==0x2000+self.load_count and capacity==(84 if self.width==4 else 104)
            assert bytes(u.mem_read(dest,capacity))==b'\xa5'*capacity
            if self.stimulus=='query-failure':r=0
            else:
                raw=bytearray(capacity);stride=5000 if self.stimulus=='descriptor-boundary' else 12
                struct.pack_into('<iiiiHH',raw,0,0,11,19,stride,1,8)
                bits=0 if self.stimulus=='null-bits' else DATA+self.load_count*0x1000
                offset=20 if self.width==4 else 24;raw[offset:offset+self.width]=bits.to_bytes(self.width,'little')
                struct.pack_into('<IiiHHIIiiII',raw,24 if self.width==4 else 32,40,11,-19 if self.stimulus=='top-down' else 19,1,8,0,228,0,0,256,0)
                u.mem_write(dest,bytes(raw));r=capacity
        elif name == 'CreateCompatibleDC':assert a==[0];r=0 if self.stimulus=='dc-failure' else 0x3000+self.load_count
        elif name == 'GetDeviceCaps':assert a[0]==0x3000+self.load_count and a[1] in (2,12,14,38,88,90);r=0xf100+a[1]
        elif name == 'SelectObject':
            dc,obj=a;assert dc==0x3000+self.load_count
            if obj==0x2000+self.load_count:
                r=0 if self.stimulus=='selection-failure' else 0x4000+self.load_count
                if r:self.selected[dc]=obj
            else:
                assert obj==0x4000+self.load_count and self.selected[dc]==0x2000+self.load_count
                r=0 if self.stimulus=='restore-failure' else self.selected.pop(dc)
        elif name == 'GetDIBColorTable':
            dc,first,count,dest=a;assert dc==0x3000+self.load_count and self.selected[dc]==0x2000+self.load_count and first==0 and count==256
            assert bytes(u.mem_read(dest,1024))==b'\xa5'*1024
            r=0 if self.stimulus=='palette-failure' else 16 if self.stimulus=='partial-palette' else 2 if self.stimulus=='palette-coverage' else 256
            if r:u.mem_write(dest,b''.join(bytes((i,(i+17)&255,(i+31)&255,0)) for i in range(r)))
            if self.stimulus=='storage-change':u.mem_write(DATA+self.load_count*0x1000,b'\xee')
        elif name == 'DeleteDC':
            assert a==[0x3000+self.load_count];r=int(self.stimulus!='cleanup-failure')
            if r:self.selected.pop(a[0],None)
        elif name == 'DeleteObject':assert a==[0x2000+self.load_count];r=int(self.stimulus!='cleanup-failure')
        else:raise AssertionError(name)
        if self.width==4:
            ret=self.integer(sp);u.reg_write(UC_X86_REG_ESP,sp+4+argc*4);u.reg_write(UC_X86_REG_EAX,r&0xffffffff);u.reg_write(UC_X86_REG_EIP,ret)
        else:u.reg_write(UC_ARM64_REG_X0,r);u.reg_write(UC_ARM64_REG_PC,u.reg_read(UC_ARM64_REG_LR))


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--kit',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
    a=p.parse_args();assert not a.output.exists();a.output.mkdir(parents=True)
    (a.output/'finite-cases.json').write_text(json.dumps(dict(stimuli=STIMULI,architectures=['x86','arm64'],maxInstructions=20000000,synthetic=True),indent=2)+'\n')
    results=[]
    no_attempts={'module-failure','resource-failure','resource-size-boundary','resource-load-failure','resource-lock-failure','system-module-failure','missing-function'}
    for arch,machine in (('x86',0x14c),('arm64',0xaa64)):
        for stimulus in STIMULI:
            vm=CursorCollectorTest(a.kit/('probe-windows-cursor-bitmap-'+arch+'.exe'),machine,stimulus);failure=None
            try:vm.u.emu_start(vm.entry,0,count=20000000)
            except Exception as e:failure=repr(e)
            envelope=dict(scope=__doc__,synthetic=True,windowsExecuted=False,gameExecuted=False,architecture=arch,stimulus=stimulus,exitCode=vm.exit,failure=failure,writeCalls=vm.write_count,rawBytes=len(vm.raw),rawSHA256=hashlib.sha256(vm.raw).hexdigest(),rawBase64=base64.b64encode(vm.raw).decode(),requests=vm.requests)
            (a.output/(arch+'-'+stimulus+'.json')).write_text(json.dumps(envelope,sort_keys=True)+'\n')
            assert failure is None and vm.exit is not None,failure
            expected={'existing':21,'write-failure':22,'write-zero':22,'flush-failure':23,'close-failure':23}.get(stimulus,0);assert vm.exit==expected
            if stimulus not in ('existing','write-failure','write-zero'):
                verified=verify_raw(json.loads(vm.raw),machine,resource_sha=hashlib.sha256(RESOURCE).hexdigest())
                assert len(verified['attempts'])==(0 if stimulus in no_attempts else 3)
                for result in verified['attempts']:
                    expected_outcome={'bitmap-failure':'load-failed','query-failure':'get-object-failed','descriptor-boundary':'collector-descriptor-boundary','null-bits':'collector-descriptor-boundary','dc-failure':'storage-only','selection-failure':'storage-only','palette-failure':'storage-only','palette-coverage':'palette-coverage-boundary'}.get(stimulus,'observed-rgb')
                    assert result['outcome']==expected_outcome
                    if expected_outcome=='observed-rgb':
                        expected_rgb=bytearray()
                        for y in range(19):
                            row=y if stimulus=='top-down' else 18-y
                            for x in range(11):
                                v=(row*12+x+result['index']*5)%16;expected_rgb.extend((v+31,v+17,v))
                        assert bytes.fromhex(result['rgbTopLeft'])==expected_rgb
                        assert result['changedStorageBytes']==int(stimulus=='storage-change')
                        assert result['deleteObjectResult']==int(stimulus!='cleanup-failure')
                    if expected_outcome in ('get-object-failed','collector-descriptor-boundary'):
                        assert not any(r['api']=='CreateCompatibleDC' for r in vm.requests)
                if stimulus in no_attempts:assert not any(r['api']=='LoadImageA' for r in vm.requests)
            elif stimulus=='existing':assert not vm.raw and not any(r['api']=='LoadLibraryExW' for r in vm.requests)
            else:
                assert vm.raw
                try:json.loads(vm.raw)
                except json.JSONDecodeError:pass
                else:raise AssertionError('Partial IO cannot be a complete capture')
            results.append(dict(architecture=arch,stimulus=stimulus,exitCode=vm.exit,rawBytes=len(vm.raw),rawSHA256=hashlib.sha256(vm.raw).hexdigest()))
    report=dict(scope=__doc__,synthetic=True,windowsExecuted=False,gameExecuted=False,compatibilityAccepted=False,tests=results)
    (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(tests=len(results),output=str(a.output),windowsExecuted=False,gameExecuted=False),indent=2))


if __name__=='__main__':main()
