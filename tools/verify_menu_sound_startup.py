#!/usr/bin/env python3
"""Independently verify immutable controlled menu-sound source artifacts.

Checks original EXE/WAV identities, exact executed bytes, library patch exclusion,
full global stores/masks/live request images, child returns and all PCM/allocator
blobs. Source emulation, controlled APIs, native acceptance and real Windows/device
evidence remain separate. No source recapture or expected-result rewriting.
"""
import argparse,base64,hashlib,json,re,struct,subprocess,zlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
H=lambda b:hashlib.sha256(b).hexdigest()
BASE,SIZE=0x44d000,0xb440
RANGES=[(0x43d08e,0x43d100),(0x401970,0x4019a9),(0x4014e0,0x40195f),(0x4450b2,0x4450bc),(0x43f384,0x43f38a)]

def unpack(path):
    raw=path.read_bytes();d=json.loads(raw)
    if set(d)=={'count','sha256','deflate'}:
        result=zlib.decompress(base64.b64decode(d['deflate']),-15)
        assert len(result)==d['count'] and H(result)==d['sha256'];return result,json.loads(result)
    return raw,d

def audit(path,fixture=None):
    path=path.resolve()
    if fixture is not None:fixture=fixture.resolve()
    raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
    assert d['exeSHA256']==EXE_SHA256
    assert H((DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes())==EXE_SHA256
    assert d['producerSHA256']==H(path.with_name(path.stem+'-source.py').read_bytes())==H((ROOT/'tools/oracle_menu_sound_startup.py').read_bytes())
    for n,h in d['dependencies'].items():assert H((ROOT/'tools'/n).read_bytes())==h
    assert d['adapterSHA256']==d['dependencies']['oracle_wave_loader.py']
    blobs={}
    for key,b in d['blobs'].items():
        payload=zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert len(payload)==b['count'] and H(payload)==key;blobs[key]=payload
    source_paths=['data\\m_join.wav','data\\m_ok.wav','data\\m_cancel.wav','data\\m_pass.wav','data\\m_end.wav']
    assert [s['path'] for s in d['sources']]==source_paths
    for s in d['sources']:
        content=(DEFAULT_SOURCE/s['path'].replace('\\','/')).read_bytes()
        assert H(content)==s['sha256'] and len(content)==s['count'] and blobs[s['sha256']]==content
    _,installer=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json')
    patches=installer['cases'][0]['patches'];assert len(patches)==13 and sum(p['count'] for p in patches)==62
    for p in patches:
        assert all(p['address']+p['count']<=start or p['address']>=end for start,end in RANGES)
    exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();pe=PE(exe)
    def exe_bytes(address,n):
        rva=address-0x400000
        s=next(s for s in pe.sections if s['rva']<=rva and rva+n<=s['rva']+s['fileSize'])
        o=s['fileOffset']+rva-s['rva'];return exe[o:o+n]
    static={}
    for start,end in RANGES:
        listing=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel',
            '--start-address='+hex(start),'--stop-address='+hex(end),str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
        for line in listing.splitlines():
            m=re.match(r'^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2} )+)\s*(.*)',line)
            if m:
                address=int(m[1],16);value=bytes.fromhex(m[2]);assert value==exe_bytes(address,len(value))
                static[address]=dict(bytes=value.hex(),assembly=m[3])
    union={};events=Counter();stores=Counter();ends=Counter();loads=Counter();temporary_live=0;helper_returns=0;compared_bytes=0
    assert len(d['cases'])==122
    parts=path.with_suffix('.parts');assert len(list(parts.glob('*.json')))==122
    for case_index,c in enumerate(d['cases']):
        checkpoint=json.loads((parts/f'{case_index+1:04d}.json').read_bytes());assert checkpoint['case']==c
        assert all(d['blobs'][key]==value for key,value in checkpoint['blobs'].items())
        before=blobs[c['beforeGlobals']];after=blobs[c['afterGlobals']];mask=blobs[c['globalMask']]
        assert len(before)==len(after)==len(mask)==SIZE and set(mask)<={0,1}
        state=bytearray(before);written=bytearray(SIZE);group={}
        for s in c['stores']:
            group.setdefault(s['eventIndex'],[]).append(s)
            assert s['origin'] in ('CPU','API') and len(bytes.fromhex(s['bytes']))==4
            if s['origin']=='CPU':assert hex(s['pc']) in c['instructions']
            else:assert s['pc']==0x30000500 and s['address']==0x44eecc
        assert set(group)<=set(range(len(c['events'])+1))
        for index in range(len(c['events'])+1):
            for s in group.get(index,[]):
                o=s['address']-BASE;payload=bytes.fromhex(s['bytes']);assert 0<=o<o+len(payload)<=SIZE
                state[o:o+len(payload)]=payload;written[o:o+len(payload)]=b'\1'*len(payload);stores[s['origin']]+=1
            if index<len(c['events']):
                e=c['events'][index];assert state==blobs[e['globals']]
                events[e['event']['wave']['kind'] if e['event']['wave'] else e['event']['kind']]+=1
        assert state==after and written==mask
        for a,value in c['instructions'].items():
            address=int(a,16);b=bytes.fromhex(value);assert address in static and b==exe_bytes(address,len(b))
            union[a]=value
        assert c['controlWord']==0x37f
        if c['exit']=='segmentEnd':
            assert c['endPC']==0x43d100 and c['stackAfter']==0x1000f00c and len(c['loads'])==5
            assert c['savedRegisters']==[0x11111111,0x22222222,0x33333333,0x44444444]
        else:assert c['exit']=='invalidCreateContinuation' and c['endPC']==0x40187a and c['loads'][-1]['exit']==c['exit']
        ends[c['exit']]+=1
        for h in c['helperReturns']:
            assert h['entry'] in (0x401970,0x4014e0)
            assert h['returnSP']==h['sp']+(4 if h['entry']==0x401970 else 8)
            assert h['saved']==[0x11111111,0x22222222,0x33333333,0x44444444]
            assert h['eax'] in (0,1);helper_returns+=1
        addresses=[]
        for i,l in enumerate(c['loads']):
            assert bytes(l['path']).decode()==source_paths[i]
            assert l['file']==d['sources'][i]['sha256'] and l['input']['destination']==0x45560c+i*4
            assert l['entrySP']==(0x1000f004) and (l['exit']!='returned' or l['stackAfter']==0x1000f00c)
            for field in ['temporary','first','second','format','descriptor']:
                r=l[field]
                if r:
                    content=blobs[r['bytes']];defined=blobs[r['defined']]
                    assert len(content)==len(defined) and set(defined)<={0,1};compared_bytes+=len(content)
                    if 'initial' in r:
                        initial=blobs[r['initial']];assert len(initial)==len(content)
                        assert all(v or content[j]==initial[j] for j,v in enumerate(defined))
            if l['format']:
                f=blobs[l['format']['bytes']];assert len(f)==18 and int.from_bytes(f[16:],'little')==l['input']['destination']&0xffff
                assert blobs[l['format']['defined']]==b'\1'*18
                desc=blobs[l['descriptor']['bytes']];assert len(desc)==36 and desc[:8]==struct.pack('<II',36,0xe0)
                assert desc[16:20]==b'\0'*4 and blobs[l['descriptor']['defined']]==b'\1'*36
            for r in l['storage']:
                assert l[r['kind']]['bytes']==r['bytes'];n=len(blobs[r['bytes']])
                assert all(r['address']+n<=a or r['address']>=a+count for a,count in addresses)
                addresses.append((r['address'],n))
                if r['kind']=='temporary':assert r['live']==l['temporaryLive']
            loads[l['exit']]+=1;temporary_live+=int(l['temporaryLive'])
        compared_bytes+=SIZE*(2+len(c['events']))
    assert union==d['instructions'] and ends=={'segmentEnd':112,'invalidCreateContinuation':10}
    assert loads=={'returned':580,'invalidCreateContinuation':10} and helper_returns==702
    pins=json.loads((ROOT/'build/research/menu-sound-startup-prior-pins.json').read_bytes());assert len(pins)==225
    for n,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/n).read_bytes())==h
    report=dict(exeSHA256=EXE_SHA256,sourceSHA256=H(raw),sourceBytes=len(raw),producerSHA256=d['producerSHA256'],
        cases=len(d['cases']),wholeSegments=ends['segmentEnd'],explicitCreateBoundaries=ends['invalidCreateContinuation'],
        loads=dict(loads),helperReturns=helper_returns,events=dict(events),eventCount=sum(events.values()),stores=dict(stores),
        retainedTemporaries=temporary_live,comparedBytes=compared_bytes,blobs=len(blobs),priorFixturesVerified=len(pins),
        actualInstructionStarts=len(union),staticInstructionStarts=len(static),unexecutedStatic=[dict(address=hex(a),**v) for a,v in sorted(static.items()) if hex(a) not in union],
        libraryPatchesDisjoint=True,actualSourceLibraryExecution=False,windowsVerified=False,appDeviceVerified=False,nativeCompared=False,
        sourceFiles=d['sources'],allAtomicPartsVerified=True)
    if fixture:
        transported,packed=unpack(fixture);assert transported==raw[:-1] and packed==d
        report.update(fixture=str(fixture.relative_to(ROOT)),fixtureSHA256=H(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size,packedBytesVerified=True)
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--fixture',type=Path);p.add_argument('--report',type=Path);a=p.parse_args()
    report=audit(a.source,a.fixture)
    if a.report:a.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('unexecutedStatic','sourceFiles')},indent=2))
if __name__=='__main__':main()
