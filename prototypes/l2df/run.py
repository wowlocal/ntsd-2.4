#!/usr/bin/env python3
"""Run local native LÖVE; retain a unique job and terminal outcome."""
import argparse,datetime,hashlib,json,os,pathlib,shutil,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--smoke',action='store_true');p.add_argument('--label');p.add_argument('--app',type=pathlib.Path)
p.add_argument('--build-name',required=True);p.add_argument('--case-input',type=pathlib.Path,help='Declared initial/input masks only, for GUI integration comparison')
p.add_argument('--ui-reset-check',action='store_true',help='Smoke-only: capture unsupported notice, invoke R callback, validate reset and continuation')
a=p.parse_args();assert not pathlib.Path(a.build_name).is_absolute() and '..' not in pathlib.Path(a.build_name).parts
storage=ROOT/'build/l2df-prototype';build=storage/a.build_name;label=a.label or datetime.datetime.now().strftime('%Y%m%d-%H%M%S');logs=build/'logs'/label;logs.mkdir(parents=True,exist_ok=False)
cmd=[str((storage/'runtime/love.app/Contents/MacOS/love').resolve()),str((build/'game').resolve())]
if a.app:cmd=[str(a.app.resolve()/'Contents/MacOS/love')]
if a.smoke:cmd.append('--smoke')
if a.ui_reset_check:
 assert a.smoke and a.case_input
 cmd.append('--ui-reset-check')
pins=[]
for path in [pathlib.Path(__file__).resolve(),build/'game/main.lua',build/'game/conf.lua',build/'game/catalog.lua',build/'game/compat-data.lua',*sorted((build/'game/compat').glob('*.lua')),build/'resource-manifest.json',pathlib.Path(cmd[0])]:
 raw=path.read_bytes();pins.append({'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
 if path.suffix in ['.py','.lua']:shutil.copy2(path,logs/path.name)
if a.app:
 path=a.app.resolve()/'Contents/Resources/NTSD.love';raw=path.read_bytes();pins.append({'path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
env=dict(os.environ,NTSD_L2DF_LOG_DIR=str(logs.resolve()))
if a.case_input:
 assert a.smoke,'Case input is only accepted for an explicit smoke run'
 raw=a.case_input.read_bytes();case=json.loads(raw)
 assert set(case)<=set(['label','initial','inputs','localPlayer']) and 'inputs' in case,'Only declared case inputs; expected states are forbidden'
 target=logs/'case-input.json';target.write_bytes(raw);env['NTSD_L2DF_CASE_INPUT']=str(target.resolve())
 pins.append({'path':str(a.case_input.resolve()),'snapshot':str(target.resolve()),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
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
