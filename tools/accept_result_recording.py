#!/usr/bin/env python3
"""Verify whole result captures and native comparison before publication."""
import base64
import json
import os
import subprocess
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest, publish


def validate():
    raw=(ROOT/'build/original/result-recording.json').read_bytes();doc=json.loads(raw)
    assert raw.endswith(b'\n') and doc['blobEncoding']=='zlib'
    assert doc['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    assert doc['crtSHA256']=='c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d'
    assert doc['cppSHA256']=='372af797353f9335915cd06d4076bab8410775dcaf2dac0593197d7c41bbffb2'
    # The completed corpus is validated without importing the emulation tools.
    cases=doc['cases'];assert len(cases)==95 and len({c['label'] for c in cases})==len(cases)
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']))
        assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    provenance=doc['recordingInput']
    assert digest((FIXTURES/provenance['fixture']).read_bytes())==provenance['fixtureSHA256']
    assert all(c['source']==provenance['recordingSHA256'] for c in cases)
    caller=set();writer=set();restore=set();library=set();writes=0;requested=0;writer_calls=0;restores=0
    for c in cases:
        assert c['fault'] is None and c['end']['pc'] in (0x422218,0x422944) and c['end']['sp']==0x1000f004
        for field,size in [('globals',0xb440),('globalsAfter',0xb440),('world',0x7d8),('actors',400*0x420),('headers',4*0x76c),
                           ('source',0x630e18),('sourceAfter',0x630e18),('saved',0x320),('playback',0x630e18),('pointers',8),('pointersAfter',8)]:
            assert len(blobs[c[field]])==size
        expected=bytearray(blobs[c['source']])
        for e in c['recordingWrites']:
            assert e['size']==4 and 0x421cdc<=e['pc']<0x422218
            offset=e['offset'];expected[offset:offset+4]=e['value'].to_bytes(4,'little')
        assert bytes(expected)==blobs[c['sourceAfter']]
        for h in c['callerHelpers']:
            assert h['entry'] in (0x43df00,0x43dd60) and h['returnSP']==h['entrySP']+4==0x1000f004
        for h in c['helpers']+c['streams']:assert h['returnSP']==h['entrySP']+4+h['pop']
        assert all(a['pc']==0x421eb1 and not a['write'] and a['sp']==0x1000f004 and a['address']==0x1000f068 and a['size']==4 for a in c['stackAccesses'])
        if c['writerInput'] is not None:
            writer_calls+=1
            assert c['writerInput']==c['sourceAfter'] and c['sourceFreed']
            assert blobs[c['pointersAfter']][:4]==bytes(4)
            assert [s['name'] for s in c['streams']]==['construct','write','write','close','destroy']
            assert c['callerHelpers'][-1]['entry']==0x43dd60
            assert [(e['kind'],e.get('name')) for e in c['writerEvents'][-5:]]==[
                ('streamReturn','close'),('free',None),('free',None),('pointer',None),('streamReturn','destroy')]
        else:
            assert not c['sourceFreed'] and not c['writerEvents'] and not c['callerHelpers']
            assert c['source']==c['sourceAfter'] and c['pointers']==c['pointersAfter']
        assert blobs[c['pointersAfter']][4:]==blobs[c['pointers']][4:]
        assert all(not x or y for x,y in zip(blobs[c['rawHookWritten']],blobs[c['codecWritten']]))
        restores+=sum(h['entry']==0x43df00 for h in c['callerHelpers'])
        for e in c['libraryEvents']:
            if e['name']=='_write':
                assert len(blobs[e['bytes']])==e['count'];writes+=1;requested+=e['count']
        caller.update(c['callerPCs']);writer.update(c['writerPCs']);restore.update(c['restorePCs']);library.update(c['libraryPCs'])
    lines=(ROOT/'build/research/result-recording-static.asm').read_text().splitlines()
    static={int(line[:6],16) for line in lines};assert len(static)==296 and caller==static
    report=dict(corpus='result-recording.json',bytes=len(raw),sha256=digest(raw),exeSHA256=doc['exeSHA256'],
        crtSHA256=doc['crtSHA256'],cppSHA256=doc['cppSHA256'],packageSHA256=doc['packageSHA256'],scope=doc['scope'],
        cases=len(cases),writerCalls=writer_calls,restoreCalls=restores,statuses=dict(Counter(str(c['codecStatus']) for c in cases)),
        callerInstructions=len(caller),callerPCs=sorted(caller),missingCallerInstructions=sorted(static-caller),
        writerInstructions=len(writer),restoreInstructions=len(restore),libraryInstructions=len(library),
        codecHelperReturns=sum(len(c['helpers']) for c in cases),streamHelperReturns=sum(len(c['streams']) for c in cases),
        completeREPCopies=sum(len(c['copies']) for c in cases),descriptorWrites=writes,descriptorRequestedBytes=requested,
        longestMatchCalls=sum(c['longestMatchCalls'] for c in cases),blobs=len(blobs),recordingInput=provenance,
        nativeComparison='Full controlled World/400 Actors/Object headers unchanged, complete globals/recording/playback/saved-settings/pointers and masks, actual compressed/adjusted buffers, ownership, descriptor requests, stream states, codec allocation lifecycle, lazy detector and caller continuation. No source stack bytes are imported for own gameplay.',
        nativePrivateABICompared=False,ownInitializedContinuation=False,windowsVerified=False)
    return report,raw


def main():
    pins={p.name:digest(p.read_bytes()) for p in FIXTURES.glob('*.json')}
    previous=json.loads((ROOT/'build/research/replay-writer-fixture-pins.json').read_bytes())
    assert len(previous)==175 and all(pins[n]==sha for n,sha in previous.items())
    report,raw=validate()
    (ROOT/'build/research/result-recording.json').write_text(json.dumps(report,indent=2)+'\n')
    subprocess.run(['swift','test','--package-path',str(ROOT/'native'),'-c','release','--filter','OriginalResultRecordingTests'],
        env=dict(os.environ,NTSD_RESULT_RECORDING_CORPUS=str(ROOT/'build/original/result-recording.json')),check=True)
    publish([('result-recording',report,raw)],pins,pin_name='result-recording-fixture-pins.json')


if __name__=='__main__':main()
