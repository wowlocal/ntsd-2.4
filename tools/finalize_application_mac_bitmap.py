"""Close this fixed physical native display validation; reuse host finalizer checks and APFS archive procedure.
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
 assert P.name=='application-mac-bitmap-20260926'
 assert not (P/'external-close1.json').exists()
 ctx=read(P/'context1.json');began=time.monotonic()
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],
  identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
  cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
 save('finalize1.job.json',job)
 def guard():
  assert time.monotonic()-began<3600
  free=shutil.disk_usage(P).free
  assert free>ctx['originalExternalReserve']+ctx['sourceCommitment'] and shutil.disk_usage(R).free>ctx['originalInternalReserve']
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
  for n in ['prepare1.job.json','build1.job.json']:terminal(read(P/n))
  queue=read(P/'tests1-queue.job.json');terminal(queue,False)
  selection=read(P/'selected-methods1.json');methods=selection['methods'];count=len(queue['completed'])
  assert len(methods)==len(set(methods))==48 and len(selection['retainedMethods'])==44 and len(selection['newMethods'])==4 and 1<=count<=48
  assert methods[:count]==[r['method'] for r in queue['completed']]
  all_passed=count==48 and all(r['passed'] for r in queue['completed'])
  assert queue['exitCode']==(0 if all_passed else 1) and bool(queue.get('all48Passed'))==all_passed
  assert all(r['passed'] for r in queue['completed'][:-1])
  if not all_passed:
   assert not queue['completed'][-1]['passed'] and queue['reason']=='First nonpassing method; remainder not started'
   assert (P/'failure-diagnosis1.json').is_file()
  assert all(not (P/f'test-{i:02d}.job.json').exists() for i in range(count+1,49))
  commands=read(P/'tests1-commands.json');checked(P/'tests1-commands.json',queue['selection'])
  checked(P/'selected-methods1.json',commands['selectedMethods']);checked(P/'package-check1.json',commands['packageCheck'])
  checked(P/'tools/run_application_host_gameplay_tests.py',commands['queueProducer']);checked(P/'tools/run_application_host_gameplay_validation.py',commands['runner'])
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
  for row in read(P/'runner-inputs1.json')+ctx['protected']:checked(Path(row['path']),row)
  for row in ctx['sourceCodePins']:checked(R/row['path'],row)
  assert len(ctx['sourceCodePins'])==55
  native(R,Path(ctx['rootManifest']),1034)
  prior=ctx['priorManifest'];checked(Path(prior['path']),prior);native(Path(ctx['priorCandidate']),Path(prior['path']),2257)
  candidate=native(P/'candidate1',P/'candidate1-inputs.json',2265)
  baseline=Path(ctx['baselineManifest']['path']);checked(baseline,ctx['baselineManifest'])
  previous=native(Path(ctx['candidateSource']),baseline,2263)
  ancestor=read(Path(ctx['candidateSource']).parent/'context1.json')
  ancestorManifest=Path(ancestor['baselineManifest']['path']);checked(ancestorManifest,ancestor['baselineManifest'])
  native(Path(ancestor['candidateSource']),ancestorManifest,2261)
  native(Path(ancestor['failedCandidate']),ancestorManifest,2261)
  correction=read(P/'correction1.json');changed=correction['path']
  assert changed=='native/Sources/NTSDMacPlatform/OriginalMacDisplayBackend.swift'
  mapped={r['path']:r for r in candidate}
  assert [r['path'] for r in previous if mapped[r['path']]!=r]==[changed]
  assert set(mapped)-{r['path'] for r in previous}==set(correction['newFiles'])
  before=(Path(ctx['candidateSource'])/changed).read_text();after=before
  for a,b in correction['replacements']:
   assert after.count(a)==1;after=after.replace(a,b)
  checked(Path(correction['extension']['path']),correction['extension'])
  after+=Path(correction['extension']['path']).read_text()
  assert after==(P/'candidate1'/changed).read_text()
  for name,row in correction['templates'].items():
   checked(Path(row['path']),row);assert Path(row['path']).read_bytes()==(P/'candidate1'/name).read_bytes()
  patch=P/'correction1.patch';roundtrip=P/'patch-roundtrip1';roundtrip.mkdir()
  target=roundtrip/changed;target.parent.mkdir(parents=True);target.write_text(before)
  for command in [['git','apply','--check',str(patch)],['git','apply',str(patch)]]:
   applied=subprocess.run(command,cwd=roundtrip,capture_output=True,text=True);assert applied.returncode==0,(applied.stdout,applied.stderr)
  for name in [changed]+correction['newFiles']:assert (roundtrip/name).read_bytes()==(P/'candidate1'/name).read_bytes()
  save('patch-roundtrip1.json',dict(changed=changed,newFiles=correction['newFiles'],bitmapProviderAdded=True,allOldTestBodiesUnchanged=True,roundtripBytesVerified=True))
  rootpatch=R/'docs/evidence/application-mac-bitmap.patch';assert not rootpatch.exists();rootpatch.write_bytes(patch.read_bytes())
  package=read(P/'package-check1.json')
  assert package['allInputBytesVerified'] and package['sourceMembershipVerified'] and package['candidateFiles']==2265 and package['fixtureFiles']==385 and package['runtimeFiles']==1301
  assert {k:v['originalSources'] for k,v in package['targets'].items()}==dict(NTSDCore=199,NTSDReferenceChecks=61,NTSDCoreTests=281,NTSDMacPlatform=7)
  for key in ['buildJob','description','binary']:checked(Path(package[key]['path']),package[key])
  for row in package['resourceFiles']:checked(Path(row['path']),row)
  release=P/'swift/arm64-apple-macosx/release'
  actual={str(f) for b in ['NTSDNative_NTSDCoreTests.bundle','NTSDNative_NTSDCore.bundle'] for f in (release/b).rglob('*') if f.is_file() and not f.is_symlink()}
  assert len(actual)==1686 and actual=={r['path'] for r in package['resourceFiles']}
  for target in package['targets'].values():
   for row in target['freshOutputs']:checked(Path(row['path']),row)
  assert not any(f.is_symlink() for b in ['NTSDNative_NTSDCoreTests.bundle','NTSDNative_NTSDCore.bundle'] for f in (release/b).rglob('*'))
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
  assert sum(r['path'].startswith('candidate1/') for r in files)==2265 and sum(r['path'].startswith('swift/') for r in files)==release_count and len(files)==2265+release_count and not links
  artifact=dict(schema='ntsd-mac-display-validation-artifact-archive-v1',UTC=now(),files=files,directories=dirs,implicitParentDirectories=sorted(implicit),links=links,bytes=sum(r['bytes'] for r in files),fullBodyModeMtimeMembershipVerified=True,distinctRegularInodes=True)
  save('artifact-archive1.json',artifact)
  sourcejob=read(Path(ctx['sourceTask'])/'capture1/source.job.json');terminal(sourcejob)
  assert sourcejob['pid']==59727
  save('source-terminal1.json',dict(UTC=now(),job=record(Path(ctx['sourceTask'])/'capture1/source.job.json'),pid=sourcejob['pid'],status=sourcejob['status'],exitCode=sourcejob['exitCode'],processAbsent=True,sourceCodePinsVerified=55,sourceRestarted=False,whole137ReturnAccepted=False))
  verification=dict(UTC=now(),all48Passed=all_passed,passedMethods=sum(t['passed'] for t in tests),selectedMethods=48,unstartedMethods=methods[count:],tests=tests,totalTestProcessSeconds=sum(t['seconds'] for t in tests),sampledTestPeakRSS=max(t['sampledTreeRSS'] for t in tests),zeroRSSMeansNoSample=True,taskProcessAbsenceVerified=True,rootNativeFiles=1034,priorNativeFiles=2257,candidateFiles=2265,sourceCodePins=55,allPreserved=True,resourceFiles=1686,independentReview=False)
  save('verification1.json',verification)
  # Do not package mutable finalizer job/stdout or recursively package old archives.
  metadata=sorted([f for f in P.iterdir() if f.is_file() and f.name not in ['finalize1.job.json','finalize1.log'] and f.suffix!='.tar']+[f for f in (P/'tools').rglob('*.py') if f.is_file()])
  assert sum(f.stat().st_size for f in metadata)<16*2**20
  members=[dict(path=str(f.relative_to(P)),**pin(f)) for f in metadata];save('metadata1-inputs.json',members)
  tarpath=P/'metadata1.tar';assert not tarpath.exists()
  with tarfile.open(tarpath,'w',format=tarfile.PAX_FORMAT) as tf:
   for f in metadata:
    guard();info=tf.gettarinfo(str(f),arcname=str(f.relative_to(P)));ns=f.stat().st_mtime_ns
    assert info.isfile();info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
    with f.open('rb') as body:tf.addfile(info,body)
  assert tarpath.stat().st_size<16*2**20
  with tarfile.open(tarpath) as tf:
   assert len(tf.getmembers())==len(members) and {m.name for m in tf.getmembers()}=={r['path'] for r in members}
   for row in members:
    m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
    assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
  guard()
  pub=dict(schema='ntsd-mac-display-validation-v1',UTC=now(),status='all48-passed' if all_passed else 'first-nonpass-retained',baseHead=ctx['head'],task=str(P),candidate=str(P/'candidate1'),candidateManifest=record(P/'candidate1-inputs.json'),context=record(P/'context1.json'),buildJob=record(P/'build1.job.json'),packageCheck=record(P/'package-check1.json'),binary=package['binary'],testQueue=record(P/'tests1-queue.job.json'),verification=record(P/'verification1.json'),passedMethods=verification['passedMethods'],selectedMethods=48,artifactArchive=dict(path=str(archive),files=len(files),directories=len(dirs)+len(implicit),links=len(links),bytes=artifact['bytes'],manifest=record(P/'artifact-archive1.json')),metadataArchive=dict(members=len(members),**record(tarpath)),sourceObservation=record(P/'source-terminal1.json'),rootNativeUnchanged=1034,priorNativeUnchanged=2257,candidateFilesVerified=2265,bitmapProviderAdded=True,allOldTestBodiesUnchanged=True,sourcePinsUnchanged=55,gates=dict(build=True,packageBytes=True,nativeComparison=all_passed,archive=True,independentReview=False,rootPromotion=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullMatch=False,fullGame=False),EXEEnvelopeRecalculated=False,originalExecuted=False,limitations=['Native bitmap/DC resources and one-to-one XRGB conversion are explicit host policy, not actual Windows GDI raster observations.','Source59727 terminal at its previously recorded34-Object publication boundary; full137 and transport/provenance audits remain open.','Unified startup is tested with declared responses plus a separate actual Mac clock whole-caller control if its exact method passes. Physical display allocation/clear/AppKit view readback methods are separately observed if passed. Native XRGB8888/logical-screen/refcount policies do not establish Windows equivalence. Whole front-screen host integration, general blit/presentation/palette/text/callbacks/other providers/input/audio remain open; NTSDApp still uses practice. Retained inspection controls are finite scheduler observations.','Short processes can finish before RSS sample; recorded0 is not known zero.'])
  save('publication1.json',pub)
  close=dict(schema='ntsd-mac-display-validation-close-v1',UTC=now(),taskFrozen=True,largePhaseClosed=True,task=str(P),externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,externalReserve=40*2**30,internalReserve=6*2**30,sourceCommitment=17*2**30,observedFreeDecrease=ctx['startFree']-shutil.disk_usage(P).free,physicalAllowance=ctx['physicalAllowanceBytes'],publication=pin(P/'publication1.json'),metadataArchive=pub['metadataArchive'],artifactArchive=pub['artifactArchive'])
  save('external-close1.json',close)
  for local,suffix in [('publication1.json','.json'),('external-close1.json','-close.json')]:
   dest=R/('docs/evidence/application-mac-bitmap'+suffix);assert not dest.exists();dest.write_bytes((P/local).read_bytes())
  job.update(status='terminal',exitCode=0,all48Passed=all_passed,passedMethods=verification['passedMethods'],archivedFiles=len(files),metadataMembers=len(members))
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'finalize1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
