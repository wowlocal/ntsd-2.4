"""Pin this finite source-only startup audio audit; no game/build/device runs."""
import datetime,json,os,plistlib,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-startup-audio-preflight-20260927'
P=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
V=P.parent/'application-mac-front-raster-correction2-20260927'
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
read=lambda p:json.loads(p.read_text())
def record(p):return dict(path=str(p.resolve()),**pin(p))
def save(name,value):
 p=P/name;assert not p.exists(),str(p);p.write_text(json.dumps(value,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def main():
 os.chdir(ROOT);began=time.monotonic()
 disk=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert disk['MountPoint']=='/Volumes/X5' and disk['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and disk['FilesystemType']=='apfs' and disk['Writable']
 free=shutil.disk_usage(P.parent).free;assert free>122*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not P.exists() and not (ROOT/'build/research'/NAME).exists()
 pub=read(V/'publication1.json');base=read(V/'context1.json')
 assert pub['status']=='all95-passed' and read(V/'external-close1.json')['taskFrozen']
 assert pub['candidateManifest']['sha256']=='eb462e3c418407b6bb467129b03f50e8c069c4adf6e9d019fd52b2f9f4d0bc9d'
 for k in ['candidateManifest','context','verification','metadataArchive']:checked(Path(pub[k]['path']),pub[k])
 for n in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']:
  j=read(V/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 source=Path(base['sourceTask']);j=read(source/'capture1/source.job.json');assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 core=['OriginalApplicationStartupPlatform','OriginalWinMainStartup','OriginalMenuSoundStartup','OriginalWaveLoader','OriginalMusicPlayback','OriginalInputStartup','OriginalStartupOutput','OriginalApplicationObservedStartup','OriginalStartupRequestExchange','OriginalApplicationWindowStartup','OriginalApplicationBootstrap','OriginalApplicationStartupInputs','OriginalRequestExchange','OriginalMenuPresentation','OriginalInitialSoundLoading','OriginalApplicationHostSession','OriginalWindowRequestExchange']
 tests=['OriginalMenuSoundStartupTests','OriginalWaveLoaderTests','OriginalMusicPlaybackTests','OriginalWinMainStartupTests','OriginalInputStartupTests','OriginalApplicationObservedStartupTests','OriginalApplicationWindowStartupTests','OriginalStartupOutputTests']
 native=[V/'candidate1'/folder/(n+'.swift') for folder,names in [('native/Sources/NTSDCore',core),('native/Sources/NTSDReferenceChecks',['WaveLoaderReference','MusicPlaybackReference']),('native/Tests/NTSDCoreTests',tests)] for n in names]
 docs=[ROOT/'docs/research'/(n+'.md') for n in ['MENU_SOUND_STARTUP','WAVE_LOADING','MUSIC_PLAYBACK','WINMAIN_STARTUP','STARTUP_OUTPUT','INPUT_STARTUP','APPLICATION_PREPARED_BACKEND_PREFLIGHT','APPLICATION_HOST_APP_PREFLIGHT','APPLICATION_OBSERVED_STARTUP','APPLICATION_OBSERVED_STARTUP_CORRECTION1','APPLICATION_OBSERVED_STARTUP_VALIDATION','APPLICATION_MAC_FRONT_RASTER_CORRECTION2']]+[ROOT/'docs/evidence'/n for n in ['menu-sound-startup.json','wave-loader.json','music-playback.json','winmain-startup.json']]
 for f in native+docs:assert f.is_file(),str(f)
 assert len(native)==27 and len(docs)==16
 assert sum(f.stat().st_size for f in native)<8*2**20 and sum(f.stat().st_size for f in docs)<8*2**20
 P.mkdir();(ROOT/'build/research'/NAME).symlink_to(P,target_is_directory=True)
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  preservation=[]
  for root,manifest,count in [(ROOT,Path(base['rootManifest']),1034),(Path(base['priorCandidate']),Path(base['priorManifest']['path']),2257),(V/'candidate1',V/'candidate1-inputs.json',2278)]:
   rows=read(manifest);assert len(rows)==count
   actual={str(f.relative_to(root)) for t in ['native/Sources','native/Tests'] for f in (root/t).rglob('*') if f.is_file()}|{'native/Package.swift'}
   assert actual=={r['path'] for r in rows}
   for r in rows:checked(root/r['path'],r)
   preservation.append(dict(root=str(root),manifest=record(manifest),files=count))
  for r in base['sourceCodePins']:checked(ROOT/r['path'],r)
  plan=ROOT/'docs/research/APPLICATION_STARTUP_AUDIO_PREFLIGHT_PLAN.md';shutil.copy2(plan,P/'plan1.md');shutil.copy2(Path(__file__),P/'prepare1.py')
  protected=[ROOT/n for n in ['AGENTS.md','AGENTS_HISTORY_2026-09-12.md','docs/research/WORKFLOW.md','docs/research/TASK_TEMPLATE.md','docs/CONTINUE_GOAL.md','docs/evidence/codex-safety-incidents-2026-09-12.json','docs/evidence/codex-cua-ghostty-refusal-2026-09-26.json']]+[V/n for n in ['publication1.json','external-close1.json','context1.json','prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']]+[source/'capture1/source.job.json',Path(__file__)]
  save('context1.json',dict(schema='ntsd-startup-audio-preflight-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),priorGoalTurn='progress:6bf406d all95 Native raster/service and package/archive verified',nativeInputs=[record(f) for f in native],documents=[record(f) for f in docs],protected=[record(f) for f in protected],plan=record(plan),candidateManifest=record(V/'candidate1-inputs.json'),preservation=preservation,sourceTask=str(source),sourceCodePins=base['sourceCodePins'],sourceTerminalPID=j['pid'],initialExternalFree=free,taskBytesLimit=64*2**20,stopTaskBytes=56*2**20,externalReserve=121*2**30,internalReserve=6*2**30,elapsedLimitSeconds=3600,sourceExecuted=False,nativeExecuted=False,deviceExecuted=False,independentReview=False))
  save('input-additions1.json',dict(additionalNativeInputs=[],documents=[]))
  assert time.monotonic()-began<1800 and free-shutil.disk_usage(P).free<64*2**20
  job.update(status='terminal',exitCode=0,nativeFiles=27,documents=16,preservedFiles=[1034,2257,2278],sourcePins=55)
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
