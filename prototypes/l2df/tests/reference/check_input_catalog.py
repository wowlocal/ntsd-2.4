#!/usr/bin/env python3
"""Check original input-frame availability using retained frame-parser evidence.

No original execution. All 585 Naruto/Sasuke frame groups / 586 occurrences
compare twelve known input fields with the pinned original parser snapshots.
Separate Native-only boundary trials reject affordable unimplemented moves
transactionally; rejection is not claimed as the original successful behavior.
"""
import argparse
import datetime
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import time
from check_actor_input import ROOT, EXE, FRAME, lua, sha
from check_world import RUNNER as WORLD_RUNNER, FIXTURE_SHA

FRAME_SHA = '5904de1b07b4c6011209d2e2fb30dd257827894a82c49ecb5584563b45d1499b'
RUNNER = WORLD_RUNNER.split('function love.load()')[0] + r'''
local Projector=require('compat.frame_projector')
local frameCases=require('frame-cases')
function love.load()
 local out=assert(io.open(love.filesystem.getSource()..'/actual.jsonl','w'))
 for _,c in ipairs(frameCases) do
  local prefix={}
  for occurrence,section in ipairs(c.definitions) do
   prefix[#prefix+1]=section
   local before=encode(prefix)
   local ok,frames=pcall(Projector.frames,prefix)
   local value={}
   if ok then
    local f=assert(frames[c.frame]);value.present=f.present==true or f.present==1
    for _,name in ipairs({'mp','hit_a','hit_d','hit_j','hit_Fa','hit_Ua','hit_Da','hit_Fj','hit_Uj','hit_Dj','hit_ja'}) do value[name]=f[name] end
   end
   out:write(encode({label=c.label,occurrence=occurrence,ok=ok,error=not ok and tostring(frames) or nil,
    value=value,inputUnchanged=before==encode(prefix)})..'\n')
  end
 end
 out:close()
 local trials={}
 for _,mp in ipairs({0,74,75,500}) do
  local cfg=config({initial={{mp=mp},{}},localPlayer=0});cfg.inputDefinitions=corpus.inputDefinitions
  local cfgBefore=encode(cfg);local world=World.new(cfg);local trial={mp=mp,rejected=false,insufficientMP=false}
  for tick=0,23 do
   local mask=tick==0 and 2 or tick==1 and 16 or tick==2 and 8 or 0
   local before={state=world:snapshot(),input=copy(world.input),random=copy(world.random)}
   local ok,result=pcall(world.tick,world,{mask,0})
   if not ok then
    trial.rejected=true;trial.error=tostring(result);trial.tick=tick
    trial.correctBoundary=trial.error:find('Unsupported successful technique transfer 263',1,true)~=nil
    trial.unchanged=encode(before)==encode({state=world:snapshot(),input=world.input,random=world.random})
    break
   end
   for _,event in ipairs(world.events) do
    if event.kind=='insufficientMP' and event.target==263 then trial.insufficientMP=true;trial.failureTick=tick end
   end
  end
  trial.finalMP=world:snapshot().actors[1].mp;trial.spentMP=world:snapshot().mpSpent[1]
  trial.configUnchanged=cfgBefore==encode(cfg);trials[#trials+1]=trial
 end
 local f=assert(io.open(love.filesystem.getSource()..'/boundaries.json','w'));f:write(encode(trials));f:close()
 love.event.quit(0)
end
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root', required=True, type=Path)
    ap.add_argument('--label', required=True)
    a = ap.parse_args(); assert a.label and all(c.isalnum() or c in '-_' for c in a.label)
    b = ROOT/'build/l2df-prototype'
    assert b.is_symlink() and str(b.resolve()).startswith('/Volumes/X5/ntsd-2.4-research/')
    vol = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert vol['VolumeUUID'].upper() == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
    assert shutil.disk_usage(b).free > 6*1024**3
    out = b/'chidori-compat-20260912'/a.label; out.mkdir(); (out/'compat').mkdir()
    frame_path = a.reference_root/'build/original/frame-oracle.json'
    fixture = a.reference_root/'native/Tests/NTSDCoreTests/Fixtures/original-projectiles.json'
    original = [b/'game/derived/chars'/name for name in ('naruto.dat', 'sasuke.dat')]
    paths = [frame_path, fixture, *original, *sorted((ROOT/'prototypes/l2df/compat').glob('*.lua')),
             b/'game/l2df/external/json.lua', Path(__file__), Path(__file__).with_name('check_actor_input.py'),
             Path(__file__).with_name('check_world.py'), a.reference_root/'docs/FRAME_LOADER.md',
             a.reference_root/'native/Sources/NTSDCore/OriginalFrameLoader.swift']
    pins = []
    for n,p in enumerate(paths):
        raw = p.read_bytes()
        if p in (frame_path, fixture): dest=out.parent/(a.label+'-'+p.name)
        elif p.parent.name == 'compat': dest=out/'compat'/p.name
        elif p.name=='json.lua': dest=out/'json.lua'
        else: dest=out/(str(n)+'-'+p.name)
        dest.write_bytes(raw);pins.append({'path':str(p),'snapshot':str(dest.resolve()),'sha256':sha(raw),'bytes':len(raw)})
    raw=Path(pins[0]['snapshot']).read_bytes();assert sha(raw)==FRAME_SHA
    frames=json.loads(raw);assert frames['exeSHA256']==EXE
    cases=[c for c in frames['cases'] if c['label'].startswith(('chars/naruto.dat:','chars/sasuke.dat:'))]
    assert len(cases)==585 and sum(len(c['snapshots']) for c in cases)==586
    assert all(len(c['definitions'])==len(c['snapshots']) for c in cases)
    input_cases=[{'label':c['label'],'frame':int(c['label'].split(':')[-1]),'definitions':c['definitions']} for c in cases]
    (out/'frame-cases.lua').write_text('return '+lua(input_cases)+'\n')
    raw=Path(pins[1]['snapshot']).read_bytes();assert sha(raw)==FIXTURE_SHA
    ref=json.loads(raw);config={k:ref[k] for k in ('headers','definitions','voiceDefinitions','projectileDefinitions','random')}
    full=[]
    for n,p in enumerate(original):
        text=p.read_bytes().decode('latin1').replace('\r\n','\n')
        sections=re.findall(r'<frame>\s+[+-]?\d+\s+.*?<frame_end>',text,re.S)
        assert len(sections)==(318 if n==0 else 268)
        prefix='chars/'+p.name+':'
        captured={int(c['label'].split(':')[-1]):c['definitions'] for c in cases if c['label'].startswith(prefix)}
        ordered={}
        for section in sections:
            frame=int(re.match(r'<frame>\s+([+-]?\d+)',section).group(1))
            ordered.setdefault(frame,[]).append(section)
        assert ordered==captured, ('Original per-frame occurrence order differs from retained frame corpus',p)
        full.append(sections)
    config['inputDefinitions']=full
    (out/'fixture.lua').write_text('return '+lua(config)+'\n')
    (out/'main.lua').write_text(RUNNER)
    (out/'conf.lua').write_text("function love.conf(t) t.identity='ntsd-input-catalog';t.window=false;t.modules.audio=false;t.modules.graphics=false;t.modules.joystick=false;t.modules.physics=false end\n")
    exe=b/'runtime/love.app/Contents/MacOS/love';command=[str(exe.resolve()),str(out.resolve())]
    started=time.monotonic();job={'command':command,'cwd':str(out.resolve()),'startUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pins':pins,'executableSHA256':sha(exe.read_bytes()),'sourceExecution':False,'timeoutSeconds':90}
    with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
        proc=subprocess.Popen(command,cwd=out,stdout=stdout,stderr=stderr)
        job.update(pid=proc.pid,status='running');(out/'job.json').write_text(json.dumps(job,indent=2)+'\n')
        try:code=proc.wait(timeout=90)
        except subprocess.TimeoutExpired:proc.kill();code=proc.wait();job['timeout']=True
    job.update(status='terminal',exitCode=code,elapsedSeconds=time.monotonic()-started);(out/'job.json').write_text(json.dumps(job,indent=2)+'\n');assert code==0,job
    expected=[]
    for c in cases:
        for n,snapshot in enumerate(c['snapshots'],1):
            expected.append({'label':c['label'],'occurrence':n,'value':{'present':snapshot['words']['0']==1,**{k:snapshot['words'][str(o)] for k,o in FRAME.items()}}})
    actual=[json.loads(line) for line in (out/'actual.jsonl').read_text().splitlines()];assert len(actual)==len(expected)==586
    failures=[]
    for got,want in zip(actual,expected):
        assert got['label']==want['label'] and got['occurrence']==want['occurrence']
        correct_types=type(got['value'].get('present')) is bool and all(type(got['value'].get(k)) in (int,float) for k in FRAME)
        if not got['ok'] or not got['inputUnchanged'] or not correct_types or got['value']!=want['value']:failures.append({'actual':got,'expected':want})
    trials=json.loads((out/'boundaries.json').read_text());assert [t['mp'] for t in trials]==[0,74,75,500]
    # Cost75 is independently present in the retained source frame263 snapshot.
    assert next(c for c in cases if c['label']=='chars/naruto.dat:263')['snapshots'][-1]['words']['76']==75
    boundary_pass=all(t['configUnchanged'] and t['finalMP']==t['mp'] and t['spentMP']==0 and
                      ((t['rejected'] and t['correctBoundary'] and t['unchanged'] and t['tick']==13) if t['mp']>=75 else
                       (not t['rejected'] and t['insufficientMP'] and t['failureTick']==13)) for t in trials)
    for p,pin in zip(paths,pins):assert sha(p.read_bytes())==pin['sha256'],('Input changed',p)
    report={'accepted':not failures and boundary_pass,'groups':585,'occurrences':586,'knownInputFields':12,'failures':failures,'nativeBoundaryTrials':trials,
            'wholeLoaderOrOriginalUnsupportedMatch':False,'nativeBoundaryTick':13,'originalWholeMoveTimingCompared':False,
            'job':job,'frameCorpusSHA256':FRAME_SHA,'directory':str(out.resolve())}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ('accepted','groups','occurrences','failures','nativeBoundaryTrials','directory')}))
    raise SystemExit(0 if report['accepted'] else 1)


if __name__=='__main__':main()
