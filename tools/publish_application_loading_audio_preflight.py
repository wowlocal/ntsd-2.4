"""Publish this finite static preflight; no Native/source/device execution."""
import datetime, hashlib, json, os, plistlib, shutil, stat, subprocess, sys, tarfile, time, traceback
from decimal import Decimal
from pathlib import Path
R = Path('/Users/michael/Developer/ntsd-2.4')
P = Path(__file__).resolve().parent
V = P.parent/'application-mac-audio-correction2-20260927'
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
    ctx=read(P/'context1.json'); assert read(P/'input-additions1.json')==dict(additionalNativeInputs=[],documents=[])
    began=time.monotonic()
    job=dict(status='running', startedUTC=now(), command=[sys.executable,str(Path(__file__).resolve())], **observe(os.getpid()))
    save('publish1.job.json',job)
    def guard():
        assert time.monotonic()-began<1800
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
        native=ctx['nativeInputs']; docs=ctx['documents']
        assert len(native)==39 and len(docs)==15 and len(ctx['SDKInputs'])==0
        assert sum(r['bytes'] for r in native)<12*2**20 and sum(r['bytes'] for r in docs)<12*2**20
        assert ctx['candidateManifest']['sha256']=='80ced805b198ebdc49068ca1c7e6068ccd7da41828d5c9053be0df04f16ce981'
        rows=native+docs+ctx['SDKInputs']+ctx['protected']+[ctx['plan'],ctx['candidateManifest']]+read(P/'publisher-inputs1.json')['additionalPins']
        copies=[]
        for ordinal,row in enumerate(rows):
            guard(); source=Path(row['path']); checked(source,row)
            dest=P/'inputs'/f'{ordinal:02d}-{source.name}'
            assert not dest.exists();dest.parent.mkdir(exist_ok=True)
            shutil.copy2(source,dest);checked(dest,row)
            copies.append(dict(source=row['path'],path=str(dest.relative_to(P)),**pin(dest)))
        save('consulted-inputs1.json',copies)
        audit=read(P/'observations1.json'); assert audit['patterns']==54
        inspector=read(P/'inspect1.job.json'); assert inspector['status']=='terminal' and inspector['exitCode']==0 and not observe(inspector['pid'])['identity']
        pins=read(P/'inspector-inputs1.json')
        for key in ['inspector','rootProducer']:checked(Path(pins[key]['path']),pins[key])
        witness=read(P/'identity-witness1.json'); assert witness['distinctRegionTokens'] and witness['incorrectAddressInterpretationOverlaps'] and witness['intersection']['bytes']==23566
        assert len(witness['controls'])==4 and all(c['observedArithmetic']==c['expected'] for c in witness['controls'])
        inventory=read(Path(witness['inventory']['path'])); checked(Path(witness['inventory']['path']),witness['inventory'])
        assert inventory['files']==409
        study=R/'docs/research/APPLICATION_LOADING_AUDIO_PREFLIGHT.md'
        shutil.copy2(study,P/'study1.md');checked(P/'study1.md',pin(study))
        prior=read(V/'publication1.json');checked(V/'tests1-queue.job.json',prior['testQueue'])
        qbytes=(V/'tests1-queue.job.json').read_bytes();(P/'validation-queue1.json').write_bytes(qbytes);q=json.loads(qbytes)
        qo=observe(q['pid']);assert q['pid']==20414 and q['status']=='terminal' and q['exitCode']==0 and not qo['identity']
        checked(V/'tests1-commands.json',q['selection']);commands=read(V/'tests1-commands.json');checked(V/'selected-methods1.json',commands['selectedMethods'])
        retained=read(V/'selected-methods1.json')['methods'];assert len(retained)==120 and all(x['passed'] for x in q['completed'])
        proposed=read(P/'next-comparison1.json');assert proposed['retainedMethods']==retained and proposed['additionalCount']==25 and proposed['existingProposedTotal']==145 and len(proposed['newGroups'])==6
        assert len(set(proposed['additionalExistingMethods']))==25 and not set(retained)&set(proposed['additionalExistingMethods'])
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
        save('validation-observation1.json',dict(UTC=now(),queue=qo,status=q['status'],completed=120,allRecordedPassed=True,priorFinalizer=record(V/'finalize1.job.json'),priorFrozen=True,source=record(sourcejob),sourcePID59727TerminalAbsent=True,sourceFull137=False,restarted=False))
        for row in rows:checked(Path(row['path']),row)
        save('verification1.json',dict(UTC=now(),consultedNativeFiles=39,consultedStudies=15,consultedSDKHeaders=0,savedWAVInventoryFiles=409,originalAssetBodiesReread=False,identityArithmeticWitnesses=1,arithmeticControls=4,anchorPatterns=54,rootNativeFilesVerified=1034,priorNativeFilesVerified=2257,candidateFilesVerified=2284,sourceCodePinsVerified=55,protectedPins=len(ctx['protected']),candidateManifestVerified=True,allConsultedInputsUnchanged=True,rootNativeEdited=False,candidateEdited=False,sourceExecuted=False,nativeExecuted=False,deviceExecuted=False,independentReview=False,EXEEnvelopeRecalculated=False,sourceFaultsOrRefusalsResolved=False,priorGoalIncrement=ctx['priorGoalTurn'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free))
        files=sorted(f for f in P.rglob('*') if f.is_file() and f.name not in ['publish1.job.json','publish1.log'] and f.suffix!='.tar')
        members=[dict(path=str(f.relative_to(P)),**pin(f)) for f in files]
        save('metadata1-inputs.json',members)
        archive=P/'metadata1.tar';assert not archive.exists()
        with tarfile.open(archive,'w',format=tarfile.PAX_FORMAT) as tf:
            for f in files:
                guard();info=tf.gettarinfo(str(f),arcname=str(f.relative_to(P)));ns=f.stat().st_mtime_ns
                assert info.isfile();info.mtime=ns//10**9;info.pax_headers['mtime']=f'{ns//10**9}.{ns%10**9:09d}'
                with f.open('rb') as body:tf.addfile(info,body)
        assert archive.stat().st_size<32*2**20
        with tarfile.open(archive) as tf:
            assert len(tf.getmembers())==len(members) and {m.name for m in tf.getmembers()}=={r['path'] for r in members}
            for row in members:
                m=tf.getmember(row['path']);assert m.isfile() and m.size==row['bytes'] and m.mode==row['mode'] and int(Decimal(m.pax_headers['mtime'])*10**9)==row['mtime_ns']
                assert hashlib.sha256(tf.extractfile(m).read()).hexdigest()==row['sha256'];checked(P/row['path'],row)
        guard()
        publication=dict(schema='ntsd-loading-audio-preflight-v1',UTC=now(),task=str(P),status='static-ownership-preflight-complete',head=ctx['head'],candidateManifest=ctx['candidateManifest'],plan=ctx['plan'],study=record(study),consultedInputs=record(P/'consulted-inputs1.json'),observations=record(P/'observations1.json'),identityWitness=record(P/'identity-witness1.json'),nextComparison=record(P/'next-comparison1.json'),verification=record(P/'verification1.json'),validationObservation=record(P/'validation-observation1.json'),metadataArchive=dict(members=len(members),allNamesBodiesModesNanosecondMtimesVerified=True,**record(archive)),publisher=record(Path(__file__)),nextContract='Common/registered per-call WAV input and explicit addressed-versus-opaque ownership through startup/common/catalog/pool/loaded-menu; ordered volume and retained service journal;145 existing methods plus6 finite comparison groups proposed',gates=dict(staticAnalysis=True,ownershipObstructionEstablished=True,implementation=False,nativeComparison=False,independentReview=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullMatch=False,fullGame=False),EXEEnvelopeRecalculated=False,originalExecuted=False,nativeExecuted=False)
        save('publication1.json',publication)
        close=dict(schema='ntsd-loading-audio-preflight-close-v1',UTC=now(),taskFrozen=True,publication=record(P/'publication1.json'),metadataArchive=publication['metadataArchive'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,taskBytes=sum(f.stat().st_size for f in P.rglob('*') if f.is_file()),elapsedFromPlanSeconds=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(ctx['UTC'])).total_seconds())
        save('external-close1.json',close)
        for name,suffix in [('publication1.json','.json'),('external-close1.json','-close.json'),('observations1.json','-observations.json'),('identity-witness1.json','-identity-witness.json'),('next-comparison1.json','-next-comparison.json')]:
            dest=R/('docs/evidence/application-loading-audio-preflight'+suffix);assert not dest.exists();dest.write_bytes((P/name).read_bytes())
        job.update(status='terminal',exitCode=0,metadataMembers=len(members))
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'publish1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
