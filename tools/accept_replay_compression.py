#!/usr/bin/env python3
"""Validate original compression, compare native, then preserve172 old pins."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, publish


def main():
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/gameplay-notices-fixture-pins.json').read_bytes())
    assert len(old)==172 and all(pins[name]==sha for name,sha in old.items())
    report,raw,doc=capture('replay-compression')
    assert len(doc['cases'])==report['cases']==815
    cache={}
    for key,item in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(item['deflate']),-15)
        assert len(value)==item['count'] and digest(value)==key
        cache[key]=value
    seen=set(); statuses=Counter(); missed_cases=[]; missed_bytes=0; helpers=0; copies=0; output_bytes=0
    modern_differences=[]; cases={c['label']:c for c in doc['cases']}
    assert len(cases)==len(doc['cases'])
    for c in doc['cases']:
        key=(c['input'],c['capacity'],c['level'],c['failAt']); assert key not in seen; seen.add(key)
        source,output,mask,raw_mask=[cache[c[name]] for name in ('input','output','written','memoryHookWritten')]
        capacity=c['capacity']; assert len(output)==len(mask)==len(raw_mask)==capacity
        assert all(v in (0,1) for v in mask+raw_mask)
        written=sum(mask); assert mask==b'\1'*written+b'\0'*(capacity-written)
        assert output[written:]==b'\xa5'*(capacity-written)
        assert all(not v or mask[i] for i,v in enumerate(raw_mask))
        position=0
        for copy in c['copies']:
            assert copy['pc'] in (0x43f5c3,0x43f5ca)
            assert copy['destination']==0x25000000+position
            if copy['pc']==0x43f5c3: assert copy['count']%4==0
            else: assert 0<=copy['count']<=3
            end=position+copy['count']; assert end<=written
            assert digest(output[position:end])==copy['sha256']
            assert sum(raw_mask[position:end])==copy['memoryHookWrites']
            position=end
        assert position==written
        if written!=sum(raw_mask):
            missed_cases.append(c['label']); missed_bytes+=written-sum(raw_mask)
        if c['result']==0:
            assert c['length']==written and zlib.decompress(output[:written])==source
            modern=zlib.compress(source,-1 if c['level'] is None else c['level'])
            if modern!=output[:written]: modern_differences.append(dict(label=c['label'],originalBytes=written,hostBytes=len(modern)))
        else: assert c['length']==capacity and c['result'] in (-2,-4,-5)
        if c['failAt']:
            assert c['result']==-4 and written==0
            assert sum(a['live'] for a in c['allocations'])==(0 if c['failAt']==1 else 4)
        else: assert not any(a['live'] for a in c['allocations'])
        for helper in c['helpers']:
            assert helper['returnSP']==helper['entrySP']+4+helper['pop']
        outer=c['helpers'][-1]
        assert outer['entry']==(0x43f4b0 if c['level'] is None else 0x43f400)
        assert outer['returnPC']==0x30000000 and outer['result']==c['result']
        statuses[c['result']]+=1;helpers+=len(c['helpers']);copies+=len(c['copies']);output_bytes+=capacity
    assert {c['level'] for c in doc['cases']}=={None,*range(-2,11)}
    assert {c['failAt'] for c in doc['cases']}==set(range(6))
    for name in ('own-recording','full-zero-recording','full-random-recording-writer-capacity','full-random-recording-larger-capacity'):
        assert len(cache[cases[name]['input']])==0x630e18
    assert cases['own-recording']['length']==10047
    assert cases['full-zero-recording']['length']==6326
    assert cases['full-random-recording-writer-capacity']['result']==-5
    assert cases['full-random-recording-writer-capacity']['capacity']==0x631200
    assert cases['full-random-recording-larger-capacity']['result']==0
    assert len(doc['recordingInputs'])==2
    for parent in doc['recordingInputs']:
        assert digest((FIXTURES/parent['fixture']).read_bytes())==parent['fixtureSHA256']
        assert parent['recordingSHA256']==cases['own-recording']['input']
    instructions=set(doc['instructions']);assert len(instructions)==report['instructions']
    lines=(ROOT/'build/research/compact.asm').read_text().splitlines()
    static={int(line[:6],16) for line in lines if len(line)>6 and line[6]==' ' and all(c in '0123456789abcdef' for c in line[:6])}
    coverage=[]
    for start,end,count in ((0x43f400,0x43f49f,51),(0x43f4b0,0x43f4ce,11)):
        body={pc for pc in static if start<=pc<end};assert len(body)==count
        coverage.append(dict(start=start,end=end,static=count,executed=len(body&instructions),missing=sorted(body-instructions)))
    report.update(helpers=helpers,completedREPCopies=copies,outputBytesCompared=output_bytes,statuses=dict(statuses),
        sourceMemoryHookDiscrepancies=dict(cases=missed_cases,missingBytes=missed_bytes),
        provenance='Original REP counts/register advances and actual copied bytes; raw hook masks retained separately',
        wrapperCoverage=coverage,executedEXEInstructions=sum(0x401000<=pc<0x446000 for pc in instructions),
        executedDLLInstructions=sum(0x78130000<=pc<0x78230000 for pc in instructions),
        hostCompressionComparison=dict(version=zlib.ZLIB_RUNTIME_VERSION,differences=modern_differences),
        internalABI=dict(originalStateBytes=5816,nativeLP64StateBytes=5920,privateHostCleanupAfterObservation=True),
        recordingInputs=doc['recordingInputs'],wholeWriterCompared=False,ownInitializedContinuation=False,
        filesWritten=False,firstTickReturned=False)
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalReplayCompressionTests'],
        env=dict(os.environ,NTSD_REPLAY_COMPRESSION_CORPUS=str(ROOT/'build/original/replay-compression.json')),check=True)
    publish([('replay-compression',report,raw)],pins,pin_name='replay-compression-fixture-pins.json')

if __name__=='__main__': main()
