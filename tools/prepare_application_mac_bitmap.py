#!/usr/bin/env python3
"""Clone the verified display candidate and prepare a finite bitmap-provider validation."""
import ast,ctypes,datetime,difflib,json,os,plistlib,re,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-mac-bitmap-20260926'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-mac-display-correction2-20260926').resolve()
PLAN=ROOT/'docs/research/APPLICATION_MAC_BITMAP_PLAN.md'
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
 free=shutil.disk_usage(TASK.parent).free;assert free>90*2**30 and shutil.disk_usage(ROOT).free>9*2**30
 assert not TASK.exists() and not (ROOT/'build/research'/NAME).exists()
 pub=read(BASE/'publication1.json');assert read(BASE/'external-close1.json')['taskFrozen'] and pub['status']=='all35-passed'
 for k in ['candidateManifest','context','verification','metadataArchive']:checked(Path(pub[k]['path']),pub[k])
 assert pub['candidateManifest']['sha256']=='89f795574ca6ef954a2f44c0a3c1078a8c259c562f51863092bbfa9ea5131417'
 base=read(BASE/'context1.json')
 for n in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']:
  j=read(BASE/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 source=Path(base['sourceTask']);j=read(source/'capture1/source.job.json');assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 TASK.mkdir();(ROOT/'build/research'/NAME).symlink_to(TASK,target_is_directory=True)
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  for row in read(Path(base['rootManifest'])):checked(ROOT/row['path'],row)
  for row in base['sourceCodePins']:checked(ROOT/row['path'],row)
  for n in ['tools','tmp','cache','config','security']:(TASK/n).mkdir()
  adaptations=[]
  for n in NAMES:
   old=(BASE/'tools'/n).read_text();new=old.replace(BASE.name,NAME).replace('35-method','48-method').replace('== 35','== 48').replace('all35Passed','all48Passed').replace('3[0-5]','3[0-9]|4[0-8]').replace("'NTSDCoreTests':280","'NTSDCoreTests':281").replace("'NTSDMacPlatform':6","'NTSDMacPlatform':7")
   ast.parse(new)
   if n==NAMES[0]:assert old[old.index('    def identity(pid):'):]==new[new.index('    def identity(pid):'):]
   if n==NAMES[1]:
    a,b='            done = re.findall(',"            job['completed'].append("
    assert old[old.index(a):old.index(b)]==new[new.index(a):new.index(b)]
   (TASK/'tools'/n).write_text(new);adaptations.append(dict(source=record(BASE/'tools'/n),generated=record(TASK/'tools'/n),patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile=n,tofile=n))))
  save('adaptation1.json',dict(records=adaptations,monitorBodyUnchanged=True,resultPredicatesUnchanged=True,originalExecuted=False))
  rows=read(BASE/'candidate1-inputs.json');assert len(rows)==2263
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for row in rows:
   assert time.monotonic()-start<1800 and free-shutil.disk_usage(TASK).free<26*2**30
   assert shutil.disk_usage(TASK).free>57*2**30 and shutil.disk_usage(ROOT).free>6*2**30
   src=BASE/'candidate1'/row['path'];dst=TASK/'candidate1'/row['path'];checked(src,row);dst.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dst),0):raise OSError(ctypes.get_errno(),str(dst))
   checked(dst,row);assert src.stat().st_ino!=dst.stat().st_ino
  shutil.copy2(BASE/'candidate1-inputs.json',TASK/'baseline-inputs1.json')
  changed='native/Sources/NTSDMacPlatform/OriginalMacDisplayBackend.swift'
  p=TASK/'candidate1'/changed;before=p.read_text();after=before
  replacements=[
   ('case display, primary, backbuffer, clipper','case display, primary, backbuffer, clipper, offscreen, module, bitmap, stockBitmap, memoryDC, surfaceDC'),
   ('var storage: Storage?, clipper: Clipper?','var storage: Storage?, clipper: Clipper?\n        var activeBitmapDC: UInt32?, sourceColorKey: [UInt32]?'),
   ('    private let identity = Identity(), budget: Budget','    private var bitmapModule: Resource?\n    public private(set) var bitmapOperations: [BitmapOperation] = []\n    private let identity = Identity(), budget: Budget'),
   ('if s.kind == .backbuffer {','if s.kind == .backbuffer || s.kind == .offscreen {'),
   ('            let value = try resource(q.words[0],as:Resource.self)\n            if let c', '            let value = try resource(q.words[0],as:Resource.self)\n            try require([Kind.display,.primary,.backbuffer,.offscreen,.clipper].contains(value.kind))\n            guard (value as? Surface)?.activeBitmapDC == nil else { throw Boundary.unsupported("surface DC still acquired") }\n            if let c')]
  for a,b in replacements:after=once(after,a,b)
  extension=ROOT/'tools/OriginalMacBitmapDisplay.swift.inc';after+=extension.read_text();p.write_text(after)
  templates={'native/Sources/NTSDMacPlatform/OriginalMacBitmapService.swift':ROOT/'tools/OriginalMacBitmapService.swift','native/Tests/NTSDCoreTests/OriginalMacBitmapBackendTests.swift':ROOT/'tools/OriginalMacBitmapBackendTests.swift'}
  for name,src in templates.items():shutil.copy2(src,TASK/'candidate1'/name)
  patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+changed,tofile='b/'+changed))
  for name in templates:patch+=''.join(difflib.unified_diff([],(TASK/'candidate1'/name).read_text().splitlines(True),fromfile='/dev/null',tofile='b/'+name))
  (TASK/'correction1.patch').write_text(patch)
  save('correction1.json',dict(path=changed,before=record(BASE/'candidate1'/changed),after=record(p),replacements=replacements,extension=record(extension),newFiles=list(templates),templates={n:record(p) for n,p in templates.items()},allOldTestsUnchanged=True))
  names=sorted([r['path'] for r in rows]+list(templates));assert len(names)==2265
  current=[dict(path=n,**pin(TASK/'candidate1'/n)) for n in names];mapped={r['path']:r for r in current}
  assert [r['path'] for r in rows if mapped[r['path']]!=r]==[changed]
  assert {str(f.relative_to(TASK/'candidate1')) for f in (TASK/'candidate1').rglob('*') if f.is_file()}==set(names)
  save('candidate1-inputs.json',current)
  for src,name in [(PLAN,'plan1.md'),(Path(__file__),'prepare1.py')]:shutil.copy2(src,TASK/name)
  parse=['xcrun','swiftc','-frontend','-parse']+[str(TASK/'candidate1'/n) for n in [changed]+list(templates)]
  result=subprocess.run(parse,capture_output=True,text=True);save('syntax1.json',dict(command=parse,exitCode=result.returncode,stdout=result.stdout,stderr=result.stderr,notTypecheck=True));assert result.returncode==0,result.stderr
  prior=read(BASE/'selected-methods1.json')['methods'];added=[]
  for family,count in [('OriginalMacBitmapBackendTests',4),('OriginalBitmapSurfaceLoadingTests',3),('OriginalDIBPixelsTests',3),('OriginalSurfaceSourceColorsTests',3)]:
   text=(TASK/'candidate1/native/Tests/NTSDCoreTests'/(family+'.swift')).read_text();found=re.findall(r'func (test\w+)\s*\(',text);assert len(found)==count
   added += [family+'/'+method for method in found]
  methods=added[:4]+prior+added[4:];assert len(methods)==len(set(methods))==48
  save('selected-methods1.json',dict(methods=methods,newMethods=added[:4],retainedMethods=prior+added[4:],priorSelection=record(BASE/'selected-methods1.json')))
  limits=read(BASE/'method-limits1.json')['methods']
  for m in added:assert m not in limits;limits[m]=dict(seconds=600,residentBytes=8*2**30,priorOrdinal=None)
  save('method-limits1.json',dict(methods=limits,queueSeconds=14400,inheritedMethods=35,priorLimits=record(BASE/'method-limits1.json')))
  env={k:os.environ[k] for k in ['HOME','USER','LOGNAME','LANG','LC_ALL'] if k in os.environ};env.update(PATH='/usr/bin:/bin:/usr/sbin:/sbin',TMPDIR=str(TASK/'tmp'))
  version=subprocess.check_output(['xcrun','swift','--version'],text=True,env=env);sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
  protected=[PLAN,Path(__file__),extension,*templates.values(),BASE/'publication1.json',BASE/'external-close1.json',BASE/'candidate1-inputs.json',BASE/'selected-methods1.json',BASE/'method-limits1.json',source/'capture1/source.job.json',TASK/'correction1.json',TASK/'correction1.patch',TASK/'baseline-inputs1.json',TASK/'adaptation1.json',TASK/'syntax1.json',TASK/'method-limits1.json']+[ROOT/n for n in ['AGENTS.md','AGENTS_HISTORY_2026-09-12.md','docs/research/WORKFLOW.md','docs/research/TASK_TEMPLATE.md','docs/research/BITMAP_SURFACE_LOADING.md','docs/research/APPLICATION_SURFACE_COLORS.md','docs/research/APPLICATION_GRAPHICS_OWNERS.md','docs/evidence/codex-safety-incidents-2026-09-12.json','build/research/application-host-gameplay-completion-20260926/reader-recovery1.json']]+[TASK/'tools'/n for n in NAMES]
  context=dict(schema='ntsd-mac-bitmap-validation-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in protected],candidateSource=str(BASE/'candidate1'),rootManifest=base['rootManifest'],priorManifest=base['priorManifest'],priorCandidate=base['priorCandidate'],baselineManifest=record(TASK/'baseline-inputs1.json'),sourceTask=str(source),sourceCodePins=base['sourceCodePins'],startFree=free,physicalAllowanceBytes=28*2**30,stopObservedDecrease=26*2**30,originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30,fullCloneVerified=True,cloneFiles=2263,distinctRegularInodes=True,swiftVersion=version,sdk=sdk,environment=env,gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True))
  save('context1.json',context)
  swift=subprocess.check_output(['xcrun','--find','swift-build'],text=True).strip()
  command=[swift,'--package-path',str(TASK/'candidate1/native'),'--scratch-path',str(TASK/'swift'),'--cache-path',str(TASK/'cache'),'--config-path',str(TASK/'config'),'--security-path',str(TASK/'security'),'--manifest-cache','local','--build-system','native','--build-tests','-c','release','--jobs','2','--disable-index-store','-Xswiftc','-enable-testing']
  config=dict(schema='ntsd-mac-bitmap-run-config-v1',phase='build1',buildPhase='build1',kind='build',command=command,cwd=str(TASK/'candidate1'),environment=env,contextSHA256=pin(TASK/'context1.json')['sha256'],candidateManifestSHA256=pin(TASK/'candidate1-inputs.json')['sha256'],stopObservedDecrease=26*2**30,externalGuardBytes=40*2**30,internalGuardBytes=6*2**30,logicalLimitBytes=150*2**30,residentGuardBytes=12*2**30,timeoutSeconds=3600,pollSeconds=1,rssPollSeconds=2,logicalPollSeconds=15)
  save('build1-config.json',config);save('runner-inputs1.json',[record(TASK/'tools'/n) for n in NAMES]+[record(ROOT/'tools/archive_catalog53_storage.py')])
  pattern=r'build1|test-(0[1-9]|[12][0-9]|3[0-9]|4[0-8])'
  assert all(re.fullmatch(pattern,p) for p in ['build1']+[f'test-{i:02d}' for i in range(1,49)])
  assert not any(re.fullmatch(pattern,p) for p in ['test-00','test-49','test-99','test-1','build2'])
  save('runner-controls1.json',dict(monitorBodyUnchanged=True,resultPredicatesUnchanged=True,phasePositive=49,phaseNegative=5,exactMethods=48,oldMethodLimitsUnchanged=True,nativeExecuted=False,originalExecuted=False,independentReview=False))
  job.update(status='terminal',exitCode=0,files=2265,preparedMethods=48,buildConfig=record(TASK/'build1-config.json'))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(TASK/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
