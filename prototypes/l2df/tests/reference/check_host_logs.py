#!/usr/bin/env python3
"""Review completed native host clock and camera-projection logs, read-only.

This checks actual timer callback observations and Object.data input to L2DF
Transform/Render. It is not a Windows event-loop, pixel or physical-device test.
Numeric modules have separate retained-source gates. Source fixtures are read
only for independently established District parameters, never supplied to game.
"""
import argparse
import datetime
import json
from pathlib import Path
from check_actor_input import sha
from check_presentation import PRESENTATION_SHA
from check_world import differences


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root',required=True,type=Path)
    ap.add_argument('--logs',required=True,type=Path)
    ap.add_argument('--report',required=True,type=Path)
    a=ap.parse_args();assert not a.report.exists()
    def read(name):return json.loads((a.logs/name).read_text())
    def rows(name):return [json.loads(line) for line in (a.logs/name).read_text().splitlines()]
    job=read('job.json');assert job['state']=='terminal' and job['exitCode']==0 and not job.get('timeout')
    assert Path(job['output']).resolve()==a.logs.resolve()
    exe=Path(job['command'][0]).resolve();fused=exe.parents[1]/'Resources/NTSD.love'
    assert job['inputPins'] and all(any(Path(p['path']).resolve()==path for p in job['inputPins']) for path in (exe,fused))
    verified=[]
    for p in job['inputPins']:
        candidates=[Path(p['snapshot'])] if 'snapshot' in p else [a.logs/Path(p['path']).name,Path(p['path'])]
        q=next((q for q in candidates if q.is_file() and q.stat().st_size==p['bytes'] and sha(q.read_bytes())==p['sha256']),None)
        assert q is not None,p
        verified.append({'path':str(q.resolve()),'sha256':p['sha256']})
    timer=rows('timer.jsonl');states=rows('world.jsonl');presentation=rows('presentation.jsonl')
    assert timer and len(states)==len(presentation)==read('summary.json')['ticks']
    assert all(type(row['tick']) is int for row in states+presentation)
    assert [s['tick'] for s in states]==[p['tick'] for p in presentation]==list(range(len(states)))
    previous=None;dispatches=0
    for index,row in enumerate(timer):
        assert row['iteration']==index and type(row['iteration']) is int
        assert all(type(v) is int and 0<=v<2**32 for v in [row['baselineBefore'],row['baselineAfter'],*row['clock']])
        assert type(row['dispatches']) is int and all(type(v) is int for v in row['sleep'])
        assert previous is None or row['baselineBefore']==previous,'Unexplained baseline reset in ordinary run'
        clock=iter(row['clock']);baseline=row['baselineBefore'];due=(next(clock)-baseline)%2**32>33
        if due:
            if (next(clock)-baseline)%2**32>100:baseline=(next(clock)-100)%2**32
            baseline=(baseline+33)%2**32
        remaining=(baseline-next(clock)+33)%2**32
        if remaining>=2**31:remaining-=2**32
        assert next(clock,None) is None and row['baselineAfter']==baseline
        assert row['dispatches']==int(due) and row['sleep']==([min(remaining,5)] if remaining>0 else [])
        dispatches+=row['dispatches'];previous=baseline
    assert dispatches==len(states),'Aggregate dispatch and game tick counts differ'
    raw=(a.reference_root/'native/Tests/NTSDCoreTests/Fixtures/original-presentation.json').read_bytes()
    assert sha(raw)==PRESENTATION_SHA
    layers=json.loads(raw)['layers'];counters=[0]*len(layers)
    pose_count=0;draw_count=0
    for item,row in zip(presentation,states):
        state=row['state'];camera=state['cameraX']
        assert type(camera) is int and 0<=camera<=166
        assert type(item['cameraX']) is int and item['cameraX']==camera
        assert not list(differences(item['viewport'],{'width':794,'height':550}))
        draws=[]
        for i,layer in enumerate(layers):
            period=int(layer.get('cc',0))
            if period>0:counters[i]=(counters[i]+1)%period
            if period<=0 or int(layer.get('c1',0))<=counters[i]<=int(layer.get('c2',0)):
                # District operands are bounded and exact here; general overflow
                # and loops/fills have separate whole-background evidence.
                x=int(layer['x'])-int((int(layer['width'])-794)*camera/166)
                draws.append({'layer':i,'x':x,'y':int(layer['y']),'transparency':int(layer['transparency'])})
        assert not list(differences(item['background'],draws)) and not list(differences(item['counters'],counters))
        source=[{'slot':i,'id':2 if i==0 else 11,'x':v['renderX'],'y':v['renderY'],'z':v['renderZ'],'facing':v['renderFacing']} for i,v in enumerate(state['actors'])]
        source+=state['projectileDraws'];source.sort(key=lambda p:p['slot'])
        assert len(item['poses'])==len(source)
        for got,want in zip(item['poses'],source):
            assert all(type(got[k]) in (int,float) for k in ('slot','id','x','y','z','facing'))
            assert {k:got[k] for k in ('slot','id','x','y','z','facing')}=={'slot':want['slot'],'id':want['id'],'x':want['x']-camera,'y':-want['y'],'z':want['z'],'facing':1-2*want['facing']}
        pose_count+=len(source);draw_count+=len(draws)
    report={'accepted':True,'reviewedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'operation':__doc__,'timerDecisions':len(timer),'dispatches':dispatches,'gameTicks':len(states),'dispatchCoupling':'Aggregate counts; single-update call site reviewed separately, no per-dispatch game tick instrumentation','backgroundRequests':draw_count,'preRenderObjectPoses':pose_count,'poseFieldsCompared':['slot','id','x','y','z','facing'],'poseFieldsNotCompared':['pic','centerx','centery'],'pixelOrDeviceClaim':False,'sourceExecution':False,'originalFixtureSHA256':PRESENTATION_SHA,'runPinsVerified':verified,'artifacts':[{'path':str((a.logs/n).resolve()),'sha256':sha((a.logs/n).read_bytes())} for n in ('job.json','timer.jsonl','world.jsonl','presentation.jsonl','summary.json')],'comparatorSHA256':sha(Path(__file__).read_bytes())}
    a.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('accepted','timerDecisions','dispatches','gameTicks','backgroundRequests','preRenderObjectPoses')}))

if __name__=='__main__':main()
