#!/usr/bin/env python3
"""Run local native LÖVE; retain a unique job and terminal outcome."""
import argparse,datetime,hashlib,json,os,pathlib,shutil,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--smoke',action='store_true');p.add_argument('--label');p.add_argument('--app',type=pathlib.Path);a=p.parse_args()
build=ROOT/'build/l2df-prototype';label=a.label or datetime.datetime.now().strftime('%Y%m%d-%H%M%S');logs=build/'logs'/label;logs.mkdir(parents=True,exist_ok=False)
cmd=[str((build/'runtime/love.app/Contents/MacOS/love').resolve()),str((build/'game').resolve())]
if a.app:cmd=[str(a.app.resolve()/'Contents/MacOS/love')]
if a.smoke:cmd.append('--smoke')
pins=[]
for path in [pathlib.Path(__file__).resolve(),build/'game/main.lua',build/'game/conf.lua',build/'game/catalog.lua',build/'resource-manifest.json',pathlib.Path(cmd[0])]:
 raw=path.read_bytes();pins.append({'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
 if path.suffix in ['.py','.lua']:shutil.copy2(path,logs/path.name)
if a.app:
 path=a.app.resolve()/'Contents/Resources/NTSD.love';raw=path.read_bytes();pins.append({'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
env=dict(os.environ,NTSD_L2DF_LOG_DIR=str(logs.resolve()))
with (logs/'stdout.log').open('wb') as out:
 proc=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=out,stderr=subprocess.STDOUT)
 job={'pid':proc.pid,'inputPins':pins,'createdAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'processStart':subprocess.check_output(['ps','-p',str(proc.pid),'-o','lstart='],text=True).strip(),'command':cmd,'cwd':str(ROOT),'output':str(logs.resolve()),'state':'running','smokeLimitSeconds':90 if a.smoke else None}
 (logs/'job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
 try:rc=proc.wait(timeout=90 if a.smoke else None)
 except subprocess.TimeoutExpired:
  # Popen still owns this exact child; preserve timeout distinctly from candidate pass.
  job['timeout']=True;proc.terminate();rc=proc.wait(timeout=10)
 job.update(state='terminal',exitCode=rc,endedAtUTC=datetime.datetime.now(datetime.timezone.utc).isoformat());(logs/'job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
raise SystemExit(rc)
