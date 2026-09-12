#!/usr/bin/env python3
"""Compare owned Lua timer/background with immutable retained NTSD evidence.

No original EXE/DLL execution. The2025 reference timer decisions use controlled
clock/dispatch/recovery/Sleep responses. The36 aggregate samples and120 District
draw lists are separate finite contracts, not actual Windows/device observations.
Expected output stays outside the Lua project. Every run preserves its inputs.
"""
import argparse
import base64
import datetime
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import time
import zlib
from check_actor_input import ROOT, EXE, lua, sha
from check_world import differences

TIMER_SHA='ee66e26e9a6b7bb7cae675e0d138827260642c2ac1431222bef0133610580b74'
RAW_SHA='181215171f305c51908de523738cc6fa75ab5beb0cbf99a7be484fb6c5a2e632'
PRESENTATION_SHA='dfc3777858d83ead181835f18cde9af3d78285f7ed8385b192804ffec170a4f0'
RUNNER=r'''
local Timer=require('compat.application_timer')
local Background=require('compat.background')
local json=require('json')
local inputs=require('inputs')
local function encode(v,key)
 local function project(v,key)
  if type(v)=='number' then return json:asNumber(string.format('%.17g',v)) end
  if type(v)~='table' then return v end
  local arrays={events=true,arguments=true,draws=true,counters=true}
  local result=arrays[key] and json:newArray({}) or {}
  for k,x in pairs(v) do result[k]=project(x,k) end
  return result
 end
 return json:encode(project(v,key))
end
function love.load()
 local out=assert(io.open(love.filesystem.getSource()..'/actual.jsonl','wb'))
 local function write(v) out:write(encode(v)..'\n') end
 for _,c in ipairs(inputs.timer) do
  local before=encode(c);local timer=Timer.new(c.baselineBefore)
  local events,reads,targets={},0,0
  local function event(kind,args) events[#events+1]={kind=kind,arguments=args} end
  timer:iterate(c.speed,{
   time=function() reads=reads+1;local value=assert(c.clockResponses[reads]);event('time',{value});return value end,
   target=function() targets=targets+1;return c.target end,
   dispatch=function(target) event('dispatch',{target,c.dispatchResult%4294967296});return c.dispatchResult end,
   recoverSurface=function() event('recoverSurface',{}) end,
   sleep=function(value) event('sleep',{value}) end})
  write({kind='timer',index=c.index,baseline=timer.baseline,events=events,targets=targets,inputUnchanged=before==encode(c)})
 end
 local aggregate,aggregateStart
 for index,c in ipairs(inputs.clock) do
  if aggregateStart~=c.start then aggregate=Timer.new(c.start);aggregateStart=c.start end
  local timer=aggregate;local ticks=0
  for iteration=1,4 do
   local before=ticks
   timer:iterate(1,{time=function() return c.now end,target=function() return 0 end,
    dispatch=function() ticks=ticks+1;return 0 end,recoverSurface=function() error('unexpected recovery') end,sleep=function() end})
   if ticks==before then break end
  end
  write({kind='clock',index=index,baseline=timer.baseline,ticks=ticks})
 end
 local before=encode(inputs.layers);local background=Background.new(960,inputs.layers)
 for index,camera in ipairs(inputs.camera) do
  local draws=background:draw(camera,true)
  local counters=encode(background.counters,'counters')
  local preview=background:draw(camera,false)
  write({kind='background',index=index,draws=draws,previewUnchanged=encode(draws,'draws')==encode(preview,'draws') and counters==encode(background.counters,'counters'),inputUnchanged=before==encode(inputs.layers)})
 end
 local timer=Timer.new(0);local requests={};local function req(s)requests[#requests+1]={kind=s,arguments={}} end
 local ok,err=pcall(timer.iterate,timer,1,{time=function() return 34 end,target=function()req('target');return 7 end,
  dispatch=function()req('dispatch');return -1 end,recoverSurface=function()req('recover') end,sleep=function()req('sleep');error('native late sleep observer') end})
 write({kind='rollback',rejected=not ok,reasonMatches=tostring(err):find('native late sleep observer',1,true)~=nil,baseline=timer.baseline,events=requests})
 out:close();love.event.quit(0)
end
'''

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root',type=Path,required=True)
    ap.add_argument('--label',required=True)
    a=ap.parse_args();assert a.label and all(c.isalnum() or c in '-_' for c in a.label)
    storage=ROOT/'build/l2df-prototype'
    assert storage.is_symlink() and str(storage.resolve()).startswith('/Volumes/X5/ntsd-2.4-research/')
    volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
    assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
    assert shutil.disk_usage(storage).free>6*1024**3
    out=storage/'presentation-20260912'/a.label;out.mkdir();(out/'compat').mkdir()
    paths=[a.reference_root/'native/Tests/NTSDCoreTests/Fixtures'/n for n in ('original-application-timer.json','original-presentation.json')]
    paths += [ROOT/'prototypes/l2df/compat'/n for n in ('application_timer.lua','background.lua')]
    paths += [storage/'game/l2df/external/json.lua',Path(__file__),Path(__file__).with_name('check_actor_input.py'),Path(__file__).with_name('check_world.py')]
    paths += [a.reference_root/'native/Sources/NTSDCore'/n for n in ('OriginalApplicationTimer.swift','OriginalClock.swift','OriginalBackgroundDrawing.swift')]
    paths += [a.reference_root/'native/Tests/NTSDCoreTests/OriginalApplicationTimerTests.swift']
    paths += [a.reference_root/'tools/oracle_presentation.py']
    pins=[]
    for index,path in enumerate(paths):
        raw=path.read_bytes()
        if index<2:dest=out.parent/(a.label+'-'+path.name)
        elif index<4:dest=out/'compat'/path.name
        elif index==4:dest=out/'json.lua'
        else:dest=out/(str(index)+'-'+path.name)
        assert not dest.exists();dest.write_bytes(raw)
        pins.append({'path':str(path),'snapshot':str(dest.resolve()),'sha256':sha(raw),'bytes':len(raw)})
    packed=Path(pins[0]['snapshot']).read_bytes();assert sha(packed)==TIMER_SHA
    transport=json.loads(packed);raw=zlib.decompress(base64.b64decode(transport['deflate']),-15)
    assert len(raw)==transport['count']==1337394 and sha(raw)==transport['sha256']==RAW_SHA
    timer=json.loads(raw);assert timer['exeSHA256']==EXE and len(timer['cases'])==2025
    raw=Path(pins[1]['snapshot']).read_bytes();assert sha(raw)==PRESENTATION_SHA
    presentation=json.loads(raw);assert presentation['exeSHA256']==EXE
    assert len(presentation['clock'])==36 and len(presentation['background'])==120 and len(presentation['layers'])==15
    inputs={'timer':[{k:c[k] for k in ('index','speed','baselineBefore','clockResponses','dispatchResult','target')} for c in timer['cases']],
            'clock':[{k:c[k] for k in ('start','now')} for c in presentation['clock']],
            'layers':presentation['layers'],'camera':[c['camera'] for c in presentation['background']]}
    (out/'inputs.lua').write_text('return '+lua(inputs)+'\n');(out/'main.lua').write_text(RUNNER)
    (out/'conf.lua').write_text("function love.conf(t) t.identity='ntsd-presentation-check';t.window=false;t.modules.audio=false;t.modules.graphics=false;t.modules.joystick=false;t.modules.physics=false end\n")
    exe=storage/'runtime/love.app/Contents/MacOS/love';command=[str(exe.resolve()),str(out.resolve())]
    started=time.monotonic();job={'command':command,'cwd':str(out.resolve()),'startUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pins':pins,'executableSHA256':sha(exe.read_bytes()),'sourceExecution':False,'timeoutSeconds':90}
    with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
        proc=subprocess.Popen(command,cwd=out,stdout=stdout,stderr=stderr)
        job.update(pid=proc.pid,status='running');(out/'job.json').write_text(json.dumps(job,indent=2)+'\n')
        try:code=proc.wait(timeout=90)
        except subprocess.TimeoutExpired:proc.kill();code=proc.wait();job['timeout']=True
    job.update(status='terminal',exitCode=code,elapsedSeconds=time.monotonic()-started);(out/'job.json').write_text(json.dumps(job,indent=2)+'\n')
    assert code==0,job
    expected=[{'kind':'timer','index':c['index'],'baseline':c['baselineAfter'],'events':c['events'],'targets':sum(e['kind']=='dispatch' for e in c['events']),'inputUnchanged':True} for c in timer['cases']]
    expected += [{'kind':'clock','index':i,'baseline':c['baseline'],'ticks':c['ticks']} for i,c in enumerate(presentation['clock'],1)]
    expected += [{'kind':'background','index':i,'draws':c['draws'],'previewUnchanged':True,'inputUnchanged':True} for i,c in enumerate(presentation['background'],1)]
    expected += [{'kind':'rollback','rejected':True,'reasonMatches':True,'baseline':0,'events':[{'kind':k,'arguments':[]} for k in ('target','dispatch','recover','sleep')]}]
    actual=[json.loads(line) for line in (out/'actual.jsonl').read_text().splitlines()]
    assert len(actual)==len(expected)==2182
    failures=[]
    for index,(got,want) in enumerate(zip(actual,expected)):
        diff=list(differences(got,want))
        if diff:failures.append({'row':index,'differences':diff})
    (out/'failures.json').write_text(json.dumps(failures,indent=2)+'\n')
    for pin in pins:
        assert sha(Path(pin['path']).read_bytes())==sha(Path(pin['snapshot']).read_bytes())==pin['sha256'],pin
    report={'accepted':not failures,'timerCases':2025,'timerEvents':sum(len(c['events']) for c in timer['cases']),'legacyClockSamples':36,'districtDrawLists':120,'lateTimerRollback':not list(differences(actual[-1],expected[-1])),'failedRows':len(failures),'job':job,'actualSHA256':sha((out/'actual.jsonl').read_bytes()),'sourceExecution':False,'wholeGameOrDeviceClaim':False,'comparison':'Exact baseline and ordered external requests, separate legacy aggregates and complete District lists; native-only rollback and nonadvancing preview.'}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='job'}));raise SystemExit(0 if report['accepted'] else 1)

if __name__=='__main__':main()
