#!/usr/bin/env python3
"""Independently validate active-key original calls and lossless state manifests.

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
    parent_report,parent=historical('continuous-gameplay'+suffix)
    assert doc['format']=='active-gameplay-components-v1'
    assert doc['exeSHA256']==parent['exeSHA256'] and doc['dllSHA256']==parent['dllSHA256']
    assert doc['parent']==dict(fixture=parent_report['fixture'],sha256=parent_report['fixtureSHA256'])
    assert doc['control']==bool(suffix) and len(doc['cases'])<=48
    for key in ('worldAddress','actorAddresses','objectAddresses'):assert doc[key]==parent[key]
    blobs={}
    for key,b in doc['blobs'].items():
        value=zlib.decompress(base64.b64decode(b['deflate']),-15)
        assert len(value)==b['count'] and digest(value)==key;blobs[key]=value
    for key,value in doc['components'].items():assert digest(encoded(value))==key
    old={name:parent['components'][key] for name,key in parent['cases'][-1]['after'].items()}
    full_fields=set(old)|{'objects','objectStrings'};middle_fields=set(old)-{'frameHeap'}
    def expanded(refs):
        assert set(refs) in (full_fields,middle_fields)
        return {name:doc['components'][key] for name,key in refs.items()}
    initial=expanded(doc['initial']);assert {k:v for k,v in initial.items() if k not in ('objects','objectStrings')}==old
    assert doc['platform']==parent['platform']
    buttons=['up','down','left','right','attack','jump','defend']
    segments=[('approach',16,['left'],['right']),('moving-attacks',8,['left','attack'],['right','attack']),
        ('release',4,[],[]),('guard-and-attack',8,['defend'],['attack']),('jump',4,['jump'],['jump']),
        ('depth-movement',4,['up'],['down']),('release-final',4,[],[])]
    schedule=[dict(index=i+1,segment=label,buttons=[a,b]) for i,(label,a,b) in enumerate((label,a,b) for label,count,a,b in segments for _ in range(count))]
    assert doc['schedule']==schedule and len(schedule)==48
    def objects(snapshot):
        assert [o['address'] for o in snapshot['objects']]==doc['objectAddresses']
        strings={x['address']:x['storage'] for x in snapshot['objectStrings']};used=set()
        for item in snapshot['objects']:
            r=item['storage'];raw=blobs[r['bytes']];mask=blobs[r['defined']]
            assert len(raw)==len(mask)==0x25360 and all(v<2 for v in mask)
            for offset in (0x98,0x9c,0xa0):
                p=int.from_bytes(raw[offset:offset+4],'little')
                if p:
                    assert p in strings;used.add(p);st=strings[p];text=blobs[st['bytes']]
                    assert len(text)==len(blobs[st['defined']]) and 0 in text
        assert used==set(strings)
    objects(initial)

    full_parent_audit=parent['fpu'];audit=doc['fpu']
    for key in ('initialization','transitions','watchedInstructions'):assert audit[key]==full_parent_audit[key]
    previous_fpu=len(full_parent_audit['checkpoints'])
    assert audit['checkpoints'][:previous_fpu]==full_parent_audit['checkpoints'] and previous_fpu==15102
    assert all(p['fpcw']==0x23f for p in audit['checkpoints'])
    # The immutable second-attempt16-return prefix has already matched Native.
    # Assert its complete serialized cases and internal FPU history again,
    # independently of the live producer's per-case comparison.
    retained_path=ROOT/'build/research/active-gameplay-attempt2'/('active-gameplay'+suffix+'-partial.json')
    retained_raw=retained_path.read_bytes()
    assert digest(retained_raw)==('e19f9621ce512c00e70899bd14c194edc4bcfab2c8fcb8e64d358fee85c35198' if suffix else 'd54467dc8b0237711fac91cdc82cab89483b51bdf6f0e3ff42ceae553c2fa1c5')
    retained=json.loads(retained_raw);assert len(retained['cases'])==16 and retained['initial']==doc['initial']
    retained_count=min(16,len(doc['cases']))
    for actual,old_case in zip(doc['cases'][:retained_count],retained['cases']):
        normalized=__import__('copy').deepcopy(actual)
        for section in normalized['stages']:assert section.pop('boundaries',[])==[]
        assert normalized==old_case,'Immutable active prefix changed'
    retained_fpu=retained['cases'][retained_count-1]['fpuEnd'] if retained_count else previous_fpu
    assert audit['checkpoints'][:retained_fpu]==retained['fpu']['checkpoints'][:retained_fpu]
    previous=doc['initial'];events=Counter();helper_counts=Counter();phases=[];ticks=[];stores=Counter()
    total_stack=0;all_pcs=set();stack_pcs=set();changed_globals=[];pressed=set();changed_replay=[];object_changes=[];key_changes=0;effect_counts=Counter();boundary_counts=Counter()
    for index,c in enumerate(doc['cases'],1):
        assert c['index']==index and c['before']==previous
        before,after=expanded(c['before']),expanded(c['after']);assert 'frameHeap' in before and 'frameHeap' in after
        assert c['end']==dict(pc=0x30000000,sp=0x1000f42c)
        acquired=expanded(c['acquired']);a=c['acquisition'];assert a['plan']==schedule[index-1]
        g=bytearray(blobs[before['state']['globals']]);original_keys=bytes(g[0x455378-0x44d000:0x455378-0x44d000+300])
        def u32(address):return int.from_bytes(g[address-0x44d000:address-0x44d000+4],'little')
        desired=set();bindings=[]
        for seat,names in enumerate(schedule[index-1]['buttons']):
            status=u32(0x450b4c+4*seat);assert 1<=status<=4;config=0x44fb20+status*80;assert u32(config)==0
            keys=[u32(config+4+4*i) for i in range(7)];assert all(k<300 for k in keys)
            bindings.append(dict(seat=seat,status=status,config=config,device=0,keys=keys))
            desired.update(keys[buttons.index(name)] for name in names)
        changes=[]
        for key in sorted(pressed|desired):
            value=100 if key in desired else 117
            if original_keys[key]!=value:
                changes.append(dict(key=key,address=0x455378+key,before=original_keys[key],after=value));g[0x455378-0x44d000+key]=value
        pressed=desired;key_changes+=len(changes)
        assert a['changes']==changes and a['bindings']==bindings and a['before']==list(original_keys)
        assert a['after']==[100 if n in desired else 117 for n in range(300)]==c['keyboardBefore']
        assert bytes(g)==blobs[acquired['state']['globals']]==blobs[acquired['early']['globals']]
        expected=__import__('copy').deepcopy(before)
        expected['state']['globals']=expected['early']['globals']=acquired['state']['globals'];assert expected==acquired
        cycle=c['cycle'];assert cycle['label']==f'active-{index:02d}' and cycle['stimulus']==[]
        assert cycle['before']==acquired['state'] and cycle['earlyBefore']==acquired['early']
        objects(after);object_changes.append(sum(x!=y for x,y in zip(before['objects'],after['objects'])))
        changed_replay.append(before['state']['memory']!=after['state']['memory'])
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
            for boundary in section.get('boundaries',[]):
                assert boundary['kind']=='memset' and boundary['entryPC']==0x4450a0
                assert boundary['returnPC']==boundary['actualReturnPC']==0x406447
                assert boundary['returnSP']==boundary['entrySP']+4 and boundary['savedBefore']==boundary['savedAfter']
                destination,value,count=boundary['arguments'];assert value==0 and count==400 and boundary['result']==destination
                assert any(h['entry']==0x4061d0 and h['this']+0xf0==destination and h['entrySP']==boundary['entrySP']+24 for h in section['helpers'])
                assert len(blobs[boundary['before']])==count and blobs[boundary['after']]==b'\0'*count
                assert 0x4450a0 not in section['instructions'];boundary_counts['constructorMemset']+=1
            for e in section['effects']:
                context=e['context'];effect_counts[e['kind']]+=1
                assert len(context['registers'])==4 and 0x10000000<=context['sp']<0x10010000
                if e['kind']=='random':
                    assert context['pc']==0x417170
                    assert any(h['entry']==0x417170 and h['entrySP']==context['sp'] and h['arguments']+[h['result']]==e['arguments'] for h in section['helpers'])
                elif e['kind'] in ('catalogSound','builtinSound'):
                    assert context['pc']==(0x416fb0 if e['kind']=='catalogSound' else 0x417090) and len(e['arguments'])==2
                else:
                    assert e['kind']=='reconstruct' and context['pc']==0x4061d0 and e['arguments']==[doc['actorAddresses'].index(context['this'])]
            b=section['boundary'];assert b['fpuBefore'][0]==b['fpuAfter'][0]==0x23f
            assert b['stageDefeatedBefore']==b['stageDefeatedAfter']==cycle['round']['stageDefeated']
            for group,items in section['events'].items():
                for e in items:events[group+':'+e['kind']]+=1
            for h in section['helpers']:
                assert h['returnSP']==h['entrySP']+4+h['pop'] and len(h['saved'])==4
                helper_counts[hex(h['entry'])]+=1
        output=c['output'];assert output['label']=='gameplay-return' and output['before']==previous_stage
        assert output['after']=={k:v for k,v in c['after'].items() if k not in ('frameHeap','objects','objectStrings')} and output['end']==c['end']
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
        value=bytearray(blobs[acquired['state']['globals']]);original=bytes(value)
        assert before['state']['globals']==before['early']['globals'] and after['state']['globals']==after['early']['globals']
        for w in c['globalsWrites']:
            offset=w['address']-0x44d000;size=w['size'];assert size in (1,2,4,8) and 0<=offset<offset+size<=len(value)
            value[offset:offset+size]=w['value'].to_bytes(size,'little');stores[hex(w['pc'])]+=1
        assert bytes(value)==blobs[after['state']['globals']],('Source global stores incomplete',index)
        changed_globals.append(sum(a!=b for a,b in zip(original,value)))
        assert c['keyboardAfter']==list(value[0x455378-0x44d000:0x455378-0x44d000+300])
        ticks.append(int.from_bytes(value[0x450b8c-0x44d000:0x450b8c-0x44d000+4],'little'))
        assert ticks[-1]==index+17
        assert int.from_bytes(value[0x450b80-0x44d000:0x450b80-0x44d000+4],'little')==1
        assert int.from_bytes(value[0x450bbc-0x44d000:0x450bbc-0x44d000+4],'little')==index+17
        assert c['fpuStart']==previous_fpu and c['fpuEnd']>c['fpuStart'];previous_fpu=c['fpuEnd']
        for access in c['stackAccesses']:
            assert access['size']>0 and len(bytes.fromhex(access['bytesBefore']))==access['size']
            assert (0x1000e9bc+0x34<=access['address']<0x1000e9bc+0x74 or 0x1000e9bc+0x44c<=access['address']<0x1000e9bc+0x5c4)
            assert access['write']==(access['reportedValue'] is not None);stack_pcs.add(access['pc'])
        total_stack+=len(c['stackAccesses']);all_pcs.update(c['observedOriginalAddressPCs']);previous=c['after']
    assert previous_fpu==len(audit['checkpoints'])
    pins=json.loads((ROOT/'build/research/continuous-gameplay-fixture-pins.json').read_bytes())
    assert len(pins)==190 and all(digest((FIXTURES/name).read_bytes())==sha for name,sha in pins.items())
    return dict(bytes=len(raw),sha256=digest(raw),parent=doc['parent'],returnedCalls=len(doc['cases']),
        components=len(doc['components']),blobs=len(blobs),oldFixturePinsUnchanged=len(pins),
        componentHashesVerified=True,allBlobBytesMasksAndHashesVerified=True,completeParentReproduced=True,
        retainedActiveCasesReproduced=retained_count,retainedActiveFPUCheckpointsReproduced=retained_fpu,
        fullReturnStateChainVerified=True,sourceGlobalsReconstructedFromWrites=True,changedGlobalBytesByCall=changed_globals,
        inputPhases=phases,ticks=ticks,recordingEnabledThroughout=True,keyTransitions=key_changes,changedRecordingByCall=changed_replay,changedObjectRecordsByCall=object_changes,primitiveEffectCounts=dict(effect_counts),declaredBoundaryCounts=dict(boundary_counts),fullObjectsAndWeaponStringsVerified=True,fpuCheckpoints=len(audit['checkpoints']),stackAccesses=total_stack,
        stackAccessPCs=len(stack_pcs),observedOriginalAddressPCs=len(all_pcs),eventCounts=dict(events),
        helperCounts=dict(helper_counts),globalStorePCs=dict(stores),
        originalNormalReturnFramesVerified=True,nativeCompared=False,windowsVerified=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--control',action='store_true');p.add_argument('--partial',action='store_true');a=p.parse_args()
    suffix='-control' if a.control else '';name='active-gameplay'+suffix
    if a.partial:
        raw=(ROOT/'build/research'/(name+'-partial.json')).read_bytes();doc=json.loads(raw)
        proof=json.loads((ROOT/'build/research'/(name+'-partial.checkpoint.json')).read_bytes())
        assert len(raw)==proof['bytes'] and digest(raw)==proof['sha256'] and len(doc['cases'])==proof['completeReturnedCalls']
    else:
        report,raw,doc=capture(name);assert len(doc['cases'])==report['returnedCalls']==48
    result=validate(doc,suffix,raw)
    (ROOT/'build/research'/(name+('-partial' if a.partial else '')+'-verification.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
