#!/usr/bin/env python3
"""Preserve an existing controlled NTSD catalog capture across a storage move.

Use the finite APPLICATION_CATALOG_TRACE_STORAGE_PLAN: verify the exact local
Unicorn worker and pinned inputs, SIGSTOP it, require closed trace descriptors,
copy every transport byte/mode/mtime to the declared local APFS task directory,
publish a canonical symlink with rollback backup, and SIGCONT the same worker.
No emulator memory/register/instruction/API/input or6GiB-reserve changes. The
host pause affects elapsed research logs, not the harness's declared game clock.
Abort/resume on open trace files, temporary parts, IO/hash/identity errors or the
declared pause bound. This is preservation, not a new native/Windows match.
"""
import argparse,base64,datetime,hashlib,json,os,plistlib,shutil,signal,subprocess,time,traceback
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def identity(pid):return subprocess.check_output(['ps','-p',str(pid),'-o','lstart=,ppid=,command='],text=True).strip()

def migrate(plan_path,output):
 plan=json.loads(plan_path.read_bytes());pid=plan['pid'];assert pid==78863
 assert not output.exists();report=dict(scope=__doc__,planSHA256=sha(plan_path),startedUTC=now(),status='preflight',pid=pid)
 source,target,backup=(Path(plan[k]) for k in ('source','target','backup'))
 assert source==ROOT/'build/research/application-catalog-candidate5-resourced.traces'
 assert backup==source.with_name(source.name+'.before-x5')
 assert target==Path(plan['taskRoot'])/plan['thread']/source.name
 assert source.is_dir() and not source.is_symlink() and not target.exists() and not backup.exists()
 assert identity(pid)==plan['identity']
 job=json.loads((ROOT/plan['sourceJob']).read_bytes());assert job['status']=='running' and job['pid']==78860
 for field in ('producer','inputManifest','planDocument'):assert sha(ROOT/plan[field])==plan[field+'SHA256']
 pins=json.loads((ROOT/plan['inputManifest']).read_bytes())['pins'];assert len(pins)==890
 for p,h in pins.items():assert sha(ROOT/p)==h,p
 volume=plistlib.loads(subprocess.check_output(['diskutil','info','-plist',plan['volumeMount']]))
 assert volume['VolumeUUID']==plan['volumeUUID'] and volume['FilesystemType']=='apfs'
 assert shutil.disk_usage(target.parent if target.parent.exists() else plan['volumeMount']).free>50*1024**3
 target.mkdir(parents=True);report['sourceFreeBefore']=shutil.disk_usage(source).free
 paused=False;published=False;link=source.with_name(source.name+'.x5-link.tmp');assert not link.exists()
 inventory=[];pause_start=None
 def deadline():
  assert time.monotonic()-pause_start<=plan['pauseLimitSeconds'],'Declared pause limit exceeded; original path must be retained'
 def save():
  temp=output.with_suffix('.tmp');temp.write_text(json.dumps(report,indent=2)+'\n');os.replace(temp,output)
 try:
  assert identity(pid)==plan['identity'];os.kill(pid,signal.SIGSTOP);paused=True;pause_start=time.monotonic()
  for _ in range(20):
   status=subprocess.check_output(['ps','-p',str(pid),'-o','stat='],text=True).strip()
   if 'T' in status:break
   time.sleep(.05)
  assert 'T' in status and identity(pid)==plan['identity'];report.update(pausedUTC=now(),pausedStatus=status,status='paused')
  descriptors=subprocess.check_output(['lsof','-p',str(pid),'-Fnft'],text=True);report['pausedDescriptors']=descriptors
  assert not any(line.startswith('n'+str(source)) for line in descriptors.splitlines())
  assert all(not line[1:].isdigit() or int(line[1:])<=2 for line in descriptors.splitlines() if line.startswith('f'))
  files=sorted(source.iterdir());assert files and all(p.is_file() and not p.is_symlink() and (p.name.endswith('.json.zlib') or p.name.endswith('-index.json')) for p in files),'Unexpected/open temporary trace storage'
  print('Paused verified worker; copying',len(files),'closed trace files',flush=True)
  for p in files:
   deadline();meta=p.stat();raw=p.read_bytes();item=dict(name=p.name,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),mode=meta.st_mode,mtimeNS=meta.st_mtime_ns)
   if p.name.endswith('-index.json'):item['indexBytesBase64']=base64.b64encode(raw).decode()
   shutil.copy2(p,target/p.name);copied=(target/p.name).read_bytes();m=(target/p.name).stat()
   assert copied==raw and m.st_mode==meta.st_mode and m.st_mtime_ns==meta.st_mtime_ns,p
   inventory.append(item)
  deadline();assert {p.name for p in target.iterdir()}=={x['name'] for x in inventory}
  report.update(files=len(inventory),bytes=sum(x['bytes'] for x in inventory),inventory=inventory,status='copied and verified')
  save();deadline();assert identity(pid)==plan['identity']
  os.symlink(target,link,target_is_directory=True);os.rename(source,backup)
  try:
   os.replace(link,source)
   for x in inventory:
    p=source/x['name'];assert p.stat().st_size==x['bytes'] and sha(p)==x['sha256'] and p.stat().st_mode==x['mode'] and p.stat().st_mtime_ns==x['mtimeNS'],p
   assert identity(pid)==plan['identity'];published=True;report.update(status='published; backup retained',target=str(target),source=str(source),backup=str(backup),publishedUTC=now())
  except BaseException:
   if source.is_symlink():source.unlink()
   if not source.exists() and backup.exists():os.rename(backup,source)
   raise
 except BaseException as e:
  report.update(status='failed; same worker must resume',error=repr(e),errorText=str(e),traceback=traceback.format_exc(),failedUTC=now(),published=published)
  raise
 finally:
  if paused:
   assert identity(pid)==plan['identity'],'Worker identity changed; do not signal a different process'
   os.kill(pid,signal.SIGCONT);report.update(resumedUTC=now(),pauseSeconds=round(time.monotonic()-pause_start,3),sameWorkerResumed=True)
  report.update(endedUTC=now(),sourceFreeAfter=shutil.disk_usage(source.parent).free,published=published)
  save()
 print('Same worker resumed; verified files',report['files'],'pause seconds',report['pauseSeconds'],'backup retained',flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--plan',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();migrate(a.plan,a.output)
