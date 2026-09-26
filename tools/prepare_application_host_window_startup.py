#!/usr/bin/env python3
"""Prepare one isolated same-Host window-startup candidate using existing pin/APFS clone procedure."""
import ctypes,datetime,json,os,plistlib,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import pin,checked
R=Path(__file__).resolve().parents[1]
B=(R/'build/research/application-window-exchange-validation-20260926').resolve()
P=B.parent/'application-host-window-startup-20260926'
PLAN=R/'docs/research/APPLICATION_HOST_WINDOW_STARTUP_PLAN.md'
read=lambda p:json.loads(p.read_text())
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def record(p):return dict(path=str(p.resolve()),**pin(p))
def save(name,data):
 p=P/name;assert not p.exists(),str(p);p.write_text(json.dumps(data,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def main():
 os.chdir(R);volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs' and volume['Writable']
 free=shutil.disk_usage(B.parent).free;assert free>65*2**30 and shutil.disk_usage(R).free>9*2**30
 assert not P.exists() and not (R/'build/research'/P.name).exists()
 pub=read(B/'publication1.json');assert pub['status']=='all10-passed' and read(B/'external-close1.json')['taskFrozen']
 for key in ['candidateManifest','context','verification','packageCheck']:checked(Path(pub[key]['path']),pub[key])
 for n in ['tests1-queue.job.json','finalize1.job.json']:
  j=read(B/n);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 old=read(B/'context1.json');source=Path(old['sourceTask']);sj=read(source/'capture1/source.job.json');assert sj['status']=='terminal' and sj['exitCode']==0 and absent(sj['pid'])
 inputs=read(B/'candidate1-inputs.json');assert len(inputs)==2244
 P.mkdir();(R/'build/research'/P.name).symlink_to(P,target_is_directory=True);start=time.monotonic()
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__))],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('prepare1.job.json',job)
 try:
  rootrows=read(Path(old['rootManifest']))
  for row in rootrows:checked(R/row['path'],row)
  for row in old['sourceCodePins']:checked(R/row['path'],row)
  protected=[PLAN,Path(__file__),R/'tools/archive_catalog53_storage.py',B/'publication1.json',B/'external-close1.json',B/'candidate1-inputs.json',B/'selected-methods1.json',Path(old['rootManifest']),source/'capture1/source.job.json',R/'AGENTS.md',R/'AGENTS_HISTORY_2026-09-12.md',R/'docs/research/WORKFLOW.md',R/'docs/research/TASK_TEMPLATE.md',R/'docs/research/APPLICATION_HOST_APP_PREFLIGHT.md',R/'docs/research/APPLICATION_HOST_TRANSACTION_PREFLIGHT.md',R/'docs/research/APPLICATION_PREPARED_BACKEND_PREFLIGHT.md',R/'docs/research/WINDOW_INITIALIZATION.md',R/'docs/research/WINMAIN_STARTUP.md',R/'tools/prepare_application_host_delivery_context.py',R/'docs/research/APPLICATION_WINDOW_EXCHANGE_VALIDATION.md',R/'docs/research/APPLICATION_WINDOW_EXCHANGE.md',R/'docs/research/APPLICATION_HOST_DELIVERY_CONTEXT.md',R/'docs/research/APPLICATION_GRAPHICS_OWNERS.md',R/'docs/research/WAVE_LOADING.md',R/'docs/evidence/codex-safety-incidents-2026-09-12.json']
  context=dict(schema='ntsd-host-window-startup-candidate-v1',UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(f) for f in protected],baseline=str(B/'candidate1'),baselineManifest=record(B/'candidate1-inputs.json'),rootManifest=old['rootManifest'],sourceTask=str(source),sourceCodePins=old['sourceCodePins'],startFree=free,physicalAllowanceBytes=4*2**30,stopDecreaseBytes=3584*2**20,logicalLimitBytes=16*2**30,elapsedLimitSeconds=7200,externalReserve=40*2**30,internalReserve=6*2**30,sourceCommitment=17*2**30,gitStatus=subprocess.check_output(['git','status','--porcelain'],text=True),independentReview=False,originalExecuted=False)
  save('context1.json',context)
  for src,name in [(PLAN,'plan1.md'),(Path(__file__),'prepare1.py'),(B/'candidate1-inputs.json','baseline-inputs1.json'),(B/'selected-methods1.json','baseline-methods1.json')]:shutil.copy2(src,P/name)
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for row in inputs:
   assert time.monotonic()-start<7200 and free-shutil.disk_usage(P).free<3584*2**20 and shutil.disk_usage(P).free>57*2**30
   src=B/'candidate1'/row['path'];dst=P/'candidate1'/row['path'];checked(src,row);dst.parent.mkdir(parents=True,exist_ok=True)
   if clone(os.fsencode(src),os.fsencode(dst),0):raise OSError(ctypes.get_errno(),str(dst))
   checked(dst,row);assert src.stat().st_ino!=dst.stat().st_ino
  assert {str(f.relative_to(P/'candidate1')) for f in (P/'candidate1').rglob('*') if f.is_file()}=={r['path'] for r in inputs}
  job.update(status='terminal',exitCode=0,files=2244,bytes=sum(r['bytes'] for r in inputs),fullCloneVerified=True,distinctRegularInodes=True)
 except BaseException as e:job.update(status='terminal',exitCode=1,error=repr(e),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(P/'prepare1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
