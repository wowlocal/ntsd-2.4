#!/usr/bin/env python3
"""Read accepted NTSD requests and masks to bound physical first-menu raster work.
No source/native/device execution, pixel decoder, renderer or expected mutation.
"""
import collections,ctypes,datetime,hashlib,json,os,plistlib,shutil,subprocess,sys,time,traceback
from pathlib import Path
from archive_catalog53_storage import ROOT,checked,pin
NAME='application-first-menu-raster-contract-20260926'
TASK=Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408')/NAME
BASE=(ROOT/'build/research/application-mac-window-geometry-20260926').resolve()
PLAN=ROOT/'docs/research/APPLICATION_FIRST_MENU_RASTER_CONTRACT_PLAN.md'
read=lambda p:json.loads(p.read_text())
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def record(p):return dict(path=str(p.resolve()),**pin(p))
def save(name,data):
 p=TASK/name;assert not p.exists(),str(p);p.write_text(json.dumps(data,indent=2)+'\n')
def absent(pid):return not subprocess.run(['ps','-p',str(pid),'-o','pid='],capture_output=True,text=True).stdout.strip()
def digest(b):return hashlib.sha256(b).hexdigest()
def main():
 os.chdir(ROOT);began=time.monotonic()
 disk=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
 assert disk['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and disk['FilesystemType']=='apfs' and disk['Writable']
 assert shutil.disk_usage(TASK.parent).free>57*2**30+256*2**20 and shutil.disk_usage(ROOT).free>6*2**30
 pub=read(BASE/'publication1.json');ctx=read(BASE/'context1.json')
 assert pub['status']=='all76-passed' and read(BASE/'external-close1.json')['taskFrozen']
 assert pub['candidateManifest']['sha256']=='880a5a79a117d9ffc0f773056ff58da829d434f081a90f703d2abe4cbb4a88e1'
 for name in ['prepare1.job.json','build1.job.json','tests1-queue.job.json','finalize1.job.json']:
  j=read(BASE/name);assert j['status']=='terminal' and j['exitCode']==0 and absent(j['pid'])
 assert TASK.is_dir() and (ROOT/'build/research'/NAME).resolve()==TASK
 failed=read(TASK/'inspect1.job.json');assert failed['status']=='terminal' and failed['exitCode']==1 and absent(failed['pid'])
 assert not (TASK/'inspect2.job.json').exists()
 for row in read(TASK/'partial-inputs1.json'):checked(TASK/row['path'],row)
 start_free=shutil.disk_usage(TASK).free
 job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
 save('inspect2.job.json',job)
 def guard():
  assert time.monotonic()-began<600
  assert shutil.disk_usage(TASK).free>57*2**30 and shutil.disk_usage(ROOT).free>6*2**30
  assert start_free-shutil.disk_usage(TASK).free<256*2**20
  assert sum(f.stat().st_size for f in TASK.rglob('*') if f.is_file())<384*2**20
 def preserve():
  sets=[(ROOT,Path(ctx['rootManifest']),1034),(Path(ctx['priorCandidate']),Path(ctx['priorManifest']['path']),2257),(BASE/'candidate1',BASE/'candidate1-inputs.json',2272)]
  for base,manifest,count in sets:
   rows=read(manifest);assert len(rows)==count
   actual={str(f.relative_to(base)) for top in ['native/Sources','native/Tests'] for f in (base/top).rglob('*') if f.is_file()}|{'native/Package.swift'}
   assert actual=={r['path'] for r in rows}
   for i,row in enumerate(rows):
    if i%200==0:guard()
    checked(base/row['path'],row)
  for row in ctx['sourceCodePins']:checked(ROOT/row['path'],row)
  source=read(Path(ctx['sourceTask'])/'capture1/source.job.json');assert source['status']=='terminal' and source['exitCode']==0 and absent(source['pid'])
 try:
  preserve();fixture=BASE/'candidate1/native/Tests/NTSDCoreTests/Fixtures'
  names=['startup-graphics-owners.json','startup-surface-colors.json','startup-dib-pixels.json','startup-dib-pixels.bin']
  inputs={name:fixture/name for name in names}
  inputs.update(graphics_reference=ROOT/'build/research/application-graphics-owners-native-20260912/reference1.json',colors_reference=ROOT/'build/research/application-surface-colors-native-20260912/reference3.json',graphics_publication=ROOT/'docs/evidence/application-graphics-owners.json',colors_publication=ROOT/'docs/evidence/application-surface-colors.json',pixels_publication=ROOT/'docs/evidence/application-dib-pixels.json')
  graphics_pub=read(inputs['graphics_publication'])
  checked(inputs['graphics_reference'],graphics_pub['pins']['build/research/application-graphics-owners-native-20260912/reference1.json'])
  g=read(inputs['graphics_reference']);checked(inputs['colors_reference'],g['inputPins']['build/research/application-surface-colors-native-20260912/reference3.json'])
  colors=read(inputs['colors_reference']);gold=read(inputs['startup-dib-pixels.json']);payload=inputs['startup-dib-pixels.bin'].read_bytes()
  assert inputs['startup-graphics-owners.json'].read_bytes()==inputs['graphics_reference'].read_bytes()
  assert read(inputs['startup-surface-colors.json'])['lifetimes']==colors['lifetimes']
  assert len(payload)==gold['payloadBytes'] and digest(payload)==gold['payloadSHA256']
  assert len(g['stages'])==224 and len(g['chains'])==110 and len(g['bitmapLifetimes'])==40 and len(gold['resources'])==36
  golden={};ranges=[]
  for item in gold['resources']:
   w,h=item['width'],item['height'];assert w>0 and h>0 and item['rgbCount']==w*h*3 and item['maskCount']==w*h
   for channel in ['rgb','mask']:
    start,count=item[channel+'Offset'],item[channel+'Count'];assert 0<=start<=len(payload)-count
    data=payload[start:start+count];assert digest(data)==item[channel+'SHA256']
    if channel=='mask':assert set(data)<={0,1} and sum(data)==item['writtenPixels'] and len(data)-sum(data)==item['unknownPixels']
   if item['rawSHA256'] in golden:
    old=golden[item['rawSHA256']];assert (old['width'],old['height'],old['rgbSHA256'],old['maskSHA256'])==(w,h,item['rgbSHA256'],item['maskSHA256'])
   else:golden[item['rawSHA256']]=item
  input_records=[];assert (TASK/'inputs').is_dir()
  clone=ctypes.CDLL(None,use_errno=True).clonefile;clone.argtypes=[ctypes.c_char_p,ctypes.c_char_p,ctypes.c_int];clone.restype=ctypes.c_int
  for name,path in inputs.items():
   dest=TASK/'inputs'/name;guard()
   if dest.exists():checked(dest,pin(path))
   elif path.stat().st_dev==TASK.stat().st_dev:
    if clone(os.fsencode(path),os.fsencode(dest),0):raise OSError(ctypes.get_errno(),str(dest))
   else:shutil.copy2(path,dest)
   row=record(path);checked(dest,row);assert dest.stat().st_ino!=path.stat().st_ino
   input_records.append(dict(name=name,original=row,copy=record(dest)))
  save('input-copies1.json',input_records)
  selected=[PLAN,Path(__file__),ROOT/'AGENTS.md',ROOT/'AGENTS_HISTORY_2026-09-12.md',ROOT/'docs/research/WORKFLOW.md',ROOT/'docs/research/TASK_TEMPLATE.md',ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json',BASE/'publication1.json',BASE/'external-close1.json',BASE/'candidate1-inputs.json',Path(ctx['rootManifest']),Path(ctx['priorManifest']['path']),Path(ctx['sourceTask'])/'capture1/source.job.json']
  selected += [ROOT/'docs/research'/name for name in ['APPLICATION_GRAPHICS_OWNERS.md','APPLICATION_SURFACE_COLORS.md','APPLICATION_DIB_PIXELS.md','BITMAP_DRAWING.md','FRONT_SCREEN_BODY.md','LIB_RUNTIME.md','APPLICATION_MAC_WINDOW_GEOMETRY.md']]
  selected += [BASE/'candidate1/native/Sources'/name for name in ['NTSDCore/OriginalBitmapDrawing.swift','NTSDCore/OriginalFrontScreenPrelude.swift','NTSDCore/OriginalLibSurfaceText.swift','NTSDCore/OriginalApplicationGraphics.swift','NTSDMacPlatform/OriginalMacDisplayBackend.swift']]
  selected += [TASK/'inspect1.py',TASK/'inspect1.job.json',TASK/'partial-inputs1.json',TASK/'failure-diagnosis1.json',TASK/'correction1-plan.md',ROOT/'tools/inspect_application_first_menu_raster.py']
  save('context1.json',dict(producerVersion=2,UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),protected=[record(p) for p in selected],rootManifest=ctx['rootManifest'],priorManifest=ctx['priorManifest'],priorCandidate=ctx['priorCandidate'],baselineManifest=record(BASE/'candidate1-inputs.json'),baseline=str(BASE/'candidate1'),sourceCodePins=ctx['sourceCodePins'],sourceTask=ctx['sourceTask'],startFree=start_free,physicalLimit=256*2**20,logicalLimit=384*2**20,externalReserve=40*2**30,internalReserve=6*2**30,sourceCommitment=17*2**30,originalExecuted=False,nativeExecuted=False,independentReview=False))
  shutil.copy2(PLAN,TASK/'plan1.md');shutil.copy2(Path(__file__),TASK/'inspect2.py')
  life_by_front={x['frontIndex']:x for x in colors['lifetimes']};assert len(life_by_front)==40
  mask_cache={}
  def footprint(raw,w,h,rect):
   left,top,right,bottom=rect;dw,dh=right-left,bottom-top
   shape='inverted' if dw<0 or dh<0 else 'zero' if dw==0 or dh==0 else 'positive'
   value=dict(shape=shape,width=dw,height=dh,inBounds=(0<=left<=right<=w and 0<=top<=bottom<=h),actualDeviceSamplingObserved=False)
   if shape!='positive' or not value['inBounds']:return value
   key=(raw,w,h,tuple(rect))
   if key not in mask_cache:
    if raw is None:known=0;unknown=dw*dh;zero=None
    else:
     item=golden[raw];assert (w,h)==(item['width'],item['height']);m=item['maskOffset'];rgb=item['rgbOffset']
     known=sum(sum(payload[m+y*w+left:m+y*w+right]) for y in range(top,bottom))
     positions=[y*w+x for y in range(top,bottom) for x in range(left,right)]
     assert known==sum(payload[m+i] for i in positions)
     unknown=len(positions)-known
     zero=sum(payload[m+i]==1 and payload[rgb+i*3:rgb+i*3+3]==b'\0\0\0' for i in positions)
    mask_cache[key]=dict(positions=dw*dh,knownPositions=known,unknownPositions=unknown,knownRGBZeroPositions=zero,twoMaskTraversalChecks=True)
   return dict(value,**mask_cache[key])
  unique={};chains=[];case0=None;flags=collections.Counter();kinds=collections.Counter()
  for chain in g['chains']:
   guard();life=g['bitmapLifetimes'][chain['bitmapLifetime']];saved=life_by_front[life['frontIndex']]
   relations={}
   for row in chain['commandRelations']+life['operations']:
    key=(row['stage'],row['eventIndex'])
    if key in relations:assert relations[key]==row
    relations[key]=row
   by_token={s['token']:s for s in saved['surfaces']};assert len(by_token)==len(saved['surfaces'])
   keys={}
   for operation in saved['operations']:
    q=operation['request']
    if q['kind']=='colorKey':keys.setdefault(q['words'][0],[]).append(dict(request=q,response=operation['response']))
   images={x['asset']['raw']:x['asset'] for x in life['images']}
   emitted=[];front=[];blits=[]
   for stage in chain['stages']:
    for command in g['stages'][stage]['commands']:
     identity=(stage,command['eventIndex']);relation=relations[identity]
     assert relation['stage']==stage and relation['eventIndex']==command['eventIndex']
     if identity in unique:assert unique[identity]==command
     else:unique[identity]=command
     emitted.append(dict(stage=stage,**command))
     if command['family']!='front':continue
     event=command['event'];entry=dict(stage=stage,command=command,relation=relation);front.append(entry)
     if event['kind']=='blit':
      b=event['blit'];src=b['source'];dst=b['destination'];assert len(src)==len(dst)==4
      info=dict(stage=stage,eventIndex=command['eventIndex'],source=src,destination=dst,flags=b['flags'],effects=b['effects'],equalExtents=(src[2]-src[0],src[3]-src[1])==(dst[2]-dst[0],dst[3]-dst[1]),sourceSurface=b['sourceSurface'],targetSurface=b['targetSurface'],declaredResult=command['result'],nullSource=b['sourceSurface']==0,colorKeyRequests=keys.get(b['sourceSurface'],[]))
      if b['sourceSurface']:
       surface=by_token[b['sourceSurface']];raw=surface['rawSHA256'];expected=relation['sourceColors']
       assert expected['rawSHA256']==raw and saved['surfaces'][expected['surfaceGeneration']]==surface
       info.update(asset=images.get(raw),sourceWidth=surface['width'],sourceHeight=surface['height'],rawSHA256=raw,footprint=footprint(raw,surface['width'],surface['height'],src))
      blits.append(info);entry['sourceFootprint']=info
   assert len(emitted)==chain['commandCount']
   kinds.update(e['command']['event']['kind'] for e in front);flags.update(str(b['flags']) for b in blits)
   result=dict(rootKind=chain['rootKind'],caseIndex=chain['caseIndex'],stages=chain['stages'],commandCount=len(emitted),frontCommandCount=len(front),frontKinds=dict(collections.Counter(e['command']['event']['kind'] for e in front)),blits=blits)
   chains.append(result)
   if chain['rootKind']=='menu' and chain['caseIndex']==0:
    assert case0 is None;case0=dict(**result,commands=emitted,front=front,text=[e for e in front if e['command']['event']['kind'] in ['getDC','setBackgroundMode','setTextColor','textOut','releaseDC']])
  assert len(unique)==5612 and sum(c['commandCount'] for c in chains)==53265
  assert collections.Counter(q['family'] for q in unique.values())==g['aggregateCounts']['uniqueCommands']
  assert len(chains)==110 and collections.Counter(c['rootKind'] for c in chains)=={'menu':48,'input':50,'loading':12}
  assert sum(c['frontCommandCount'] for c in chains)==sum(v['front'] for v in g['aggregateCounts']['byRoot'].values()) and sum(len(c['blits']) for c in chains)==901
  assert {s for c in chains for s in c['stages']}==set(g['stages'])
  assert case0 is not None and case0['commandCount']==472 and case0['frontCommandCount']==22
  texts=[e['command']['event'] for e in case0['text'] if e['command']['event']['kind']=='textOut']
  assert len(texts)==3 and all(len(e['strings'])==1 and e['arguments'][3]==len(e['strings'][0]) for e in texts)
  assert all(e['command']['event']['arguments'][1]==1 for e in case0['text'] if e['command']['event']['kind']=='setBackgroundMode')
  save('chains1.json',dict(chains=chains,uniqueStageCommandCount=len(unique),composedCommands=53265,countsOverlap=True))
  save('first-menu1.json',case0)
  unqblit=[q for q in unique.values() if q['family']=='front' and q['event']['kind']=='blit'];assert len(unqblit)==491
  first_blits=case0['blits']
  summary=dict(schema='ntsd-first-menu-raster-contract-v1',UTC=now(),profile='Saved command/color-mask readiness, not a rasterizer or actual Windows/device outcome',stages=224,chains=110,uniqueCommands=len(unique),composedCommands=53265,uniqueBlitCommands=491,composedBlitOccurrences=901,composedFrontKinds=dict(kinds),composedBlitFlags=dict(flags),firstMenu=dict(commandCount=472,frontCount=22,frontKinds=case0['frontKinds'],blits=first_blits,textCommands=texts,bitmapCommands=sum(q['family']=='bitmap' for q in case0['commands']),historicalPresentation=[e for e in case0['front'] if e['command']['event']['kind']=='method']),blitFootprintRequests=sum(len(c['blits']) for c in chains),footprintOutcomes=dict(collections.Counter('nullSource' if b['nullSource'] else b['footprint']['shape']+('/inBounds' if b['footprint']['inBounds'] else '/outOfBounds') for c in chains for b in c['blits'])),uniqueMaskFootprints=len(mask_cache),knownSourceDoesNotProveRaster=True,nativeGeometrySeparatePublication=record(ROOT/'docs/evidence/application-mac-window-geometry.json'),dependencies=g['rasterDependencies'],gates=dict(savedInputs=True,joins=True,footprintConsistency=True,nativeRaster=False,windowsObserved=False,independentReview=False,fullMenuFrame=False,fullGame=False),sourceExecuted=False,nativeExecuted=False,pixelDecoderExecuted=False,historicalProducerAuditorExecuted=False,EXEEnvelopeRecalculated=False)
  save('inspection1.json',summary)
  for name in ['chains1.json','first-menu1.json','inspection1.json']:assert (TASK/name).stat().st_size<16*2**20
  preserve()
  for row in read(TASK/'context1.json')['protected']:checked(Path(row['path']),row)
  for row in input_records:checked(Path(row['original']['path']),row['original']);checked(Path(row['copy']['path']),row['copy'])
  save('verification1.json',dict(UTC=now(),rootFilesUnchanged=1034,priorFilesUnchanged=2257,baselineFilesUnchanged=2272,sourceCodePinsUnchanged=55,allInputBytesPreserved=True,sourceStillTerminal=True,sourceRestarted=False,allSavedCommandMembershipsCompared=True,allConsumedPayloadSHAAndExtentsChecked=True,twoFootprintTraversals=True,independentReview=False,sourceExecuted=False,nativeExecuted=False))
  job.update(status='terminal',exitCode=0,stages=224,chains=110,firstMenuFrontCommands=22)
 except BaseException as error:
  job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
 finally:
  job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(TASK/'inspect2.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
