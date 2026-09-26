#!/usr/bin/env python3
"""Prepare a frozen catalog-package validation using the existing host tools."""
import ast,ctypes,datetime,difflib,importlib.util,json,os,plistlib,re,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-catalog-package-validation-20260926'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-catalog-package-20260926').resolve()
OLD=ROOT/'build/research/application-host-gameplay-correction1-20260926-tools'
OLD_NAME='application-host-gameplay-correction1-20260926'
PLAN=ROOT/'docs/research/APPLICATION_CATALOG_PACKAGE_VALIDATION_PLAN.md'
NAMES=['run_application_host_gameplay_validation.py','run_application_host_gameplay_tests.py','verify_application_host_gameplay_package.py']
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
read=lambda p:json.loads(p.read_text())
def record(p):return dict(path=str(p.resolve()),**pin(p))
def once(s,a,b):
 assert s.count(a)==1,(a,s.count(a));return s.replace(a,b)
def save(name,value):
 p=TASK/name;assert not p.exists();p.write_text(json.dumps(value,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()

def generate(name):
 old=(OLD/name).read_text();text=old.replace(OLD_NAME,NAME)
 for n in NAMES:text=text.replace(str(ROOT/'build/research'/(NAME+'-tools')/n),str(TASK/'tools'/n))
 if name==NAMES[0]:
  text=once(text,"r'build[123]|test-(0[1-9]|[1-6][0-9])'","r'build1|test-(0[1-9]|[1-6][0-9]|7[0-6])'")
  begin,end='    def identity(pid):',"if __name__=='__main__':"
  assert old[old.index(begin):old.index(end)]==text[text.index(begin):text.index(end)]
 elif name==NAMES[1]:
  text=text.replace('69-method','76-method').replace('== 69','== 76').replace('all69Passed','all76Passed')
  text=once(text,'    cases = []',"    bounds = json.loads((task/'method-limits1.json').read_text())['methods']\n    assert set(bounds) == set(methods)\n    cases = []")
  text=once(text,'timeoutSeconds=1800 if index >= 64 else 900 if index >= 51 else 600,\n            residentGuardBytes=(16 if index >= 51 else 12 if index in (26,28) or 35 <= index <= 37 or 43 <= index <= 50 else 8)*2**30, selectionDeadlineUnix=deadline)',"timeoutSeconds=bounds[method]['seconds'], residentGuardBytes=bounds[method]['residentBytes'], selectionDeadlineUnix=deadline)")
  receipt=read(ROOT/'build/research/application-host-gameplay-completion-20260926/reader-recovery1.json')
  text=once(text,receipt['oldPattern'],receipt['newPattern'])
  text=once(text,"not child.get('guardReason'))","not child.get('guardReason') and not child.get('signals'))")
  text=text.replace('same exact named XCTest regex and one-test zero-failure summary as Catalog53 completion','Verified one-anchor recovery pattern; exact method and all success/guard/process predicates retained')
 else:
  text=text.replace("'NTSDCore':191,'NTSDReferenceChecks':61,'NTSDCoreTests':270","'NTSDCore':192,'NTSDReferenceChecks':61,'NTSDCoreTests':271")
  text=text.replace("'native/Sources/NTSDCore/Resources/', 102","'native/Sources/NTSDCore/Resources/', 1301").replace('runtimeFiles=102','runtimeFiles=1301')
 ast.parse(text);return old,text

def main():
 os.chdir(ROOT)
 volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs' and volume['WritableVolume']
 free=shutil.disk_usage(TASK.parent).free;assert free>90*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not TASK.exists();TASK.mkdir();(ROOT/'build/research'/NAME).symlink_to(TASK,target_is_directory=True)
 began=time.monotonic();job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  pub=read(BASE/'publication1.json');assert read(BASE/'external-close1.json')['taskFrozen']
  for key in ['candidateManifest','context','inputInventory','packageVerification','candidateArchive','metadataArchive','selection','patch']:checked(Path(pub[key]['path']),pub[key])
  oldctx=read(BASE/'context1.json');candidate=read(BASE/'candidate1-inputs.json');assert len(candidate)==2241
  for item in candidate:checked(BASE/'candidate1'/item['path'],item)
  for m in oldctx['manifests']:
   for item in read(Path(m['manifest']['path'])):checked(Path(m['base'])/item['path'],item)
  for item in oldctx['sourceCodePins']:checked(ROOT/item['path'],item)
  for pid in [98474,90854,26386,59727]:assert absent(pid)
  for name in ['tools','tmp','cache','config','security']:(TASK/name).mkdir()
  records=[]
  for name in NAMES:
   old,new=generate(name);dest=TASK/'tools'/name;dest.write_text(new)
   records.append(dict(source=record(OLD/name),generated=record(dest),patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=name,tofile=name))))
  save('adaptation1.json',dict(UTC=now(),records=records,monitorBodyUnchanged=True,resultPatternSource=str(ROOT/'build/research/application-host-gameplay-completion-20260926/reader-recovery1.json'),noOriginalExecution=True))
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for item in candidate:
   assert free-shutil.disk_usage(TASK).free<26*2**30
   src,dest=BASE/'candidate1'/item['path'],TASK/'candidate1'/item['path'];dest.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dest),0):raise OSError(ctypes.get_errno(),str(dest))
   checked(dest,item);assert dest.stat().st_ino!=src.stat().st_ino
  assert {str(f.relative_to(TASK/'candidate1')) for f in (TASK/'candidate1').rglob('*') if f.is_file()}=={i['path'] for i in candidate}
  shutil.copy2(BASE/'candidate1-inputs.json',TASK/'candidate1-inputs.json');shutil.copy2(BASE/'selected-methods2.json',TASK/'selected-methods1.json');shutil.copy2(PLAN,TASK/'plan1.md');shutil.copy2(Path(__file__),TASK/'prepare1.py')
  selection=read(TASK/'selected-methods1.json');assert len(selection['methods'])==76
  limits={}
  for i,m in enumerate(selection['methods'],1):
   cls,method=m.split('/');text=(TASK/'candidate1/native/Tests/NTSDCoreTests'/(cls+'.swift')).read_text();assert len(re.findall(r'func\s+'+method+r'\s*\(',text))==1
   if i<=4:seconds,rss=600,12
   elif i<=7:seconds,rss=900,16
   else:
    old=i-7;seconds=1800 if old>=64 else 900 if old>=51 else 600
    rss=16 if old>=51 else 12 if old in (26,28) or 35<=old<=37 or 43<=old<=50 else 8
   limits[m]=dict(seconds=seconds,residentBytes=rss*2**30,priorOrdinal=i-7 if i>7 else None)
  save('method-limits1.json',dict(methods=limits,queueSeconds=14400,unchangedInheritedMethods=69))
  source=Path(oldctx['sourceTask']);sj=read(source/'capture1/source.job.json');assert sj['status']=='terminal' and absent(sj['pid'])
  environment={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ};environment.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(TASK/'tmp'))
  version=subprocess.check_output(['xcrun','swift','--version'],text=True,env=environment);sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
  protected=[PLAN,Path(__file__),BASE/'publication1.json',BASE/'external-close1.json',BASE/'candidate1-inputs.json',BASE/'selected-methods2.json',ROOT/'AGENTS.md',ROOT/'AGENTS_HISTORY_2026-09-12.md',ROOT/'docs/research/WORKFLOW.md',ROOT/'docs/research/TASK_TEMPLATE.md',ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json',ROOT/'build/research/application-host-gameplay-completion-20260926/reader-recovery1.json',TASK/'adaptation1.json',TASK/'method-limits1.json',source/'capture1/source.job.json']+[TASK/'tools'/n for n in NAMES]
  context=dict(schema='ntsd-catalog-package-validation-context-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],candidateSource=str(BASE/'candidate1'),rootManifest=oldctx['manifests'][0]['manifest']['path'],priorManifest=oldctx['manifests'][1],sourceTask=str(source),sourceCodePins=oldctx['sourceCodePins'],startFree=free,physicalAllowanceBytes=28*2**30,stopObservedDecrease=26*2**30,originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30,fullCloneVerified=True,cloneFiles=2241,distinctRegularInodes=True,swiftVersion=version,sdk=sdk,environment=environment,gitStatus=subprocess.check_output(['git','status','--porcelain=v1'],text=True))
  save('context1.json',context)
  swift=subprocess.check_output(['xcrun','--find','swift-build'],text=True).strip()
  command=[swift,'--package-path',str(TASK/'candidate1/native'),'--scratch-path',str(TASK/'swift'),'--cache-path',str(TASK/'cache'),'--config-path',str(TASK/'config'),'--security-path',str(TASK/'security'),'--manifest-cache','local','--build-system','native','--build-tests','-c','release','--jobs','2','--disable-index-store','-Xswiftc','-enable-testing']
  config=dict(schema='ntsd-catalog-package-validation-run-config-v1',phase='build1',buildPhase='build1',kind='build',command=command,cwd=str(TASK/'candidate1'),environment=environment,contextSHA256=pin(TASK/'context1.json')['sha256'],candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],stopObservedDecrease=26*2**30,externalGuardBytes=40*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=150*2**30,residentGuardBytes=12*2**30,timeoutSeconds=3600,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15)
  save('build1-config.json',config);save('runner-inputs1.json',[record(TASK/'tools'/n) for n in NAMES]+[record(ROOT/'tools/archive_catalog53_storage.py')])
  spec=importlib.util.spec_from_file_location('catalog_package_monitor_controls',TASK/'tools'/NAMES[0]);runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
  assert runner.owned_cwd(f'p123\nfcwd\nn{TASK}/candidate1',123,TASK)
  for v,pid in [(f'p124\nfcwd\nn{TASK}',123),('',123),('p123\nfcwd\nn/tmp',123),(f'p123\nfcwd\nn{TASK}-foreign',123)]:assert not runner.owned_cwd(v,pid,TASK)
  prefix='123 Fri Sep 26 00:00:00 2026 ';compiler='/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/';cwd=f'p123\nfcwd\nn{TASK}/candidate1'
  assert runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,cwd,TASK)
  assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+'/bin/sh',cwd,cwd,TASK)
  assert not runner.compiler_transition(prefix+compiler+'swift-build',prefix+compiler+'swift-frontend',cwd,'',TASK)
  assert runner.transient_xctest_exit(prefix+'/Applications/Xcode.app/Contents/Developer/usr/bin/xctest a',prefix+'(xctest)','')
  assert not runner.transient_xctest_exit(prefix+'/bin/sh',prefix+'(xctest)','')
  pattern=r'build1|test-(0[1-9]|[1-6][0-9]|7[0-6])'
  assert all(re.fullmatch(pattern,p) for p in ['build1']+[f'test-{i:02d}' for i in range(1,77)])
  assert not any(re.fullmatch(pattern,p) for p in ['build0','build2','test-00','test-77','test-99','test-1','test-01x'])
  save('runner-controls1.json',dict(monitorBodyUnchanged=True,cwdPositive=1,cwdNegative=4,compilerPositive=1,compilerNegative=2,transientPositive=1,transientNegative=1,phasePositive=77,phaseNegative=7,exactMethods=76,nativeExecuted=False,originalExecuted=False,independentReview=False))
  job.update(status='terminal',exitCode=0,files=2241,fullCloneVerified=True,preparedMethods=76,buildConfig=record(TASK/'build1-config.json'))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(TASK/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job))
if __name__=='__main__':main()
