"""Pin the Native audio-consumer audit; no game/build/device runs."""
import datetime,json,os,plistlib,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-loading-audio-preflight-20260927'
P=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
V=P.parent/'application-mac-audio-correction2-20260927'
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
 assert pub['status']=='all120-passed' and read(V/'external-close1.json')['taskFrozen']
 assert pub['candidateManifest']['sha256']=='80ced805b198ebdc49068ca1c7e6068ccd7da41828d5c9053be0df04f16ce981'
 for k in ['candidateManifest','context','verification','metadataArchive']:checked(Path(pub[k]['path']),pub[k])
 for n in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']:
  j=read(V/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 source=Path(base['sourceTask']);j=read(source/'capture1/source.job.json');assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 core=['OriginalStartupAudio','OriginalWaveLoader','OriginalInitialSoundLoading','OriginalInitialLoadingCommon','OriginalInitialLoading','OriginalRegisteredSoundLoading','OriginalApplicationLoadingSession','OriginalApplicationLoadingInputs','OriginalApplicationCatalogSession','OriginalApplicationCatalogControls','OriginalApplicationPoolSession','OriginalApplicationLoadedMenuSession','OriginalApplicationHostSession','OriginalApplicationObservedStartup','OriginalStartupRequestExchange','OriginalRequestExchange','OriginalMenuSoundStartup','OriginalApplicationPreparedStartupPlatform','OriginalApplicationGameplaySession','OriginalApplicationObservedGraphicsIteration','OriginalApplicationMatchLaunchSession','OriginalFrameLoader']
 tests=['OriginalStartupAudioTests','OriginalMacAudioBackendTests','OriginalInitialLoadingTests','OriginalApplicationLoadingPrefixTests','OriginalApplicationLoadingSessionTests','OriginalApplicationCatalogSessionTests','OriginalApplicationCatalogFullTests','OriginalApplicationPoolTests','OriginalApplicationLoadedMenuTests','OriginalApplicationHostLoadingTests','OriginalCatalogSoundsTests','OriginalApplicationHostDeliveryContextTests']
 native=[V/'candidate1'/folder/(n+'.swift') for folder,names in [('native/Sources/NTSDCore',core),('native/Sources/NTSDReferenceChecks',['WaveLoaderReference','CatalogSoundsReference']),('native/Sources/NTSDMacPlatform',['OriginalMacResourceIdentityPool','OriginalMacAudioBackend','OriginalMacAudioService']),('native/Tests/NTSDCoreTests',tests)] for n in names]
 docs=[ROOT/'docs/research'/(n+'.md') for n in ['WAVE_LOADING','CATALOG_SOUNDS','INITIAL_LOADING','APPLICATION_LOADING_PREFIX','APPLICATION_LOADING_SESSION','APPLICATION_CATALOG_SESSION','APPLICATION_CATALOG_FULL_NATIVE','APPLICATION_MAC_AUDIO_PREFLIGHT','APPLICATION_MAC_AUDIO_CORRECTION2']]+[ROOT/'docs/evidence'/n for n in ['wave-loader.json','catalog-sounds.json','catalog-sounds-interleaved.json','application-mac-audio-preflight.json','application-mac-audio-preflight-wav-inputs.json','application-mac-audio-correction2.json']]
 sdk=[]
 for f in native+docs:assert f.is_file(),str(f)
 assert len(native)==39 and len(docs)==15
 assert sum(f.stat().st_size for f in native)<12*2**20 and sum(f.stat().st_size for f in docs)<12*2**20
 P.mkdir();(ROOT/'build/research'/NAME).symlink_to(P,target_is_directory=True)
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  preservation=[]
  for root,manifest,count in [(ROOT,Path(base['rootManifest']),1034),(Path(base['priorCandidate']),Path(base['priorManifest']['path']),2257),(V/'candidate1',V/'candidate1-inputs.json',2284)]:
   rows=read(manifest);assert len(rows)==count
   actual={str(f.relative_to(root)) for t in ['native/Sources','native/Tests'] for f in (root/t).rglob('*') if f.is_file()}|{'native/Package.swift'}
   assert actual=={r['path'] for r in rows}
   for r in rows:checked(root/r['path'],r)
   preservation.append(dict(root=str(root),manifest=record(manifest),files=count))
  for r in base['sourceCodePins']:checked(ROOT/r['path'],r)
  plan=ROOT/'docs/research/APPLICATION_LOADING_AUDIO_PREFLIGHT_PLAN.md';shutil.copy2(plan,P/'plan1.md');shutil.copy2(Path(__file__),P/'prepare1.py')
  protected=[ROOT/n for n in ['AGENTS.md','AGENTS_HISTORY_2026-09-12.md','docs/research/WORKFLOW.md','docs/research/TASK_TEMPLATE.md','docs/CONTINUE_GOAL.md','docs/evidence/codex-safety-incidents-2026-09-12.json','docs/evidence/codex-cua-ghostty-refusal-2026-09-26.json']]+[V/n for n in ['publication1.json','external-close1.json','context1.json','prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']]+[source/'capture1/source.job.json',Path(__file__)]
  save('context1.json',dict(schema='ntsd-mac-audio-preflight-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),priorGoalTurn='progress:fe4399f all120 owned PCM startup/offline and package/archive verified',nativeInputs=[record(f) for f in native],documents=[record(f) for f in docs],SDKInputs=[record(f) for f in sdk],protected=[record(f) for f in protected],plan=record(plan),candidateManifest=record(V/'candidate1-inputs.json'),preservation=preservation,sourceTask=str(source),sourceCodePins=base['sourceCodePins'],sourceTerminalPID=j['pid'],initialExternalFree=free,taskBytesLimit=64*2**20,stopTaskBytes=56*2**20,externalReserve=121*2**30,internalReserve=6*2**30,elapsedLimitSeconds=3600,sourceExecuted=False,nativeExecuted=False,deviceExecuted=False,independentReview=False))
  save('input-additions1.json',dict(additionalNativeInputs=[],documents=[]))
  assert time.monotonic()-began<1800 and free-shutil.disk_usage(P).free<64*2**20
  job.update(status='terminal',exitCode=0,nativeFiles=39,documents=15,SDKHeaders=0,preservedFiles=[1034,2257,2284],sourcePins=55)
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
