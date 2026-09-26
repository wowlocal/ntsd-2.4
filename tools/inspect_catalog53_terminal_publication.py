#!/usr/bin/env python3
"""Bounded metadata preflight of an immutable terminal game capture; no execution."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import resource
import shutil
import signal
import stat
import subprocess
import time
import traceback
from catalog_trace_reader import Limits, TraceReader, strict_json
from prepare_application_host_candidate import pin, same

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'build/research/first-damage-catalog53-source-20260922'
HOST = ROOT/'build/research/application-host-gameplay-correction1-20260926'
TASK = Path('/Volumes/X5/ntsd-2.4-research/01a0dc49-738f-7972-8fb0-e98fb2f34408/catalog53-terminal-preflight-20260926')
PLAN = ROOT/'docs/research/FIRST_DAMAGE_CATALOG53_TERMINAL_PREFLIGHT_PLAN.md'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read(path):
    return json.loads(path.read_bytes())


def observe(job):
    pid = str(job['pid'])
    ident = subprocess.run(['ps','-p',pid,'-o','pid=,lstart=,command='],capture_output=True,text=True).stdout.strip()
    cwd = subprocess.run(['lsof','-a','-p',pid,'-d','cwd','-Fn'],capture_output=True,text=True).stdout.strip()
    if job['status'] == 'running':
        assert ident.split() == job['processIdentity'].split() and cwd == job['cwdObservation']
    else:
        assert job['status'] == 'terminal' and not ident and not cwd
    return dict(UTC=now(),pid=job['pid'],status=job['status'],identity=ident,cwd=cwd)


def host_observation():
    q = read(HOST/'tests1-queue.job.json')
    result = dict(queue=observe(q),completed=len(q['completed']),allRecordedPass=all(r['passed'] for r in q['completed']))
    if q.get('current'):
        path = HOST/(q['current']['phase']+'.job.json')
        result['current'] = q['current']['phase']
        if path.exists():
            child = read(path)
            # A process may terminate between its running record and observation.
            # Re-read terminal state before interpreting an absent OS observation.
            try:
                result['child'] = observe(child)
            except AssertionError:
                newer = read(path)
                if newer['status'] != 'terminal':
                    result['childObservationRace'] = dict(recordStatus=newer['status'],pid=newer.get('pid'))
                else:
                    result['child'] = observe(newer)
        else:
            result['childPreflight'] = True
    return result


def outline(value, depth=3):
    if isinstance(value, dict):
        if depth <= 0:
            return dict(type='object',keys=list(value))
        return {k:outline(v,depth-1) for k,v in value.items()}
    if isinstance(value, list):
        return dict(type='array',count=len(value),firstSchema=outline(value[0],0) if value else None,
                    lastSchema=outline(value[-1],0) if value else None)
    if isinstance(value,str) and len(value)>1024:
        return dict(type='string',characters=len(value),sha256=hashlib.sha256(value.encode()).hexdigest())
    return value


def main():
    volume = plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
    assert volume['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and volume['FilesystemType']=='apfs'
    external,internal = shutil.disk_usage('/Volumes/X5').free,shutil.disk_usage(ROOT).free
    assert external>(40+17+24)*2**30+16*2**20 and internal>6*2**30
    assert not TASK.exists()
    source_job = read(SOURCE/'capture1/source.job.json')
    source_observation = observe(source_job)
    assert source_job['status']=='terminal' and source_job['exitCode']==0
    launch = read(SOURCE/'launch1.json')
    for item in launch['codePins']:
        same(ROOT/item['path'],item)
    host = host_observation()
    TASK.mkdir()
    alias = ROOT/'build/research'/TASK.name
    assert not alias.exists() and not alias.is_symlink()
    alias.symlink_to(TASK,target_is_directory=True)
    began = time.monotonic()
    job = dict(schema='ntsd-catalog53-terminal-preflight-job-v1',status='running',pid=os.getpid(),startedUTC=now(),
        processIdentity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
        cwdObservation=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip(),
        originalExecuted=False,nativeExecuted=False,independentReview=False)
    def save(name,value):
        raw=(json.dumps(value,indent=2)+'\n').encode()
        assert sum(p.stat().st_size for p in TASK.rglob('*') if p.is_file())+len(raw)<12*2**20
        p=TASK/name
        assert not p.exists()
        p.write_bytes(raw)
    def guard():
        assert time.monotonic()-began<600 and resource.getrusage(resource.RUSAGE_SELF).ru_maxrss<4*2**30
        assert shutil.disk_usage(TASK).free>40*2**30 and shutil.disk_usage(ROOT).free>6*2**30
    def timeout(*_):
        raise TimeoutError('Declared preflight 600-second boundary')
    save('job-start1.json',job)
    signal.signal(signal.SIGALRM,timeout);signal.alarm(600)
    try:
        protected = [PLAN,Path(__file__),ROOT/'tools/catalog_trace_reader.py',
            ROOT/'tools/prepare_application_host_candidate.py',SOURCE/'launch1.json',SOURCE/'capture1/source.job.json',
            ROOT/'docs/research/FIRST_DAMAGE_CATALOG53_SOURCE_PLAN.md',
            ROOT/'docs/research/FIRST_DAMAGE_CATALOG53_CHECKPOINT_PLAN.md',
            ROOT/'tools/verify_catalog53_checkpoint.py',ROOT/'tools/derive_catalog53_checkpoint_audits.py',
            ROOT/'AGENTS_HISTORY_2026-09-12.md',ROOT/'docs/evidence/codex-safety-incidents-2026-09-12.json']
        protected_pins=[pin(p) for p in protected]
        context=read(HOST/'context1.json')
        manifests=[(ROOT,Path(context['rootManifest'])),(HOST/'candidate1',HOST/'candidate1-inputs.json')]
        for parent,manifest in manifests:
            for item in read(manifest):
                same(parent/item['path'],item)
        source=SOURCE/'capture1/capture1.json'
        source_pin=pin(source)
        assert source_pin['bytes']==249780969 and source_pin['sha256']=='010c6cfec0280e501954cf2c678a08de620022d9eceedf73a6b94b90071c6232'
        assert source_pin['sha256']==source_job['result']['publication']['sha256']
        save('context1.json',dict(UTC=now(),head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
            protected=protected_pins,source=source_pin,sourceObservation=source_observation,hostObservation=host,
            sourceCodePins=launch['codePins'],nativeManifests=[pin(m) for _,m in manifests],
            initialExternalFree=external,initialInternalFree=internal,outputLimitBytes=16*2**20))
        before=source.stat()
        raw=source.read_bytes()
        assert len(raw)==source_pin['bytes'] and hashlib.sha256(raw).hexdigest()==source_pin['sha256']
        data=strict_json(raw);del raw;guard()
        groups=[];references={};duplicates=[];findings=[]
        limits=Limits(200000,2**63-1,2**63-1)
        def walk(value,path):
            if isinstance(value,dict):
                if isinstance(value.get('encoding'),str) and 'ordered-json-array-zlib-parts' in value['encoding']:
                    record=dict(path=path,encoding=value['encoding'],declaredCount=value.get('count'),parts=len(value.get('parts',[])),
                        rawBytes=sum(p.get('rawBytes',0) for p in value.get('parts',[])),
                        packedBytes=sum(p.get('packedBytes',0) for p in value.get('parts',[])),metadataValid=False,
                        bodyHashesVerified=False,decoded=False)
                    try:
                        TraceReader(source.parent/value['directory'],value,limits)
                        record['metadataValid']=True
                    except Exception as error:
                        record['metadataError']=repr(error);findings.append(dict(path=path,error=repr(error)))
                    for part in value.get('parts',[]):
                        key=value['directory']+'/'+part['path']
                        if key in references:
                            duplicates.append(dict(path=key,group=path,sameMetadata=references[key]==part))
                        else:
                            references[key]=part
                    groups.append(record)
                    return
                for key,child in value.items():
                    if key not in ('blobs','assets'):
                        walk(child,path+'.'+key)
            elif isinstance(value,list):
                for i,child in enumerate(value):
                    if isinstance(child,(dict,list)):
                        walk(child,path+f'[{i}]')
        walk(data,'$');guard()
        assert sum(g['parts'] for g in groups)<=200000
        missing=[];mismatched=[];referenced_bytes=0
        for i,(name,part) in enumerate(references.items()):
            path=source.parent/name
            if not path.exists():missing.append(name);continue
            info=path.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_size!=part['packedBytes']:
                mismatched.append(dict(path=name,actualBytes=info.st_size,expectedBytes=part['packedBytes'],mode=info.st_mode))
            referenced_bytes+=info.st_size
            if i%5000==0:guard()
        actual={};unreferenced=[]
        for i,path in enumerate(sorted((source.parent/'capture1.traces').iterdir())):
            assert i<200000
            info=path.lstat();name=str(path.relative_to(source.parent))
            assert stat.S_ISREG(info.st_mode),name
            actual[name]=info.st_size
            if name not in references:unreferenced.append(dict(path=name,bytes=info.st_size))
            if i%5000==0:guard()
        blob_values=data.get('blobs',{})
        blobs=dict(count=len(blob_values),declaredRawBytes=sum(v.get('count',0) for v in blob_values.values()),
            base64Characters=sum(len(v.get('deflate','')) for v in blob_values.values()),
            declarationKeySets=sorted({','.join(sorted(v)) for v in blob_values.values()}),decoded=False,hashesVerified=False)
        result=dict(UTC=now(),source=source_pin,sourceJobOutcome=source_job['result'],sourceBoundary=source_job['publicationBudget'],
            topLevelKeys=list(data),moduleHashes={k:data.get(k) for k in ['exeSHA256','libSHA256','crtSHA256']},
            caseOutline=outline(data.get('case'),3),topLevelOutline={k:outline(v,1) for k,v in data.items() if k not in ('case','blobs','assets')},
            traces=groups,totalPartReferences=sum(g['parts'] for g in groups),uniqueParts=len(references),duplicateReferences=duplicates,
            declaredTraceRawBytes=sum(g['rawBytes'] for g in groups),declaredTracePackedBytes=sum(g['packedBytes'] for g in groups),
            blobs=blobs,files=dict(regularFiles=len(actual),bytes=sum(actual.values()),referencedBytes=referenced_bytes,
                inventorySHA256=hashlib.sha256(json.dumps(actual,sort_keys=True,separators=(',',':')).encode()).hexdigest(),
                missing=missing,sizeOrTypeMismatches=mismatched,unreferenced=unreferenced,bodyHashesVerified=False),findings=findings,
            memoryProvenanceAudited=False,nativeCompared=False,independentReview=False,sourceReturned=False)
        after=source.stat()
        assert (before.st_ino,before.st_size,before.st_mtime_ns)==(after.st_ino,after.st_size,after.st_mtime_ns)
        for item in protected_pins:same(Path(item['path']),item)
        for item in launch['codePins']:same(ROOT/item['path'],item)
        for parent,manifest in manifests:
            for item in read(manifest):same(parent/item['path'],item)
        save('inventory1.json',result);save('host-observation-after1.json',host_observation());guard()
        job.update(status='terminal',exitCode=0,metadataInventoried=True,sourceBytesVerified=True)
        print(json.dumps({k:result[k] for k in ['topLevelKeys','totalPartReferences','uniqueParts','declaredTraceRawBytes','declaredTracePackedBytes','blobs','findings']}),flush=True)
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc())
        raise
    finally:
        signal.alarm(0)
        job.update(endedUTC=now(),seconds=time.monotonic()-began,peakResidentBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
        save('job-terminal1.json',job)
        print(json.dumps(job),flush=True)


if __name__=='__main__':
    main()
