#!/usr/bin/env python3
"""Independently audit input-startup source, provenance and lossless transport.

Pinned EXE/WAVs, actual instructions and original API request/output fields;
no execution, Windows claim or expected-state modification. Four source returns
with unknown capability reads remain separate from54 native-supported segments.
"""
import argparse,base64,json,struct,subprocess,re,zlib
from pathlib import Path
from collections import Counter
from import_ntsd import ROOT,DEFAULT_SOURCE,EXE_SHA256
from inspect_original import PE
from verify_menu_sound_startup import unpack,H
BASE,SIZE=0x44d000,0xb440
RANGES=[(0x43d078,0x43d100),(0x43bf10,0x43c0bb),(0x401970,0x4019a9),(0x4014e0,0x40195f),
        (0x4450b2,0x4450bc),(0x43f384,0x43f38a),(0x43b3d0,0x43bc3f)]

def audit(path,fixture=None):
    path=path.resolve();raw=path.read_bytes();d=json.loads(raw);assert raw.endswith(b'\n')
    exe=(DEFAULT_SOURCE/'NTSD 2.4.exe').read_bytes();assert H(exe)==d['exeSHA256']==EXE_SHA256;pe=PE(exe)
    producer=d.get('producerFile','oracle_input_startup.py');assert producer in ['oracle_input_startup.py','oracle_input_startup_success.py']
    successful=producer=='oracle_input_startup_success.py'
    assert d['producerSHA256']==H(path.with_name(path.stem+'-source.py').read_bytes())==H((ROOT/'tools'/producer).read_bytes())
    for n,h in d['dependencies'].items():assert H((ROOT/'tools'/n).read_bytes())==h
    blobs={}
    for h,b in d['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']),-15);assert len(value)==b['count'] and H(value)==h;blobs[h]=value
    for s in d['sources']:
        actual=(DEFAULT_SOURCE/s['path'].replace('\\','/')).read_bytes();assert H(actual)==s['sha256'] and len(actual)==s['count'] and actual==blobs[s['sha256']]
    _,lib=unpack(ROOT/'native/Tests/NTSDCoreTests/Fixtures/original-lib-initialization.json')
    patches=lib['cases'][0]['patches'];assert len(patches)==13
    assert all(p['address']+p['count']<=a or p['address']>=b for p in patches for a,b in RANGES)
    static={}
    for start,end in RANGES:
        out=subprocess.check_output(['xcrun','llvm-objdump','--disassemble','--x86-asm-syntax=intel','--start-address='+hex(start),'--stop-address='+hex(end),str(DEFAULT_SOURCE/'NTSD 2.4.exe')],text=True)
        for line in out.splitlines():
            m=re.match(r'^\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(.*)',line)
            if m:static[int(m[1],16)]=dict(bytes=bytes.fromhex(m[2]).hex(),assembly=m[3])
    union={};groups=Counter();event_counts=Counter();store_counts=Counter();native_events=0;unknown=[];caps_reads=Counter();callbacks=0;loads=0;global_bytes=0;capability_checkpoints=0
    def instructions(mapping):
        for a,v in mapping.items():
            address=int(a,16);value=bytes.fromhex(v);o=pe.offset(address-0x400000)
            assert value==exe[o:o+len(value)] and address in static and static[address]['bytes']==v,(a,v)
            union[a]=v
    def state_trace(c,limit=None):
        nonlocal global_bytes
        before=blobs[c['beforeGlobals']];after=blobs[c['afterGlobals']];mask=blobs[c['globalMask']]
        assert len(before)==len(after)==len(mask)==SIZE and set(mask)<={0,1}
        grouped={}
        for s in c['stores']:grouped.setdefault(s['eventIndex'],[]).append(s)
        assert set(grouped)<=set(range(len(c['events'])+1))
        state=bytearray(before);written=bytearray(SIZE);store_index=0
        for i in range(len(c['events'])+1):
            for s in grouped.get(i,[]):
                value=bytes.fromhex(s['bytes']);o=s['address']-BASE;assert 0<=o<o+len(value)<=SIZE
                if s['origin']=='CPU':assert hex(s['pc']) in c['instructions']
                elif s['origin']=='API':assert s['pc']==0x30000500 and s['address']==0x44eecc
                else:assert s['origin']=='memset' and s['pc']==0x4450a0 and s['address']==0x455378 and value==b'\x75'*256
                if limit and store_index==limit['storeCount']:assert state==blobs[limit['globals']]
                state[o:o+len(value)]=value;written[o:o+len(value)]=b'\1'*len(value);store_index+=1;store_counts[s['origin']]+=1
            if i<len(c['events']):
                e=c['events'][i];assert state==blobs[e['globals']]
                name=e['event']['wave']['kind'] if e['event']['wave'] else e['event']['kind'];event_counts[name]+=1
        assert state==after and written==mask
        global_bytes+=SIZE*(len(c['events'])+2);instructions(c['instructions'])
    expected_cases=2 if successful else 58
    parts=path.with_suffix('.parts');assert len(d['cases'])==expected_cases and len(list(parts.glob('*.json')))==expected_cases
    for index,c in enumerate(d['cases']):
        part=json.loads((parts/f'{index+1:04d}.json').read_bytes());assert part['case']==c
        assert all(d['blobs'][h]==v for h,v in part['blobs'].items())
        state_trace(c,c['ownBoundary']);assert c['endPC']==0x43d100 and c['stackAfter']==0x1000f00c and c['controlWord']==0x37f
        assert c['joystickReturn']['sp']==0x1000f000 and c['joystickReturn']['saved']==[0x11111111,0x22222222,0x33333333,0x44444444]
        assert len(c['helperReturns'])==6 and len(c['loads'])==5
        for h in c['helperReturns']:
            assert h['entry'] in (0x401970,0x4014e0) and h['returnSP']==h['sp']+(4 if h['entry']==0x401970 else 8)
            assert h['saved']==[0x11111111,0x22222222,0x33333333,0x44444444]
        # Independent own JOYINFOEX/capability output reconstruction, not an
        # import of source's after structures into the native implementation.
        info=bytearray(52);struct.pack_into('<II',info,0,52,0x83);caps=bytearray(404);known=bytearray(404);cap_index=0
        for r in c['joyRequests']:
            name=r['request']['kind'];response=r['response']
            if name=='position':assert r['request']['information']==list(info)
            else:assert r['request']['information'] is None
            for w in response['writes']:
                assert name in ('position','capabilities');target=info if name=='position' else caps
                o=w['offset'];value=bytes(w['bytes']);assert 0<=o<=o+len(value)<=len(target);target[o:o+len(value)]=value
                if name=='capabilities':known[o:o+len(value)]=b'\1'*len(value)
            if name=='capabilities':
                s=c['capsStates'][cap_index];cap_index+=1;assert s['id']==r['request']['arguments'][0]
                assert blobs[s['defined']]==known
                assert all(not bit or blobs[s['bytes']][i]==caps[i] for i,bit in enumerate(known));capability_checkpoints+=1
        assert cap_index==len(c['capsStates'])
        for r in c['capsReads']:
            assert r['offset'] in (36,40,44,48) and r['count']==4 and len(bytes.fromhex(r['bytes']))==4
            caps_reads['known' if r['known'] else 'unknown']+=1
        if c['ownBoundary']:
            b=c['ownBoundary'];assert b['offset']==36 and b['count']==4 and any(not r['known'] for r in c['capsReads']) and not c['callbacks']
            unknown.append(dict(case=index,label=c['spec']['label'],**b));groups['nativeRejected']+=1;native_events+=b['eventCount']
        else:
            assert all(r['known'] for r in c['capsReads']);groups['nativeSupported']+=1;native_events+=len(c['events'])
        prior=c['afterGlobals']
        for callback in c['callbacks']:
            assert callback['beforeGlobals']==prior;state_trace(callback);prior=callback['afterGlobals'];callbacks+=1
            assert callback['returned']==0xffffff85 and callback['stackAfter']==0x1000f014
            assert len(callback['events'])==1 and callback['events'][0]['event']['kind']=='windowDefault'
        for i,l in enumerate(c['loads']):
            assert l['file']==d['sources'][i]['sha256'] and bytes(l['path']).decode()==d['sources'][i]['path']
            assert l['exit']=='returned' and l['entrySP']==0x1000f004 and l['stackAfter']==0x1000f00c
            for field in ['first','second','temporary','format','descriptor']:
                r=l[field]
                if r:
                    content=blobs[r['bytes']];defined=blobs[r['defined']];assert len(content)==len(defined) and set(defined)<={0,1}
                    if 'initial' in r:assert all(bit or content[i]==blobs[r['initial']][i] for i,bit in enumerate(defined))
            loads+=1
    assert union==d['instructions'] and groups==({'nativeSupported':2} if successful else {'nativeSupported':54,'nativeRejected':4})
    assert callbacks==(228 if successful else 1672) and loads==5*expected_cases
    if successful:
        assert not unknown
        for c in d['cases']:
            assert c['spec']['joysticks']['count']==2 and c['spec']['device']['cooperativeResult']==0
            assert all(r['response']['result']==0 for r in c['joyRequests'] if r['request']['kind']!='numberDevices')
    pins=json.loads((ROOT/'build/research/input-startup-prior-pins.json').read_bytes());assert len(pins)==226
    for n,h in pins.items():assert H((ROOT/'native/Tests/NTSDCoreTests/Fixtures'/n).read_bytes())==h
    vendor=ROOT/'native/Sources/NTSDReplayCodec';v=json.loads((vendor/'upstream.json').read_bytes())
    for n,p in v['files'].items():assert H((vendor/'vendor'/n).read_bytes())==p['vendoredSHA256']
    report=dict(exeSHA256=EXE_SHA256,producerSHA256=d['producerSHA256'],sourceSHA256=H(raw),sourceBytes=len(raw),sourceCalls=expected_cases,
        nativeSupportedSegments=groups['nativeSupported'],nativeRejectedUnknownReads=groups['nativeRejected'],ownCallbacks=callbacks,sourceWAVLoads=loads,nativeWAVLoads=5*groups['nativeSupported'],
        actualInstructionStarts=len(union),staticInstructionStarts=len(static),unexecutedStatic=[dict(address=hex(a),**v) for a,v in sorted(static.items()) if hex(a) not in union],
        globalsComparedBytes=global_bytes,events=dict(event_counts),sourceEvents=sum(event_counts.values()),nativeStartupEvents=native_events,
        stores=dict(store_counts),capabilityReads=dict(caps_reads),capabilityCheckpoints=capability_checkpoints,unknownBoundaries=unknown,
        blobs=len(blobs),allAtomicPartsVerified=True,priorFixturesVerified=226,vendorFilesVerified=10,libraryPatchesDisjoint=True,
        actualSourceLibraryExecution=False,windowsVerified=False,nativeCompared=False,fullWinMainClaim=False)
    if fixture:
        fixture=fixture.resolve();transported,packed=unpack(fixture);assert transported==raw[:-1] and packed==d
        report.update(fixture=str(fixture.relative_to(ROOT)),fixtureSHA256=H(fixture.read_bytes()),fixtureBytes=fixture.stat().st_size,packedBytesVerified=True)
    return report
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('--fixture',type=Path);p.add_argument('--report',type=Path);a=p.parse_args();r=audit(a.source,a.fixture)
    if a.report:a.report.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k not in ('unexecutedStatic','unknownBoundaries')},indent=2))
if __name__=='__main__':main()
