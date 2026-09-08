#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Execute the complete source catalog with real enabled WAV children in one CPU.

Same actual Object/Frame/weapon cache lookups, shared count/paths and4014e0.
The existing MMIO/COM adapter attaches to the parent's live stack. No Windows
DLL/device output claim; new captures do not rewrite the disabled-audio corpus.
"""
import argparse
import base64
import json
import struct
import subprocess
import zlib
from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, ROOT
from oracle_loaded_catalog import LoadedCatalog, INTERLEAVED
from oracle_wave_loader import WaveLoader, platform, DEVICE, VTABLE, FIRST, SECOND, GLOBAL, GLOBAL_SIZE, digest
from oracle_state import STACK, STOP
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EBP, UC_X86_REG_ECX, UC_X86_REG_ESI, UC_X86_REG_EDI, UC_X86_REG_ESP

REGISTERS=[UC_X86_REG_EBX,UC_X86_REG_EBP,UC_X86_REG_ESI,UC_X86_REG_EDI]


class SoundCatalog(LoadedCatalog):
    def __init__(self):
        super().__init__()
        # This hook precedes the wave's temporary instruction hook, so caller
        # return disables wave-domain checking before execution resumes there.
        for pc in (0x4014E0,0x40BE1D,0x410A4D):self.uc.hook_add(UC_HOOK_CODE,self.sound_call,begin=pc,end=pc)
        self.wave=WaveLoader(uc=self.uc);self.sound_calls=[];self.sound_sources={};self.sound_pending=None;self.wave_hooks=[]
        self.put(0x44EECC,DEVICE);self.put(VTABLE+0x3C,STOP+0xB00)
        self.uc.hook_add(UC_HOOK_CODE,self.sound_volume,begin=STOP+0xB00,end=STOP+0xB00)
        for pc in (0x4450A6,0x4450C2):self.uc.hook_add(UC_HOOK_CODE,self.wave_crt,begin=pc,end=pc)

    def checkpoint(self,uc,address,size,data):
        if getattr(self,'wave',None) is not None and self.wave.running:
            assert address==0x4450AC
            self.wave.crt(uc,address,size,data);return
        super().checkpoint(uc,address,size,data)
    def wave_crt(self,uc,address,size,data):
        assert self.wave.running
        self.wave.crt(uc,address,size,data)
    def sound_call(self,uc,address,size,data):
        w=self.wave;sp=uc.reg_read(UC_X86_REG_ESP)
        if address==0x4014E0:
            assert self.sound_pending is None
            index=self.u32(0x458438);destination=uc.reg_read(UC_X86_REG_ECX)
            assert destination==0x452948+index*4
            path=self.cstr(self.u32(sp+4));raw=(DEFAULT_SOURCE/path.decode('latin1').replace('\\','/')).read_bytes()
            kind={0x40BE1D:'weapon',0x410A4D:'frame'}[self.u32(sp)]
            w.path=path;w.raw=raw;w.p=platform(raw,index,destination=destination);w.wave_entry_sp=sp
            w.put(w.p['buffer'],VTABLE)
            w.regions={};w.events=[];w.device_format=w.descriptor=None;w.descents=w.reads=w.locks=0;w.stack_mask=bytearray(0x10000)
            w.region('first',FIRST,w.p['firstCount'])
            if w.p['secondPointer']:w.region('second',SECOND,w.p['secondCount'])
            self.sound_pending=dict(index=index,kind=kind,path=list(path),file=w.blob(raw),input=w.p,
                beforeGlobals=w.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),outputBefore=self.u32(destination),
                cacheBefore=w.blob(uc.mem_read(0x455638,0x2E00)),entrySP=sp,returnAddress=self.u32(sp),
                savedBefore=[uc.reg_read(r) for r in REGISTERS],objectPath=self.pending['path'])
            self.sound_sources[path.decode('latin1')]=dict(path=path.decode('latin1'),sha256=digest(raw),bytes=len(raw))
            w.running=True
            self.wave_hooks=[uc.hook_add(UC_HOOK_MEM_WRITE,w.stack_written,begin=STACK,end=STACK+0xFFFF),uc.hook_add(UC_HOOK_CODE,w.allowed)]
        else:
            item=self.sound_pending;assert item is not None and item['returnAddress']==address
            assert sp==item['entrySP']+8 and [uc.reg_read(r) for r in REGISTERS]==item['savedBefore']
            item.update(afterGlobals=w.blob(uc.mem_read(GLOBAL,GLOBAL_SIZE)),outputAfter=self.u32(w.p['destination']),
                returned=uc.reg_read(UC_X86_REG_EAX),stackAfter=sp,savedAfter=[uc.reg_read(r) for r in REGISTERS],
                temporary=w.record('temporary'),temporaryLive=w.regions.get('temporary',{}).get('live',False),
                first=w.record('first'),second=w.record('second'),format=w.device_format,descriptor=w.descriptor,events=w.events)
            assert item['returned']==1 and item['outputAfter']!=0, 'Full-source audio failed before unsafe SetVolume'
            w.running=False
            for hook in self.wave_hooks:uc.hook_del(hook)
            self.wave_hooks=[];self.sound_pending=None;self.sound_calls.append(item)
    def sound_volume(self,uc,address,size,data):
        item=self.sound_calls[-1];sp=uc.reg_read(UC_X86_REG_ESP)
        args=[self.u32(sp+4),self.u32(sp+8)]
        assert args==[item['outputAfter'],0xFFFFD8F0] and 'volume' not in item
        assert self.u32(0x458438)==item['index']
        item['volume']=args;self.ret(-1,8)


def pack(doc):
    raw=json.dumps(doc,separators=(',',':')).encode()
    return json.dumps(dict(count=len(raw),sha256=digest(raw),deflate=base64.b64encode(zlib.compress(raw,level=9,wbits=-15)).decode()),separators=(',',':'))+'\n'


def check_wave_parent():
    report=json.loads((ROOT/'docs/evidence/wave-loader.json').read_text())
    raw=(ROOT/'build/original'/report['corpus']).read_bytes();assert digest(raw)==report['corpusSHA256']
    doc=json.loads(raw);vm=WaveLoader()
    for item in doc['cases']:
        b=doc['blobs'][item['file']];file=zlib.decompress(base64.b64decode(b['deflate']),wbits=-15)
        assert vm.run(item['label'],bytes(item['path']),file,item['input'])==item,item['label']
    for item in doc['startups']:assert vm.startup(item['mode'])==item
    assert vm.blobs==doc['blobs']
    print('Historical WAV corpus reproduced:431 cases,3 initial sound passes and every blob',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--interleaved',action='store_true');parser.add_argument('--accept',action='store_true');parser.add_argument('--check-wave-parent',action='store_true');args=parser.parse_args()
    if args.check_wave_parent:check_wave_parent();return
    if args.accept:accept();return
    vm=SoundCatalog();catalog=vm.run(INTERLEAVED if args.interleaved else None,0xFFFFF123 if args.interleaved else 0)
    assert vm.sound_pending is None and len(vm.sound_calls)==catalog['soundCount'] and all('volume' in c for c in vm.sound_calls)
    sounds=dict(exeSHA256=EXE_SHA256,calls=vm.sound_calls,sources=list(vm.sound_sources.values()),blobs=vm.wave.blobs,
        finalBuffers=vm.blob(vm.uc.mem_read(0x452948,4*catalog['soundCount'])),scope=__doc__)
    # final buffer bytes belong to the sound transport, not the catalog's blobs.
    sounds['finalBuffers']=vm.wave.blob(vm.uc.mem_read(0x452948,4*catalog['soundCount']))
    suffix='-interleaved' if args.interleaved else ''
    cp=ROOT/'build/original'/f'loaded-catalog-audio{suffix}.json';sp=ROOT/'build/original'/f'catalog-sounds{suffix}.json'
    cp.write_text(json.dumps(catalog,separators=(',',':'))+'\n');sp.write_text(json.dumps(sounds,separators=(',',':'))+'\n')
    report=dict(exeSHA256=EXE_SHA256,catalog=cp.name,catalogSHA256=digest(cp.read_bytes()),sounds=sp.name,soundsSHA256=digest(sp.read_bytes()),
        calls=len(vm.sound_calls),sources=len(vm.sound_sources),nativeComparison='pending')
    (ROOT/'docs/evidence'/f'catalog-sounds{suffix}.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Captured',len(vm.sound_calls),'real catalog WAV calls',flush=True)


def accept():
    subprocess.run(['swift','build','--package-path',str(ROOT/'native'),'-c','release','--product','NTSDCatalogCheck'],check=True)
    for suffix in ('','-interleaved'):
        rp=ROOT/'docs/evidence'/f'catalog-sounds{suffix}.json';report=json.loads(rp.read_text());pending={}
        for key in ('catalog','sounds'):
            raw=(ROOT/'build/original'/report[key]).read_bytes();assert digest(raw)==report[key+'SHA256']
            doc=json.loads(raw)
            if key=='catalog':
                doc.pop('scans');doc.pop('readsBeforeWrites');doc['events']=[e for e in doc['events'] if e['kind']=='mirror-blit']
            temporary=ROOT/'build/original'/f'{key}-audio-check{suffix}.json';temporary.write_text(pack(doc));pending[key]=temporary
        result=subprocess.run([str(ROOT/'native/.build/release/NTSDCatalogCheck'),'--catalog-sounds',str(pending['catalog']),str(pending['sounds'])],capture_output=True,text=True)
        print(result.stdout,end='',flush=True)
        if result.returncode:print(result.stderr,end='',flush=True);result.check_returncode()
        for key in ('catalog','sounds'):
            fixture=ROOT/'native/Tests/NTSDCoreTests/Fixtures'/('original-'+report[key]);fixture.write_bytes(pending[key].read_bytes())
            report[key+'Fixture']=fixture.name;report[key+'FixtureSHA256']=digest(fixture.read_bytes());report[key+'FixtureBytes']=fixture.stat().st_size
        report['nativeComparison']=result.stdout.strip();rp.write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
