"""Publish this finite static preflight; no Native/source/device execution."""
import datetime, hashlib, json, os, plistlib, shutil, stat, subprocess, sys, tarfile, time, traceback
from decimal import Decimal
from pathlib import Path
R = Path('/Users/michael/Developer/ntsd-2.4')
P = Path(__file__).resolve().parent
V = P.parent/'application-startup-audio-correction1-20260927'
sys.path.insert(0, str(R/'tools'))
from archive_catalog53_storage import pin, checked
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
read = lambda p: json.loads(p.read_text())
def save(name, value):
    p = P/name
    assert not p.exists(), str(p)
    p.write_text(json.dumps(value, indent=2)+'\n')
def record(p): return dict(path=str(p.resolve()), **pin(p))
def observe(pid):
    return dict(pid=pid, identity=subprocess.run(['ps','-p',str(pid),'-o','pid=,lstart=,command='], capture_output=True, text=True).stdout.strip(), cwd=subprocess.run(['lsof','-a','-p',str(pid),'-d','cwd','-Fn'], capture_output=True, text=True).stdout.strip())

def main():
    ctx=read(P/'context1.json'); additions=read(P/'input-additions2.json'); assert read(P/'input-additions1.json')==dict(additionalNativeInputs=[],documents=[])
    began=time.monotonic()
    job=dict(status='running', startedUTC=now(), command=[sys.executable,str(Path(__file__).resolve())], **observe(os.getpid()))
    save('publish1.job.json',job)
    def guard():
        elapsed=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(ctx['UTC'])).total_seconds()
        assert elapsed<ctx['elapsedLimitSeconds']
        free=shutil.disk_usage(P).free
        assert free>ctx['externalReserve'] and shutil.disk_usage(R).free>ctx['internalReserve']
        assert ctx['initialExternalFree']-free<ctx['taskBytesLimit']
        assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file())<56*2**20
    try:
        disk=plistlib.loads(subprocess.check_output(['diskutil','info','-plist','/Volumes/X5']))
        assert disk['MountPoint']=='/Volumes/X5' and disk['VolumeUUID']=='3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548' and disk['FilesystemType']=='apfs' and disk['Writable']
        guard(); checked(Path(__file__),read(P/'publisher-inputs1.json')['publisher'])
        native=ctx['nativeInputs']+additions['additionalNativeInputs']; docs=ctx['documents']+additions['documents']
        assert len(native)==38 and len(docs)==17 and len(ctx['SDKInputs'])==5
        assert sum(r['bytes'] for r in native)<8*2**20 and sum(r['bytes'] for r in docs)<8*2**20
        assert ctx['candidateManifest']['sha256']=='7b609b8c4f61f1ec6d3903c84239478f84dba89f9820d2e3182fac262ef6a4ea'
        rows=native+docs+ctx['SDKInputs']+ctx['protected']+[ctx['plan'],ctx['candidateManifest']]+read(P/'publisher-inputs1.json')['additionalPins']
        copies=[]
        for ordinal,row in enumerate(rows):
            guard(); source=Path(row['path']); checked(source,row)
            dest=P/'inputs'/f'{ordinal:02d}-{source.name}'
            assert not dest.exists();dest.parent.mkdir(exist_ok=True)
            shutil.copy2(source,dest);checked(dest,row)
            copies.append(dict(source=row['path'],path=str(dest.relative_to(P)),**pin(dest)))
        save('consulted-inputs1.json',copies)
        keyed={Path(row['path']).name:row for row in native+docs}
        audit=read(P/'observations2.json');assert audit['patterns']==79
        for n,exitcode in [('inspect1.job.json',1),('inspect2.job.json',0)]:
            jobrow=read(P/n);assert jobrow['status']=='terminal' and jobrow['exitCode']==exitcode and not observe(jobrow['pid'])['identity']
        for version in [1,2]:
            pins=read(P/f'inspector-inputs{version}.json')
            for key in ['inspector','rootProducer']:checked(Path(pins[key]['path']),pins[key])
        inventory=read(P/'wav-input-inventory2.json')
        assert inventory['files']==409 and inventory['bytes']==15412062 and len(inventory['formats'])==23
        assert inventory['allFirstChunksFormat'] and inventory['allBlockAligned'] and inventory['allPCMArithmeticConsistent']
        for row in inventory['rows']:checked(Path(row['file']['path']),row['file'])
        api=read(P/'api-notes1.json');assert len(api['sources'])==8
        study=R/'docs/research/APPLICATION_MAC_AUDIO_PREFLIGHT.md'
        shutil.copy2(study,P/'study1.md');checked(P/'study1.md',pin(study))
        prior=read(V/'publication1.json'); checked(V/'tests1-queue.job.json',prior['testQueue'])
        qbytes=(V/'tests1-queue.job.json').read_bytes(); (P/'validation-queue1.json').write_bytes(qbytes); q=json.loads(qbytes)
        qo=observe(q['pid']); assert q['pid']==57131 and q['status']=='terminal' and q['exitCode']==0 and not qo['identity']
        checked(V/'tests1-commands.json',q['selection']); commands=read(V/'tests1-commands.json'); checked(V/'selected-methods1.json',commands['selectedMethods'])
        retained=read(V/'selected-methods1.json')['methods']; assert len(retained)==105 and all(x['passed'] for x in q['completed'])
        extra=[]
        import re
        for family in ['OriginalQueuedSoundTests','OriginalCatalogSoundsTests','OriginalMusicPlaybackTests','OriginalGraphEventsTests']:
            text=Path(keyed[family+'.swift']['path']).read_text()
            extra += [family+'/'+name for name in re.findall(r'func (test\w+)\(',text)]
        assert len(extra)==10 and not set(extra)&set(retained)
        proposed=['testOriginalWAVsThroughOwnedBuffers','testWholeStartupWithOwnedMenuBuffers','testLateRetryAndResourceLifetimes','testUnsupportedInputsAndServiceProtocol','testOfflinePCMTransportForEveryOriginalFormat']
        save('next-comparison1.json',dict(UTC=now(),existingSelection=record(V/'selected-methods1.json'),selectionPinFromFrozenQueue=commands['selectedMethods'],retainedMethods=retained+extra,retainedCount=115,proposedNewGroups=5,proposedTotal=120,proposedNewMethods=['OriginalMacAudioBackendTests/'+name for name in proposed],newMethodNamesAndLimits='freeze actual implementation plan/selection/limits before execution',noMethodsExecuted=True,independentReview=False))
        for group in ctx['preservation']:
            manifest=Path(group['manifest']['path']); checked(manifest,group['manifest']); base=Path(group['root']); entries=read(manifest)
            actual={str(f.relative_to(base)) for top in ['native/Sources','native/Tests'] for f in (base/top).rglob('*') if f.is_file()}|{'native/Package.swift'}
            assert len(entries)==group['files'] and actual=={r['path'] for r in entries}
            for i,row in enumerate(entries):
                if i%200==0:guard()
                checked(base/row['path'],row)
        for row in ctx['sourceCodePins']:checked(R/row['path'],row)
        sourcejob=Path(ctx['sourceTask'])/'capture1/source.job.json'; sj=read(sourcejob); assert sj['pid']==59727 and sj['status']=='terminal' and sj['exitCode']==0 and not observe(sj['pid'])['identity']
        prep=read(P/'prepare1.job.json'); assert prep['status']=='terminal' and prep['exitCode']==0 and not observe(prep['pid'])['identity']
        final=read(V/'finalize1.job.json'); assert final['status']=='terminal' and final['exitCode']==0 and not observe(final['pid'])['identity']
        save('validation-observation1.json',dict(UTC=now(),queue=qo,status=q['status'],completed=105,allRecordedPassed=True,priorFinalizer=record(V/'finalize1.job.json'),priorFrozen=True,source=record(sourcejob),sourcePID59727TerminalAbsent=True,sourceFull137=False,restarted=False))
        for row in rows:checked(Path(row['path']),row)
        save('verification1.json',dict(UTC=now(),consultedNativeFiles=38,consultedStudies=17,consultedSDKHeaders=5,originalWAVsVerified=409,originalWAVBytes=15412062,originalFormats=23,anchorPatterns=79,rootNativeFilesVerified=1034,priorNativeFilesVerified=2257,candidateFilesVerified=2281,sourceCodePinsVerified=55,protectedPins=len(ctx['protected']),candidateManifestVerified=True,allConsultedInputsUnchanged=True,rootNativeEdited=False,candidateEdited=False,sourceExecuted=False,nativeExecuted=False,deviceExecuted=False,independentReview=False,EXEEnvelopeRecalculated=False,sourceFaultsOrRefusalsResolved=False,priorGoalIncrement=ctx['priorGoalTurn'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free))
        files=sorted(f for f in P.rglob('*') if f.is_file() and f.name not in ['publish1.job.json','publish1.log'] and f.suffix!='.tar')
        members=[dict(path=str(f.relative_to(P)),**pin(f)) for f in files]
        save('metadata1-inputs.json',members)
        archive=P/'metadata1.tar';assert not archive.exists()
        with tarfile.open(archive,'w',format=tarfile.PAX_FORMAT) as tf:
            for f in files:
                guard();info=tf.gettarinfo(str(f),arcname=str(f.relative_to(P)));ns=f.stat().st_mtime_ns
                assert info.isfile();info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
                with f.open('rb') as body:tf.addfile(info,body)
        assert archive.stat().st_size<16*2**20
        with tarfile.open(archive) as tf:
            assert len(tf.getmembers())==len(members) and {m.name for m in tf.getmembers()}=={r['path'] for r in members}
            for row in members:
                m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
                assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
        guard()
        publication=dict(schema='ntsd-mac-audio-preflight-v1',UTC=now(),task=str(P),status='static-preflight-complete',head=ctx['head'],candidateManifest=ctx['candidateManifest'],plan=ctx['plan'],study=record(study),consultedInputs=record(P/'consulted-inputs1.json'),observations=record(P/'observations2.json'),originalInputInventory=record(P/'wav-input-inventory2.json'),API=record(P/'api-notes1.json'),firstAuditFailure=record(P/'inspection-failure1.json'),nextComparison=record(P/'next-comparison1.json'),verification=record(P/'verification1.json'),validationObservation=record(P/'validation-observation1.json'),metadataArchive=dict(members=len(members),allNamesBodiesModesNanosecondMtimesVerified=True,**record(archive)),publisher=record(Path(__file__)),nextContract='Own Native PCM backend and retained startup service;409 original input buffers, whole own WinMain,115 retained methods plus5 new groups including bounded offline transport; no physical playback/Windows claim',gates=dict(staticAnalysis=True,originalInputInventory=True,implementation=False,independentReview=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullMatch=False,fullGame=False),EXEEnvelopeRecalculated=False)
        save('publication1.json',publication)
        close=dict(schema='ntsd-mac-audio-preflight-close-v1',UTC=now(),taskFrozen=True,publication=record(P/'publication1.json'),metadataArchive=publication['metadataArchive'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,taskBytes=sum(f.stat().st_size for f in P.rglob('*') if f.is_file()),elapsedFromPlanSeconds=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(ctx['UTC'])).total_seconds())
        save('external-close1.json',close)
        for name,suffix in [('publication1.json','.json'),('external-close1.json','-close.json'),('observations2.json','-observations.json'),('wav-input-inventory2.json','-wav-inputs.json'),('next-comparison1.json','-next-comparison.json'),('inspection-failure1.json','-failure.json'),('api-notes1.json','-api.json')]:
            dest=R/('docs/evidence/application-mac-audio-preflight'+suffix);assert not dest.exists();dest.write_bytes((P/name).read_bytes())
        job.update(status='terminal',exitCode=0,metadataMembers=len(members))
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'publish1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
