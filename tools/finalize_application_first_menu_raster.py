#!/usr/bin/env python3
"""Close the data-only first-menu raster contract using existing pin/APFS/PAX checks."""
import ctypes,datetime,hashlib,json,os,plistlib,shutil,stat,subprocess,sys,tarfile,time,traceback
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
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def main():
 assert P.name=='application-first-menu-raster-contract-20260926'
 ctx=read(P/'context1.json');start=time.monotonic()
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip());save('finalize1.job.json',job)
 def guard():
  assert time.monotonic()-start<600 and shutil.disk_usage(P).free>57*2**30 and shutil.disk_usage(R).free>6*2**30
  assert ctx['startFree']-shutil.disk_usage(P).free<ctx['physicalLimit']
  assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file() and not f.is_symlink())<ctx['logicalLimit']
 try:
  d=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
  assert d['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and d['FilesystemType']=='apfs' and d['Writable']
  guard();checked(Path(__file__),read(P/'finalizer-inputs1.json')['producer'])
  for name,code in [('inspect1.job.json',1),('inspect2.job.json',0)]:
   j=read(P/name);assert j['status']=='terminal' and j['exitCode']==code and absent(j['pid'])
  assert 'OSError(18' in read(P/'inspect1.job.json')['error']
  summary=read(P/'inspection1.json');assert summary['uniqueCommands']==5612 and summary['composedCommands']==53265 and summary['firstMenu']['frontCount']==22
  assert summary['footprintOutcomes']=={'positive/inBounds':883,'nullSource':18}
  assert sum(b['footprint']['unknownPositions'] for b in summary['firstMenu']['blits'])==101
  assert not summary['sourceExecuted'] and not summary['nativeExecuted'] and not summary['gates']['fullMenuFrame']
  for row in ctx['protected']:checked(Path(row['path']),row)
  for row in ctx['sourceCodePins']:checked(R/row['path'],row)
  for base,manifest,count in [(R,Path(ctx['rootManifest']),1034),(Path(ctx['priorCandidate']),Path(ctx['priorManifest']['path']),2257),(Path(ctx['baseline']),Path(ctx['baselineManifest']['path']),2272)]:
   rows=read(manifest);assert len(rows)==count
   names={str(f.relative_to(base)) for top in ['native/Sources','native/Tests'] for f in (base/top).rglob('*') if f.is_file()}|{'native/Package.swift'}
   assert names=={r['path'] for r in rows}
   for i,row in enumerate(rows):
    if i%200==0:guard()
    checked(base/row['path'],row)
  source=read(Path(ctx['sourceTask'])/'capture1/source.job.json');assert source['status']=='terminal' and source['exitCode']==0 and absent(source['pid'])
  # Same regular APFS clone preservation used by the Native candidate finalizers.
  archive=P/'input-archive1';assert not archive.exists();archive.mkdir();copies=read(P/'input-copies1.json');assert len(copies)==9
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  members=[]
  for row in copies:
   guard();src=Path(row['copy']['path']);checked(src,row['copy']);checked(Path(row['original']['path']),row['original']);dest=archive/row['name']
   if clone(os.fsencode(src),os.fsencode(dest),0):raise OSError(ctypes.get_errno(),str(dest))
   checked(dest,row['copy']);assert dest.stat().st_ino!=src.stat().st_ino
   members.append(dict(path=row['name'],**pin(dest)))
  assert {x.name for x in archive.iterdir()}=={x['path'] for x in members} and all(x.is_file() and not x.is_symlink() for x in archive.iterdir())
  save('input-archive1.json',dict(files=members,bytes=sum(r['bytes'] for r in members),bodyModeNsMtimeMembershipVerified=True,distinctInodes=True))
  # Immutable top-level metadata only; input bodies are in the regular archive.
  files=sorted(f for f in P.iterdir() if f.is_file() and f.name not in ['finalize1.job.json','finalize1.log'] and f.suffix!='.tar')
  assert sum(f.stat().st_size for f in files)<16*2**20
  rows=[dict(path=f.name,**pin(f)) for f in files];save('metadata1-inputs.json',rows)
  tarpath=P/'metadata1.tar';assert not tarpath.exists()
  with tarfile.open(tarpath,'w',format=tarfile.PAX_FORMAT) as tf:
   for row in rows:
    guard();f=P/row['path'];info=tf.gettarinfo(str(f),arcname=f.name);assert info.isfile();ns=row['mtime_ns']
    info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
    with f.open('rb') as body:tf.addfile(info,body)
  assert tarpath.stat().st_size<16*2**20
  with tarfile.open(tarpath) as tf:
   assert len(tf.getmembers())==len(rows) and {x.name for x in tf.getmembers()}=={x['path'] for x in rows}
   for row in rows:
    m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
    assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
  for row in members:checked(archive/row['path'],row)
  guard()
  pub=dict(summary,schema='ntsd-first-menu-raster-contract-publication-v1',UTC=now(),status='finite-saved-raster-contract-verified',task=str(P),baseHead=ctx['head'],inspection=record(P/'inspection1.json'),fullFirstMenu=record(P/'first-menu1.json'),chains=record(P/'chains1.json'),verification=record(P/'verification1.json'),context=record(P/'context1.json'),producer=record(P/'inspect2.py'),preservedFailure=record(P/'failure-diagnosis1.json'),inputArchive=dict(path=str(archive),files=len(members),bytes=sum(r['bytes'] for r in members),manifest=record(P/'input-archive1.json')),metadataArchive=dict(members=len(rows),**record(tarpath)),rootNativeUnchanged=1034,priorNativeUnchanged=2257,baselineNativeUnchanged=2272,sourceCodePinsUnchanged=55)
  save('publication1.json',pub)
  close=dict(UTC=now(),taskFrozen=True,task=str(P),publication=record(P/'publication1.json'),inputArchive=pub['inputArchive'],metadataArchive=pub['metadataArchive'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,observedFreeDecrease=ctx['startFree']-shutil.disk_usage(P).free,physicalLimit=ctx['physicalLimit'],originalExternalReserve=40*2**30,originalInternalReserve=6*2**30,sourceCommitment=17*2**30)
  save('external-close1.json',close)
  for src,suffix in [('publication1.json','.json'),('external-close1.json','-close.json')]:
   dest=R/('docs/evidence/application-first-menu-raster-contract'+suffix);assert not dest.exists();dest.write_bytes((P/src).read_bytes())
  job.update(status='terminal',exitCode=0,inputFiles=len(members),metadataMembers=len(rows),sourceExecuted=False,nativeExecuted=False)
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-start);(P/'finalize1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
