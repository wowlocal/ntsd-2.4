"""Finite static caller/SDK and original WAV-header audit. No audio execution."""
import collections, datetime, json, os, shutil, struct, subprocess, sys, time, traceback
from pathlib import Path
R=Path('/Users/michael/Developer/ntsd-2.4')
P=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'tools'))
from archive_catalog53_storage import pin, checked
now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
read=lambda p:json.loads(p.read_text())
def save(name,value):
    p=P/name;assert not p.exists(),str(p);p.write_text(json.dumps(value,indent=2)+'\n')
def record(p):return dict(path=str(p.resolve()),**pin(p))
def main():
    began=time.monotonic();ctx=read(P/'context1.json')
    checked(Path(__file__),read(P/'inspector-inputs1.json')['inspector'])
    job=dict(status='running',pid=os.getpid(),startedUTC=now(),command=[sys.executable,str(Path(__file__).resolve())],identity=subprocess.check_output(['ps','-p',str(os.getpid()),'-o','pid=,lstart=,command='],text=True).strip(),cwd=subprocess.check_output(['lsof','-a','-p',str(os.getpid()),'-d','cwd','-Fn'],text=True).strip())
    save('inspect1.job.json',job)
    def guard():
        assert (datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(ctx['UTC'])).total_seconds()<ctx['elapsedLimitSeconds']
        assert shutil.disk_usage(P).free>ctx['externalReserve'] and shutil.disk_usage(R).free>ctx['internalReserve']
        assert sum(f.stat().st_size for f in P.rglob('*') if f.is_file())<ctx['stopTaskBytes']
    try:
        rows=ctx['nativeInputs']+read(P/'input-additions2.json')['additionalNativeInputs']+ctx['documents']+ctx['SDKInputs'];keyed={Path(r['path']).name:r for r in rows}
        for r in rows:checked(Path(r['path']),r)
        anchors={
            'OriginalStartupAudio.swift':['contains no future audio reply','case created(Int32,UInt32?)','public let bytes: [UInt8]?, defined: [Bool]?','public func validate() throws'],
            'OriginalWaveLoader.swift':['try format.write(UInt16(truncatingIfNeeded: p.destination)','UInt32(0xe0)','result.temporaryLive = true','let created = try audio','let reply = try audio','try audio(.init(.init(.copy'],
            'OriginalMenuSoundStartup.swift':['response.result != 0','response.output != nil','let cooperative = Event','public static func loadObserved'],
            'OriginalInitialSoundLoading.swift':['OriginalWaveLoader.load','audio:'],
            'OriginalInitialLoadingCommon.swift':['OriginalInitialSoundLoading.load','fileSource:fileSource,platform:platform'],
            'OriginalRegisteredSoundLoading.swift':['OriginalWaveLoader.load','onVolume([result.output','buffers[request.index] = result'],
            'OriginalApplicationCatalogSession.swift':['let p = try controls.wave','try candidate.load(request','self.controls.volume(args)','try retainWave(owner,p)'],
            'OriginalApplicationLoadingSession.swift':['OriginalInitialLoadingCommon.load','waves[index]'],
            'OriginalApplicationMenuSession.swift':['case "soundMethod": try emit','frontProvider'],
            'OriginalApplicationLoadedMenuSession.swift':['let response = try musicReply','ignoredResult:response'],
            'OriginalApplicationGameplaySession.swift':['let soundBuffers = Set','func sound(','ignoredResult:outputInput.methodResult','return outputInput.methodResult'],
            'OriginalQueuedSound.swift':['try method(word(globals,address),0x48','try method(word(globals,address),0x34','try method(word(globals,address),0x30','400,0x457588','80,0x453e10','right &- left','right &+ left'],
            'OriginalMusicPlayback.swift':['public static func initializeGraph','public static func seekToStart','if query.result < 0','if render < 0','let level: Int32'],
            'OriginalGraphEvents.swift':['0x80004004','seekToStart'],
            'OriginalMusicConfiguration.swift':['bgm\\\\main.wma','OriginalMusicPlayback.stop'],
            'OriginalApplicationObservedStartup.swift':['outside resume','public func beginService','public func answer','public func fail'],
            'OriginalApplicationObservedGraphicsIteration.swift':['The entire Host/Core attempt has unwound','self.exchange.finish(consumed)'],
            'OriginalMenuGraphicsRequestExchange.swift':['case front(Stage','case "blit","fill","method"','default:return false'],
            'OriginalMacResourceIdentityPool.swift':['Tokens','private var next: UInt32 = 1','next &+= 1'],
            'OriginalMacBitmapService.swift':['try begin()','try backend.performBitmap(prepared)','try fail(String(reflecting:error),backend.retainedResources)'],
            'AVAudioBuffer.h':['initWithPCMFormat:','floatChannelData returns pointers','frameLength'],
            'AVAudioEngine.h':['before accessing any of mainMixerNode, inputNode or outputNode','renderOffline:toBuffer:error:','output buffer\'s frameLength'],
            'AVAudioFormat.h':['Signed 16-bit native-endian integers','32-bit floating point'],
            'AVAudioMixing.h':['Range:      0.0 -> 1.0','Range:      -1.0 -> 1.0'],
            'AVAudioPlayerNode.h':['buffers are at the same','unschedules all previously scheduled buffers','buffer loops indefinitely'],
        }
        observations=[]
        for name,patterns in anchors.items():
            row=keyed[name];lines=Path(row['path']).read_text().splitlines();matches=[]
            for pattern in patterns:
                found=[dict(line=i+1,text=s) for i,s in enumerate(lines) if pattern in s]
                assert found,(name,pattern)
                matches.append(dict(anchor=pattern,matches=found))
            observations.append(dict(file=row,anchors=matches))
        save('observations1.json',dict(UTC=now(),classification='static Native/caller and SDK inspection; no source/Native/device execution',sources=observations,patterns=sum(len(x) for x in anchors.values()),independentReview=False))
        publication=read(Path(keyed['wave-loader.json']['path']))
        assert publication['exeSHA256']=='3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
        sources=publication['sources'];assert len(sources)==409 and len({r['path'] for r in sources})==409
        root=R/'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a'
        inventory=[];groups=collections.Counter();total=0
        for row in sources:
            guard();f=root/row['path'].replace('\\','/');assert f.is_file() and f.stat().st_size<2*2**20
            before=record(f);assert before['bytes']==row['bytes'] and before['sha256']==row['sha256']
            total+=row['bytes'];assert total<=128*2**20
            raw=f.read_bytes();assert raw[:4]==b'RIFF' and raw[8:12]==b'WAVE'
            limit=8+struct.unpack_from('<I',raw,4)[0];assert 12<=limit<=len(raw)
            cursor=12;chunks=[]
            while cursor<limit:
                assert len(chunks)<256 and cursor+8<=limit
                count=struct.unpack_from('<I',raw,cursor+4)[0];end=cursor+8+count
                assert end<=limit
                chunks.append(dict(idHex=raw[cursor:cursor+4].hex(),headerOffset=cursor,dataOffset=cursor+8,bytes=count))
                cursor=end+(count&1)
            assert cursor in (limit,limit+1)
            fmt=[c for c in chunks if c['idHex']==b'fmt '.hex()];data=[c for c in chunks if c['idHex']==b'data'.hex()]
            assert len(fmt)==1 and len(data)==1 and fmt[0]['bytes']>=16
            o=fmt[0]['dataOffset'];tag,channels,rate,average,align,bits=struct.unpack_from('<HHIIHH',raw,o)
            fields=dict(tag=tag,channels=channels,rate=rate,averageBytesPerSecond=average,blockAlign=align,bits=bits)
            groups[tuple(fields.values())]+=1
            inventory.append(dict(source=row,file=before,format=fields,formatPrefixHex=raw[o:o+min(fmt[0]['bytes'],64)].hex(),loader18InputHex=raw[o:o+18].hex(),firstChunkIsFormat=chunks[0]==fmt[0],data=data[0],chunks=chunks,trailingFileBytes=len(raw)-limit,blockAligned=bool(align and data[0]['bytes']%align==0),pcmArithmeticConsistent=bool(tag==1 and align==channels*bits//8 and average==rate*align)))
            checked(f,before)
        save('wav-input-inventory1.json',dict(UTC=now(),sourcePublication=keyed['wave-loader.json'],files=409,bytes=total,formats=[dict(fields=dict(zip(['tag','channels','rate','averageBytesPerSecond','blockAlign','bits'],key)),files=value) for key,value in sorted(groups.items())],allFirstChunksFormat=all(x['firstChunkIsFormat'] for x in inventory),allBlockAligned=all(x['blockAligned'] for x in inventory),allPCMArithmeticConsistent=all(x['pcmArithmeticConsistent'] for x in inventory),rows=inventory,classification='original asset bytes only; not Windows/MMIO/device behavior; no PCM playback/decoding'))
        for r in rows:checked(Path(r['path']),r)
        guard();job.update(status='terminal',exitCode=0,anchorPatterns=sum(len(x) for x in anchors.values()),originalFiles=409,originalBytes=total,formats=len(groups),sourceExecuted=False,nativeExecuted=False,deviceExecuted=False)
    except BaseException as error:
        job.update(status='terminal',exitCode=1,error=repr(error),traceback=traceback.format_exc());raise
    finally:
        job.update(endedUTC=now(),elapsedSeconds=time.monotonic()-began);(P/'inspect1.job.json').write_text(json.dumps(job,indent=2)+'\n');print(json.dumps(job),flush=True)
if __name__=='__main__':main()
