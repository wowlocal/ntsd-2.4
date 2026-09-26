"""Preserve one checked build/package/test progress snapshot, without touching the live queue."""
import datetime,hashlib,importlib.util,json,os,shutil,stat,subprocess,sys,tarfile,time,traceback
from decimal import Decimal
from pathlib import Path
R=Path('/Users/michael/Developer/ntsd-2.4');P=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'tools'))
from archive_catalog53_storage import pin,checked
read=lambda p:json.loads(p.read_text())
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def record(p):return dict(path=str(p.resolve()),**pin(p))
def save(name,data):
 p=P/name;assert not p.exists(),str(p);p.write_text(json.dumps(data,indent=2)+'\n')
def process(pid):
 return dict(identity=subprocess.run(['ps','-p',str(pid),'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip(),cwd=subprocess.run(['lsof','-a','-p',str(pid),'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip())
def main():
 start=time.monotonic();ctx=read(P/'context1.json')
 checked(P/'finalize1.py',read(P/'finalizer-inputs1.json')['finalizer'])
 spec=importlib.util.spec_from_file_location('saved_delivery_result',P/'finalize1.py');f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
 build=read(P/'build1.job.json');f.terminal(build)
 prep=read(P/'prepare1.job.json');f.terminal(prep)
 package=read(P/'package-check1.json');assert package['allInputBytesVerified'] and package['sourceMembershipVerified']
 for key in ['buildJob','description','binary']:checked(Path(package[key]['path']),package[key])
 for row in package['resourceFiles']:checked(Path(row['path']),row)
 for target in package['targets'].values():
  for row in target['freshOutputs']:checked(Path(row['path']),row)
 for row in ctx['protected']:checked(Path(row['path']),row)
 for row in ctx['sourceCodePins']:checked(R/row['path'],row)
 for base,manifest,count in [(R,Path(ctx['rootManifest']),1034),(Path(ctx['candidateSource']),P/'baseline-inputs1.json',2268),(P/'candidate1',P/'candidate1-inputs.json',2268),(Path(ctx['priorCandidate']),Path(ctx['priorManifest']['path']),2257)]:
  rows=read(manifest);assert len(rows)==count
  actual={str(x.relative_to(base)) for top in ['native/Sources','native/Tests'] for x in (base/top).rglob('*') if x.is_file()}|{'native/Package.swift'}
  assert actual=={r['path'] for r in rows}
  for row in rows:checked(base/row['path'],row)
 q=read(P/'tests1-queue.job.json');assert q['status']=='running'
 observation=process(q['pid']);assert observation['identity'].split()==q['processIdentity'].split() and observation['cwd']==q['cwdObservation']
 methods=read(P/'selected-methods1.json')['methods'];completed=q['completed'];assert 5<=len(completed)<69 and [r['method'] for r in completed]==methods[:len(completed)]
 for row in completed:
  job=P/(row['phase']+'.job.json');log=P/(row['phase']+'.log');checked(job,row['job']);checked(log,row['log']);j=read(job);f.terminal(j)
  passed,done=f.result(log.read_text(),j,row['method']);assert passed and row['passed'] and [list(v) for v in done]==row['completed']
 save('start-queue1.json',q)
 current=P/(q['current']['phase']+'.job.json');child=None
 if current.exists():
  j=read(current);child=dict(job=j,observation=process(j['pid']) if j.get('pid') else None)
  # Queue can transition while the read-only snapshot is gathered; preserve the
  # actual observation without treating an admission/exit gap as a child failure.
 save('start-observation1.json',dict(UTC=now(),queue=observation,current=child,queueLiveVerified=True,currentObservationNonAtomic=True))
 names=['context1.json','candidate1-inputs.json','selected-methods1.json','method-limits1.json','adaptation1.json','prepare1.job.json','prepare1.py','plan1.md','build1-config.json','build1.job.json','build1.log','build1-storage.jsonl','runner-inputs1.json','runner-controls1.json','package-check1.json','tests1-commands.json','tests1-queue.py','start-queue1.json','start-observation1.json','finalize1.py','finalizer-inputs1.json','publish-start1.py','publisher-inputs1.json','correction1.json','correction1.patch','syntax1.json','baseline-inputs1.json']
 files=[P/n for n in names]+sorted((P/'tools').glob('*.py'))+sorted(P.glob('test-*-config.json'))
 for row in completed:files.extend(P/(row['phase']+suffix) for suffix in ['.job.json','.log','-storage.jsonl'])
 assert len(files)==len(set(files)) and sum(x.stat().st_size for x in files)<16*2**20
 members=[dict(path=str(x.relative_to(P)),**pin(x)) for x in sorted(files)];save('start-metadata1-inputs.json',members)
 archive=P/'start-metadata1.tar';assert not archive.exists()
 with tarfile.open(archive,'w',format=tarfile.PAX_FORMAT) as tf:
  for row in members:
   path=P/row['path'];info=tf.gettarinfo(str(path),arcname=row['path']);assert info.isfile()
   ns=row['mtime_ns'];info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
   with path.open('rb') as stream:tf.addfile(info,stream)
 assert archive.stat().st_size<16*2**20
 with tarfile.open(archive) as tf:
  assert len(tf.getmembers())==len(members) and {m.name for m in tf.getmembers()}=={r['path'] for r in members}
  for row in members:
   m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
   assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
 assert time.monotonic()-start<3600 and shutil.disk_usage(P).free>57*2**30 and shutil.disk_usage(R).free>6*2**30
 assert ctx['startFree']-shutil.disk_usage(P).free<ctx['stopObservedDecrease']
 value=dict(schema='ntsd-observed-bitmap-correction1-start-v1',UTC=now(),task=str(P),candidateManifest=record(P/'candidate1-inputs.json'),buildJob=record(P/'build1.job.json'),packageCheck=record(P/'package-check1.json'),binary=package['binary'],selection=record(P/'selected-methods1.json'),queueSnapshot=record(P/'start-queue1.json'),observation=record(P/'start-observation1.json'),passedMethods=len(completed),selectedMethods=69,allFiveNewPassed=True,queuePID=q['pid'],queueStatusAtSnapshot='running',queueCurrent=q['current']['phase'],rootFilesUnchanged=1034,priorFilesUnchanged=2257,candidateFilesUnchanged=2268,sourcePinsUnchanged=55,metadataArchive=dict(members=len(members),**record(archive)),externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,observedFreeDecrease=ctx['startFree']-shutil.disk_usage(P).free,taskFrozen=False,gates=dict(build=True,package=True,newFiveMethods=True,all69=False,metadataArchive=True,completeArtifactArchive=False,independentReview=False,rootPromotion=False,devices=False,fullGame=False),originalExecuted=False,EXEEnvelopeRecalculated=False)
 save('start1.json',value);out=R/'docs/evidence/application-observed-bitmap-correction1-start.json';assert not out.exists();out.write_bytes((P/'start1.json').read_bytes())
 print(json.dumps(dict(passedMethods=len(completed),queuePID=q['pid'],metadataMembers=len(members),seconds=time.monotonic()-start)),flush=True)
if __name__=='__main__':
 os.chdir(R);began=time.monotonic();observation=process(os.getpid())
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__))],producer=pin(Path(__file__)),**observation)
 save('start1.job.json',job)
 try:
  main();job.update(status='terminal',exitCode=0)
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'start1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
