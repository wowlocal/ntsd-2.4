import AppKit
import NTSDCore
import UniformTypeIdentifiers

/// Runtime loading after the menu requests it: common sounds, the whole
/// catalog, the 400-slot pool, first input and the loaded menu, then the Host
/// tail. Audio is served inline on the loading exchange (one attempt instead of
/// one attempt per request). Other providers are runtime answers:
/// - allocations: runtime heap addresses, zero backing (`allocationFill` 0); the
///   catalog block's registry/background/stage backing is declared initialized
///   zero (a fresh large Windows heap block is demand-zero pages);
/// - bitmaps: real display-backend surfaces from the original packages; Core
///   derives BITMAP fields itself, so replies carry results/outputs only;
/// - files: packaged catalog bytes, declared 65536/4096 stream buffering;
/// - clock: live; loading PeekMessage sees an empty queue (input stays queued);
/// - draw/present results inside loading are declared 0 and are not rendered.
@MainActor public final class OriginalMacRuntimeLoading {
    public typealias P = OriginalApplicationPreparedStartupPlatform
    public typealias Host = OriginalApplicationHostSession<P>
    public typealias Catalog = OriginalApplicationCatalogSession
    public typealias LoadedMenu = OriginalApplicationLoadedMenuSession
    public enum Boundary: Error, Equatable { case missing(String), unexpected(String) }
    public struct Counts: Equatable {
        public var allocations = 0, bitmapRequests = 0, files = 0, audioRequests = 0, times = 0, messages = 0, music = 0, objectInputs = 0, characterAI = 0
        public var controls = 0, replayedDraws = 0, skippedDraws = 0, rejectedDraws = 0, replayFiles = 0, musicResumes = 0, epilogues = 0
    }
    /// Declared processor signature for the replay codec's lazy detection
    /// (4428b0): only family bits 0xf00 ≥ 0x600 matter, which every x86 CPU
    /// Windows runs on reports (Intel family 6, AMD family 0xf).
    public static let processorSignature: UInt32 = 0x600
    /// Writable files beside the original EXE; nil keeps replay output in memory.
    public var overlay: OriginalMacRuntimeOverlay?
    /// GetLocalTime's source date; the app pins it for reproducible runs.
    public var localDate: () -> Date = { Date() }
    /// Playback Recording's GetOpenFileNameA: a scripted path (used once), else
    /// an open panel on the overlay's recording folder when interactive, else
    /// a cancelled dialog.
    public var playbackFile: String?
    public var playbackInteractive = false
    /// MessageBoxA texts and ShellExecuteA documents of this run, in order.
    public private(set) var playbackAlerts: [String] = []
    /// GetOpenFileNameA requests and their answers (nil: cancelled), in order.
    public private(set) var playbackDialogs: [String?] = []
    public private(set) var openedDocuments: [String] = []
    /// Per-stage owned snapshots of gameplay bodies and loaded cycles. The app
    /// never consumes them; `true` runs the unchanged observation path.
    public var stageCheckpoints = false
    /// Replay files written by the gameplay body, applied only after the
    /// enclosing Host batch commits (a discarded attempt writes nothing).
    public private(set) var savedReplays: [OriginalMacRuntimeStartupService.FileEffect] = []
    /// PostQuitMessage codes of committed batches not yet posted as WM_QUIT.
    public var quitCodes: [UInt32] = []
    private var pendingReplays: [OriginalMacRuntimeStartupService.FileEffect] = []
    private var openReplay: (path: String,bytes: [UInt8])?
    /// Replay paths the declared file policy refused (reported, not hidden).
    public private(set) var refusedReplayOpens: [String] = []
    public private(set) var counts = Counts()
    /// Sleep(ms) requested by Host tails; the app waits before the next iteration.
    public private(set) var sleeps: [UInt32] = []
    /// Graphics of the prepared input continuation: the requesting iteration's
    /// staged effects (already performed through permits) and, on the first
    /// load, the blocking loading's progress frames. Replay starts after them.
    private var continuationGraphics = 0
    let started: OriginalMacRuntimeStartup.Started
    let clock: () throws -> UInt32
    let startupInputs: OriginalApplicationStartupInputs
    let catalogInputs: OriginalApplicationCatalogInputs, loadingInputs: OriginalApplicationLoadingInputs
    let interfaceInputs: OriginalApplicationInterfaceInputs, menuInputs: OriginalApplicationMenuInputs
    let arenaInputs: OriginalApplicationArenaInputs
    let bitmapInputs: OriginalMacDisplayBackend.BitmapInputs
    public init(_ started: OriginalMacRuntimeStartup.Started,startupInputs: OriginalApplicationStartupInputs,
        catalogInputs: OriginalApplicationCatalogInputs,loadingInputs: OriginalApplicationLoadingInputs,
        interfaceInputs: OriginalApplicationInterfaceInputs,menuInputs: OriginalApplicationMenuInputs,
        arenaInputs: OriginalApplicationArenaInputs,clock: @escaping () throws -> UInt32) {
        self.started = started; self.clock = clock; self.startupInputs = startupInputs
        self.catalogInputs = catalogInputs; self.loadingInputs = loadingInputs
        self.interfaceInputs = interfaceInputs; self.menuInputs = menuInputs; self.arenaInputs = arenaInputs
        // Embedded DIB resources by name; bitmap files by path. Resource names
        // are declared missing as files, as LR_LOADFROMFILE fails before the
        // resource retry.
        var resources: [String:OriginalApplicationStartupInputs.Bitmap] = [:]
        var files: [String:OriginalMacDisplayBackend.BitmapInputs.File] = [:]
        for source in [startupInputs.bitmaps,interfaceInputs.bitmaps,menuInputs.bitmaps,catalogInputs.bitmaps,arenaInputs.bitmaps] {
            for (name,bitmap) in source {
                if bitmap.bitmapFileHeader != nil { files[name] = .bitmap(bitmap) }
                else { resources[name] = bitmap; if files[name] == nil { files[name] = .missing } }
            }
        }
        bitmapInputs = .init(resources:resources,files:files)
    }
    public static func bundled(_ started: OriginalMacRuntimeStartup.Started,startupInputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32) throws -> OriginalMacRuntimeLoading {
        try .init(started,startupInputs:startupInputs,catalogInputs:.bundled(),loadingInputs:.bundled(),
            interfaceInputs:.bundled(),menuInputs:.bundledWithWar(),arenaInputs:.bundled(),clock:clock)
    }
    func presentation(_ target: UInt32) throws -> OriginalMenuPresentationInput {
        try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":target,"methodResult":0,"queryResult":0,"audioGetResult":0,"audioSetResult":0,
            "queriedAudio":0,"audioVolume":0,"dcResult":OriginalMacRuntimeMenu.getDCFailure,"dc":0,"postResult":0]))
    }
    func bitmap(_ q: OriginalBitmapSurfaceLoading.Request) throws -> OriginalBitmapSurfaceLoading.Response {
        counts.bitmapRequests += 1
        let display = started.display
        if q.kind == "message" || q.kind == "debug" { throw Boundary.unexpected("bitmap \(q.kind): \(q.strings.map { String(decoding:$0,as:UTF8.self) })") }
        let served = try display.performBitmap(display.prepareBitmap(q,inputs:bitmapInputs))
        return .init(result:served.response.result,output:served.response.output)
    }
    func wave(_ path: String) throws -> OriginalWaveFileInput {
        if let bytes = try? loadingInputs.file(path) { return try OriginalMacRuntimeWave.input(path,bytes) }
        guard let bytes = try catalogInputs.file(path) else { throw Boundary.missing(path) }
        return try OriginalMacRuntimeWave.input(path,bytes)
    }
    func music(_ e: OriginalMusicEvent) throws -> OriginalMusicResponse {
        counts.music += 1
        if e.kind == .helper || e.kind == .format { return .init() }
        return try started.runtime.music.answer(e)
    }
    func time() throws -> UInt32 { counts.times += 1; return try clock() }

    /// Runs the whole loading preparation in one inline attempt and the Host
    /// tail; returns the Host outcome of the tail or the pending match prelude.
    public func run() throws -> Host.LoadedOutcome {
        let host = started.host,heap = started.runtime.heap
        guard let pending = host.pendingLoading,let startup = host.snapshot.startup,let sounds = startup.input?.sounds else { throw Boundary.missing("pending loading") }
        let device = try pending.state.full.integer(at:0x44eecc-0x44d000,as:UInt32.self)
        let owners = try sounds.loads.enumerated().map { i,result in
            try started.audio.ownership(.init(i,OriginalMenuSoundStartup.paths[i],UInt32(0x45560c+i*4),device),result:result)
        }
        let startupSounds = try Catalog.StartupSounds(owner:sounds,waveOwners:owners,music:startup.output.music)
        let driver = try OriginalApplicationObservedLoadingAudio<P>(host:host,domain:.opaque(started.audio.loadingDomain))
        let service = OriginalMacAudioService(backend:started.audio)
        let outcome = try driver.resumeInline(prepare:{ context,_,audio in
            var loading = try context.entry.makeLoadingSession()
            let common = try loading.prepareCommon(inputs:self.loadingInputs,prepareWave:{ i,path,destination,device in
                audio.prepare(.init(i,path,destination,device),file:try self.wave(path))
            },drawResult:0,presentationResult:0)
            var catalog = try Catalog(pending:common,startup:startupSounds)
            let resources = try Catalog.Resources(files:self.catalogInputs.files,bitmaps:self.catalogInputs.bitmaps,
                presentation:self.presentation(common.target),drawResult:0,graphicsResult:0,allocationFill:0,allocationDefined:true)
            let loaded = try catalog.load(resources:resources,makeControls:{
                .init(allocate:{ _,count in self.counts.allocations += 1; return try heap.reserve(count) },
                    bitmap:{ try self.bitmap($0) },
                    file:{ _,_ in
                        self.counts.files += 1
                        return .init(token:try heap.reserve(32),buffer:try heap.reserve(65536),descriptor:UInt32(self.counts.files+2),
                            capacity:65536,readLimit:4096)
                    },
                    wavePreparation:{ q,device in
                        audio.prepare(.init(q.index,q.path,UInt32(0x452948+q.index*4),device),file:try self.wave(q.path))
                    },
                    volume:{ binding,args in
                        guard args.count == 2 else { throw Boundary.unexpected("volume arguments") }
                        return try audio.volume(binding,buffer:args[0],value:Int32(bitPattern:args[1]))
                    },
                    time:{ try self.time() },
                    message:{ name,_ in
                        guard name == "PeekMessageA" else { throw Boundary.unexpected(name) }
                        self.counts.messages += 1; return .init(name:name,response:.init(result:0))
                    })
            })
            var pool = try LoadedMenu.Input.Pool(pending:loaded)
            let pooled = try pool.prepare(inputs:self.interfaceInputs,makeControls:{
                .init(allocate:{ _,count in self.counts.allocations += 1; return try heap.allocate(count) },bitmap:{ try self.bitmap($0) })
            })
            var input = try LoadedMenu.Input(pending:pooled,arithmeticPrecision:.bits53),environment: Void = ()
            let ready = try input.advance(environment:&environment,controlBoundary:{ q,_ in throw Boundary.unexpected("input control \(q)") })
            self.continuationGraphics = ready.graphics.count
            return .init(menu:try self.loadedMenu(ready,target:common.target))
        },serve:{ permit,exchange in self.counts.audioRequests += 1; try service.serve(permit,on:exchange) })
        return outcome
    }
    /// Winsock policy for a local game: WSAStartup was never called, so socket
    /// requests fail with SOCKET_ERROR and write nothing. Declared, unobserved.
    func control(_ q: OriginalInputControlRequest) throws -> OriginalInputControlResponse {
        counts.controls += 1
        switch q.kind {
        case .asyncSelect,.ioctl: return .init(result:-1)
        // Hotkey (416c70..416fad), playback-restore and input-reset notices:
        // Core performs their effects; nothing is asked of the platform.
        case .action,.restorePlayback,.inputReset: return .init()
        default: throw Boundary.unexpected("input control \(q.kind)")
        }
    }
    func loadedMenu(_ ready: LoadedMenu.Input.PendingContinuation,target: UInt32) throws -> LoadedMenu.Outcome {
        let heap = started.runtime.heap
        var menu = try LoadedMenu(pending:ready),unit: Void = ()
        return try menu.advanceUntilBoundary(inputs:menuInputs.adding(arenaInputs.bitmaps),environment:&unit,
            screenInput:.init(dcResult:OriginalMacRuntimeMenu.getDCFailure,dc:0,methodResult:0,drawResults:[0],shellResult:42),
            outputInput:presentation(target),
            allocate:{ _,count,_ in self.counts.allocations += 1; return try heap.allocate(count) },
            bitmap:{ q,_ in try self.bitmap(q) },music:{ e,_ in try self.music(e) },milliseconds:{ _ in try self.time() },
            // War start (43a21f) prepares its match inside the menu call.
            localTime:{ _ in Self.localTime(self.localDate()) },
            allocateReplay:{ count,_ in self.counts.allocations += 1; return try heap.reserve(count) },
            demoMusicTrack:Self.demoMusicResidue,
            playback:.init(choose:{ _ in self.chooseRecording() },
                read:{ path,_ in FileManager.default.contents(atPath:path).map { [UInt8]($0) } },
                alert:{ message,_ in self.alert(message) },open:{ path,_ in self.openDocument(path) }))
    }
    func chooseRecording() -> String? {
        let answer = answerDialog()
        playbackDialogs.append(answer)
        return answer
    }
    private func answerDialog() -> String? {
        if let file = playbackFile { playbackFile = nil; return file }
        guard playbackInteractive else { return nil }
        let directory = try? overlay?.url("recording")
        return MainActor.assumeIsolated {
            let panel = NSOpenPanel()
            panel.title = "Open"
            panel.allowedContentTypes = ["lfr","txt"].compactMap { UTType(filenameExtension:$0) }
            panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            if let directory { panel.directoryURL = directory }
            return panel.runModal() == .OK ? panel.url?.path : nil
        }
    }
    /// MessageBoxA(NULL, text, NULL, MB_OK): Windows titles it "Error".
    func alert(_ message: [UInt8]) {
        let text = String(decoding:message,as:UTF8.self)
        playbackAlerts.append(text)
        guard playbackInteractive else { return }
        MainActor.assumeIsolated {
            let alert = NSAlert()
            alert.messageText = "Error"; alert.informativeText = text
            alert.runModal()
        }
    }
    func openDocument(_ path: String) {
        openedDocuments.append(path)
        guard playbackInteractive else { return }
        MainActor.assumeIsolated { _ = NSWorkspace.shared.open(URL(fileURLWithPath:path)) }
    }
    /// Declared runtime policy for the Demo start: 4025d0 reads its track from
    /// ECX, the residue of lib.dll's text replacement (10001298), whose last
    /// instruction before returning is DirectDraw's GetDC (failure) or
    /// ReleaseDC. That register is unknown on Windows; the app declares a value
    /// outside 0..8 (the E_FAIL of its own GetDC), so the configured track in
    /// 44eed0 plays and no RNG draw is taken. APPLICATION_DEMO.md.
    static let demoMusicResidue = OriginalMacRuntimeMenu.getDCFailure
    /// A cached cycle after the first loading: the retained owners advance the
    /// cycle's input step, then either gameplay (retained as gameplay input) or
    /// the loaded menu; no catalog work repeats.
    public func runCycle() throws -> Host.LoadedOutcome {
        try started.host.prepareLoadedUntilBoundary(prepare:{ context,_ in
            guard var cycle = context.cycle else { throw Boundary.missing("cached loaded cycle") }
            var unit: Void = ()
            let ready = try cycle.advance(environment:&unit,dispatch:{ d,match,_ in
                let slot = Int(d.arguments[0])
                if d.kind == .objectInput { try OriginalObjectInput.apply(slot:slot,state:&match); self.counts.objectInputs += 1; return }
                if d.kind == .characterAI {
                    do { try OriginalCharacterAI.apply(slot:slot,mode:Int32(bitPattern:d.arguments[1]),state:&match); self.counts.characterAI += 1; return }
                    catch OriginalLoaderError.outsideVerifiedDomain(let reason) { throw Boundary.unexpected("character AI slot \(slot): \(reason)") }
                }
                // Unreachable for the two recovered kinds: report the object.
                let index = try match.world.integer(at:0x194+slot*4,as:UInt32.self)
                let actor = index < 400 ? match.actors[Int(index)] : nil
                let object = try actor?.integer(at:0x368,as:UInt32.self) ?? UInt32.max
                let id = object < match.loadedObjects.count ? try match.loadedObjects[Int(object)].header.integer(at:0x6f4,as:Int32.self) : -1
                let frame = try actor?.integer(at:0x70,as:UInt32.self) ?? UInt32.max
                throw Boundary.unexpected("AI/object child \(d.kind.rawValue) slot \(slot) object \(object) header6f4 \(id) frame \(frame)")
            },controlBoundary:{ q,_ in try self.control(q) },checkpoints:stageCheckpoints)
            self.continuationGraphics = ready.graphics.count
            switch ready.round.continuation {
            case .gameplay,.pausedRendering: return .gameplayInput(ready)
            case .epilogue:
                self.counts.epilogues += 1
                return .init(menu:.returned(try OriginalApplicationEpilogueSession.finish(pending:ready,
                    outputInput:self.presentation(ready.loading.target))))
            case .menu: return .init(menu:try self.loadedMenu(ready,target:context.entry.target))
            }
        })
    }
    /// Complete one outer loading request: first load or cached cycle, then the
    /// match launch or gameplay body when retained, then the Host tail and replay.
    public enum Completed: Equatable { case menu, launched, gameplay }
    public func complete(first: Bool) throws -> Completed {
        let outcome = first ? try run() : try runCycle()
        let completed: Completed
        switch outcome {
        case .returned: completed = .menu
        case .matchPrelude: _ = try launch(); completed = .launched
        case .gameplayInput: _ = try gameplay(); completed = .gameplay
        }
        guard case .committed = try finish() else { throw Boundary.unexpected("Host tail did not commit") }
        return completed
    }
    /// GetLocalTime from the macOS local calendar (declared runtime source).
    static func localTime(_ date: Date = Date()) -> OriginalLocalTime {
        let c = Calendar(identifier:.gregorian).dateComponents(in:.current,from:date)
        return .init(year:UInt16(c.year!),month:UInt16(c.month!),dayOfWeek:UInt16(c.weekday!-1),day:UInt16(c.day!),
            hour:UInt16(c.hour!),minute:UInt16(c.minute!),second:UInt16(c.second!),milliseconds:UInt16((c.nanosecond ?? 0)/1_000_000))
    }
    /// The retained Start child: prelude, arena layers (packaged District),
    /// music, 6.5 MB recording (runtime heap address) and the outer clock.
    public func launch() throws -> LoadedMenu.PendingReturn {
        let heap = started.runtime.heap
        return try started.host.resumeMatchLaunch(prepare:{ pending,_ in
            var session = try OriginalApplicationMatchLaunchSession(pending:pending),unit: Void = ()
            // Replay keeps the cycle's continuation offset: the prelude's own draws
            // (the final selection frame) were not committed and replay with the launch.
            return try session.advance(environment:&unit,bitmaps:self.arenaInputs.bitmaps,outputInput:self.presentation(pending.loading.target),
                allocateBitmap:{ _,count,_ in self.counts.allocations += 1; return try heap.allocate(count) },
                bitmap:{ q,_ in try self.bitmap(q) },localTime:{ _ in Self.localTime(self.localDate()) },music:{ e,_ in try self.music(e) },
                allocateReplay:{ count,_ in self.counts.allocations += 1; return try heap.reserve(count) },
                milliseconds:{ _ in try self.time() })
        })
    }
    /// One retained gameplay body. DDBLTFX backing for fills is zero. Without
    /// `stageCheckpoints` no per-stage snapshots are built.
    public func gameplay() throws -> LoadedMenu.PendingReturn {
        let heap = started.runtime.heap
        return try started.host.resumeGameplay(prepare:{ ready,_ in
            self.pendingReplays = []; self.openReplay = nil
            var session = try OriginalApplicationGameplaySession(pending:ready),unit: Void = ()
            // The caller's formatter locals (root44c..5bf): declared unknown
            // backing each body; formatting must produce every byte it reads.
            // Root SP+0x68, the playback indicator's destination, is stored at
            // 41bce4 from 41bc90's own argument: this body's draw target.
            let caller = try OriginalGameplayBody.Caller(formatter:.init(
                bytes:[UInt8](repeating:0,count:OriginalResultLayout.localSize),
                defined:[Bool](repeating:false,count:OriginalResultLayout.localSize)),indicatorTarget:ready.loading.target)
            return try session.advance(environment:&unit,outputInput:self.presentation(ready.loading.target),caller:caller,
                fillBacking:{ [UInt8](repeating:0,count:100) },
                allocate:{ _ in self.counts.allocations += 1; return try heap.reserve(OriginalReplayWriter.capacity) },
                processorSignature:{ _ in Self.processorSignature },
                open:{ q,_ in self.replayOpen(q) },write:{ bytes,_ in self.replayWrite(bytes) },close:{ _ in self.replayClose() },
                resumeMusic:{ control,_ in
                    self.counts.musicResumes += 1
                    return try self.music(.init(.method,[control,0x1c])).result
                },music:{ e,_ in try self.music(e) },checkpoints:self.stageCheckpoints,
                transformBacking:{ try Self.transformBacking($0.actorTokens) })
        })
    }
    /// Runtime heap policy for lib.dll's write through Actor+0x7b4
    /// (LIB_TRANSFORMS): Actors are consecutive 0x420-byte runtime heap blocks,
    /// so the write lands in the next Actor at +0x394; the last Actor's goes to
    /// a declared record standing for the following block. Neither the EXE nor
    /// the DLL reads these bytes (static scan), so only ownership is modeled.
    static func transformBacking(_ tokens: [UInt32]) throws -> OriginalLibTransformBacking {
        guard tokens.count == 400,zip(tokens,tokens.dropFirst()).allSatisfy({ $1 &- $0 == 0x420 }) else {
            throw Boundary.unexpected("Actor runtime heap blocks are not consecutive")
        }
        var destinations: [Int:OriginalLibTransformBacking.Destination] = [:]
        for i in 0..<399 { destinations[i] = .actor(index:i+1,offset:0x394) }
        destinations[399] = .external(index:0,offset:0x394)
        let following = try OriginalStateRecord(bytes:[UInt8](repeating:0,count:0x420),defined:[Bool](repeating:false,count:0x420))
        return .init(destinations:destinations,actorAddressTokens:Dictionary(uniqueKeysWithValues:tokens.enumerated().map { ($0.offset,$0.element) }),
                     externalRecords:[following])
    }
    /// _wfsopen(path,"wb",0x40) on a path relative to the EXE directory. The
    /// package's own folders (such as `recording`) exist beside the EXE; other
    /// or malformed paths fail as a missing directory would.
    func replayOpen(_ q: OriginalReplayFileOutput.OpenRequest) -> Bool {
        let path = String(decoding:q.path,as:UTF16.self)
        guard q.mode == [0x77,0x62],openReplay == nil,let overlay,(try? overlay.url(path)) != nil,
              path.split(separator:"\\").count == 2,path.lowercased().hasPrefix("recording\\") else { refusedReplayOpens.append(path); return false }
        openReplay = (path,[]); return true
    }
    func replayWrite(_ bytes: [UInt8]) -> Int32 {
        guard openReplay != nil else { return -1 }
        openReplay!.bytes += bytes; return Int32(bytes.count)
    }
    func replayClose() -> Int32 {
        guard let file = openReplay else { return -1 }
        pendingReplays.append(.init(path:file.path,bytes:file.bytes)); openReplay = nil; return 0
    }
    /// The Host tail after a returned loaded menu (its single timeGetTime), then
    /// the committed loaded batch's front draws replayed on the display: the
    /// Core already recorded declared success for them. Text stays omitted.
    public func finish() throws -> Host.Outcome {
        let outcome = try started.host.finishLoadedMenu(perform:{ request,_ in
            switch request.kind {
            case .time: return .init(result:Int32(bitPattern:try self.time()))
            case .sleep:
                guard request.arguments.count == 1 else { throw Boundary.unexpected("tail Sleep arguments") }
                self.sleeps.append(request.arguments[0]); return .init()
            default: throw Boundary.unexpected("tail \(request.kind)")
            }
        })
        while let batch = try started.host.takeCommitted() {
            guard case .loaded(let commit) = batch.contents else { continue }
            for case .front(let e,_,_) in commit.operations where e.kind == "postQuit" { quitCodes.append(e.arguments[0]) }
            counts.skippedDraws += min(continuationGraphics,commit.graphics.count)
            try replay(Array(commit.graphics.dropFirst(continuationGraphics)))
        }
        if case .committed = outcome, !pendingReplays.isEmpty {
            try overlay?.apply(pendingReplays)
            savedReplays += pendingReplays; counts.replayFiles += pendingReplays.count; pendingReplays = []
        }
        return outcome
    }
    func replay(_ commands: [OriginalApplicationGraphics.Command]) throws {
        let display = started.display
        for command in commands {
            guard let e = command.event else { continue }
            switch e.kind {
            case "blit":
                if OriginalMacRuntimeMenu.empty(e.blit) { counts.skippedDraws += 1; continue }
            case "fill": break
            case "method": guard let method = e.arguments.dropFirst().first,[8,0x14,0x2c].contains(method) else { continue }
            default: continue
            }
            // Core recorded declared success; the recovered callers ignore the
            // result, so a DDERR_INVALIDRECT Blt only leaves the pixels unchanged.
            let served = try display.performFront(display.prepareFront(e)); counts.replayedDraws += 1
            if served.response.result == OriginalMacDisplayBackend.invalidRect { counts.rejectedDraws += 1 }
        }
    }
}
