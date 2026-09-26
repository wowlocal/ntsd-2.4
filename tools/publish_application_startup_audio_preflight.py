"""Publish this finite static preflight; no Native/source/device execution."""
import datetime, hashlib, json, os, plistlib, shutil, stat, subprocess, sys, tarfile, time, traceback
from decimal import Decimal
from pathlib import Path
R = Path('/Users/michael/Developer/ntsd-2.4')
P = Path(__file__).resolve().parent
V = P.parent/'application-mac-front-raster-correction2-20260927'
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
        assert len(native)==28 and len(docs)==16
        assert sum(r['bytes'] for r in native)<8*2**20 and sum(r['bytes'] for r in docs)<8*2**20
        assert ctx['candidateManifest']['sha256']=='eb462e3c418407b6bb467129b03f50e8c069c4adf6e9d019fd52b2f9f4d0bc9d'
        rows=native+docs+ctx['protected']+[ctx['plan'],ctx['candidateManifest']]
        copies=[]
        for ordinal,row in enumerate(rows):
            guard(); source=Path(row['path']); checked(source,row)
            dest=P/'inputs'/f'{ordinal:02d}-{source.name}'
            assert not dest.exists();dest.parent.mkdir(exist_ok=True)
            shutil.copy2(source,dest);checked(dest,row)
            copies.append(dict(source=row['path'],path=str(dest.relative_to(P)),**pin(dest)))
        save('consulted-inputs1.json',copies)
        keyed={Path(row['path']).name:row for row in native+docs}
        anchors={
            'OriginalMenuSoundStartup.swift':['public struct Platform','try observe(.init("deviceCreate"','if let output = platform.createdDevice','if platform.createResult != 0','try observe(.init("cooperativeLevel"','let p = try wavePlatform','let file = try device == 0','guard result.exit == .returned'],
            'OriginalWaveLoader.swift':['public struct OriginalWavePlatform','public struct OriginalWaveLoadResult','var result = try OriginalWaveLoadResult','if p.device == 0','try event(.read, [p.stream, 18','try format.write(UInt16(truncatingIfNeeded: p.destination)','try event(.create','result.exit = .invalidCreateContinuation','if p.lockResults[0] == 0x88780096','try event(.copy','try event(.unlock'],
            'OriginalApplicationStartupPlatform.swift':['Neither copy may perform host IO','case let .wave(event,_)','private var currentWave','var sound:','func wave(_ index:','operations.append(.wave(wave,input))','operations.append(.sound(event,sound))'],
            'OriginalWinMainStartup.swift':['var sound:','func wave(_ index:','candidate.dates = try','candidate.input = try','afterWave:'],
            'OriginalStartupOutput.swift':['try OriginalMusicPlayback.play','let cursor = try requestCursor','self = candidate;globals = state'],
            'OriginalMusicPlayback.swift':['public struct OriginalMusicResponse','public var allocations:','if query.result < 0','let level: Int32','public static func initializeGraph','let converted = try request','let render = try method','if render < 0','Could not create a filter graph'],
            'OriginalInputStartup.swift':['public static func load','let joystickReturn = try','let sounds = try OriginalMenuSoundStartup.load'],
            'OriginalStartupRequestExchange.swift':['case music(','case wave(','case cursor(UInt32)'],
            'OriginalApplicationPreparedStartupPlatform.swift':['public var sound:','public var waves:','copy.state = state','guard var cursor = startupExchange','event.kind == .helper','return try response(.music(event)','try response(.wave(Wave'],
            'OriginalApplicationObservedStartup.swift':['Returned requests must be served outside resume','let cursor = try exchange.snapshot.cursor()','self.exchange.finish(consumed)','public func beginService','public func fail'],
            'OriginalRequestExchange.swift':['public func beginService','public func answer','public func fail','afterCancellation: status == .cancelled'],
            'WaveLoaderReference.swift':['private static func error','public static func compare','raw[$0] != actual.bytes[$0]','let native = try OriginalWaveLoader.load','try OriginalInitialSoundLoading.load'],
            'OriginalMenuSoundStartupTests.swift':['XCTAssertEqual(actual.bytes, bytes','XCTAssertEqual(actual.defined','XCTAssertEqual(whole,112)','func testMissingDeviceAndLateObserverRollback'],
            'OriginalApplicationObservedStartupTests.swift':['let expected = try reference.start','XCTAssertEqual(try D().encoded(value.operations)','XCTAssertEqual(events,6325)','func testLateFailuresRetriesAndOwners'],
            'WINMAIN_STARTUP.md':['23 whole native chains','five original4014e0','Platform implementations must stage'],
            'WAVE_LOADING.md':['cbSize','не освобождает','не проверяются'],
        }
        observations=[]
        for name,patterns in anchors.items():
            row=keyed[name];lines=Path(row['path']).read_text().splitlines();matches=[]
            for pattern in patterns:
                found=[dict(line=i+1,text=s) for i,s in enumerate(lines) if pattern in s]
                assert found,(name,pattern)
                matches.append(dict(anchor=pattern,matches=found))
            observations.append(dict(file=row,anchors=matches))
        save('observations1.json',dict(UTC=now(),classification='static Native source and saved contract inspection; no new D/W/device result',sources=observations,historyResolution=dict(path=str(R/'AGENTS_HISTORY_2026-09-12.md'),lines=[[1543,1575],[3349,3380],[3648,3681]],currentContract=keyed['OriginalApplicationObservedStartup.swift'],scope='No host IO inside Core remains binding; observed service happens after unwind and fulfilled receipts survive rollback; no physical undo claimed'),selectedNext='Request-driven shared DirectSound initialization and WAV device/copy children through whole WinMain; explicit prepared file/backing inputs retained',designIsOriginalRule=False,independentReview=False))
        study=R/'docs/research/APPLICATION_STARTUP_AUDIO_PREFLIGHT.md'
        shutil.copy2(study,P/'study1.md');checked(P/'study1.md',pin(study))
        prior=read(V/'publication1.json'); checked(V/'tests1-queue.job.json',prior['testQueue'])
        qbytes=(V/'tests1-queue.job.json').read_bytes(); (P/'validation-queue1.json').write_bytes(qbytes); q=json.loads(qbytes)
        qo=observe(q['pid']); assert q['pid']==8265 and q['status']=='terminal' and q['exitCode']==0 and not qo['identity']
        checked(V/'tests1-commands.json',q['selection']); commands=read(V/'tests1-commands.json'); checked(V/'selected-methods1.json',commands['selectedMethods'])
        retained=read(V/'selected-methods1.json')['methods']; assert len(retained)==95 and all(x['passed'] for x in q['completed'])
        extra=['OriginalMenuSoundStartupTests/testWholeMenuSoundStartupAgainstOriginal','OriginalMenuSoundStartupTests/testMissingDeviceAndLateObserverRollback','OriginalWaveLoaderTests/testEveryOriginalWaveAndInitialSoundLoadingAgainstEXE','OriginalInputStartupTests/testInputSoundProducerAndOwnJoystickCallbacks','OriginalInputStartupTests/testLateStartupAndCallbackRollback']
        assert not set(extra)&set(retained)
        for method in extra:
            family,name=method.split('/'); source=Path(keyed[family+'.swift']['path']).read_text()
            assert source.count('func '+name+'(')==1
        save('next-comparison1.json',dict(UTC=now(),existingSelection=record(V/'selected-methods1.json'),selectionPinFromFrozenQueue=commands['selectedMethods'],retainedMethods=retained+extra,retainedCount=100,proposedNewGroups=5,proposedTotal=105,newMethodNamesAndLimits='must be frozen in implementation plan before execution',noMethodsExecuted=True))
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
        save('validation-observation1.json',dict(UTC=now(),queue=qo,status=q['status'],completed=95,allRecordedPassed=True,priorFinalizer=record(V/'finalize1.job.json'),priorFrozen=True,source=record(sourcejob),sourcePID59727TerminalAbsent=True,sourceFull137=False,restarted=False))
        for row in rows:checked(Path(row['path']),row)
        save('verification1.json',dict(UTC=now(),consultedNativeFiles=28,consultedStudies=16,rootNativeFilesVerified=1034,priorNativeFilesVerified=2257,candidateFilesVerified=2278,sourceCodePinsVerified=55,protectedPins=len(ctx['protected']),candidateManifestVerified=True,allConsultedInputsUnchanged=True,rootNativeEdited=False,candidateEdited=False,sourceExecuted=False,nativeExecuted=False,deviceExecuted=False,independentReview=False,EXEEnvelopeRecalculated=False,sourceFaultsOrRefusalsResolved=False,priorGoalIncrement=ctx['priorGoalTurn'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free))
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
        publication=dict(schema='ntsd-startup-audio-preflight-v1',UTC=now(),task=str(P),status='static-preflight-complete',head=ctx['head'],candidateManifest=ctx['candidateManifest'],plan=ctx['plan'],study=record(study),consultedInputs=record(P/'consulted-inputs1.json'),observations=record(P/'observations1.json'),verification=record(P/'verification1.json'),validationObservation=record(P/'validation-observation1.json'),metadataArchive=dict(members=len(members),allNamesBodiesModesNanosecondMtimesVerified=True,**record(archive)),publisher=record(Path(__file__)),nextContract='Per-call DirectSound initialization and WAV device/copy through whole WinMain; explicit file/backing inputs, complete retained comparisons, no physical rollback claim',gates=dict(staticAnalysis=True,implementation=False,independentReview=False,actualWindowInputAudio=False,wholeCatalogSource=False,fullMatch=False,fullGame=False),EXEEnvelopeRecalculated=False)
        save('publication1.json',publication)
        close=dict(schema='ntsd-startup-audio-preflight-close-v1',UTC=now(),taskFrozen=True,publication=record(P/'publication1.json'),metadataArchive=publication['metadataArchive'],externalFree=shutil.disk_usage(P).free,internalFree=shutil.disk_usage(R).free,taskBytes=sum(f.stat().st_size for f in P.rglob('*') if f.is_file()),elapsedFromPlanSeconds=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(ctx['UTC'])).total_seconds())
        save('external-close1.json',close)
        for name,suffix in [('publication1.json','.json'),('external-close1.json','-close.json')]:
            dest=R/('docs/evidence/application-startup-audio-preflight'+suffix);assert not dest.exists();dest.write_bytes((P/name).read_bytes())
        job.update(status='terminal',exitCode=0,metadataMembers=len(members))
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'publish1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
