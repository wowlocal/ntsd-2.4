#!/usr/bin/env python3
"""Read completed native GUI logs and compare every state/input with a retained case.

No process is started and no EXE is executed. Verifies callback-derived input,
full MeleeState, audio call count, run pins and exact case cardinality. Visual
inspection and physical keyboard/heard audio remain separate observations.
"""
import argparse
import datetime
import json
from pathlib import Path
from check_actor_input import EXE, sha
from check_world import FIXTURE_SHA, differences


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root',type=Path,required=True)
    ap.add_argument('--log-dir',type=Path,required=True)
    ap.add_argument('--report',type=Path,required=True)
    a=ap.parse_args(); assert not a.report.exists(), 'Preserve existing review'
    logs=a.log_dir
    job=json.loads((logs/'job.json').read_text())
    assert job['state']=='terminal' and job['exitCode']==0 and not job.get('timeout'),job
    assert Path(job['output']).resolve()==logs.resolve(), 'Job output does not identify reviewed logs'
    assert job['inputPins'] and job['command'], 'Missing run provenance'
    executable=Path(job['command'][0]).resolve()
    assert any(Path(p['path']).resolve()==executable for p in job['inputPins']), 'Executable pin missing'
    assert any(p.get('snapshot') and Path(p['snapshot']).resolve()==(logs/'case-input.json').resolve() for p in job['inputPins']), 'Case input snapshot pin missing'
    fused=executable.parents[1]/'Resources/NTSD.love'
    if fused.exists():
        assert any(Path(p['path']).resolve()==fused.resolve() for p in job['inputPins']), 'Fused game pin missing'
    else:
        game=Path(job['command'][1]).resolve()
        assert (game/'main.lua').is_file() and any(Path(p['path']).resolve()==game/'main.lua' for p in job['inputPins']), 'Unfused game source pin missing'
    raw=(a.reference_root/'native/Tests/NTSDCoreTests/Fixtures/original-projectiles.json').read_bytes()
    assert sha(raw)==FIXTURE_SHA
    corpus=json.loads(raw);assert corpus['exeSHA256']==EXE
    case_input=json.loads((logs/'case-input.json').read_text())
    case=next(c for c in corpus['cases'] if c['label']==case_input['label'])
    assert case_input=={k:v for k,v in case.items() if k!='states'}, 'Initial/held inputs differ from declared case'
    actual=[json.loads(line) for line in (logs/'world.jsonl').read_text().splitlines()]
    masks=[json.loads(line) for line in (logs/'inputs.jsonl').read_text().splitlines()]
    assert len(actual)==len(masks)==len(case['states'])==len(case['inputs'])
    assert all(type(r['tick']) is int for r in actual+masks)
    assert all(isinstance(r['inputs'],list) and len(r['inputs'])==2 and all(type(v) is int and 0<=v<=255 for v in r['inputs']) for r in masks)
    assert [r['tick'] for r in actual]==[r['tick'] for r in masks]==list(range(len(actual)))
    assert [r['inputs'] for r in masks]==case['inputs'], 'L2DF callback/controller input differs'
    failures=[]
    for tick,row in enumerate(actual):
        assert set(row)=={'tick','state'}
        diffs=list(differences(row['state'],case['states'][tick]))
        if diffs:failures.append({'tick':tick,'differences':diffs})
    verified=[]
    for pin in job['inputPins']:
        candidates=[Path(pin['snapshot'])] if 'snapshot' in pin else [logs/Path(pin['path']).name,Path(pin['path'])]
        match=next((p for p in candidates if p.is_file() and p.stat().st_size==pin['bytes'] and sha(p.read_bytes())==pin['sha256']),None)
        assert match is not None,('Run pin unavailable or changed',pin)
        verified.append({'original':pin['path'],'verified':str(match.resolve()),'sha256':pin['sha256']})
    summary=json.loads((logs/'summary.json').read_text());assert summary['ticks']==len(actual) and not summary.get('boundary')
    expected_sounds=sum(len(s['sounds']) for s in case['states'])
    assert summary['counts']['audioCalls']==summary['counts']['audioPlaying']==expected_sounds
    assert summary['mpSpent']==case['states'][-1]['mpSpent']
    result={'accepted':not failures,'reviewedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'case':case['label'],
            'ticks':len(actual),'comparison':'Every exported MeleeState field; exact numeric equality, callback masks and original initial inputs',
            'fixtureSHA256':FIXTURE_SHA,'stateTraceSHA256':sha((logs/'world.jsonl').read_bytes()),'inputTraceSHA256':sha((logs/'inputs.jsonl').read_bytes()),
            'audioCallAndPlayingCount':expected_sounds,'physicalKeyboardOrHeardAudioClaim':False,'originalExecuted':False,'wholeMatchClaim':False,
            'failures':failures,'verifiedRunPins':verified,'job':job,'summary':summary}
    a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('accepted','case','ticks','audioCallAndPlayingCount','failures')}))
    raise SystemExit(0 if result['accepted'] else 1)


if __name__=='__main__':main()
