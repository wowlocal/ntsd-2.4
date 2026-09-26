#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4"]
# ///
"""Run only the new menu-text collector with synthetic owned Win32/COM objects.

No original EXE/DLL, actual Windows or Native renderer executes. All pixel/font
responses here are artificial control markers, never compatibility references.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct
from build_windows_menu_text_probe import IMPORTS
from build_windows_nls_probe import inspect_pe
from test_windows_nls_probe import CollectorTest,API_BASE,STACK
from verify_windows_menu_text_capture import verify_raw
from unicorn import Uc,UC_ARCH_X86,UC_MODE_32,UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_ESP,UC_X86_REG_EIP,UC_X86_REG_EAX

DATA=0x50000000
PIXELS=DATA+0x10000
DYNAMIC={'RegisterClassW':1,'CreateWindowExW':12,'DestroyWindow':1,'UnregisterClassW':2,
         'DefWindowProcW':4,'DirectDrawCreate':3,'GetCurrentObject':2,'GetObjectW':3,
         'GetTextMetricsW':2,'GetTextFaceW':3,'GetDeviceCaps':2,'GetTextCharset':1,
         'GetTextAlign':1,'GetMapMode':1,'GetBkMode':1,'GetTextColor':1,'GetBkColor':1,
         'GetViewportOrgEx':2,'GetWindowOrgEx':2,'GetViewportExtEx':2,'GetWindowExtEx':2,
         'SetBkMode':2,'SetTextColor':2,'GetTextExtentPoint32A':4,'TextOutA':5,'IsWow64Process2':3}
COM={'Release':1,'SetCooperativeLevel':3,'CreateSurface':4,'Blt':6,'GetDC':2,
     'GetPixelFormat':2,'Lock':5,'ReleaseDC':2,'Unlock':2}
STIMULI=('complete','negative-pitch','bpp16','bpp24','short-write','module-failure',
         'missing-function','register-failure','window-failure','dd-failure',
         'cooperative-failure','primary-failure','primary-failure-output',
         'back-failure','back-failure-output','fill-failure','lock-failure',
         'descriptor-boundary','null-pixels','unlock-failure','dc-failure',
         'positive-dc','null-dc','font-failure','metadata-failure','text-failure',
         'release-dc-failure','cleanup-failure','existing','write-failure',
         'write-zero','flush-failure','close-failure')


class MenuTextTest(CollectorTest):
    def __init__(self,exe,stimulus,lines):
        self.stimulus,self.lines,self.width=stimulus,lines,4
        self.raw=bytearray();self.exit=None;self.error=0;self.requests=[];self.write_count=0
        self.locked=False;self.dc=False;self.drawn=[];self.acquisitions=0;self.creations=0
        self.meta=inspect_pe(exe,0x14c,IMPORTS);self.u=Uc(UC_ARCH_X86,UC_MODE_32)
        b=exe.read_bytes();pe=struct.unpack_from('<I',b,0x3c)[0];opt=pe+24
        base=struct.unpack_from('<I',b,opt+28)[0];extent=struct.unpack_from('<I',b,opt+56)[0]
        self.u.mem_map(base,extent);self.u.mem_write(base,b[:0x400])
        for s in self.meta['sections']:
            if s['rawSize']:self.u.mem_write(base+s['rva'],b[s['rawOffset']:s['rawOffset']+s['rawSize']])
        self.u.mem_map(API_BASE,0x1000);self.u.mem_map(STACK,0x100000);self.u.mem_map(DATA,0x400000)
        self.u.reg_write(UC_X86_REG_ESP,STACK+0xff000)
        iat=struct.unpack_from('<I',b,opt+96+12*8)[0];self.boundaries={}
        for i,item in enumerate(self.meta['imports']):
            pc=API_BASE+i*16;self.boundaries[pc]=(item['name'],IMPORTS[item['name']]//4);self.put(base+iat+i*4,pc)
        self.symbols={n:API_BASE+(64+i)*16 for i,n in enumerate(DYNAMIC)}
        self.com={n:API_BASE+(128+i)*16 for i,n in enumerate(COM)}
        for n,pc in self.symbols.items():self.boundaries[pc]=(n,DYNAMIC[n])
        for n,pc in self.com.items():self.boundaries[pc]=(n,COM[n])
        self.objects={'draw':DATA,'primary':DATA+0x100,'back':DATA+0x200}
        for name,address in self.objects.items():
            vtable=address+0x1000;self.put(address,vtable)
            table={2:'Release',6:'CreateSurface',20:'SetCooperativeLevel'} if name=='draw' else {2:'Release',5:'Blt',17:'GetDC',21:'GetPixelFormat',25:'Lock',26:'ReleaseDC',32:'Unlock'}
            for slot,symbol in table.items():self.put(vtable+slot*4,self.com[symbol])
        self.bpp=32 if stimulus=='complete' else 24 if stimulus=='bpp24' else 16 if stimulus in ('bpp16','negative-pitch') else 8
        self.row=794*self.bpp//8;self.pitch=self.row+12
        if stimulus=='negative-pitch':self.pitch=-self.pitch
        self.pixelPointer=PIXELS+(549*abs(self.pitch) if self.pitch<0 else 0)
        self.format=[32,0x40 if self.bpp!=8 else 0x60,0,self.bpp,0xff0000,0xff00,0xff,0]
        self.u.hook_add(UC_HOOK_CODE,self.api,begin=API_BASE,end=API_BASE+0xfff)
        self.entry=base+self.meta['entryRVA']

    def expected_pixels(self,after):
        data=bytearray((x+y*3)%251 for y in range(550) for x in range(self.row))
        if after:
            for i in self.drawn:
                x,y=self.lines[i]['arguments'][1:3];data[y*self.row+x*self.bpp//8]=0xf0+i
        return bytes(data)

    def api(self,u,pc,size,data):
        name,argc=self.boundaries[pc];sp=u.reg_read(UC_X86_REG_ESP);a=[self.integer(sp+4+i*4) for i in range(argc)]
        if name!='WriteFile':self.requests.append(dict(api=name,arguments=a))
        r=1;s=self.stimulus
        if name=='ExitProcess':self.exit=a[0];u.emu_stop();return
        elif name=='SetLastError':self.error=a[0];r=0
        elif name=='GetLastError':r=self.error
        elif name=='CreateFileW':
            assert self.string(a[0],True)=='menu-text.json' and a[1:]==[0x40000000,0,0,1,0x80,0]
            r=0xffffffff if s=='existing' else 0x1234
        elif name=='WriteFile':
            h,p,n,w,overlap=a;assert h==0x1234 and not overlap;self.write_count+=1
            if s in ('write-failure','write-zero') and self.write_count==8:self.put(w,0);r=int(s=='write-zero')
            else:
                if s=='short-write' and self.write_count%11==1:n=min(n,7)
                self.raw.extend(u.mem_read(p,n));self.put(w,n)
        elif name in ('FlushFileBuffers','CloseHandle'):
            assert a==[0x1234];r=int(not(s=='flush-failure' and name=='FlushFileBuffers') and not(s=='close-failure' and name=='CloseHandle'))
        elif name=='LoadLibraryExW':
            assert a[1:]==[0,0x800];path=self.string(a[0],True)
            r={'user32.dll':0x1100,'gdi32.dll':0x1200,'ddraw.dll':0x1300}[path]
            if s=='module-failure' and path=='ddraw.dll':r=0
        elif name=='FreeLibrary':assert a[0] in (0x1100,0x1200,0x1300)
        elif name=='GetModuleHandleW':
            assert a[0]==0 or self.string(a[0],True)=='kernel32.dll';r=0x1000 if a[0] else 0x400000
        elif name=='GetProcAddress':
            symbol=self.string(a[1]);assert symbol in self.symbols
            expected=0x1000 if symbol=='IsWow64Process2' else 0x1300 if symbol=='DirectDrawCreate' else 0x1100 if symbol in ('RegisterClassW','CreateWindowExW','DestroyWindow','UnregisterClassW','DefWindowProcW') else 0x1200
            assert a[0]==expected;r=0 if s=='missing-function' and symbol=='GetTextFaceW' else self.symbols[symbol]
        elif name=='GetModuleFileNameW':
            assert a[0] in (0x1000,0x1100,0x1200,0x1300) and a[2]==1024
            path='C:\\SYNTHETIC-NOT-WINDOWS\\'+{0x1000:'kernel32',0x1100:'user32',0x1200:'gdi32',0x1300:'ddraw'}[a[0]]+'.dll';u.mem_write(a[1],(path+'\0').encode('utf-16le'));r=len(path)
        elif name in ('GetACP','GetOEMCP'):r=0xf001
        elif name=='GetCurrentProcess':r=0xffffffff
        elif name=='IsWow64Process2':assert a[0]==0xffffffff;self.put(a[1],332,2);self.put(a[2],0xaa64,2)
        elif name=='RegisterClassW':
            c=struct.unpack('<10I',bytes(u.mem_read(a[0],40)))
            assert c[:9]==(3,self.symbols['DefWindowProcW'],0,0,0x400000,0,0,0,0) and self.string(c[9],True)=='NTSD Menu Text Observer'
            r=0 if s=='register-failure' else 0x2345
        elif name=='CreateWindowExW':
            assert a[0]==0 and self.string(a[1],True)==self.string(a[2],True)=='NTSD Menu Text Observer'
            assert a[3:]==[0x10cb0000,0x80000000,5,794,550,0,0,0x400000,0];r=0 if s=='window-failure' else 0x5000
        elif name=='DestroyWindow':assert a==[0x5000];r=int(s!='cleanup-failure')
        elif name=='UnregisterClassW':assert self.string(a[0],True)=='NTSD Menu Text Observer' and a[1]==0x400000;r=int(s!='cleanup-failure')
        elif name=='DirectDrawCreate':assert a[0]==a[2]==0;self.put(a[1],0 if s=='dd-failure' else DATA);r=-1 if s=='dd-failure' else 0
        elif name=='SetCooperativeLevel':assert a==[DATA,0x5000,8];r=-1 if s=='cooperative-failure' else 0
        elif name=='CreateSurface':
            assert a[0]==DATA and a[3]==0;self.creations+=1
            d=list(struct.unpack('<27I',bytes(u.mem_read(a[1],108))));expected=[0]*27;expected[0]=108
            if self.creations==1:expected[1]=1;expected[26]=0x200;kind='primary'
            else:assert self.creations==2;expected[1:4]=[7,550,794];expected[26]=0x40;kind='back'
            assert d==expected
            failure=s in (kind+'-failure',kind+'-failure-output');r=-1 if failure else 0
            self.put(a[2],0xdead0000 if s==kind+'-failure-output' else 0 if failure else self.objects[kind])
        elif name=='GetPixelFormat':
            assert a[0]==self.objects['back'] and bytes(u.mem_read(a[1],32))==struct.pack('<I',32)+b'\xa5'*28
            u.mem_write(a[1],struct.pack('<8I',*self.format));r=0
        elif name=='Blt':
            assert a[0]==self.objects['back'] and a[2:5]==[0,0,0x1000400]
            assert struct.unpack('<4I',bytes(u.mem_read(a[1],16)))==(0,0,794,550)
            fx=list(struct.unpack('<25I',bytes(u.mem_read(a[5],100))));expected=[0]*25;expected[0]=100;expected[20]=0x10206c;assert fx==expected
            raw=self.expected_pixels(False)
            for y in range(550):u.mem_write(self.pixelPointer+y*self.pitch,raw[y*self.row:(y+1)*self.row])
            r=-1 if s=='fill-failure' else 0
        elif name=='Lock':
            assert not self.dc and not self.locked and a[0]==self.objects['back'] and a[1]==0 and a[3:]==[17,0]
            assert bytes(u.mem_read(a[2],108))==struct.pack('<I',108)+b'\xa5'*104
            r=-1 if s=='lock-failure' else 0
            if r==0:
                self.locked=True;d=[0]*27;d[:5]=[108,0x180f,550,794,self.pitch&0xffffffff];d[9]=self.pixelPointer;d[18:26]=self.format;d[26]=0x40
                if s=='descriptor-boundary':d[4]=50000
                if s=='null-pixels':d[9]=0
                u.mem_write(a[2],struct.pack('<27I',*d))
        elif name=='Unlock':
            assert self.locked and a==[self.objects['back'],0 if s=='null-pixels' else self.pixelPointer]
            r=-1 if s=='unlock-failure' else 0
            if r==0:self.locked=False
        elif name=='GetDC':
            assert not self.dc and not self.locked and a[0]==self.objects['back'];self.acquisitions+=1
            r=-1 if s=='dc-failure' else 1 if s=='positive-dc' else 0
            self.put(a[1],0 if s in ('dc-failure','null-dc') else 0x6000+self.acquisitions)
            self.dc=r>=0 and s!='null-dc'
        elif name=='ReleaseDC':
            assert self.dc and a==[self.objects['back'],0x6000+self.acquisitions];r=-1 if s=='release-dc-failure' else 0
            if r==0:self.dc=False
        elif name=='Release':
            assert a[0] in self.objects.values();r=17 if s=='cleanup-failure' else 0
        elif name=='GetCurrentObject':assert self.dc and a==[0x6000+self.acquisitions,6];r=0 if s=='font-failure' else 0x7000
        elif name=='GetObjectW':
            assert a[:2]==[0x7000,92] and bytes(u.mem_read(a[2],92))==b'\xa5'*92
            r=0 if s=='metadata-failure' else 92
            if r:u.mem_write(a[2],bytes(range(92)))
        elif name=='GetTextMetricsW':
            assert self.dc and a[0]==0x6000+self.acquisitions and bytes(u.mem_read(a[1],60))==b'\xa5'*60
            r=int(s!='metadata-failure')
            if r:u.mem_write(a[1],bytes(range(60)))
        elif name=='GetTextFaceW':
            assert self.dc and a[:2]==[0x6000+self.acquisitions,256]
            nameBytes='SYNTHETIC-NOT-WINDOWS\0'.encode('utf-16le');r=0 if s=='metadata-failure' else len(nameBytes)//2
            if r:u.mem_write(a[2],nameBytes)
        elif name=='GetDeviceCaps':assert self.dc and a[0]==0x6000+self.acquisitions and a[1] in (2,8,10,12,14,38,88,90,104,117,118);r=0xf000+a[1]
        elif name in ('GetTextCharset','GetTextAlign','GetMapMode','GetBkMode','GetTextColor','GetBkColor'):
            assert self.dc and a==[0x6000+self.acquisitions];r=0xf002
        elif name in ('GetViewportOrgEx','GetWindowOrgEx','GetViewportExtEx','GetWindowExtEx'):
            assert self.dc and a[0]==0x6000+self.acquisitions and bytes(u.mem_read(a[1],8))==b'\xa5'*8
            r=int(s!='metadata-failure')
            if r:u.mem_write(a[1],struct.pack('<ii',-71,139))
        elif name=='GetTextExtentPoint32A':
            assert self.dc and a[0]==0x6000+self.acquisitions
            row=self.lines[self.acquisitions-1];assert a[2]==row['arguments'][3] and bytes(u.mem_read(a[1],a[2]))==bytes(row['strings'][0])
            assert bytes(u.mem_read(a[3],8))==b'\xa5'*8;r=int(s!='metadata-failure')
            if r:u.mem_write(a[3],struct.pack('<ii',321,17))
        elif name in ('SetBkMode','SetTextColor'):
            assert self.dc and a==[0x6000+self.acquisitions,1 if name=='SetBkMode' else 0xd07750];r=2 if name=='SetBkMode' else 0xffffff
        elif name=='TextOutA':
            assert self.dc and a[0]==0x6000+self.acquisitions
            i=self.acquisitions-1;row=self.lines[i];assert [a[1],a[2],a[4]]==row['arguments'][1:] and bytes(u.mem_read(a[3],a[4]))==bytes(row['strings'][0])
            r=int(s!='text-failure')
            if r:self.drawn.append(i);u.mem_write(self.pixelPointer+a[2]*self.pitch+a[1]*self.bpp//8,bytes([0xf0+i]))
        else:raise AssertionError(name)
        ret=self.integer(sp);u.reg_write(UC_X86_REG_ESP,sp+4+argc*4);u.reg_write(UC_X86_REG_EAX,r&0xffffffff);u.reg_write(UC_X86_REG_EIP,ret)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--kit',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    assert not a.output.exists();a.output.mkdir(parents=True)
    (a.output/'finite-cases.json').write_text(json.dumps(dict(stimuli=STIMULI,synthetic=True,maxInstructions=300000000,originalExecuted=False),indent=2)+'\n')
    source=json.loads((a.kit/'first-menu1.json').read_bytes());lines=[v['command']['event'] for v in source['front'] if v['command']['event']['kind']=='textOut']
    results=[]
    no_lines={'module-failure','missing-function','register-failure','window-failure','dd-failure','cooperative-failure','primary-failure','primary-failure-output','back-failure','back-failure-output','fill-failure','unlock-failure'}
    for stimulus in STIMULI:
        vm=MenuTextTest(a.kit/'probe-windows-menu-text-x86.exe',stimulus,lines);failure=None
        try:vm.u.emu_start(vm.entry,0,count=300000000)
        except Exception as e:failure=repr(e)
        envelope=dict(synthetic=True,WindowsExecuted=False,originalExecuted=False,stimulus=stimulus,exitCode=vm.exit,failure=failure,writeCalls=vm.write_count,rawSHA256=hashlib.sha256(vm.raw).hexdigest(),rawBytes=len(vm.raw),rawBase64=base64.b64encode(vm.raw).decode(),requests=vm.requests)
        (a.output/(stimulus+'.json')).write_text(json.dumps(envelope,sort_keys=True)+'\n')
        assert failure is None and vm.exit is not None,failure
        assert vm.exit=={'existing':21,'write-failure':22,'write-zero':22,'flush-failure':23,'close-failure':23}.get(stimulus,0)
        if stimulus not in ('existing','write-failure','write-zero'):
            raw=json.loads(vm.raw);verified=verify_raw(raw,lines)
            assert len(verified['lines'])==(0 if stimulus in no_lines else 1 if stimulus in ('null-dc','release-dc-failure') else 3)
            for label,after in [('beforeText',False),('afterText',True)]:
                if label in raw and raw[label]['storageAccepted']:
                    assert bytes.fromhex(raw[label]['pixelsTopLeft'])==vm.expected_pixels(after)
            if 'primary-failure' in stimulus:assert 'releasePrimary' not in raw and 'releaseBack' not in raw
            if 'back-failure' in stimulus:assert 'releasePrimary' in raw and 'releaseBack' not in raw
            if stimulus in ('unlock-failure','release-dc-failure','null-dc'):assert 'afterText' not in raw
            if stimulus in ('descriptor-boundary','null-pixels'):assert not any(s['outcome']=='owned-pixels-observed' for s in verified['snapshots'].values())
            if stimulus=='dc-failure':assert not any(r['api']=='TextOutA' for r in vm.requests)
            if stimulus=='text-failure':assert verified['changedPixelStorageBytes']==0
            if verified['changedPixelStorageBytes'] is not None and stimulus!='text-failure':assert verified['changedPixelStorageBytes']==len(vm.drawn)
        elif stimulus=='existing':assert not vm.raw and not any(r['api']=='LoadLibraryExW' for r in vm.requests)
        else:
            assert vm.raw
            try:json.loads(vm.raw)
            except json.JSONDecodeError:pass
            else:raise AssertionError('Incomplete IO parsed as complete output')
        results.append(dict(stimulus=stimulus,exitCode=vm.exit,rawBytes=len(vm.raw),rawSHA256=hashlib.sha256(vm.raw).hexdigest()))
        print(stimulus,'PASS',flush=True)
    (a.output/'report.json').write_text(json.dumps(dict(tests=results,synthetic=True,WindowsExecuted=False,originalExecuted=False,compatibilityAccepted=False),indent=2)+'\n')
    print(json.dumps(dict(tests=len(results),output=str(a.output))))


if __name__=='__main__':main()
