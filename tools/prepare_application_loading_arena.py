#!/usr/bin/env python3
"""Prepare a test-only front arena correction in a fresh exact clone."""
import ast,ctypes,datetime,difflib,json,os,plistlib,re,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-loading-arena-20260927'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-decimal-materialization-20260927').resolve()
PLAN=ROOT/'docs/research/APPLICATION_LOADING_ARENA_PLAN.md'
HELPER=ROOT/'tools/apply_loading_arena_candidate.py'
NAMES=['run_application_host_gameplay_validation2.py','run_application_host_gameplay_tests2.py','verify_application_host_gameplay_package.py']
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
 assert v['MountPoint']=='/Volumes/X5' and v['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and v['FilesystemType']=='apfs' and v['Writable']
 free=shutil.disk_usage(TASK.parent).free;assert free>129*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not TASK.exists() and not (ROOT/'build/research'/NAME).exists()
 pub=read(BASE/'publication1.json');assert read(BASE/'external-close1.json')['taskFrozen'] and pub['status']=='first-nonpass-retained' and pub['passedMethods']==20
 for k in ['candidateManifest','context','verification','metadataArchive']:checked(Path(pub[k]['path']),pub[k])
 assert pub['candidateManifest']['sha256']=='e23c59520310c10f97d505eb10386d8dd04d92f77022414589be1a8ae8c937ce'
 base=read(BASE/'context1.json')
 for n in ['prepare1.job.json','build1.job.json','finalize1.job.json']+[f'test-{i:02d}.job.json' for i in range(1,21)]:
  j=read(BASE/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 queue=read(BASE/'tests1-queue.job.json');stopped=read(BASE/'test-21.job.json')
 assert queue['status']=='terminal' and queue['exitCode']==1 and absent(queue['pid']) and len(queue['completed'])==21
 assert stopped['status']=='terminal' and stopped['exitCode']==1 and not stopped.get('guardReason') and absent(stopped['pid'])
 assert not stopped['remainingProcessGroup'] and not stopped['remainingObservedProcesses']
 assert read(BASE/'verification1.json')['passedMethods']==20 and len(read(BASE/'failure-diagnosis1.json')['unstartedMethods'])==145
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
   if n==NAMES[0]:new=once(new,'1[0-5][0-9]|16[0-6]','1[0-5][0-9]|16[0-7]')
   if n==NAMES[1]:
    new=new.replace('166-method','167-method').replace('== 166','== 167').replace('all166Passed','all167Passed')
   ast.parse(new)
   if n==NAMES[1]:
    a,b='            done = re.findall(',"            job['completed'].append("
    assert old[old.index(a):old.index(b)]==new[new.index(a):new.index(b)]
   (TASK/'tools'/n).write_text(new);adaptations.append(dict(source=record(BASE/'tools'/source_name),generated=record(TASK/'tools'/n),patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=source_name,tofile=n))))
  save('adaptation1.json',dict(records=adaptations,boundedCompilerObservationRetained=True,actionIdentityChecksUnchanged=True,resultPredicatesUnchanged=True,originalExecuted=False))
  rows=read(BASE/'candidate1-inputs.json');assert len(rows)==2291
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for row in rows:
   assert time.monotonic()-start<1800 and free-shutil.disk_usage(TASK).free<6*2**30
   assert shutil.disk_usage(TASK).free>121*2**30 and shutil.disk_usage(ROOT).free>6*2**30
   src=BASE/'candidate1'/row['path'];dst=TASK/'candidate1'/row['path'];checked(src,row);dst.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dst),0):raise OSError(ctypes.get_errno(),str(dst))
   checked(dst,row);assert src.stat().st_ino!=dst.stat().st_ino
  shutil.copy2(BASE/'candidate1-inputs.json',TASK/'baseline-inputs1.json')
  from apply_loading_arena_candidate import apply
  changes=apply(TASK/'candidate1')
  assert len(changes)==2
  modified={n for n,c in changes.items() if c['before'] is not None};newfiles=set(changes)-modified
  from apply_loading_arena_candidate import EXISTING,ADDED
  assert modified=={'native/'+n for n in EXISTING} and newfiles=={'native/'+n for n in ADDED}
  diff=''.join(''.join(difflib.unified_diff((c['before'] or '').splitlines(True),c['after'].splitlines(True),fromfile='a/'+n if c['before'] is not None else '/dev/null',tofile='b/'+n)) for n,c in changes.items())
  (TASK/'candidate1.patch').write_text(diff)
  save('candidate-changes1.json',dict(changes=[dict(path=n,before=record(BASE/'candidate1'/n) if c['before'] is not None else None,after=record(TASK/'candidate1'/n)) for n,c in changes.items()],newFiles=sorted(newfiles),existingTestMethodsUnchanged=True,testEnvironmentOnly=True,productionUnchanged=True,referenceAndMacUnchanged=True,expectedBytesAndMasksUnchanged=True,independentReview=False))
  current=[dict(path=n,**pin(TASK/'candidate1'/n)) for n in sorted({r['path'] for r in rows}|newfiles)]
  mapped={r['path']:r for r in current}
  assert {r['path'] for r in rows if mapped[r['path']]!=r}==modified and len(current)==2291
  assert {str(f.relative_to(TASK/'candidate1')) for f in (TASK/'candidate1').rglob('*') if f.is_file()}==set(mapped)
  save('candidate1-inputs.json',current)
  for src,name in [(PLAN,'plan1.md'),(Path(__file__),'prepare1.py'),(HELPER,'candidate-transform1.py')]:shutil.copy2(src,TASK/name)
  parse=['xcrun','swiftc','-frontend','-parse']+[str(TASK/'candidate1'/n) for n in changes]
  result=subprocess.run(parse,capture_output=True,text=True);save('syntax1.json',dict(command=parse,exitCode=result.returncode,stdout=result.stdout,stderr=result.stderr,notTypecheck=True));assert result.returncode==0,result.stderr
  from apply_loading_arena_candidate import NEW
  previous=read(BASE/'selected-methods1.json')['methods'];assert len(previous)==166
  methods=NEW+previous;assert len(methods)==len(set(methods))==167
  save('selected-methods1.json',dict(methods=methods,newMethods=NEW,retainedMethods=previous,
      priorSelection=record(BASE/'selected-methods1.json')))
  bounds=read(BASE/'method-limits1.json')['methods']
  for m in NEW:bounds[m]=dict(seconds=1800,residentBytes=12*2**30)
  assert bounds['OriginalMacLoadingAudioTests/testWholeCatalogPoolLoadedMenuHostWithOwnedAudio']['seconds']==3600
  save('method-limits1.json',dict(methods=bounds,priorLimitsPreserved=True,queueSeconds=14400))
  assert set(bounds)==set(methods)
  for m in methods:
   family,method=m.split('/');body=(TASK/'candidate1/native/Tests/NTSDCoreTests'/(family+'.swift')).read_text()
   assert len(re.findall(r'func\s+'+method+r'\s*\(',body))==1
  env={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ};env.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(TASK/'tmp'))
  version=subprocess.check_output(['xcrun','swift','--version'],text=True,env=env);sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
  protected=[PLAN,Path(__file__),HELPER]+sorted((ROOT/'tools/loading_arena_candidate').glob('*.swift'))+[ROOT/'tools/loading_arena_candidate/authoring-observations.json',ROOT/'tools/loading_arena_candidate/address-audit.json']+[BASE/n for n in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','test-21.job.json','test-21.log','failure-diagnosis1.json','finalize1.job.json','publication1.json','external-close1.json','candidate1-inputs.json','selected-methods1.json','method-limits1.json','runner-inputs2.json','test-21-native-sample1.txt','test-21-native-sample1-analysis.json','overlap-witness1.json','overlap-witness2.json','package-check1.json','author-review1.json']]+[source/'capture1/source.job.json']+[TASK/n for n in ['candidate-changes1.json','candidate1.patch','baseline-inputs1.json','adaptation1.json','syntax1.json','method-limits1.json','selected-methods1.json']]+[ROOT/n for n in ['AGENTS.md','AGENTS_HISTORY_2026-09-12.md','docs/research/WORKFLOW.md','docs/research/TASK_TEMPLATE.md','docs/research/APPLICATION_DECIMAL_MATERIALIZATION.md','docs/research/APPLICATION_DECIMAL_MATERIALIZATION_PLAN.md','docs/research/APPLICATION_OBSERVED_BITMAP_CORRECTION1.md','docs/research/APPLICATION_MAC_WINDOW.md','docs/research/APPLICATION_POOL_INTERFACE.md','docs/research/APPLICATION_LOADED_MENU.md','docs/research/APPLICATION_LOADING_AUDIO.md','docs/research/APPLICATION_LOADING_AUDIO_PLAN.md','docs/evidence/application-loading-audio.json','docs/evidence/application-loading-audio-failure.json','docs/evidence/application-loading-audio-docs.json','docs/evidence/codex-safety-incidents-2026-09-12.json','docs/evidence/codex-cua-ghostty-refusal-2026-09-26.json','build/research/application-host-gameplay-completion-20260926/reader-recovery1.json']]+[TASK/'tools'/n for n in NAMES]+[Path(r['path']) for r in read(BASE/'runner-inputs2.json')]
  context=dict(schema='ntsd-loading-arena-validation-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],candidateSource=str(BASE/'candidate1'),rootManifest=base['rootManifest'],priorManifest=base['priorManifest'],priorCandidate=base['priorCandidate'],baselineManifest=record(TASK/'baseline-inputs1.json'),sourceTask=str(source),sourceCodePins=base['sourceCodePins'],startFree=free,physicalAllowanceBytes=8*2**30,stopObservedDecrease=6*2**30,originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30,prospectiveVMCommitment=64*2**30,fullCloneVerified=True,cloneFiles=2291,distinctRegularInodes=True,swiftVersion=version,sdk=sdk,environment=env,gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True))
  save('context1.json',context)
  swift=subprocess.check_output(['xcrun','--find','swift-build'],text=True).strip()
  command=[swift,'--package-path',str(TASK/'candidate1/native'),'--scratch-path',str(TASK/'swift'),'--cache-path',str(TASK/'cache'),'--config-path',str(TASK/'config'),'--security-path',str(TASK/'security'),'--manifest-cache','local','--build-system','native','--build-tests','-c','release','--jobs','2','--disable-index-store','-Xswiftc','-enable-testing']
  config=dict(schema='ntsd-loading-arena-run-config-v1',phase='build1',buildPhase='build1',kind='build',command=command,cwd=str(TASK/'candidate1'),environment=env,contextSHA256=pin(TASK/'context1.json')['sha256'],candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],stopObservedDecrease=6*2**30,externalGuardBytes=121*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=150*2**30,residentGuardBytes=12*2**30,timeoutSeconds=3600,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15)
  save('build1-config.json',config);save('runner-inputs2.json',[record(TASK/'tools'/n) for n in NAMES]+[record(ROOT/'tools/archive_catalog53_storage.py')])
  pattern=r'build1|test-(0[1-9]|[1-9][0-9]|1[0-5][0-9]|16[0-7])'
  assert all(re.fullmatch(pattern,p) for p in ['build1']+[f'test-{i:02d}' for i in range(1,168)])
  assert not any(re.fullmatch(pattern,p) for p in ['test-00','test-168','test-999','test-1','build2'])
  sys.path.insert(0,str(TASK/'tools'))
  from run_application_host_gameplay_validation2 import same_lifetime,deferred_compiler_cwd
  identity='59727 Tue Sep 22 18:00:00 2026 /usr/bin/python3 source.py'
  controls=[(identity,True),(identity.replace('source.py','changed.py'),True),(identity.replace('59727','54930'),False),(identity.replace('18:00:00','19:00:00'),False),('',False),('59727 (unknown)',False)]
  assert all(same_lifetime(identity,b)==expected for b,expected in controls)
  compiler='12345 Sun Sep 27 03:00:00 2026 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend -c owned.swift'
  dsym=compiler.replace('swift-frontend','dsymutil');build=compiler.replace('swift-frontend','swift-build')
  xctest=compiler.replace('swift-frontend','xctest');foreign=compiler.replace('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin','/usr/local/bin')
  observations=[(compiler,compiler,'',True),(dsym,dsym,'',True),(build,build,'',True),(compiler,compiler.replace('12345','12346'),'',False),(compiler,compiler.replace('03:00:00','03:00:01'),'',False),(compiler,compiler+' changed', '',False),(compiler,compiler,'p12345\nfcwd\nn'+str(TASK),False),(compiler,compiler,'p12345\nfcwd\nn/unrelated',False),('12345 unknown','12345 unknown','',False),(xctest,xctest,'',False),(foreign,foreign,'',False),('','','',False)]
  assert len(observations)==12 and all(deferred_compiler_cwd(a,b,c)==expected for a,b,c,expected in observations)
  save('runner-controls1.json',dict(boundedCompilerObservationRetained=True,actionIdentityChecksUnchanged=True,compilerObservationControls=12,observations=observations,lifetimeControls=6,resultPredicatesUnchanged=True,phasePositive=168,phaseNegative=5,exactMethods=167,priorMethodLimitsUnchanged=True,nativeExecuted=False,originalExecuted=False,independentReview=False))
  job.update(status='terminal',exitCode=0,files=2291,preparedMethods=167,buildConfig=record(TASK/'build1-config.json'))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(TASK/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
