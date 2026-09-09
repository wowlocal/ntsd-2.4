#!/usr/bin/env python3
"""Validate whole43dd60 captures, compare native, then publish losslessly."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def main():
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    old=json.loads((ROOT/'build/research/replay-stream-fixture-pins.json').read_bytes())
    assert len(old)==174 and all(pins[name]==sha for name,sha in old.items())
    raw=(ROOT/'build/original/replay-writer.json').read_bytes();doc=json.loads(raw)
    assert raw.endswith(b'\n') and doc['blobEncoding']=='zlib'
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert doc['cppSHA256']=='372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2'
    cases=doc['cases'];assert len(cases)==26 and len({c['label'] for c in cases})==26
    blobs={}
    for key,item in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(item['deflate']))
        assert len(value)==item['count'] and digest(value)==key
        blobs[key]=value
    provenance=doc['recordingInput']
    assert digest((FIXTURES/provenance['fixture']).read_bytes())==provenance['fixtureSHA256']
    assert cases[0]['source']==provenance['recordingSHA256']
    assert doc['sourceCount']==0x630e18 and doc['capacity']==0x631200
    complete=[];faults=[];writer_pcs=set();library_pcs=set();helpers=0;stream_returns=0;copies=0;writes=0;output_bytes=0
    compared_writes=0;compared_bytes=0
    for c in cases:
        assert len(blobs[c['source']])==doc['sourceCount']
        before,after=blobs[c['globals']],blobs[c['globalsAfter']]
        assert len(before)==len(after)==0xb440
        expected=bytearray(before)
        for e in c['selectorWrites']:
            assert e['pc']==0x442903 and e['address']==0x44dd50 and e['size']==4
            expected[0xd50:0xd54]=e['value'].to_bytes(4,'little')
        assert bytes(expected)==after
        for s in c['streams']:
            assert s['returnSP']==s['entrySP']+4+s['pop']
        for helper in c['helpers']:
            assert helper['returnSP']==helper['entrySP']+4+helper['pop']
        written,hook=blobs[c['codecWritten']],blobs[c['rawHookWritten']]
        assert len(written)==len(hook)==doc['capacity']
        assert all(not a or b for a,b in zip(hook,written))
        if c['fault']:
            faults.append(dict(label=c['label'],**c['fault']))
            assert c['end']['pc']!=0x30000000
            if c['fault']['kind']=='nullBacking':assert c['fault']['pc'] not in c['writerPCs']
            elif c['fault']['kind']=='unmappedBacking':
                assert c['label']=='zero-long-key' and c['end']['pc']==0x44043c
                assert c['fault']['address']==0x31313131 and c['codecStatus'] is None
            elif c['fault']['kind']=='crtInvalidParameter':
                assert c['label']=='null-destination-empty-key' and c['fault']['returnPC']==0x78180458
            else:assert c['fault']['kind']=='cookie' and c['end']['pc']==0x44556a
        else:
            complete.append(c['label'])
            assert c['end']==dict(pc=0x30000000,sp=0x1000f004)
            assert c['recordingPointer']==0 and c['sourceFreed']==(not c['nullSource'])
            assert [s['name'] for s in c['streams']]==['construct','write','write','close','destroy']
            tail=c['writerEvents'][-5:]
            assert [(e['kind'],e.get('name')) for e in tail]==[
                ('streamReturn','close'),('free',None),('free',None),('pointer',None),('streamReturn','destroy')]
            assert tail[1]['address']==c['allocations'][0]['address']
            assert tail[2]['address']==(0 if c['nullSource'] else 0x24000000)
            assert not c['allocations'][0]['live']
        for e in c['libraryEvents']:
            if e['name']=='_write':
                assert len(blobs[e['bytes']])==e['count'] and -1<=e['result']<=e['count']
                writes+=1;output_bytes+=e['count']
                if not c['fault']:compared_writes+=1;compared_bytes+=e['count']
        helpers+=len(c['helpers']);stream_returns+=len(c['streams']);copies+=len(c['copies'])
        writer_pcs.update(c['writerPCs']);library_pcs.update(c['libraryPCs'])
    assert len(complete)==21 and len(faults)==5
    report=dict(corpus='replay-writer.json',bytes=len(raw),sha256=digest(raw),exeSHA256=doc['exeSHA256'],
        crtSHA256=doc['crtSHA256'],cppSHA256=doc['cppSHA256'],packageSHA256=doc['packageSHA256'],
        cases=len(cases),wholeReturns=len(complete),sourceFaults=faults,
        statuses=dict(Counter(str(c['codecStatus']) for c in cases)),
        writerInstructions=len(writer_pcs),writerPCs=sorted(writer_pcs),libraryInstructions=len(library_pcs),
        codecHelperReturns=helpers,streamHelperReturns=stream_returns,completeREPCopies=copies,
        sourceDescriptorWrites=writes,sourceDescriptorRequestedBytes=output_bytes,
        comparedDescriptorWrites=compared_writes,comparedDescriptorRequestedBytes=compared_bytes,blobs=len(blobs),
        longestMatchCalls=sum(c['longestMatchCalls'] for c in cases),
        recordingInput=provenance,blobEncoding=doc['blobEncoding'],
        scope=doc['scope'],instructionCounting=doc['instructionCounting'],
        nativeComparison='21 whole returns: full source/compressed/adjusted bytes and masks, whole globals, owned buffer liveness/pointer, ordered format/allocation/IO/close/free/clear/destruction, normalized private codec allocation events, match invocation count and supplied detector signatures. Five source faults are explicit native rejections with game-state rollback, not successful-call equivalence.',
        inheritedBoundaries=['pinned CRT thread/C locale/locks','explicit _osplatform2 without startup producer',
            'FILE/descriptor3 binary nonappend backing','private C++/CRT allocator',
            'original calloc/free with explicit ordinal failure','_wfsopen/_write/_close numeric results'],
        nativePrivateABICompared=False,nativeHostHeapPressureCompared=False,ownInitializedContinuation=False,
        sourceDLLStartupExecuted=False,windowsVerified=False)
    (ROOT/'build/research/replay-writer.json').write_text(json.dumps(report,indent=2)+'\n')
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalReplayWriterTests'],
        env=dict(os.environ,NTSD_REPLAY_WRITER_CORPUS=str(ROOT/'build/original/replay-writer.json')),check=True)
    publish([('replay-writer',report,raw)],pins,pin_name='replay-writer-fixture-pins.json')


if __name__=='__main__':main()
