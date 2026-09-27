"""Close the test-only front storage correction validation; reuse host finalizer checks and APFS archive procedure.
Only terminal saved Native results and files are read; no build, test, or original executes.
"""
import ctypes,datetime,hashlib,json,os,plistlib,re,shutil,stat,subprocess,sys,tarfile,time,traceback
from decimal import Decimal
from pathlib import Path
R=Path('/Users/michael/Developer/ntsd-2.4');P=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'tools'))
from archive_catalog53_storage import pin,checked
read=lambda p:json.loads(p.read_text())
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def record(p):return dict(path=str(p.resolve()),**pin(p))
def save(name,value):
 p=P/name;assert not p.exists(),str(p);p.write_text(json.dumps(value,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],text=True,capture_output=True).stdout.strip()
def terminal(j,success=True):
 assert j['status']=='terminal' and absent(j['pid'])
 if success:assert j['exitCode']==0 and not j.get('guardReason') and not j.get('signals')
 assert not j.get('remainingProcessGroup') and not j.get('remainingObservedProcesses')
 assert all(absent(int(pid)) for pid in j.get('observedProcesses',{}))
def result(log,j,method):
 # Exactly the separately verified one-anchor reader used by this fixed queue.
 done=re.findall(r"Test Case '-\[NTSDCoreTests\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([^)]*)\)\.$",log,re.M)
 passed=(j['exitCode']==0 and len(done)==1 and '/'.join(done[0][:2])==method and
  done[0][2]=='passed' and log.count('Executed 1 test, with 0 failures (0 unexpected)')==3 and
  "Test Suite 'Selected tests' passed" in log and not j.get('guardReason') and not j.get('signals') and
  not j.get('remainingProcessGroup') and not j.get('remainingObservedProcesses'))
 return passed,done

def main():
 assert P.name=='application-loading-arena-20260927'
 assert not (P/'external-close1.json').exists()
 ctx=read(P/'context1.json');began=time.monotonic()
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],
  identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
  cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
 save('finalize1.job.json',job)
 def guard():
  assert time.monotonic()-began<3600
  free=shutil.disk_usage(P).free
  assert free>ctx['originalExternalReserve']+ctx['sourceCommitment']+ctx['prospectiveVMCommitment'] and shutil.disk_usage(R).free>ctx['originalInternalReserve']
  assert ctx['startFree']-free<ctx['stopObservedDecrease']
  assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file() and not f.is_symlink())<150*2**30
 def native(base,manifest,count):
  rows=read(manifest)
  actual={str(f.relative_to(base)) for t in ['native/Sources','native/Tests'] for f in (base/t).rglob('*') if f.is_file()}|{'native/Package.swift'}
  assert len(rows)==count and actual=={r['path'] for r in rows}
  for i,row in enumerate(rows):
   if i%200==0:guard()
   f=base/row['path'];assert f.is_file() and not f.is_symlink();checked(f,row)
  return rows
 try:
  disk=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
  assert disk['MountPoint']=='/Volumes/X5' and disk['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and disk['FilesystemType']=='apfs' and disk['Writable']
  guard();checked(Path(__file__),read(P/'finalizer-inputs1.json')['finalizer'])
  terminal(read(P/'prepare1.job.json'))
  build=read(P/'build1.job.json')
  if build['status']=='monitor-error':
   recovery=read(P/'build1-process-absence.json')
   checked(P/'build1.job.json',recovery['job']);checked(P/'build1.log',recovery['log'])
   assert recovery['allObservedProcessesAbsent'] and recovery['buildExitUnknown'] and recovery['buildExitCode'] is None
   assert all(row['absent'] and absent(row['pid']) for row in recovery['observations'])
   assert not recovery['taskCommandMatches'] and not build.get('signals')
  else:terminal(build,False)
  build_ok=build.get('exitCode')==0 and not build.get('guardReason') and not build.get('signals')
  selection=read(P/'selected-methods1.json');methods=selection['methods'];count=0;tests=[];all_passed=False
  assert len(methods)==len(set(methods))==167 and len(selection['retainedMethods'])==166 and len(selection['newMethods'])==1
  if not build_ok:
   assert build.get('exitCode')!=0 and not (P/'tests1-queue.job.json').exists() and not list(P.glob('test-*.job.json'))
   assert not (P/'package-check1.json').exists() and (P/'failure-diagnosis1.json').exists()
  else:
   queue=read(P/'tests1-queue.job.json');terminal(queue,False)
   selection=read(P/'selected-methods1.json');methods=selection['methods'];count=len(queue['completed'])
   assert len(methods)==len(set(methods))==167 and len(selection['retainedMethods'])==166 and len(selection['newMethods'])==1 and 1<=count<=167
   assert methods[:count]==[r['method'] for r in queue['completed']]
   all_passed=count==167 and all(r['passed'] for r in queue['completed'])
   assert queue['exitCode']==(0 if all_passed else 1) and bool(queue.get('all167Passed'))==all_passed
   assert all(r['passed'] for r in queue['completed'][:-1])
   if not all_passed:
    assert not queue['completed'][-1]['passed'] and queue['reason']=='First nonpassing method; remainder not started'
    assert (P/'failure-diagnosis1.json').is_file()
   assert all(not (P/f'test-{i:02d}.job.json').exists() for i in range(count+1,168))
   commands=read(P/'tests1-commands.json');checked(P/'tests1-commands.json',queue['selection'])
   checked(P/'selected-methods1.json',commands['selectedMethods']);checked(P/'package-check1.json',commands['packageCheck'])
   checked(P/'tools/run_application_host_gameplay_tests2.py',commands['queueProducer']);checked(P/'tools/run_application_host_gameplay_validation2.py',commands['runner'])
   assert methods==[r['method'] for r in commands['cases']]
   tests=[]
   for entry in queue['completed']:
    childpath=P/(entry['phase']+'.job.json');logpath=P/(entry['phase']+'.log')
    checked(childpath,entry['job']);checked(logpath,entry['log']);child=read(childpath);terminal(child,False)
    assert child['exitCode']==entry['exitCode']
    passed,done=result(logpath.read_text(),child,entry['method'])
    assert passed==entry['passed'] and [list(x) for x in done]==entry['completed']
    outcome='pass' if passed else 'guard-incomplete' if child.get('guardReason') else 'test-failure' if len(done)==1 and done[0][2]=='failed' else 'native-process-or-result-failure'
    tests.append(dict(method=entry['method'],phase=entry['phase'],pid=child['pid'],passed=passed,outcome=outcome,exitCode=child['exitCode'],seconds=child['elapsedSeconds'],sampledTreeRSS=child['peakTreeRSS'],guardReason=child.get('guardReason'),initialIdentityObservationGap=child.get('initialIdentityObservationGap'),transientExitObservations=child.get('transientExitObservations',[])))
   for row in commands['cases']:
    checked(Path(row['config']),row['pin'])
    childfile=P/(row['phase']+'.job.json')
    if childfile.exists():
     j=read(childfile);config=read(Path(row['config']));checked(Path(row['config']),j['config'])
     assert j['command']==config['command'] and j['contextSHA256']==pin(P/'context1.json')['sha256'] and j['candidateManifestSHA256']==pin(P/'candidate1-inputs.json')['sha256']
  author_review=read(P/'author-review1.json')
  assert author_review['independentReview'] is False and author_review['retainedSelectedMethodsVerifiedUnchanged']==166
  assert author_review['changedSwiftPaths']==2 and author_review['addedSwiftPaths']==0
  assert author_review['testEnvironmentOnly'] and author_review['productionUnchanged'] and author_review['priorMethodLimitsUnchanged']
  parent=Path(ctx['candidateSource']).parent
  assert methods[1:]==selection['retainedMethods']==read(parent/'selected-methods1.json')['methods']
  oldlimits=read(parent/'method-limits1.json')['methods'];limits=read(P/'method-limits1.json')['methods']
  assert all(limits[m]==b for m,b in oldlimits.items())
  checked(Path(author_review['addressAudit']['path']),author_review['addressAudit'])
  for key in ['candidateManifest','patch']:checked(Path(author_review[key]['path']),author_review[key])
  for row in read(P/'runner-inputs2.json')+ctx['protected']:checked(Path(row['path']),row)
  for row in ctx['sourceCodePins']:checked(R/row['path'],row)
  assert len(ctx['sourceCodePins'])==55
  native(R,Path(ctx['rootManifest']),1034)
  prior=ctx['priorManifest'];checked(Path(prior['path']),prior);native(Path(ctx['priorCandidate']),Path(prior['path']),2257)
  candidate=native(P/'candidate1',P/'candidate1-inputs.json',2291)
  baseline=Path(ctx['baselineManifest']['path']);checked(baseline,ctx['baselineManifest'])
  previous=native(Path(ctx['candidateSource']),baseline,2291)
  correction=read(P/'candidate-changes1.json');changes=correction['changes']
  assert len(changes)==2 and len(correction['newFiles'])==0
  modified={r['path'] for r in changes if r['before']};assert len(modified)==2
  mapped={r['path']:r for r in candidate}
  assert {r['path'] for r in previous if mapped[r['path']]!=r}==modified
  assert set(mapped)-{r['path'] for r in previous}==set(correction['newFiles'])
  from apply_loading_arena_candidate import EXISTING,ADDED
  assert modified=={'native/'+n for n in EXISTING} and set(correction['newFiles'])=={'native/'+n for n in ADDED}
  for row in changes:
   if row['before']:checked(Path(row['before']['path']),row['before'])
   checked(P/'candidate1'/row['path'],row['after'])
  patch=P/'candidate1.patch';roundtrip=P/'patch-roundtrip1';roundtrip.mkdir()
  for name in modified:
   target=roundtrip/name;target.parent.mkdir(parents=True,exist_ok=True)
   target.write_bytes((Path(ctx['candidateSource'])/name).read_bytes())
  for command in [['git','apply','--check',str(patch)],['git','apply',str(patch)]]:
   applied=subprocess.run(command,cwd=roundtrip,capture_output=True,text=True);assert applied.returncode==0,(applied.stdout,applied.stderr)
  for row in changes:assert (roundtrip/row['path']).read_bytes()==(P/'candidate1'/row['path']).read_bytes()
  save('patch-roundtrip1.json',dict(modified=sorted(modified),newFiles=correction['newFiles'],testEnvironmentOnly=True,productionUnchanged=True,referenceAndMacUnchanged=True,existingTestMethodsUnchanged=True,retainedSelectorsPreserved=True,expectedBytesAndMasksUnchanged=True,roundtripBytesVerified=True))
  rootpatch=R/'docs/evidence/application-loading-arena.patch';assert not rootpatch.exists();rootpatch.write_bytes(patch.read_bytes())
  release=P/'swift/arm64-apple-macosx/release';package=None;copied=[]
  if build_ok:
   package=read(P/'package-check1.json')
   assert package['allInputBytesVerified'] and package['sourceMembershipVerified'] and package['candidateFiles']==2291 and package['fixtureFiles']==385 and package['runtimeFiles']==1301
   assert {k:v['originalSources'] for k,v in package['targets'].items()}==dict(NTSDCore=210,NTSDReferenceChecks=61,NTSDCoreTests=292,NTSDMacPlatform=11)
   for key in ['buildJob','description','binary']:checked(Path(package[key]['path']),package[key])
   for row in package['resourceFiles']:checked(Path(row['path']),row)
   actual={str(f) for b in ['NTSDNative_NTSDCoreTests.bundle','NTSDNative_NTSDCore.bundle'] for f in (release/b).rglob('*') if f.is_file() and not f.is_symlink()}
   assert len(actual)==1686 and actual=={r['path'] for r in package['resourceFiles']}
   for target in package['targets'].values():
    for row in target['freshOutputs']:checked(Path(row['path']),row)
   assert not any(f.is_symlink() for b in ['NTSDNative_NTSDCoreTests.bundle','NTSDNative_NTSDCore.bundle'] for f in (release/b).rglob('*'))
  else:
   for bundle,marker,expected_count in [('NTSDNative_NTSDCoreTests.bundle','native/Tests/NTSDCoreTests/',385),('NTSDNative_NTSDCore.bundle','native/Sources/NTSDCore/Resources/',1301)]:
    expected={r['path'][len(marker):]:r for r in candidate if r['path'].startswith(marker) and ('/Fixtures/' in r['path'] if 'Tests' in bundle else True)}
    assert len(expected)==expected_count
    for f in sorted((release/bundle).rglob('*')):
     if f.is_file():
      key=str(f.relative_to(release/bundle));assert key in expected and not f.is_symlink()
      checked(f,{k:expected[key][k] for k in ['bytes','sha256']});copied.append(record(f))
   save('copied-resources1.json',dict(resources=copied,packageGate=False,buildFailed=True))
  # Preserve the full exact candidate and fresh release through regular APFS clones.
  archive=P/'artifact-archive1';assert not archive.exists();archive.mkdir()
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  files=[];dirs=[];links=[]
  for source,base,top,cloning in [(P/'candidate1',P,'candidate1',True),(release,P,'swift/arm64-apple-macosx/release',True)]:
   for i,f in enumerate([source,*sorted(source.rglob('*'))]):
    if i%200==0:guard()
    rel=Path(top)/f.relative_to(source);dest=archive/rel;s=f.lstat()
    if f.is_symlink():
     target=os.readlink(f);assert not Path(target).is_absolute() and (f.parent/target).resolve().is_relative_to(base)
     dest.parent.mkdir(parents=True,exist_ok=True);os.symlink(target,dest);os.utime(dest,ns=(s.st_atime_ns,s.st_mtime_ns),follow_symlinks=False)
     links.append(dict(path=str(rel),target=target,mode=stat.S_IMODE(s.st_mode),mtime_ns=s.st_mtime_ns))
    elif f.is_dir():dest.mkdir(parents=True,exist_ok=True);dirs.append(dict(path=str(rel),source=str(f),mode=stat.S_IMODE(s.st_mode),mtime_ns=s.st_mtime_ns))
    else:
     assert stat.S_ISREG(s.st_mode);row=dict(path=str(rel),source=str(f),**pin(f));dest.parent.mkdir(parents=True,exist_ok=True)
     if cloning:
      if clone(os.fsencode(f),os.fsencode(dest),0):raise OSError(ctypes.get_errno(),str(dest))
     else:shutil.copy2(f,dest)
     checked(dest,row);assert (f.stat().st_dev,f.stat().st_ino)!=(dest.stat().st_dev,dest.stat().st_ino);files.append(row)
  for row in reversed(dirs):shutil.copystat(row['source'],archive/row['path'],follow_symlinks=False)
  implicit={'swift','swift/arm64-apple-macosx'}
  assert {str(f.relative_to(archive)) for f in archive.rglob('*') if f.is_file() and not f.is_symlink()}=={r['path'] for r in files}
  assert {str(f.relative_to(archive)) for f in archive.rglob('*') if f.is_dir() and not f.is_symlink()}=={r['path'] for r in dirs}|implicit
  assert {str(f.relative_to(archive)) for f in archive.rglob('*') if f.is_symlink()}=={r['path'] for r in links}
  for i,row in enumerate(files):
   if i%200==0:guard()
   checked(Path(row['source']),row);checked(archive/row['path'],row)
  for row in dirs+links:
   f=archive/row['path'];s=f.lstat();assert stat.S_IMODE(s.st_mode)==row['mode'] and s.st_mtime_ns==row['mtime_ns']
   if 'target' in row:assert os.readlink(f)==row['target']
  release_count=sum(f.is_file() and not f.is_symlink() for f in release.rglob('*'))
  assert sum(r['path'].startswith('candidate1/') for r in files)==2291 and sum(r['path'].startswith('swift/') for r in files)==release_count and len(files)==2291+release_count and not links
  artifact=dict(schema='ntsd-application-loading-arena-validation-artifact-archive-v1',UTC=now(),files=files,directories=dirs,implicitParentDirectories=sorted(implicit),links=links,bytes=sum(r['bytes'] for r in files),fullBodyModeMtimeMembershipVerified=True,distinctRegularInodes=True)
  save('artifact-archive1.json',artifact)
  sourcejob=read(Path(ctx['sourceTask'])/'capture1/source.job.json');terminal(sourcejob)
  assert sourcejob['pid']==59727
  save('source-terminal1.json',dict(UTC=now(),job=record(Path(ctx['sourceTask'])/'capture1/source.job.json'),pid=sourcejob['pid'],status=sourcejob['status'],exitCode=sourcejob['exitCode'],processAbsent=True,sourceCodePinsVerified=55,sourceRestarted=False,whole137ReturnAccepted=False))
  verification=dict(UTC=now(),all167Passed=all_passed,passedMethods=sum(t['passed'] for t in tests),selectedMethods=167,unstartedMethods=methods[count:],tests=tests,totalTestProcessSeconds=sum(t['seconds'] for t in tests),sampledTestPeakRSS=max((t['sampledTreeRSS'] for t in tests),default=0),zeroRSSMeansNoSample=True,taskProcessAbsenceVerified=True,rootNativeFiles=1034,priorNativeFiles=2257,candidateFiles=2291,sourceCodePins=55,allPreserved=True,resourceFiles=1686 if build_ok else len(copied),buildMonitorStatus=build['status'],buildExitCode=build.get('exitCode'),buildPassed=build_ok,packageGate=build_ok,independentReview=False)
  save('verification1.json',verification)
  # Do not package mutable finalizer job/stdout or recursively package old archives.
  metadata=sorted([f for f in P.iterdir() if f.is_file() and f.name not in ['finalize1.job.json','finalize1.log'] and f.suffix!='.tar']+[f for f in (P/'tools').rglob('*.py') if f.is_file()])
  assert sum(f.stat().st_size for f in metadata)<32*2**20
  members=[dict(path=str(f.relative_to(P)),**pin(f)) for f in metadata];save('metadata1-inputs.json',members)
  tarpath=P/'metadata1.tar';assert not tarpath.exists()
  with tarfile.open(tarpath,'w',format=tarfile.PAX_FORMAT) as tf:
   for f in metadata:
    guard();info=tf.gettarinfo(str(f),arcname=str(f.relative_to(P)));ns=f.stat().st_mtime_ns
    assert info.isfile();info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
    with f.open('rb') as body:tf.addfile(info,body)
  assert tarpath.stat().st_size<32*2**20
  with tarfile.open(tarpath) as tf:
   assert len(tf.getmembers())==len(members) and {m.name for m in tf.getmembers()}=={r['path'] for r in members}
   for row in members:
    m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
    assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
  guard()
  pub=dict(schema='ntsd-application-loading-arena-validation-v1',UTC=now(),status='all167-passed' if all_passed else 'first-nonpass-retained' if build_ok else 'build-incomplete-before-tests',baseHead=ctx['head'],task=str(P),candidate=str(P/'candidate1'),candidateManifest=record(P/'candidate1-inputs.json'),context=record(P/'context1.json'),buildJob=record(P/'build1.job.json'),packageCheck=record(P/'package-check1.json') if build_ok else None,binary=package['binary'] if package else None,testQueue=record(P/'tests1-queue.job.json') if build_ok else None,failureDiagnosis=record(P/'failure-diagnosis1.json') if not all_passed else None,verification=record(P/'verification1.json'),passedMethods=verification['passedMethods'],selectedMethods=167,artifactArchive=dict(path=str(archive),files=len(files),directories=len(dirs)+len(implicit),links=len(links),bytes=artifact['bytes'],manifest=record(P/'artifact-archive1.json')),metadataArchive=dict(members=len(members),**record(tarpath)),sourceObservation=record(P/'source-terminal1.json'),parentFailurePreserved=record(Path(ctx['candidateSource']).parent/'failure-diagnosis1.json'),rootNativeUnchanged=1034,priorNativeUnchanged=2257,candidateFilesVerified=2291,testEnvironmentOnly=True,productionUnchanged=True,referenceAndMacUnchanged=True,existingTestMethodsUnchanged=True,retainedSelectorsPreserved=True,expectedBytesAndMasksUnchanged=True,sourcePinsUnchanged=55,gates=dict(build=build_ok,packageBytes=build_ok,nativeComparison=all_passed,archive=True,independentReview=False,rootPromotion=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullMatch=False,fullGame=False),EXEEnvelopeRecalculated=False,originalExecuted=False,limitations=['Only two test files change: a default-preserving wrapper arena parameter, explicit disjoint base in the loading composition and one finite disjointness control. Production, source expectations and all guards remain unchanged.',
   'All167 selection retains all166 previous selectors, their method bodies and limits, plus one new front-storage control covering old Object64 collision, 16726 future addressed inputs and actual ready owners. Only passed methods establish comparison. Independent review remains open.',
   'The address audit is a test-environment control, not a game oracle or Windows heap observation. Whole-caller comparisons remain unchanged; no original execution, fixture edit, root promotion or shipping integration.',
   'Source59727 terminal34Objects is not137. Runtime playback/WMA/gain/pan/mixing/resampling/latency, Windows font/cursor/device, review/integration/clean-Mac/full match/game and safety incidents remain open; NTSDApp still Practice.',
   'Short processes may finish before RSS sampling; zero is not known zero.'])
  save('publication1.json',pub)
  close=dict(schema='ntsd-application-loading-arena-validation-close-v1',UTC=now(),taskFrozen=True,largePhaseClosed=True,task=str(P),externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,externalReserve=40*2**30,internalReserve=6*2**30,sourceCommitment=17*2**30,prospectiveVMCommitment=64*2**30,observedFreeDecrease=ctx['startFree']-shutil.disk_usage(P).free,physicalAllowance=ctx['physicalAllowanceBytes'],publication=pin(P/'publication1.json'),metadataArchive=pub['metadataArchive'],artifactArchive=pub['artifactArchive'])
  save('external-close1.json',close)
  for local,suffix in [('publication1.json','.json'),('external-close1.json','-close.json')]:
   dest=R/('docs/evidence/application-loading-arena'+suffix);assert not dest.exists();dest.write_bytes((P/local).read_bytes())
  job.update(status='terminal',exitCode=0,all167Passed=all_passed,passedMethods=verification['passedMethods'],archivedFiles=len(files),metadataMembers=len(members))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'finalize1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
