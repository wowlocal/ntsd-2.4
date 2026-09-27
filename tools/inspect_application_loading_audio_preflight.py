"""Inspect the saved loading/audio handoffs; no source, Native or device run."""
import datetime, json, os, re, shutil, subprocess, sys, time, traceback
from pathlib import Path
R = Path('/Users/michael/Developer/ntsd-2.4')
P = Path(__file__).resolve().parent
sys.path.insert(0, str(R/'tools'))
from archive_catalog53_storage import checked, pin
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
read = lambda p: json.loads(p.read_text())
def record(p): return dict(path=str(p.resolve()), **pin(p))
def save(name, value):
    p = P/name
    assert not p.exists(), str(p)
    p.write_text(json.dumps(value, indent=2)+'\n')

def main():
    began = time.monotonic(); ctx = read(P/'context1.json')
    checked(Path(__file__), read(P/'inspector-inputs1.json')['inspector'])
    job = dict(status='running', pid=os.getpid(), startedUTC=now(),
        command=[sys.executable, str(Path(__file__).resolve())],
        identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),
        cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
    save('inspect1.job.json', job)
    def guard():
        assert time.monotonic()-began < 300
        assert shutil.disk_usage(P).free > ctx['externalReserve'] and shutil.disk_usage(R).free > ctx['internalReserve']
        assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file()) < ctx['stopTaskBytes']
    try:
        rows = ctx['nativeInputs']+ctx['documents']; keyed = {Path(r['path']).name:r for r in rows}
        for row in rows: checked(Path(row['path']), row)
        anchors = {
            'OriginalMacResourceIdentityPool.swift':['do not encode pointers or source address ranges','private var next: UInt32 = 1','next &+= 1'],
            'OriginalMacAudioBackend.swift':['Device(windows.identities.take())','Buffer(windows.identities.take()','Region(windows.identities.take()','firstPointer:r.token','b.raw = try .init(bytes:q.bytes!,defined:q.defined!)'],
            'OriginalMacAudioService.swift':['let prepared = try backend.prepare(request)','try begin()','try fail(String(reflecting:error),backend.retainedResources)'],
            'OriginalWaveLoader.swift':['public var lockReplies: [OriginalWaveResponse]','public var regions: [UInt32: OriginalStateRecord]','result.lockReplies.append(reply)','region.token == token'],
            'OriginalInitialSoundLoading.swift':['audio: OriginalWaveRequest.Factory?','audio:try audio?(input)','Count is always'],
            'OriginalInitialLoadingCommon.swift':['OriginalInitialSoundLoading.load','fileSource:fileSource,platform:platform'],
            'OriginalRegisteredSoundLoading.swift':['guard device != 0','OriginalWaveLoader.load','onVolume([result.output','buffers[request.index] = result'],
            'OriginalApplicationLoadingSession.swift':['public let waveInputs: [OriginalWavePlatform]','return waves[index]','common:common,waveInputs:waves'],
            'OriginalApplicationCatalogControls.swift':['public let wave:','public let volume:','self.volume = volume','wave:{ _,_ in try owner.take'],
            'OriginalApplicationCatalogSession.swift':['public let owner: OriginalMenuSoundStartup.Result, platforms: [OriginalWavePlatform]','func retainWave(','try range(p.firstPointer','let p = try controls.wave','try candidate.load(request','self.controls.volume(args)','waveInputs.append(p)','try store(0x455638+request.index*20,incoming)'],
            'OriginalApplicationPoolSession.swift':['for (owner,p) in zip(entry.startup.owner.loads,entry.startup.platforms)','for (i,p) in entry.snapshot.waveInputs.enumerated()','reserve(p.firstPointer','guard !ranges.contains'],
            'OriginalApplicationLoadedMenuSession.swift':['for (a,p) in zip(catalog.startup.owner.loads,catalog.startup.platforms)','for (i,p) in catalog.snapshot.waveInputs.enumerated()','reserve(p.firstPointer','!ranges.contains'],
            'OriginalApplicationObservedGraphicsIteration.swift':['The entire Host/Core attempt has unwound','self.exchange.finish(consumed)'],
            'OriginalStartupRequestExchange.swift':['case sound(OriginalMenuSoundStartup.Event), waveAudio','case let (.waveAudio(_,q),.waveAudio(r))'],
            'OriginalApplicationHostSession.swift':['public func prepareLoadedUntilBoundary','validate(_ child:','child.loading.isSameAttempt'],
        }
        observations=[]
        for name, patterns in anchors.items():
            lines=Path(keyed[name]['path']).read_text().splitlines(); matches=[]
            for pattern in patterns:
                found=[dict(line=i+1,text=s) for i,s in enumerate(lines) if pattern in s]
                assert found,(name,pattern)
                matches.append(dict(anchor=pattern,matches=found))
            observations.append(dict(file=keyed[name],anchors=matches))
        save('observations1.json',dict(UTC=now(),classification='Static Native ownership/caller inspection; not executed behavior',patterns=sum(map(len,anchors.values())),sources=observations,independentReview=False))
        prior=read(Path(keyed['application-mac-audio-preflight.json']['path']))
        inventory_path=Path(keyed['application-mac-audio-preflight-wav-inputs.json']['path'])
        checked(inventory_path,{k:prior['originalInputInventory'][k] for k in ['bytes','sha256']})
        inventory=read(inventory_path);assert inventory['files']==409
        selected=[next(r for r in inventory['rows'] if r['source']['path']==name) for name in ['data\\001.wav','data\\002.wav']]
        lengths=[r['data']['bytes'] for r in selected];assert lengths==[23568,23578]
        def overlap(a,n,b,m): return n>0 and m>0 and a<b+m and b<a+n
        native=dict(device=1,buffers=[2,4],regions=[3,5],counts=lengths)
        lo=max(native['regions']);hi=min(a+n for a,n in zip(native['regions'],lengths))
        assert overlap(3,lengths[0],5,lengths[1]) and hi-lo==23566
        controls=[dict(name='addressed-disjoint',a=0x60000020,n=lengths[0],b=0x60010020,m=lengths[1],expected=False),
                  dict(name='addressed-overlap',a=0x60000020,n=lengths[0],b=0x60000022,m=lengths[1],expected=True),
                  dict(name='touching-exclusive-end',a=0x1000,n=16,b=0x1010,m=16,expected=False),
                  dict(name='zero-count-is-not-a-range',a=0x1000,n=0,b=0x1000,m=16,expected=False)]
        for c in controls:
            c['observedArithmetic']=overlap(c['a'],c['n'],c['b'],c['m']);assert c['observedArithmetic']==c['expected']
        save('identity-witness1.json',dict(UTC=now(),classification='Synthetic arithmetic witness from pinned implementation and saved original payload lengths; no Native/device run',inventory=record(inventory_path),inputs=[dict(source=r['source'],data=r['data']) for r in selected],syntheticAllocationOrder=native,distinctRegionTokens=True,incorrectAddressInterpretationOverlaps=True,intersection=dict(start=lo,endExclusive=hi,bytes=hi-lo),controls=controls,conclusion='Opaque Native region identities cannot be treated as byte-address intervals. Existing addressed-source overlap checks must remain in their explicit domain.',sourceFault=False,comparatorAcceptance=False,independentReview=False))
        base=Path(ctx['candidateManifest']['path']).parent
        methods=read(base/'selected-methods1.json')['methods'];assert len(methods)==len(set(methods))==120
        families=['OriginalInitialLoadingTests','OriginalApplicationLoadingPrefixTests','OriginalApplicationLoadingSessionTests','OriginalApplicationCatalogSessionTests','OriginalApplicationCatalogFullTests','OriginalApplicationPoolTests','OriginalApplicationLoadedMenuTests','OriginalApplicationHostLoadingTests']
        extra=[]
        for family in families:
            body=Path(keyed[family+'.swift']['path']).read_text()
            found=re.findall(r'func\s+(test\w+)\s*\(',body);assert found and len(found)==len(set(found))
            for method in found:
                name=family+'/'+method
                if name not in methods:extra.append(name)
        assert len(extra)==len(set(extra)) and not set(extra)&set(methods)
        for method in methods+extra:
            family,name=method.split('/');body=(base/'candidate1/native/Tests/NTSDCoreTests'/(family+'.swift')).read_text()
            assert len(re.findall(r'func\s+'+name+r'\s*\(',body))==1
        groups=[
            'Whole12 saved common-loading application cases plus retained full initial-loading controls through per-call replies; preserve failed Create/short reads and all globals/events/masks.',
            'Whole source catalog400 and interleaved29 registrations through per-call WAV and ordered ignored SetVolume replies; preserve stride20 overlap-sensitive path cache.',
            'One Native owner from own startup through18 common loads and registered loading with opaque Lock-derived regions; retain actual buffers and compare original payload samples without future device outputs.',
            'Full Native catalog137 Objects/PendingPool under declared non-audio controls, then existing pool/loaded-menu/Host handoffs; distinguish it from unavailable full original application return.',
            'Late failure/retry/cancel/foreign receipts, exactly-once service work and owner retention across all handoffs; preserve addressed-source overlap rejection and reject malformed region provenance.',
            'Ordered volume-before-cache and repeated-path distinct owners/live cache; unsupported ordinary resource failures remain explicit. Real playback/gain/endpoint stays separate.'
        ]
        save('next-comparison1.json',dict(UTC=now(),existingSelection=record(base/'selected-methods1.json'),retainedMethods=methods,retainedCount=120,additionalExistingMethods=extra,additionalCount=len(extra),existingProposedTotal=len(methods)+len(extra),newGroups=groups,newMethodNamesAndLimits='Freeze actual implementation/selection/limits before a later build; this audit executes none.',performanceBoundary='The current journal replays a whole Core attempt per new request. Bound complete-catalog work before execution; a timeout is incomplete, not permission to drop callers or service inside Core.',noMethodsExecuted=True,independentReview=False))
        for row in rows:checked(Path(row['path']),row)
        guard();job.update(status='terminal',exitCode=0,anchorPatterns=sum(map(len,anchors.values())),arithmeticWitnesses=1,arithmeticControls=len(controls),retainedMethods=120,additionalExistingMethods=len(extra),sourceExecuted=False,nativeExecuted=False,deviceExecuted=False)
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began)
        (P/'inspect1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
