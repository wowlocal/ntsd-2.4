import Foundation
import NTSDCore

/// Runtime loading after the menu requests it: common sounds, the whole
/// catalog, the 400-slot pool, first input and the loaded menu, then the Host
/// tail. Audio is served inline on the loading exchange (one attempt instead of
/// one attempt per request). Other providers are runtime answers:
/// - allocations: runtime heap addresses, zero backing (`allocationFill` 0); the
///   catalog block's registry/background/stage backing is declared initialized
///   zero (a fresh large Windows heap block is demand-zero pages);
/// - bitmaps: real display-backend surfaces from the original packages; Core
///   derives BITMAP fields itself, so replies carry results/outputs only;
/// - files: packaged catalog bytes, declared 65536/4096 stream buffering, and
///   VC80's fscanf("%c") lookahead in the DAT decoder (catalog checksum 1ec3356);
/// - clock: live; loading PeekMessage sees an empty queue (input stays queued);
/// - draw/present results inside loading are declared 0 and are not rendered.
/// Interactive host dialogs of playback and the menu's document links.
@MainActor public struct OriginalRuntimeLoadingDialogs {
    /// The recording chooser (GetOpenFileName for .lfr/.txt), starting in
    /// `directory`: a path, or nil when cancelled.
    public var chooseRecording: (URL?) -> String?
    /// MessageBoxA(NULL, text, NULL, MB_OK), which Windows titles "Error".
    public var alert: (String) -> Void
    /// ShellExecute's "open" of a document path.
    public var open: (String) -> Void
    public init(chooseRecording: @escaping (URL?) -> String?,alert: @escaping (String) -> Void,open: @escaping (String) -> Void) {
        self.chooseRecording = chooseRecording; self.alert = alert; self.open = open
    }
}

@MainActor public final class OriginalMacRuntimeLoading {
    public typealias P = OriginalApplicationPreparedStartupPlatform
    public typealias Host = OriginalApplicationHostSession<P>
    public typealias Catalog = OriginalApplicationCatalogSession
    public typealias LoadedMenu = OriginalApplicationLoadedMenuSession
    public enum Boundary: Error, Equatable { case missing(String), unexpected(String) }
    public struct Counts: Equatable {
        public var allocations = 0, bitmapRequests = 0, files = 0, audioRequests = 0, times = 0, messages = 0, music = 0, objectInputs = 0, characterAI = 0
        public var controls = 0, replayedDraws = 0, skippedDraws = 0, rejectedDraws = 0, replayFiles = 0, musicResumes = 0, epilogues = 0, replayedText = 0
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
    /// Playback's ShellExecuteA of a chosen .txt: its result is ignored, so it
    /// is performed when the loaded batch commits, after that batch's Sleep.
    private var pendingDocuments: [String] = []
    /// Per-stage owned snapshots of gameplay bodies and loaded cycles. The app
    /// never consumes them; `true` runs the unchanged observation path.
    public var stageCheckpoints = false
    /// Replay files written by the gameplay body, applied only after the
    /// enclosing Host batch commits (a discarded attempt writes nothing).
    public private(set) var savedReplays: [OriginalMacRuntimeStartupService.FileEffect] = []
    /// PostQuitMessage codes of committed batches not yet posted as WM_QUIT.
    public var quitCodes: [UInt32] = []
    /// ShellExecuteA of the screens after START (mode screen and panel links,
    /// Playback's folder): the app's handler, given the milliseconds of the
    /// screen's Sleep before it. Set by the app, as for the front menu.
    public var shell: (([UInt8],[UInt8],UInt32) throws -> Void)?
    /// The same live sockets used by the front-menu handshake.
    public var network: OriginalMacRuntimeNetwork?
    public var messageBox: (([UInt8],[UInt8],UInt32) throws -> Int32)?
    public var postMessage: ((UInt32,UInt32,UInt32) -> Void)?
    /// An inline control method is already serviced even if a later source
    /// fault prevents commit. Synchronize the player before the next request.
    public var presentControlMusic: (() throws -> Void)?
    private struct ControlRequest: OriginalExchangeRequest {
        let value: OriginalInputControlRequest
        func accepts(_ response: OriginalInputControlResponse) -> Bool { true }
    }
    private typealias ControlExchange = OriginalRequestExchange<ControlRequest,Void>
    private var controlDelivery: (sequence:UInt64,exchange:ControlExchange)?
    private var controlCursor: ControlExchange.Cursor?
    /// Replay files the platform could not write; the original's failing
    /// fopen/fwrite leaves the game running (declared).
    public private(set) var failedReplayWrites: [String] = []
    /// DirectSound methods: receipt-backed input calls play inline; other
    /// loaded-batch methods play on commit.
    public var sounds: OriginalMacSoundEffects?
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
        arenaInputs: OriginalApplicationArenaInputs,clock: @escaping () throws -> UInt32,dialogs: OriginalRuntimeLoadingDialogs) {
        self.started = started; self.clock = clock; self.dialogs = dialogs; self.startupInputs = startupInputs
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
        clock: @escaping () throws -> UInt32,dialogs: OriginalRuntimeLoadingDialogs,in bundle: Bundle = .main) throws -> OriginalMacRuntimeLoading {
        try .init(started,startupInputs:startupInputs,catalogInputs:.bundled(in:bundle),loadingInputs:.bundled(in:bundle),
            interfaceInputs:.bundled(in:bundle),menuInputs:.bundledWithWar(in:bundle),arenaInputs:.bundled(in:bundle),clock:clock,dialogs:dialogs)
    }
    /// The host's interactive dialogs.
    public var dialogs: OriginalRuntimeLoadingDialogs
    func presentation(_ target: UInt32) throws -> OriginalMenuPresentationInput {
        try JSONDecoder().decode(OriginalMenuPresentationInput.self,from:JSONSerialization.data(withJSONObject:[
            "targetSurface":target,"methodResult":0,"queryResult":0,"audioGetResult":0,"audioSetResult":0,
            "queriedAudio":0,"audioVolume":0,"dcResult":0,"dc":OriginalMacDisplayBackend.textDCHandle,"postResult":0]))
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
                presentation:self.presentation(common.target),drawResult:0,graphicsResult:0,allocationFill:0,allocationDefined:true,scanfLookahead:true)
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
            try self.beginInputControl()
            let ready = try input.advance(environment:&environment,controlBoundary:{ q,_ in try self.control(q) })
            self.continuationGraphics = ready.graphics.count
            return .init(menu:try self.loadedMenu(ready,target:common.target))
        },serve:{ permit,exchange in self.counts.audioRequests += 1; try service.serve(permit,on:exchange) })
        return outcome
    }
    /// One receipt journal per owned input call. A failed Core attempt can
    /// recompute against the same replies; IO already serviced is not repeated.
    /// The completed outer commit releases the journal instead of accumulating
    /// a session-long log. Offline calls keep the existing failed-socket policy.
    func beginInputControl() throws {
        guard network?.winsock.started == true else { return }
        let sequence = started.host.committedSequence
        if controlDelivery?.sequence != sequence { controlDelivery = (sequence,ControlExchange()) }
        guard let exchange = controlDelivery?.exchange else { throw Boundary.missing("control exchange") }
        controlCursor = try exchange.inlineCursor { [unowned self] permit in
            try exchange.beginService(permit)
            do { try exchange.answer(permit,response:try self.performControl(permit.request.value)) }
            catch { try exchange.fail(permit,diagnostic:String(reflecting:error));throw error }
        }
    }
    func control(_ q: OriginalInputControlRequest) throws -> OriginalInputControlResponse {
        counts.controls += 1
        switch q.kind {
        case .asyncSelect,.ioctl,.send,.receive,.message,.method,.postMessage:
            if var cursor = controlCursor {
                let response = try cursor.response(for:.init(value:q));controlCursor = cursor;return response
            }
        default:break
        }
        return try performControl(q)
    }
    private func performControl(_ q: OriginalInputControlRequest) throws -> OriginalInputControlResponse {
        switch q.kind {
        case .asyncSelect,.ioctl,.send,.receive:
            if let network { return try network.answer(q) }
            guard q.kind == .asyncSelect || q.kind == .ioctl else { throw Boundary.unexpected("offline input control \(q.kind)") }
            return .init(result:-1)
        case .message:
            guard q.arguments.count == 4,q.arguments[0] == 0,q.arguments[2] == 0x447850,q.arguments[3] == 0,q.data.isEmpty,
                  let messageBox else { throw Boundary.unexpected("control MessageBoxA") }
            return .init(result:try messageBox(OriginalMacRuntimeNetwork.controlError(q.arguments[1]),Array("Error".utf8),0))
        case .postMessage:
            guard q.arguments.count == 4,q.arguments[1] == 0x10,q.arguments[2] == 0,q.arguments[3] == 0 else { throw Boundary.unexpected("control PostMessageA") }
            if controlCursor != nil { postMessage?(q.arguments[1],q.arguments[2],q.arguments[3]) }
            return .init(result:1)
        case .method:
            if controlCursor != nil {
                let call = try OriginalMacSoundEffects.call(q.arguments)
                if started.runtime.music.interface(call.buffer) != nil {
                    _ = try started.runtime.music.answer(.init(.method,q.arguments)); counts.music += 1
                    try presentControlMusic?()
                } else if let sounds { try performSound(call,on:sounds) }
            }
            return .init() // The original ignores these method results.
        case .free:return .init() // Core owns the freed record; heap.collect adopts it.
        // Hotkey (416c70..416fad), playback-restore and input-reset notices:
        // Core performs their effects; nothing is asked of the platform.
        case .action,.restorePlayback,.inputReset,.soundRequest: return .init()
        }
    }
    func loadedMenu(_ ready: LoadedMenu.Input.PendingContinuation,target: UInt32) throws -> LoadedMenu.Outcome {
        let heap = started.runtime.heap
        heap.collect(ready.state.memory)
        pendingDocuments = []
        var menu = try LoadedMenu(pending:ready),unit: Void = ()
        return try menu.advanceUntilBoundary(inputs:menuInputs.adding(arenaInputs.bitmaps),environment:&unit,
            screenInput:.init(dcResult:0,dc:OriginalMacDisplayBackend.textDCHandle,methodResult:0,drawResults:[0],shellResult:42),
            outputInput:presentation(target),
            allocate:{ _,count,_ in self.counts.allocations += 1; return try heap.allocate(count) },
            bitmap:{ q,_ in try self.bitmap(q) },music:{ e,_ in try self.music(e) },milliseconds:{ _ in try self.time() },
            // War start (43a21f) prepares its match inside the menu call.
            localTime:{ _ in Self.localTime(self.localDate()) },
            allocateReplay:{ count,_ in self.counts.allocations += 1; return try heap.reserveReplay(count) },
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
        return MainActor.assumeIsolated { dialogs.chooseRecording(directory) }
    }
    /// MessageBoxA(NULL, text, NULL, MB_OK): Windows titles it "Error".
    func alert(_ message: [UInt8]) {
        let text = String(decoding:message,as:UTF8.self)
        playbackAlerts.append(text)
        guard playbackInteractive else { return }
        MainActor.assumeIsolated { dialogs.alert(text) }
    }
    func openDocument(_ path: String) { pendingDocuments.append(path) }
    /// Declared runtime policy for the Demo start: 4025d0 reads its track from
    /// ECX, the residue of lib.dll's text replacement (10001298), whose last
    /// instruction before returning is DirectDraw's GetDC (failure) or
    /// ReleaseDC. That register is unknown on Windows; the app declares a value
    /// outside 0..8, so the configured track in 44eed0 plays and no RNG draw is
    /// taken (APPLICATION_DEMO.md). Since GetDC succeeds (GDI text), the residue
    /// would come from ReleaseDC, equally unknown; the value stays a temporary
    /// placeholder (user decision 2026-10-01).
    static let demoMusicResidue = OriginalMacRuntimeMenu.getDCFailure
    /// A cached cycle after the first loading: the retained owners advance the
    /// cycle's input step, then either gameplay (retained as gameplay input) or
    /// the loaded menu; no catalog work repeats.
    public func runCycle() throws -> Host.LoadedOutcome {
        try beginInputControl()
        return try started.host.prepareLoadedUntilBoundary(prepare:{ context,_ in
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
            heap.collect(pending.snapshot.state.memory)
            var session = try OriginalApplicationMatchLaunchSession(pending:pending),unit: Void = ()
            // Replay keeps the cycle's continuation offset: the prelude's own draws
            // (the final selection frame) were not committed and replay with the launch.
            return try session.advance(environment:&unit,bitmaps:self.arenaInputs.bitmaps,outputInput:self.presentation(pending.loading.target),
                allocateBitmap:{ _,count,_ in self.counts.allocations += 1; return try heap.allocate(count) },
                bitmap:{ q,_ in try self.bitmap(q) },localTime:{ _ in Self.localTime(self.localDate()) },music:{ e,_ in try self.music(e) },
                allocateReplay:{ count,_ in self.counts.allocations += 1; return try heap.reserveReplay(count) },
                milliseconds:{ _ in try self.time() })
        })
    }
    /// One retained gameplay body. DDBLTFX backing for fills is zero. Without
    /// `stageCheckpoints` no per-stage snapshots are built.
    public func gameplay() throws -> LoadedMenu.PendingReturn {
        let heap = started.runtime.heap
        return try started.host.resumeGameplay(prepare:{ ready,_ in
            self.pendingReplays = []; self.openReplay = nil
            heap.collect(ready.state.memory)
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
                allocate:{ _ in self.counts.allocations += 1; return try heap.reserveReplay(OriginalReplayWriter.capacity) },
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
        let controlEffectsDelivered = controlCursor != nil
        let outcome = try started.host.finishLoadedMenu(perform:{ request,_ in
            switch request.kind {
            case .time: return .init(result:Int32(bitPattern:try self.time()))
            case .sleep:
                guard request.arguments.count == 1 else { throw Boundary.unexpected("tail Sleep arguments") }
                self.sleeps.append(request.arguments[0]); return .init()
            default: throw Boundary.unexpected("tail \(request.kind)")
            }
        })
        if case .committed = outcome,let exchange = controlDelivery?.exchange,let cursor = controlCursor {
            _ = try exchange.finish(cursor);controlCursor = nil;controlDelivery = nil
        }
        while let batch = try started.host.takeCommitted() {
            guard case .loaded(let commit) = batch.contents else { continue }
            var slept: UInt32 = 0
            for case .front(let e,_,_) in commit.operations {
                switch e.kind {
                case "postQuit": quitCodes.append(e.arguments[0])
                // The screen's own Sleep (300 before a link or a mode) blocks the original's thread.
                case "sleep" where e.arguments.count == 1: sleeps.append(e.arguments[0]); slept &+= e.arguments[0]
                case "shell":
                    guard e.arguments == [0,0,0,1],e.strings.count == 2,[Array("open".utf8),Array("explore".utf8)].contains(e.strings[0]) else {
                        throw Boundary.unexpected("ShellExecuteA \(e.arguments)")
                    }
                    try shell?(e.strings[0],e.strings[1],slept)
                default: break
                }
            }
            // Playback's Sleep(300) precedes its dialog and the open.
            for path in pendingDocuments {
                openedDocuments.append(path)
                if playbackInteractive {
                    let open = dialogs.open
                    DispatchQueue.main.asyncAfter(deadline:.now() + .milliseconds(Int(slept))) { MainActor.assumeIsolated { open(path) } }
                }
            }
            pendingDocuments = []
            counts.skippedDraws += min(continuationGraphics,commit.graphics.count)
            try replay(Array(commit.graphics.dropFirst(continuationGraphics)))
            // Preserve the recorded order across sound/music releases and the
            // final close post, as well as ordinary round and hotkey methods.
            for operation in commit.operations {
                // These effects already ran in source order in their receipts,
                // including before a later dialog or a failed Core attempt.
                if controlEffectsDelivered,case .preceding(.control(let q,_)) = operation,
                   q.kind == .method || q.kind == .postMessage { continue }
                try answerRoundMusic([operation])
                if let sounds {
                    let music = started.runtime.music
                    for call in try OriginalMacSoundEffects.calls([operation],music:{ music.interface($0) != nil }) {
                        try performSound(call,on:sounds)
                    }
                }
                if case .preceding(.control(let q,_)) = operation,q.kind == .postMessage {
                    postMessage?(q.arguments[1],q.arguments[2],q.arguments[3])
                }
            }
        }
        if case .committed = outcome, !pendingReplays.isEmpty {
            do {
                try overlay?.apply(pendingReplays)
                savedReplays += pendingReplays; counts.replayFiles += pendingReplays.count
            } catch { failedReplayWrites += pendingReplays.map { "\($0.path): \(error)" } }
            pendingReplays = []
        }
        return outcome
    }
    /// Input shutdown carries IUnknown::Release for both secondary buffers and
    /// the DirectSound device. Use the same release policy as window shutdown;
    /// a device has no PCM voice and an unused buffer need not load its samples.
    func performSound(_ call: OriginalMacSoundEffects.Call,on sounds: OriginalMacSoundEffects) throws {
        guard call.method == 8 else { try sounds.perform(call);return }
        guard call.arguments.isEmpty else { throw Boundary.unexpected("sound Release arguments") }
        if started.audio.deviceTokens.contains(call.buffer) { return }
        _ = try started.audio.observation(call.buffer)
        sounds.release(call.buffer)
    }
    /// Methods on music interface tokens — the round's music stop and the
    /// front screens' 402100 stop (a tournament's Winner screen, Music: OFF),
    /// i.e. IMediaControl::Stop and put_CurrentPosition — reach the music
    /// runtime when their batch commits, in operation order. Core already
    /// declared their results (0, ignored as by the original).
    func answerRoundMusic(_ operations: [LoadedMenu.Operation]) throws {
        let music = started.runtime.music
        for operation in operations {
            let words: [UInt32]
            switch operation {
            case .preceding(.roundMethod(let e)) where e.kind == .method: words = e.arguments
            case .preceding(.control(let q,_)) where q.kind == .method: words = q.arguments
            case .front(let e,_,_) where e.kind == "musicMethod": words = e.arguments
            default: continue
            }
            guard let token = words.first,music.interface(token) != nil else { continue }
            _ = try music.answer(.init(.method,words)); counts.music += 1
        }
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
            // GDI text: the Core declared GetDC success with the display's DC
            // handle; each call replays in order (APPLICATION_GDI_TEXT_PLAN.md).
            case "getDC","setBackgroundMode","setBackgroundColor","setTextColor","textOut","releaseDC":
                let served = try display.performFront(display.prepareFront(e))
                if e.kind == "getDC",served.response.output != OriginalMacDisplayBackend.textDCHandle { throw Boundary.unexpected("text DC") }
                counts.replayedText += 1; continue
            default: continue
            }
            // Core recorded declared success; the recovered callers ignore the
            // result, so a DDERR_INVALIDRECT Blt only leaves the pixels unchanged.
            let served = try display.performFront(display.prepareFront(e)); counts.replayedDraws += 1
            if served.response.result == OriginalMacDisplayBackend.invalidRect { counts.rejectedDraws += 1 }
        }
    }
}
