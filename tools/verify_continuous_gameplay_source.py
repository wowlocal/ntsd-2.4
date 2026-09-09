#!/usr/bin/env python3
"""Independently validate successive original calls and lossless state manifests.

The component format deduplicates complete snapshot fields. Expand each field
and verify its canonical JSON hash, every binary blob, actual parent identity,
whole-return state chain, original stores, input phases and saved/FPU frames.
This source check does not establish native equivalence or Windows/device output.
"""
import argparse
import base64
import json
import zlib
from collections import Counter
from pathlib import Path
from accept_initialized_gameplay import ROOT, FIXTURES, capture, digest, historical
from accept_gameplay_return import CALLER, EPILOGUE, OUTER_EPILOGUE, STAGES as OUTPUT_STAGES

BODY_STAGES=[('control',0x41e634),('physics',0x41eed1),('depth-attachments',0x41eed8),('contacts',0x41eefb),
    ('hits-items',0x41f2ac),('cpoint-actions',0x41f2b3),('cpoint-placement',0x41f2b8),('cpoint-cleanup',0x41f47d),
    ('cpoint-attachments',0x41f484),('camera-background',0x41f496),('world-drawing',0x41f4ac),
    ('post-draw-impulses',0x41f550),('post-draw-lifecycle',0x4214d5),('post-draw-commands',0x421a15),
    ('world-hud',0x421a2d),('post-hud-notices',0x421cdc),('result-recording',0x422944),('result-layout',0x422994)]


def encoded(value):return json.dumps(value,separators=(',',':'),sort_keys=True).encode()


def validate(doc,suffix,raw):
    parent_report,parent=historical('gameplay-return'+suffix)
    assert doc['format']=='continuous-gameplay-components-v1'
    assert doc['exeSHA256']==parent['exeSHA256'] and doc['dllSHA256']==parent['dllSHA256']
    assert doc['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
    assert doc['control']==bool(suffix) and len(doc['cases'])<=16
    for key in ('worldAddress','actorAddresses','objectAddresses'):assert doc[key]==parent[key]
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    for key,value in doc['components'].items():assert digest(encoded(value))==key
    def expanded(refs):
        assert set(refs) in (set(parent['cases'][0]['after']),set(parent['cases'][0]['after'])-{'frameHeap'})
        return {name:doc['components'][key] for name,key in refs.items()}
    initial=expanded(doc['initial']);assert initial==parent['cases'][0]['after']
    assert doc['platform']=={key:parent['cases'][0]['gameplayReturn'][key] for key in ('input','methodBindings','loadedSoundBuffers','resourceSurfaces','drawResults')}
    full_parent_audit=parent['fpu'];audit=doc['fpu']
    for key in ('initialization','transitions','watchedInstructions'):assert audit[key]==full_parent_audit[key]
    previous_fpu=len(full_parent_audit['checkpoints'])
    assert audit['checkpoints'][:previous_fpu]==full_parent_audit['checkpoints'] and previous_fpu==1614
    assert all(p['fpcw']==0x23f for p in audit['checkpoints'])
    previous=doc['initial'];events=Counter();helper_counts=Counter();phases=[];ticks=[];stores=Counter()
    total_stack=0;recording_sizes=[];all_pcs=set();stack_pcs=set();changed_globals=[]
    for index,c in enumerate(doc['cases'],1):
        assert c['index']==index and c['before']==previous
        before,after=expanded(c['before']),expanded(c['after']);assert 'frameHeap' in before and 'frameHeap' in after
        assert c['end']==dict(pc=0x30000000,sp=0x1000f42c)
        assert c['keyboardBefore']==c['keyboardAfter']==[117]*300
        cycle=c['cycle'];assert cycle['label']==f'neutral-{index:02d}' and cycle['stimulus']==[]
        assert cycle['before']==before['state'] and cycle['earlyBefore']==before['early']
        assert cycle['prefix']['paused']==0 and cycle['local']['natural'] and cycle['local']['parent']
        assert cycle['local']['dispatch']==[] and cycle['round']['continuation']=='gameplay'
        assert cycle['round']['endPC']==0x41e339 and cycle['end']==dict(pc=0x41e339,sp=0x1000e9bc)
        assert cycle['round']['inherited'] and cycle['inputControl']['inherited'] and cycle['replay']['inherited']
        phases.append(cycle['prefix']['phase']);assert phases[-1]==(index+1)%2
        first=expanded(c['stages'][0]['before'])
        assert first['state']==cycle['after'] and first['early']==cycle['earlyAfter']
        previous_stage=c['stages'][0]['before'];assert len(c['stages'])==len(BODY_STAGES)
        for section,(label,end) in zip(c['stages'],BODY_STAGES):
            assert section['label']==label and section['end']==dict(pc=end,sp=0x1000e9bc)
            assert section['before']==previous_stage
            expanded(section['before']);expanded(section['after']);previous_stage=section['after']
            b=section['boundary'];assert b['fpuBefore'][0]==b['fpuAfter'][0]==0x23f
            assert b['stageDefeatedBefore']==b['stageDefeatedAfter']==cycle['round']['stageDefeated']
            for group,items in section['events'].items():
                for e in items:events[group+':'+e['kind']]+=1
            for h in section['helpers']:
                assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4
                helper_counts[hex(h['entry'])]+=1
        output=c['output'];assert output['label']=='gameplay-return' and output['before']==previous_stage
        assert output['after']=={k:v for k,v in c['after'].items() if k!='frameHeap'} and output['end']==c['end']
        assert [e['arguments'][0] for e in output['events'] if e['kind']=='stage']==OUTPUT_STAGES
        assert output['events'][-1]==dict(kind='dispatcherWrite',arguments=[0x457580,0],strings=[])
        assert CALLER|EPILOGUE|OUTER_EPILOGUE|{0x424746,0x424750}<=set(output['instructions'])
        assert 0x30000000 not in output['instructions']
        for e in output['events']:events['output:'+e['kind']]+=1
        for h in output['helpers']:
            assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4
            helper_counts[hex(h['entry'])]+=1
        assert sum(h['entry']==0x4450b2 for h in output['helpers'])==3
        outer,inner=output['entryObservations'];ret=output['returnObservations']
        assert (outer['pc'],outer['sp'],outer['returnPC'],outer['seh'])==(0x4246b0,0x1000f424,0x30000000,0x12345678)
        assert outer['saved']==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert (inner['pc'],inner['sp'],inner['returnPC'])==(0x41bc90,0x1000eff8,0x424746)
        assert [(r['pc'],r['sp']) for r in ret]==[(0x422a95,0x1000e9bc),(0x424746,0x1000f000),(0x4287de,0x1000f000),(0x30000000,0x1000f42c)]
        assert all((r['saved'],r['seh'])==(inner['saved'],inner['seh']) for r in ret[1:3])
        assert (ret[-1]['saved'],ret[-1]['seh'])==(outer['saved'],outer['seh'])
        value=bytearray(blobs[before['state']['globals']]);original=bytes(value)
        assert before['state']['globals']==before['early']['globals'] and after['state']['globals']==after['early']['globals']
        for w in c['globalsWrites']:
            offset=w['address']-0x44d000;size=w['size'];assert size in (1,2,4,8) and 0<=offset<offset+size<=len(value)
            value[offset:offset+size]=w['value'].to_bytes(size,'little');stores[hex(w['pc'])]+=1
        assert bytes(value)==blobs[after['state']['globals']],('Source global stores incomplete',index)
        changed_globals.append(sum(a!=b for a,b in zip(original,value)))
        ticks.append(int.from_bytes(value[0x450b8c-0x44d000:0x450b8c-0x44d000+4],'little'))
        assert ticks[-1]==index+1
        assert int.from_bytes(value[0x450b80-0x44d000:0x450b80-0x44d000+4],'little')==1
        assert int.from_bytes(value[0x450bbc-0x44d000:0x450bbc-0x44d000+4],'little')==index+1
        assert c['fpuStart']==previous_fpu and c['fpuEnd']>c['fpuStart'];previous_fpu=c['fpuEnd']
        for access in c['stackAccesses']:
            assert access['size']>0 and len(bytes.fromhex(access['bytesBefore']))==access['size']
            assert (0x1000e9bc+0x34<=access['address']<0x1000e9bc+0x74 or 0x1000e9bc+0x44c<=access['address']<0x1000e9bc+0x5c4)
            assert access['write']==(access['reportedValue'] is not None);stack_pcs.add(access['pc'])
        total_stack+=len(c['stackAccesses']);all_pcs.update(c['observedOriginalAddressPCs']);previous=c['after']
    assert previous_fpu==len(audit['checkpoints'])
    pins=json.loads((ROOT/'build/research/gameplay-return-fixture-pins.json').read_bytes())
    assert len(pins)==188 and all(digest((FIXTURES/name).read_bytes())==sha for name,sha in pins.items())
    return dict(bytes=len(raw),sha256=digest(raw),parent=doc['parent'],returnedCalls=len(doc['cases']),
        components=len(doc['components']),blobs=len(blobs),oldFixturePinsUnchanged=len(pins),
        componentHashesVerified=True,allBlobBytesMasksAndHashesVerified=True,completeParentReproduced=True,
        fullReturnStateChainVerified=True,sourceGlobalsReconstructedFromWrites=True,changedGlobalBytesByCall=changed_globals,
        inputPhases=phases,ticks=ticks,recordingEnabledThroughout=True,sourceLogTickLabelActuallyRecordingFlag=True,fpuCheckpoints=len(audit['checkpoints']),stackAccesses=total_stack,
        stackAccessPCs=len(stack_pcs),observedOriginalAddressPCs=len(all_pcs),eventCounts=dict(events),
        helperCounts=dict(helper_counts),globalStorePCs=dict(stores),
        originalNormalReturnFramesVerified=True,nativeCompared=False,windowsVerified=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--partial',action='store_true');a=p.parse_args()
    suffix='-control' if a.control else '';name='continuous-gameplay'+suffix
    if a.partial:
        raw=(ROOT/'build/research'/(name+'-partial.json')).read_bytes();doc=json.loads(raw)
        proof=json.loads((ROOT/'build/research'/(name+'-partial.checkpoint.json')).read_bytes())
        assert len(raw)==proof['bytes'] and digest(raw)==proof['sha256'] and len(doc['cases'])==proof['completeReturnedCalls']
    else:
        report,raw,doc=capture(name);assert len(doc['cases'])==report['returnedCalls']==16
    result=validate(doc,suffix,raw)
    (ROOT/'build/research'/(name+('-partial' if a.partial else '')+'-verification.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
