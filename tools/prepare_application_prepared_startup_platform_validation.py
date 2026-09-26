#!/usr/bin/env python3
"""Prepare exact prepared startup platform validation with the existing guarded host tools."""
import ast,ctypes,datetime,difflib,importlib.util,json,os,plistlib,re,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-prepared-startup-platform-validation-20260926'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-prepared-startup-platform-20260926').resolve()
OLD=(ROOT/'build/research/application-host-window-inspection-validation-20260926').resolve()
PLAN=ROOT/'docs/research/APPLICATION_PREPARED_STARTUP_PLATFORM_VALIDATION_PLAN.md'
NAMES=['run_application_host_gameplay_validation.py','run_application_host_gameplay_tests.py','verify_application_host_gameplay_package.py']
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
read=lambda p:json.loads(p.read_text())
def record(p):return dict(path=str(p.resolve()),**pin(p))
def once(text,before,after):
 assert text.count(before)==1,(before,text.count(before));return text.replace(before,after)
def save(name,data):
 p=TASK/name;assert not p.exists(),str(p);p.write_text(json.dumps(data,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def generate(name):
 old=(OLD/'tools'/name).read_text();new=old.replace(OLD.name,NAME)
 if name==NAMES[0]:
  new=once(new,"r'build1|test-0[1-8]'","r'build1|test-(0[1-9]|1[01])'")
  marker='    def identity(pid):';assert old[old.index(marker):]==new[new.index(marker):]
 elif name==NAMES[1]:
  new=once(new,'8-method','11-method');new=once(new,'== 8','== 11');new=once(new,'all8Passed','all11Passed')
  begin,end='            done = re.findall(',"            job['completed'].append("
  assert old[old.index(begin):old.index(end)]==new[new.index(begin):new.index(end)]
 else:
  new=once(new,"'NTSDCoreTests':275","'NTSDCoreTests':276");new=once(new,"'NTSDCore':194","'NTSDCore':195")
 ast.parse(new);return old,new
def main():
 os.chdir(ROOT);start=time.monotonic()
 volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs' and volume['Writable']
 free=shutil.disk_usage(TASK.parent).free;assert free>90*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not TASK.exists() and not (ROOT/'build/research'/NAME).exists()
 pub=read(BASE/'publication1.json');assert read(BASE/'external-close1.json')['taskFrozen'] and pub['gates']['archive']
 for key in ['candidateManifest','context','verification','selection','patch','syntax','metadataArchive']:checked(Path(pub[key]['path']),pub[key])
 checked(Path(pub['artifactArchive']['manifest']['path']),pub['artifactArchive']['manifest'])
 basecontext=read(BASE/'context1.json');oldcontext=read(OLD/'context1.json')
 for parent,names in [(BASE,['prepare1.job.json','parse1.job.json','finalize1.job.json']),(OLD,['tests1-queue.job.json','finalize2.job.json'])]:
  for n in names:
   j=read(parent/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 source=Path(basecontext['sourceTask']);sj=read(source/'capture1/source.job.json');assert sj['status']=='terminal' and sj['exitCode']==0 and absent(sj['pid'])
 TASK.mkdir();(ROOT/'build/research'/NAME).symlink_to(TASK,target_is_directory=True)
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  for row in read(Path(basecontext['rootManifest'])):checked(ROOT/row['path'],row)
  for row in read(OLD/'candidate1-inputs.json'):checked(OLD/'candidate1'/row['path'],row)
  for row in basecontext['sourceCodePins']:checked(ROOT/row['path'],row)
  for n in ['tools','tmp','cache','config','security']:(TASK/n).mkdir()
  records=[]
  for n in NAMES:
   before,after=generate(n);p=TASK/'tools'/n;p.write_text(after)
   records.append(dict(source=record(OLD/'tools'/n),generated=record(p),patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=n,tofile=n))))
  save('adaptation1.json',dict(UTC=now(),records=records,monitorBodyUnchanged=True,resultPredicatesUnchanged=True,originalExecuted=False))
  rows=read(BASE/'candidate1-inputs.json');assert len(rows)==2249
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for row in rows:
   assert time.monotonic()-start<1800 and free-shutil.disk_usage(TASK).free<26*2**30
   assert shutil.disk_usage(TASK).free>57*2**30 and shutil.disk_usage(ROOT).free>6*2**30
   src=BASE/'candidate1'/row['path'];dst=TASK/'candidate1'/row['path'];checked(src,row);dst.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dst),0):raise OSError(ctypes.get_errno(),str(dst))
   checked(dst,row);assert dst.stat().st_ino!=src.stat().st_ino
  assert {str(f.relative_to(TASK/'candidate1')) for f in (TASK/'candidate1').rglob('*') if f.is_file()}=={r['path'] for r in rows}
  for src,name in [(BASE/'candidate1-inputs.json','candidate1-inputs.json'),(BASE/'selected-methods1.json','selected-methods1.json'),(PLAN,'plan1.md'),(Path(__file__),'prepare1.py')]:shutil.copy2(src,TASK/name)
  selection=read(TASK/'selected-methods1.json');methods=selection['methods'];new=selection['newMethods'];old=selection['retainedMethods']
  assert len(methods)==len(set(methods))==11 and len(new)==3 and len(old)==8 and methods==new+old
  priorContext=OLD.parent/'application-host-delivery-context-validation-20260926'
  previous=read(OLD/'method-limits1.json')['methods'];extra=read(priorContext/'method-limits1.json')['methods']
  inherited={m:previous[m] if m in previous else extra[m] for m in old}
  assert len(inherited)==8
  limits={}
  for m in methods:
   family,method=m.split('/');text=(TASK/'candidate1/native/Tests/NTSDCoreTests'/(family+'.swift')).read_text()
   assert len(re.findall(r'func\s+'+method+r'\s*\(',text))==1
   limits[m]=inherited[m] if m in inherited else dict(seconds=600,residentBytes=8*2**30,priorOrdinal=None)
  assert all(limits[m]==inherited[m] for m in inherited)
  save('method-limits1.json',dict(methods=limits,queueSeconds=14400,inheritedMethods=8,priorLimits=record(OLD/'method-limits1.json'),priorContextLimits=record(priorContext/'method-limits1.json'),priorSelection=record(OLD/'selected-methods1.json'),precedingComparisonsAreSeparate=True))
  env={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ};env.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(TASK/'tmp'))
  version=subprocess.check_output(['xcrun','swift','--version'],text=True,env=env);sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
  protected=[PLAN,Path(__file__),BASE/'publication1.json',BASE/'external-close1.json',BASE/'candidate1-inputs.json',BASE/'selected-methods1.json',OLD/'publication1.json',OLD/'external-close1.json',OLD/'method-limits1.json',ROOT/'AGENTS.md',ROOT/'AGENTS_HISTORY_2026-09-12.md',ROOT/'docs/research/WORKFLOW.md',ROOT/'docs/research/TASK_TEMPLATE.md',ROOT/'docs/research/APPLICATION_PREPARED_STARTUP_PLATFORM.md',ROOT/'docs/research/APPLICATION_PREPARED_STARTUP_PLATFORM_PLAN.md',ROOT/'docs/research/WINDOW_INITIALIZATION.md',ROOT/'docs/research/WINMAIN_STARTUP.md',ROOT/'tools/prepare_application_host_window_inspection_validation.py',ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json',ROOT/'build/research/application-host-gameplay-completion-20260926/reader-recovery1.json',TASK/'adaptation1.json',TASK/'method-limits1.json',source/'capture1/source.job.json']+[TASK/'tools'/n for n in NAMES]
  context=dict(schema='ntsd-prepared-startup-platform-validation-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],candidateSource=str(BASE/'candidate1'),rootManifest=basecontext['rootManifest'],priorManifest=basecontext['baselineManifest'],priorCandidate=str(OLD/'candidate1'),sourceTask=str(source),sourceCodePins=basecontext['sourceCodePins'],startFree=free,physicalAllowanceBytes=28*2**30,stopObservedDecrease=26*2**30,originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30,fullCloneVerified=True,cloneFiles=2249,distinctRegularInodes=True,swiftVersion=version,sdk=sdk,environment=env,gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True))
  save('context1.json',context)
  swift=subprocess.check_output(['xcrun','--find','swift-build'],text=True).strip()
  command=[swift,'--package-path',str(TASK/'candidate1/native'),'--scratch-path',str(TASK/'swift'),'--cache-path',str(TASK/'cache'),'--config-path',str(TASK/'config'),'--security-path',str(TASK/'security'),'--manifest-cache','local','--build-system','native','--build-tests','-c','release','--jobs','2','--disable-index-store','-Xswiftc','-enable-testing']
  config=dict(schema='ntsd-prepared-startup-platform-run-config-v1',phase='build1',buildPhase='build1',kind='build',command=command,cwd=str(TASK/'candidate1'),environment=env,contextSHA256=pin(TASK/'context1.json')['sha256'],candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],stopObservedDecrease=26*2**30,externalGuardBytes=40*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=150*2**30,residentGuardBytes=12*2**30,timeoutSeconds=3600,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15)
  save('build1-config.json',config);save('runner-inputs1.json',[record(TASK/'tools'/n) for n in NAMES]+[record(ROOT/'tools/archive_catalog53_storage.py')])
  spec=importlib.util.spec_from_file_location('delivery_monitor_controls',TASK/'tools'/NAMES[0]);runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
  assert runner.owned_cwd(f'p123\nfcwd\nn{TASK}/candidate1',123,TASK)
  for v,pid in [(f'p124\nfcwd\nn{TASK}',123),('',123),('p123\nfcwd\nn/tmp',123),(f'p123\nfcwd\nn{TASK}-foreign',123)]:assert not runner.owned_cwd(v,pid,TASK)
  prefix='123 Fri Sep 26 00:00:00 2026 ';compiler='/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/';cwd=f'p123\nfcwd\nn{TASK}/candidate1'
  assert runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,cwd,TASK)
  assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+'/bin/sh',cwd,cwd,TASK)
  assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,'',TASK)
  assert runner.transient_xctest_exit(prefix+'/Applications/Xcode.app/Contents/Developer/usr/bin/xctest a',prefix+'(xctest)','')
  assert not runner.transient_xctest_exit(prefix+'/bin/sh',prefix+'(xctest)','')
  pattern=r'build1|test-(0[1-9]|1[01])'
  assert all(re.fullmatch(pattern,p) for p in ['build1']+[f'test-{i:02d}' for i in range(1,12)])
  invalid=['build0','build2','test-00','test-12','test-99','test-1','test-01x'];assert not any(re.fullmatch(pattern,p) for p in invalid)
  save('runner-controls1.json',dict(UTC=now(),monitorBodyUnchanged=True,resultPredicatesUnchanged=True,cwdPositive=1,cwdNegative=4,compilerPositive=1,compilerNegative=2,transientPositive=1,transientNegative=1,phasePositive=12,phaseNegative=7,exactMethods=11,oldMethodLimitsUnchanged=True,nativeExecuted=False,originalExecuted=False,independentReview=False))
  job.update(status='terminal',exitCode=0,files=2249,preparedMethods=8,buildConfig=record(TASK/'build1-config.json'))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(TASK/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
