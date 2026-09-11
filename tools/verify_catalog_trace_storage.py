#!/usr/bin/env python3
"""Read-only continuity audit after moving the controlled NTSD trace transport.

Check copied bytes/modes/mtimes, full saved index prefixes and new lossless parts,
the same live worker's identity and increasing post-resume chunks. Verify every
unchanged source input. No original execution hook, register/memory write,
reference edit, fault continuation or Windows/native-match claim. The separate
redundant backup remains until this independent audit succeeds.
"""
import argparse,ast,base64,datetime,hashlib,json,os,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def identity(pid):return subprocess.check_output(['ps','-p',str(pid),'-o','lstart=,ppid=,command='],text=True).strip()
def observation(pid,log):
 status=subprocess.check_output(['ps','-p',str(pid),'-o','stat=,etime=,time='],text=True).strip();assert 'T' not in status.split()[0]
 value=ast.literal_eval(log.read_text().splitlines()[-1]);assert 'chunks' in value
 return dict(timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),status=status,progress=value)

def verify(plan_path,migration_path,output):
 assert not output.exists();plan=json.loads(plan_path.read_bytes());m=json.loads(migration_path.read_bytes())
 assert m['planSHA256']==sha(plan_path.read_bytes()) and m['published'] and m['sameWorkerResumed'] and m['status']=='published; backup retained'
 pid=plan['pid'];assert identity(pid)==plan['identity'];source,target,backup=(Path(plan[k]) for k in ('source','target','backup'))
 assert source.is_symlink() and Path(os.readlink(source))==target and source.resolve()==target and backup.is_dir()
 log=ROOT/'build/research/application-catalog-candidate5-resourced.log';before=observation(pid,log)
 old_parts=0;old_bytes=0;new_parts=0;new_bytes=0;indexes=[]
 for item in m['inventory']:
  p=source/item['name'];saved=(backup/item['name']).read_bytes();assert len(saved)==item['bytes'] and sha(saved)==item['sha256']
  raw=p.read_bytes()
  if 'indexBytesBase64' not in item:
   assert raw==saved and p.stat().st_mode==item['mode'] and p.stat().st_mtime_ns==item['mtimeNS'],item['name']
   old_parts+=1;old_bytes+=len(raw);continue
  assert saved==base64.b64decode(item['indexBytesBase64'])
  old,current=json.loads(saved),json.loads(raw)
  assert old['encoding']==current['encoding']=='ordered-json-array-zlib-parts-v1'
  assert old['directory']==current['directory']==source.name and current['count']>=old['count']
  assert current['parts'][:len(old['parts'])]==old['parts']
  first=0
  for i,part in enumerate(current['parts']):
   assert part['first']==first and part['count']>0;first+=part['count']
   if i<len(old['parts']):continue
   packed=(source/part['path']).read_bytes();assert len(packed)==part['packedBytes'] and sha(packed)==part['packedSHA256']
   decoded=zlib.decompress(packed);assert len(decoded)==part['rawBytes'] and sha(decoded)==part['rawSHA256']
   rows=json.loads(decoded);assert isinstance(rows,list) and len(rows)==part['count']
   new_parts+=1;new_bytes+=len(packed)
  assert first==current['count'];indexes.append(dict(name=item['name'],oldCount=old['count'],newCount=current['count'],oldParts=len(old['parts']),newParts=len(current['parts'])))
 assert old_parts+len(indexes)==m['files'] and old_bytes+sum(x['bytes'] for x in m['inventory'] if 'indexBytesBase64' in x)==m['bytes']
 pins=json.loads((ROOT/plan['inputManifest']).read_bytes())['pins']
 for p,h in pins.items():assert sha((ROOT/p).read_bytes())==h,p
 for field in ('producer','inputManifest','planDocument'):assert sha((ROOT/plan[field]).read_bytes())==plan[field+'SHA256']
 end=time.monotonic()+25
 while True:
  assert identity(pid)==plan['identity'];after=observation(pid,log)
  if after['progress']['chunks']>before['progress']['chunks']:break
  assert time.monotonic()<end,'No observed post-resume chunk yet; source is not declared terminal'
  time.sleep(.5)
 assert new_parts>0 and any(x['newCount']>x['oldCount'] for x in indexes)
 d=dict(scope=__doc__,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),planSHA256=sha(plan_path.read_bytes()),migrationSHA256=sha(migration_path.read_bytes()),sameProcessIdentity=True,pid=pid,source=str(source),target=str(target),backup=str(backup),preservedFiles=m['files'],preservedBytes=m['bytes'],immutableParts=old_parts,indexes=indexes,newPartsVerified=new_parts,newPackedBytesVerified=new_bytes,frozenInputsUnchanged=len(pins),firstPostResumeObservation=before,secondPostResumeObservation=after,backupRemovalAuthorizedByChecks=True,wholeCatalogReturned=False,nativeCompared=False,windowsVerified=False)
 output.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps({k:v for k,v in d.items() if k not in ('scope','indexes')},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--plan',type=Path,required=True);p.add_argument('--migration',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();verify(a.plan,a.migration,a.output)
