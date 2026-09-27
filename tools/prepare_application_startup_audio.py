#!/usr/bin/env python3
"""Clone the checked front raster candidate and prepare bounded per-call startup audio comparison."""
import ast,ctypes,datetime,difflib,json,os,plistlib,re,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-startup-audio-20260927'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-mac-front-raster-correction2-20260927').resolve()
PLAN=ROOT/'docs/research/APPLICATION_STARTUP_AUDIO_PLAN.md'
TEMPLATES=[ROOT/'tools'/n for n in ['OriginalStartupAudio.swift','OriginalStartupAudioTests.swift','OriginalStartupAudioMenuCorpus.swift','generate_startup_audio_tests.py','OriginalStartupAudioTestHelpers.part','OriginalStartupAudioTestControls.part']]
HELPER=ROOT/'tools/apply_startup_audio_candidate.py'
NAMES=['run_application_host_gameplay_validation.py','run_application_host_gameplay_tests.py','verify_application_host_gameplay_package.py']
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
read=lambda p:json.loads(p.read_text())
def record(p):return dict(path=str(p.resolve()),**pin(p))
def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a));return s.replace(a,b)
def save(name,data):
 p=TASK/name;assert not p.exists(),str(p);p.write_text(json.dumps(data,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def main():
 os.chdir(ROOT);start=time.monotonic()
 v=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert v['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and v['FilesystemType']=='apfs' and v['Writable']
 free=shutil.disk_usage(TASK.parent).free;assert free>131*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not TASK.exists() and not (ROOT/'build/research'/NAME).exists()
 pub=read(BASE/'publication1.json');assert read(BASE/'external-close1.json')['taskFrozen'] and pub['status']=='all95-passed' and pub['passedMethods']==95
 for k in ['candidateManifest','context','verification','metadataArchive']:checked(Path(pub[k]['path']),pub[k])
 assert pub['candidateManifest']['sha256']=='eb462e3c418407b6bb467129b03f50e8c069c4adf6e9d019fd52b2f9f4d0bc9d'
 base=read(BASE/'context1.json')
 for n in ['prepare1.job.json','build1.job.json','finalize1.job.json']:
  j=read(BASE/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 queue=read(BASE/'tests1-queue.job.json');assert queue['status']=='terminal' and queue['exitCode']==0 and len(queue['completed'])==95 and absent(queue['pid'])
 source=Path(base['sourceTask']);j=read(source/'capture1/source.job.json');assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 TASK.mkdir();(ROOT/'build/research'/NAME).symlink_to(TASK,target_is_directory=True)
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  for row in read(Path(base['rootManifest'])):checked(ROOT/row['path'],row)
  for row in base['sourceCodePins']:checked(ROOT/row['path'],row)
  for n in ['tools','tmp','cache','config','security']:(TASK/n).mkdir()
  adaptations=[]
  for n in NAMES:
   source_name=n
   old=(BASE/'tools'/source_name).read_text()
   new=old.replace(BASE.name,NAME)
   if n==NAMES[0]:new=once(new,"build1|test-(0[1-9]|[1-8][0-9]|9[0-5])","build1|test-(0[1-9]|[1-9][0-9]|10[0-5])")
   if n==NAMES[1]:new=new.replace('95-method','105-method').replace('== 95','== 105').replace('all95Passed','all105Passed')
   if n==NAMES[2]:new=once(once(new,"'NTSDCore':205","'NTSDCore':206"),"'NTSDCoreTests':286","'NTSDCoreTests':288")
   ast.parse(new)
   if n==NAMES[0]:
    a='    def identity(pid):'
    assert old[old.index(a):]==new[new.index(a):]
   if n==NAMES[1]:
    a,b='            done = re.findall(',"            job['completed'].append("
    assert old[old.index(a):old.index(b)]==new[new.index(a):new.index(b)]
   (TASK/'tools'/n).write_text(new);adaptations.append(dict(source=record(BASE/'tools'/source_name),generated=record(TASK/'tools'/n),patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=source_name,tofile=n))))
  save('adaptation1.json',dict(records=adaptations,guardBodyUnchanged=True,resultPredicatesUnchanged=True,originalExecuted=False))
  rows=read(BASE/'candidate1-inputs.json');assert len(rows)==2278
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for row in rows:
   assert time.monotonic()-start<1800 and free-shutil.disk_usage(TASK).free<6*2**30
   assert shutil.disk_usage(TASK).free>121*2**30 and shutil.disk_usage(ROOT).free>6*2**30
   src=BASE/'candidate1'/row['path'];dst=TASK/'candidate1'/row['path'];checked(src,row);dst.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dst),0):raise OSError(ctypes.get_errno(),str(dst))
   checked(dst,row);assert src.stat().st_ino!=dst.stat().st_ino
  shutil.copy2(BASE/'candidate1-inputs.json',TASK/'baseline-inputs1.json')
  from apply_startup_audio_candidate import apply
  changes=apply(TASK/'candidate1',ROOT/'tools')
  assert len(changes)==13 and sum(c['before'] is None for c in changes.values())==3
  modified={n for n,c in changes.items() if c['before'] is not None};newfiles=set(changes)-modified
  assert len(modified)==10
  diff=''.join(''.join(difflib.unified_diff((c['before'] or '').splitlines(True),c['after'].splitlines(True),fromfile='a/'+n if c['before'] is not None else '/dev/null',tofile='b/'+n)) for n,c in changes.items())
  (TASK/'candidate1.patch').write_text(diff)
  save('candidate-changes1.json',dict(changes=[dict(path=n,before=record(BASE/'candidate1'/n) if c['before'] is not None else None,after=record(TASK/'candidate1'/n)) for n,c in changes.items()],newFiles=sorted(newfiles),retainedTestMethodsUnchanged=True,expectedBytesAndMasksUnchanged=True,perCallAudio=True,independentReview=False))
  current=[dict(path=n,**pin(TASK/'candidate1'/n)) for n in sorted({r['path'] for r in rows}|newfiles)]
  mapped={r['path']:r for r in current}
  assert {r['path'] for r in rows if mapped[r['path']]!=r}==modified and len(current)==2281
  assert {str(f.relative_to(TASK/'candidate1')) for f in (TASK/'candidate1').rglob('*') if f.is_file()}==set(mapped)
  save('candidate1-inputs.json',current)
  for src,name in [(PLAN,'plan1.md'),(Path(__file__),'prepare1.py'),(HELPER,'candidate-transform1.py')]+[(f,f.name) for f in TEMPLATES]:shutil.copy2(src,TASK/name)
  parse=['xcrun','swiftc','-frontend','-parse']+[str(TASK/'candidate1'/n) for n in changes]
  result=subprocess.run(parse,capture_output=True,text=True);save('syntax1.json',dict(command=parse,exitCode=result.returncode,stdout=result.stdout,stderr=result.stderr,notTypecheck=True));assert result.returncode==0,result.stderr
  proposed=read(ROOT/'docs/evidence/application-startup-audio-preflight-next-comparison.json')
  retained=proposed['retainedMethods'];old=read(BASE/'selected-methods1.json')['methods']
  assert len(retained)==100 and retained[:95]==old
  newmethods=['OriginalStartupAudioTests/'+n for n in ['testPerCallWaveCorpusAndInitialCallerKeepAllBytesAndMasks','testPerCallMenuSoundCorpusKeepsWholeAndStoppedOutcomes','testWholeWinMainAudioRequestsMatchSourceAndPreparedState','testAudioProtocolAndLockRegionsKeepDistinctOutcomes','testLateStartupAudioFailuresDoNotRepeatServedCopies']]
  methods=newmethods+retained
  assert len(methods)==len(set(methods))==105
  save('selected-methods1.json',dict(methods=methods,newMethods=newmethods,retainedMethods=retained,priorSelection=record(BASE/'selected-methods1.json'),preflightSelection=record(ROOT/'docs/evidence/application-startup-audio-preflight-next-comparison.json')))
  for m in methods:
   family,method=m.split('/');body=(TASK/'candidate1/native/Tests/NTSDCoreTests'/(family+'.swift')).read_text()
   assert len(re.findall(r'func\s+'+method+r'\s*\(',body))==1
  limits=read(BASE/'method-limits1.json')['methods'];oldlimits=dict(limits)
  for m in retained[95:]:limits[m]=dict(seconds=300,residentBytes=8*2**30)
  for i,m in enumerate(newmethods):limits[m]=dict(seconds=300 if i==3 else 1200,residentBytes=(4 if i==3 else 12)*2**30)
  assert all(limits[k]==v for k,v in oldlimits.items()) and set(limits)==set(methods)
  save('method-limits1.json',dict(methods=limits,queueSeconds=14400,inheritedMethods=95,priorLimits=[record(BASE/'method-limits1.json')]))
  env={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ};env.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(TASK/'tmp'))
  version=subprocess.check_output(['xcrun','swift','--version'],text=True,env=env);sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
  protected=[PLAN,Path(__file__),HELPER,*TEMPLATES,BASE/'build1.job.json',BASE/'build1.log',BASE/'test-01.log',BASE/'test-01.job.json',BASE/'tests1-queue.job.json',BASE/'publication1.json',BASE/'external-close1.json',BASE/'candidate1-inputs.json',BASE/'selected-methods1.json',BASE/'method-limits1.json',source/'capture1/source.job.json',TASK/'candidate-changes1.json',TASK/'candidate1.patch',TASK/'baseline-inputs1.json',TASK/'adaptation1.json',TASK/'syntax1.json',TASK/'method-limits1.json',TASK/'selected-methods1.json']+[ROOT/n for n in ['AGENTS.md','AGENTS_HISTORY_2026-09-12.md','docs/research/WORKFLOW.md','docs/research/TASK_TEMPLATE.md','docs/research/APPLICATION_STARTUP_AUDIO_PREFLIGHT_PLAN.md','docs/research/APPLICATION_STARTUP_AUDIO_PREFLIGHT.md','docs/research/WAVE_LOADING.md','docs/research/MENU_SOUND_STARTUP.md','docs/research/INPUT_STARTUP.md','docs/research/WINMAIN_STARTUP.md','docs/research/MUSIC_PLAYBACK.md','docs/evidence/application-startup-audio-preflight-next-comparison.json','docs/evidence/codex-safety-incidents-2026-09-12.json','build/research/application-host-gameplay-completion-20260926/reader-recovery1.json']]+[TASK/'tools'/n for n in NAMES]
  context=dict(schema='ntsd-startup-audio-validation-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],candidateSource=str(BASE/'candidate1'),rootManifest=base['rootManifest'],priorManifest=base['priorManifest'],priorCandidate=base['priorCandidate'],baselineManifest=record(TASK/'baseline-inputs1.json'),sourceTask=str(source),sourceCodePins=base['sourceCodePins'],startFree=free,physicalAllowanceBytes=8*2**30,stopObservedDecrease=6*2**30,originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30,prospectiveVMCommitment=64*2**30,fullCloneVerified=True,cloneFiles=2278,distinctRegularInodes=True,swiftVersion=version,sdk=sdk,environment=env,gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True))
  save('context1.json',context)
  swift=subprocess.check_output(['xcrun','--find','swift-build'],text=True).strip()
  command=[swift,'--package-path',str(TASK/'candidate1/native'),'--scratch-path',str(TASK/'swift'),'--cache-path',str(TASK/'cache'),'--config-path',str(TASK/'config'),'--security-path',str(TASK/'security'),'--manifest-cache','local','--build-system','native','--build-tests','-c','release','--jobs','2','--disable-index-store','-Xswiftc','-enable-testing']
  config=dict(schema='ntsd-startup-audio-run-config-v1',phase='build1',buildPhase='build1',kind='build',command=command,cwd=str(TASK/'candidate1'),environment=env,contextSHA256=pin(TASK/'context1.json')['sha256'],candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],stopObservedDecrease=6*2**30,externalGuardBytes=121*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=150*2**30,residentGuardBytes=12*2**30,timeoutSeconds=3600,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15)
  save('build1-config.json',config);save('runner-inputs1.json',[record(TASK/'tools'/n) for n in NAMES]+[record(ROOT/'tools/archive_catalog53_storage.py')])
  pattern=r'build1|test-(0[1-9]|[1-9][0-9]|10[0-5])'
  assert all(re.fullmatch(pattern,p) for p in ['build1']+[f'test-{i:02d}' for i in range(1,106)])
  assert not any(re.fullmatch(pattern,p) for p in ['test-00','test-106','test-999','test-1','build2'])
  sys.path.insert(0,str(TASK/'tools'))
  from run_application_host_gameplay_validation import same_lifetime
  identity='59727 Tue Sep 22 18:00:00 2026 /usr/bin/python3 source.py'
  controls=[(identity,True),(identity.replace('source.py','changed.py'),True),(identity.replace('59727','54930'),False),(identity.replace('18:00:00','19:00:00'),False),('',False),('59727 (unknown)',False)]
  assert all(same_lifetime(identity,b)==expected for b,expected in controls)
  save('runner-controls1.json',dict(guardBodyUnchanged=True,lifetimeControls=6,resultPredicatesUnchanged=True,phasePositive=106,phaseNegative=5,exactMethods=105,oldMethodLimitsUnchanged=True,nativeExecuted=False,originalExecuted=False,independentReview=False))
  job.update(status='terminal',exitCode=0,files=2281,preparedMethods=105,buildConfig=record(TASK/'build1-config.json'))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(TASK/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
