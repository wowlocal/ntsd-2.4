#!/usr/bin/env python3
"""Independently compare a Lua World with retained projectile sequences.

Reads the pinned original corpus, never executes its EXE. Lua receives only
DAT/header/replay RNG and declared case inputs. Original expected snapshots
remain outside its project. Checks whole exported MeleeState, including every
vrest entry, rendering pose, sounds, RNG and MP accounting. This is the retained
two-fighter Practice composition, not original startup or a full match.
"""
import argparse
from collections import Counter
import datetime
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

from check_actor_input import ROOT, EXE, lua, sha

FIXTURE_SHA = '42467b39267e4da268ed6e509777fc75d24fc9bf81c329200ad69cb15158d10c'
FULL_SHA = '8f3643331fb82cf7615a60fe8bc05f7c71250f0d50acdc84677a59764b7d27aa'
RUNNER = r'''
local json=require('json')
local World=require('compat.world')
local corpus=require('fixture')
function love.errorhandler(message)
 io.stderr:write(tostring(message)..'\n');io.stderr:flush()
 return function() return 1 end
end
-- JSON's default tostring loses double precision. Preserve round-trip decimals
-- through its public asNumber API; no game-state or upstream changes.
local arrays={actors=true,sounds=true,projectiles=true,projectileDraws=true,mpSpent=true,vrest=true,combos=true}
local function precise(v,key)
 if type(v)=='number' then return json:asNumber(string.format('%.17g',v)) end
 if type(v)~='table' then return v end
 local r=arrays[key] and json:newArray({}) or {}
 for k,x in pairs(v) do r[k]=precise(x,k) end
 return r
end
local function encode(v) return json:encode(precise(v)) end
local function copy(v)
 if type(v)~='table' then return v end
 local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function rngInputs(r) return {table=r.table,source=r.source,sourceSHA256=r.sourceSHA256} end
local function config(c)
 return {headers=corpus.headers,definitions=corpus.definitions,voiceDefinitions=corpus.voiceDefinitions,
  projectileDefinitions=corpus.projectileDefinitions,random=corpus.random,initial=c.initial,localPlayer=c.localPlayer}
end
function love.load()
 local out=assert(io.open(love.filesystem.getSource()..'/actual.jsonl','w'))
 local integrity={}
 for _,c in ipairs(corpus.cases) do
  local cfg=copy(config(c));local before=encode(cfg);local inputsBefore=encode(c.inputs)
  local ok,world=pcall(World.new,cfg)
  if not ok then out:write(encode({label=c.label,tick=-1,ok=false,error=tostring(world)})..'\n')
  else
   for tick,masks in ipairs(c.inputs) do
    local good,state=pcall(world.tick,world,masks)
    out:write(encode({label=c.label,tick=tick-1,ok=good,state=good and state or nil,error=not good and tostring(state) or nil})..'\n')
    if not good then break end
   end
  end
  integrity[#integrity+1]={label=c.label,configUnchanged=before==encode(cfg),inputsUnchanged=inputsBefore==encode(c.inputs),
   rngTableAndProvenanceUnchanged=ok and encode(rngInputs(world.random))==encode(rngInputs(cfg.random)) or false}
  out:flush()
 end
 out:close()
 local check=assert(io.open(love.filesystem.getSource()..'/input-integrity.json','w'));check:write(encode(integrity));check:close()
 -- Existing Native regression: reject unsupported attack while five live shots
 -- and spent chakra exist, retaining both state and the next valid tick.
 local ok,result=pcall(function()
  local cfg=config({initial={{frame=212,y=-500,x=400},{x=580}},localPlayer=0})
  local left,right=copy(cfg),copy(cfg);local cfgBefore=encode(cfg)
  local world,untouched=World.new(left),World.new(right)
  for tick=0,21 do local masks={0,tick==0 and 2 or tick==1 and 32 or tick==2 and 8 or 0};world:tick(masks);untouched:tick(masks) end
  local state=world:snapshot();local before=encode(state);local rngBefore=encode(world.random)
  assert(#state.projectiles==5 and state.mpSpent[2]==100,'Rollback setup needs five live shots and 100 spent MP')
  local success,message=pcall(world.tick,world,{8,0})
  return {rejected=not success,error=not success and tostring(message) or nil,
   expectedBoundary=not success and tostring(message):find('Unsupported jump attack',1,true)~=nil,
   unchanged=before==encode(world:snapshot()),rngUnchanged=rngBefore==encode(world.random),
   configUnchanged=cfgBefore==encode(left) and cfgBefore==encode(right),
   continuationEqual=encode(world:tick({0,0}))==encode(untouched:tick({0,0}))}
 end)
 local f=assert(io.open(love.filesystem.getSource()..'/rollback-result.json','w'))
 f:write(encode({ok=ok,result=ok and result or nil,error=not ok and tostring(result) or nil}));f:close()
 love.event.quit(0)
end
'''


def differences(actual, expected, path='$'):
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            yield path, actual, expected
            return
        for k in sorted(expected.keys() | actual.keys()):
            if k not in expected or k not in actual:
                yield path+'.'+k, actual.get(k, '<missing>'), expected.get(k, '<missing>')
            else:
                yield from differences(actual[k], expected[k], path+'.'+k)
    elif isinstance(expected, list):
        if not isinstance(actual, list):
            yield path, actual, expected
            return
        if len(actual) != len(expected): yield path+'.length', len(actual), len(expected)
        for i, (a, e) in enumerate(zip(actual, expected)):
            yield from differences(a, e, f'{path}[{i}]')
    elif ((isinstance(actual, bool) != isinstance(expected, bool))
          or (isinstance(expected, (int, float)) and not isinstance(actual, (int, float)))
          or actual != expected):
        yield path, actual, expected


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root', type=Path, required=True)
    ap.add_argument('--label', required=True)
    ap.add_argument('--full-retained', action='store_true', help='Use the existing, pinned 575-case corpus; never regenerate it')
    args = ap.parse_args()
    assert args.label and all(c.isalnum() or c in '-_' for c in args.label)
    build = ROOT/'build/l2df-prototype'
    assert build.is_symlink() and str(build.resolve()).startswith('/Volumes/X5/ntsd-2.4-research/')
    vol = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert vol['VolumeUUID'].upper() == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
    assert shutil.disk_usage(build).free > 6*1024**3
    out = build/'chidori-compat-20260912'/args.label
    out.mkdir()
    (out/'compat').mkdir(); (out/'reference-pins').mkdir()
    reference = args.reference_root/('build/original/projectiles-oracle.json' if args.full_retained else 'native/Tests/NTSDCoreTests/Fixtures/original-projectiles.json')
    expected_sha = FULL_SHA if args.full_retained else FIXTURE_SHA
    expected_cases, expected_ticks = (575, 16685) if args.full_retained else (20, 2010)
    paths = [reference,
             *[args.reference_root/'native/Sources/NTSDCore'/n for n in
               ('OriginalFighter.swift', 'OriginalMelee.swift', 'OriginalProjectile.swift', 'OriginalRandom.swift', 'OriginalFrameLoader.swift', 'OriginalStateRecord.swift', 'GameData.swift')],
             args.reference_root/'native/Tests/NTSDCoreTests/OriginalMeleeTests.swift',
             *[args.reference_root/'docs'/n for n in ('FRAME_LOADER.md', 'MOVEMENT.md', 'COMBAT.md', 'PROJECTILES.md')],
             *sorted((ROOT/'prototypes/l2df/compat').glob('*.lua')), Path(__file__),
             Path(__file__).with_name('check_actor_input.py'), build/'game/l2df/external/json.lua']
    assert (ROOT/'prototypes/l2df/compat/world.lua') in paths
    pins = []
    for p in paths:
        raw = p.read_bytes()
        dest = out/'compat'/p.name if p.parent.name == 'compat' else out/'reference-pins'/p.name
        if p.name == 'json.lua': dest = out/'json.lua'
        if p == reference: dest = out.parent/(args.label+'-'+reference.name)
        dest.write_bytes(raw)
        pins.append({'path': str(p), 'sha256': sha(raw), 'bytes': len(raw), 'snapshot': str(dest.resolve())})
    # Original expected file is kept as an evidence sibling, not inside Lua's
    # source project. The test kernel only receives fixture.lua below.
    expected_file = out.parent/(args.label+'-'+reference.name)
    raw = expected_file.read_bytes(); assert sha(raw) == expected_sha
    corpus = json.loads(raw); assert corpus['exeSHA256'] == EXE
    cases = corpus['cases']; assert len(cases) == expected_cases and sum(len(c['states']) for c in cases) == expected_ticks
    assert len({c['label'] for c in cases}) == expected_cases
    for c in cases: assert len(c['inputs']) == len(c['states'])
    controlled = {k: v for k, v in corpus.items() if k not in ('cases', 'randomSamples')}
    controlled['cases'] = [{k: v for k, v in c.items() if k != 'states'} for c in cases]
    (out/'fixture.lua').write_text('return '+lua(controlled)+'\n')
    (out/'main.lua').write_text(RUNNER)
    (out/'conf.lua').write_text("function love.conf(t) t.identity='ntsd-world-reference';t.window=false;t.modules.audio=false;t.modules.graphics=false;t.modules.joystick=false;t.modules.physics=false end\n")
    exe = build/'runtime/love.app/Contents/MacOS/love'
    command = [str(exe.resolve()), str(out.resolve())]
    started = time.monotonic()
    job = {'command': command, 'cwd': str(out.resolve()), 'startUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'pins': pins, 'executableSHA256': sha(exe.read_bytes()), 'timeoutSeconds': 90,
           'sourceExecution': False, 'status': 'starting'}
    with (out/'stdout.log').open('wb') as stdout, (out/'stderr.log').open('wb') as stderr:
        proc = subprocess.Popen(command, cwd=out, stdout=stdout, stderr=stderr)
        job.update(pid=proc.pid, status='running'); (out/'job.json').write_text(json.dumps(job, indent=2)+'\n')
        try: code = proc.wait(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill(); code = proc.wait(); job['timeout'] = True
    job.update(exitCode=code, elapsedSeconds=time.monotonic()-started, status='terminal')
    (out/'job.json').write_text(json.dumps(job, indent=2)+'\n')
    assert code == 0, job
    actual = [json.loads(line) for line in (out/'actual.jsonl').read_text().splitlines()]
    by_case = {c['label']: {} for c in cases}
    for item in actual:
        assert item['label'] in by_case and item['tick'] not in by_case[item['label']]
        by_case[item['label']][item['tick']] = item
    failures = []; summaries = []; total_ticks = 0
    for c in cases:
        actual_ticks = by_case[c['label']]; errors = [v for v in actual_ticks.values() if not v['ok']]
        exact_tick_set = set(actual_ticks) == set(range(len(c['states'])))
        count = 0; mismatch_ticks = 0; samples = []; field_counts = Counter()
        for tick, expected in enumerate(c['states']):
            got = actual_ticks.get(tick)
            if got is None or not got['ok']: continue
            count += 1
            diffs = list(differences(got['state'], expected))
            if diffs:
                mismatch_ticks += 1
                for path, _, _ in diffs: field_counts[path] += 1
                if len(samples) < 20:
                    samples.append({'tick': tick, 'differences': [{'path': p, 'actual': a, 'expected': e} for p, a, e in diffs[:25]], 'totalDifferences': len(diffs)})
        total_ticks += count
        accepted = exact_tick_set and count == len(c['states']) and not mismatch_ticks and not errors
        item = {'label': c['label'], 'accepted': accepted, 'returnedTicks': count, 'expectedTicks': len(c['states']),
                'mismatchedTicks': mismatch_ticks, 'exactTickSet': exact_tick_set, 'errors': errors, 'differingFields': dict(field_counts)}
        summaries.append(item)
        if not accepted: failures.append({**item, 'firstDifferences': samples})
    rollback = json.loads((out/'rollback-result.json').read_text())
    rollback_pass = rollback['ok'] and all(rollback['result'][k] for k in ('rejected', 'expectedBoundary', 'unchanged', 'rngUnchanged', 'configUnchanged', 'continuationEqual'))
    integrity = json.loads((out/'input-integrity.json').read_text())
    assert [c['label'] for c in integrity] == [c['label'] for c in cases]
    integrity_pass = all(all(c[k] for k in ('configUnchanged', 'inputsUnchanged', 'rngTableAndProvenanceUnchanged')) for c in integrity)
    for p, pin in zip(paths, pins): assert sha(p.read_bytes()) == pin['sha256'], ('input changed during run', str(p))
    report = {'accepted': not failures and rollback_pass and integrity_pass and len(actual) == expected_ticks,
              'cases': expected_cases, 'returnedTicks': total_ticks, 'expectedTicks': expected_ticks, 'outputRecords': len(actual),
              'failedCases': len(failures), 'casesSummary': summaries, 'rollback': rollback, 'job': job,
              'fixtureSHA256': expected_sha, 'fullRetainedCorpus': args.full_retained, 'sourceReexecuted': False, 'wholeOriginalMatch': False, 'inputIntegrity': integrity,
              'comparison': 'All exported MeleeState fields; exact numeric equality, no epsilon; %.17g double serialization',
              'actualSHA256': sha((out/'actual.jsonl').read_bytes()), 'directory': str(out.resolve())}
    (out/'failures.json').write_text(json.dumps(failures, indent=2)+'\n')
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ('accepted', 'cases', 'returnedTicks', 'failedCases', 'rollback', 'directory')}))
    raise SystemExit(0 if report['accepted'] else 1)


if __name__ == '__main__': main()
