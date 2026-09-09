#!/usr/bin/env python3
"""Verify complete own pause/step/resume source manifests, stores and returns.

Expected snapshots remain assertions, never native initial state. This validates
emulated source evidence at declared input/device boundaries, not Windows.
"""
import argparse
import base64
import json
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT,FIXTURES,capture,digest,historical
from verify_continuous_gameplay_source import BODY_STAGES,encoded
from accept_gameplay_return import CALLER,EPILOGUE,OUTER_EPILOGUE,STAGES as OUTPUT_STAGES

PAUSE_STOPS=[('background',0x41d74d),('drawing',0x41d762),('hud',0x41d76a),('pauseBitmap',0x41d78b),('indicators',0x422994)]
PAUSED=[False,False,True,True,True,True,False,False,True,True,True,True,False,False]


def validate(doc,suffix):
    parent_report,parent=historical('continuous-gameplay'+suffix)
    assert doc['format']=='paused-gameplay-components-v1' and doc['control']==bool(suffix)
    assert doc['exeSHA256']==parent['exeSHA256'] and doc['dllSHA256']==parent['dllSHA256']
    assert doc['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
    for key in ('worldAddress','actorAddresses','objectAddresses','platform'):assert doc[key]==parent[key]
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    for key,value in doc['components'].items():assert digest(encoded(value))==key
    def expanded(refs):return {name:doc['components'][key] for name,key in refs.items()}
    prior={name:parent['components'][key] for name,key in parent['cases'][-1]['after'].items()}
    assert expanded(doc['initial'])==prior
    audit=doc['fpu'];old=parent['fpu']
    for key in ('initialization','transitions','watchedInstructions'):assert audit[key]==old[key]
    previous_fpu=len(old['checkpoints']);assert previous_fpu==15102
    assert audit['checkpoints'][:previous_fpu]==old['checkpoints'] and all(p['fpcw']==0x23f for p in audit['checkpoints'])
    previous=doc['initial'];events=Counter();helpers=Counter();stores=Counter();ticks=[];elapsed=[];paused_pcs=set();stack_count=0
    assert len(doc['cases'])==len(doc['schedule'])==14
    assert [c['paused'] for c in doc['cases']]==PAUSED
    for index,c in enumerate(doc['cases']):
        assert c['index']==index+1 and c['before']==previous and c['end']==dict(pc=0x30000000,sp=0x1000f42c)
        before,after=expanded(c['before']),expanded(c['after']);assert 'frameHeap' in before and 'frameHeap' in after
        a=c['acquisition'];keys=[0x4553e8] if index in (0,10) else [0x4553e9] if index==4 else []
        assert a['plan']==doc['schedule'][index]==dict(index=index+1,keys=keys)
        value=bytearray(blobs[before['state']['globals']]);key_offset=0x455378-0x44d000
        assert a['before']==list(value[key_offset:key_offset+300])
        changes=[]
        for address in (0x4553e8,0x4553e9):
            byte=100 if address in keys else 117
            if value[address-0x44d000]!=byte:
                value[address-0x44d000]=byte;changes.append(dict(address=address,bytes=bytes([byte]).hex()))
        assert changes==a['changes'] and a['after']==list(value[key_offset:key_offset+300])
        cycle=c['cycle'];assert cycle['stimulus']==[] and cycle['local']['natural'] and cycle['local']['parent']
        assert cycle['local']['dispatch']==[] and cycle['prefix']['phase']==index%2
        assert (cycle['local']['call'] is None)==c['paused']
        assert (cycle['local']['beforeDispatch'] is None)==c['paused']
        assert cycle['prefix']['paused']==int(c['paused'])
        assert cycle['round']['continuation']==('pausedRendering' if c['paused'] else 'gameplay')
        assert cycle['round']['endPC']==(0x41d73b if c['paused'] else 0x41e339)
        assert cycle['end']==dict(pc=cycle['round']['endPC'],sp=0x1000e9bc)
        assert blobs[cycle['before']['globals']]==bytes(value)
        for key in before['state']:
            if key!='globals':assert cycle['before'][key]==before['state'][key]
        assert cycle['earlyBefore']['globals']==cycle['before']['globals']
        assert cycle['round']['inherited'] and cycle['inputControl']['inherited'] and cycle['replay']['inherited']
        if c['paused']:
            assert c['stages']==[] and cycle['round']['stageDefeated'] is None
            r=c['rendering'];assert r['end']==dict(pc=0x422994,sp=0x1000e9bc)
            assert [(p['stage'],p['pc']) for p in r['checkpoints']]==PAUSE_STOPS
            assert [e for p in r['checkpoints'] for e in p['events']]==r['events']
            assert r['checkpoints'][-1]['state']==r['after']
            assert r['target']==doc['platform']['input']['targetSurface'] and r['drawResults']==[0,1] and r['fillResult']==0
            first=expanded(r['before']);previous_stage=r['after'];sections=[r]
            flags=blobs[first['state']['globals']]
            for point in r['checkpoints']:
                state=expanded(point['state']);g=blobs[state['state']['globals']]
                for address in (0x450bb8,0x450bc0,0x450bc4):
                    offset=address-0x44d000;assert g[offset:offset+4]==flags[offset:offset+4]
                assert int.from_bytes(g[0x2c:0x30],'little')==1
                assert state['state']['poolBytes']==first['state']['poolBytes'] and state['state']['poolMask']==first['state']['poolMask']
                assert point['fpu'][0]==0x23f
                for e in point['events']:events['paused-'+point['stage']+':'+e['kind']]+=1
            assert 0x422994 not in r['instructions'] and 0x41b5d0 not in r['instructions']
            assert not {0x421a1c,0x421a22}&set(r['instructions'])
            assert {0x41d73b,0x41d742,0x41d748,0x41d75d,0x41d765,0x41d786,0x41d792}<=set(r['instructions'])
            paused_pcs.update(r['instructions'])
        else:
            assert c['rendering'] is None and len(c['stages'])==len(BODY_STAGES)
            first=expanded(c['stages'][0]['before']);previous_stage=c['stages'][0]['before'];sections=c['stages']
            for section,(label,end) in zip(sections,BODY_STAGES):
                assert section['label']==label and section['end']==dict(pc=end,sp=0x1000e9bc) and section['before']==previous_stage
                expanded(section['before']);expanded(section['after']);previous_stage=section['after']
                assert section['boundary']['fpuBefore'][0]==section['boundary']['fpuAfter'][0]==0x23f
                for group,items in section['events'].items():
                    for e in items:events[group+':'+e['kind']]+=1
        assert first['state']==cycle['after'] and first['early']==cycle['earlyAfter']
        output=c['output'];assert output['before']==previous_stage and output['end']==c['end']
        assert output['after']=={k:v for k,v in c['after'].items() if k!='frameHeap'}
        assert [e['arguments'][0] for e in output['events'] if e['kind']=='stage']==OUTPUT_STAGES
        assert output['events'][-1]==dict(kind='dispatcherWrite',arguments=[0x457580,0],strings=[])
        assert CALLER|EPILOGUE|OUTER_EPILOGUE|{0x424746,0x424750}<=set(output['instructions']) and 0x30000000 not in output['instructions']
        for e in output['events']:events['output:'+e['kind']]+=1
        for section in [*sections,output]:
            for h in section['helpers']:
                assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4;helpers[hex(h['entry'])]+=1
        assert sum(h['entry']==0x4450b2 for h in output['helpers'])==3
        outer,inner=output['entryObservations'];ret=output['returnObservations']
        assert (outer['pc'],outer['sp'],outer['returnPC'],outer['seh'])==(0x4246b0,0x1000f424,0x30000000,0x12345678)
        assert outer['saved']==[0x11223344,0x22334455,0x33445566,0x44556677]
        assert (inner['pc'],inner['sp'],inner['returnPC'])==(0x41bc90,0x1000eff8,0x424746)
        assert [(r['pc'],r['sp']) for r in ret]==[(0x422a95,0x1000e9bc),(0x424746,0x1000f000),(0x4287de,0x1000f000),(0x30000000,0x1000f42c)]
        assert all((r['saved'],r['seh'])==(inner['saved'],inner['seh']) for r in ret[1:3])
        assert (ret[-1]['saved'],ret[-1]['seh'])==(outer['saved'],outer['seh'])
        for w in c['globalsWrites']:
            offset=w['address']-0x44d000;size=w['size'];assert 0<=offset<offset+size<=len(value)
            value[offset:offset+size]=w['value'].to_bytes(size,'little');stores[hex(w['pc'])]+=1
        assert bytes(value)==blobs[after['state']['globals']],('Incomplete original global writes',index+1)
        assert c['keyboardAfter']==list(value[key_offset:key_offset+300])
        for address,values in ((0x450b8c,ticks),(0x450bbc,elapsed)):
            offset=address-0x44d000;old_value=int.from_bytes(blobs[before['state']['globals']][offset:offset+4],'little')
            values.append(int.from_bytes(value[offset:offset+4],'little'));assert values[-1]==old_value+(0 if c['paused'] else 1)
        assert c['fpuStart']==previous_fpu and c['fpuEnd']>previous_fpu;previous_fpu=c['fpuEnd']
        for access in c['stackAccesses']:
            assert access['size']>0 and len(bytes.fromhex(access['bytesBefore']))==access['size']
            assert access['write']==(access['reportedValue'] is not None)
        stack_count+=len(c['stackAccesses']);previous=c['after']
    assert previous_fpu==len(audit['checkpoints']) and ticks[-1]==elapsed[-1]==23
    pins=json.loads((ROOT/'build/research/paused-hud-fixture-pins.json').read_bytes())
    assert len(pins)==191 and all(digest((FIXTURES/name).read_bytes())==sha for name,sha in pins.items())
    return dict(parentReproduced=True,returnedCalls=14,pausedCalls=8,resumedOrTransitionCalls=6,
        replayTicks=ticks,elapsedCounters=elapsed,events=dict(events),helpers=sum(helpers.values()),helperEntries=dict(helpers),
        wholeGlobalStoreReplayVerified=True,globalStorePCs=dict(stores),stackAccesses=stack_count,
        pausedInstructionStarts=len(paused_pcs),pausedInstructions=sorted(paused_pcs),blobs=len(blobs),components=len(doc['components']),
        fpuCheckpoints=previous_fpu,oldFixturePinsUnchanged=191,nativeCompared=False,windowsVerified=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');a=p.parse_args();suffix='-control' if a.control else ''
    report,raw,doc=capture('paused-gameplay'+suffix);result=validate(doc,suffix)
    (ROOT/'build/research'/('paused-gameplay'+suffix+'-verification.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
