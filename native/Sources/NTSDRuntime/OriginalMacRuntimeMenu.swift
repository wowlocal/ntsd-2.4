import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import NTSDCore

/// Advances the recovered front menu one whole Host iteration at a time after
/// runtime startup. Every external request is served by the display/bitmap
/// services or the runtime message queue: queue requests and the back-buffer
/// clear (window Blt) inside the Host attempt (CORE_REALTIME M2), the others as
/// permits. Declared runtime policies:
/// GetDC for text fails (E_FAIL) until a GDI text contract exists, so the game
/// omits text; OutputDebugStringA is recorded; MessageBoxA shows an alert.
@MainActor public final class OriginalMacRuntimeMenu {
    public typealias P = OriginalApplicationPreparedStartupPlatform
    public typealias Host = OriginalApplicationHostSession<P>
    public typealias Driver = OriginalApplicationObservedIteration<P>
    public enum Boundary: Error, Equatable { case requestBound(Int), unserved(String) }
    public static let getDCFailure: Int32 = -2147467259 // E_FAIL
    /// DDERR_INVALIDRECT for a zero-area Blt; unobserved on Windows, and the
    /// recovered callers ignore this draw result. No pixels change.
    public static let invalidRect = Int32(bitPattern:0x88760096)
    static func empty(_ b: OriginalBitmapBlit?) -> Bool {
        guard let b,b.source.count == 4,b.destination.count == 4 else { return false }
        return b.destination[2] <= b.destination[0] || b.destination[3] <= b.destination[1] ||
            b.source[2] <= b.source[0] || b.source[3] <= b.source[1]
    }
    public let host: Host, messages: OriginalMacRuntimeMessages, music: OriginalMacRuntimeMusic
    /// DirectSound buffer methods of committed iterations are performed here.
    public var sounds: OriginalMacSoundEffects?
    /// data\control.txt as the game reads it (text mode: CRLF → LF): the
    /// overlay's copy when the player has saved settings, else the packaged
    /// file. CONTROL SETTINGS' OK writes it back to the overlay (LF → CRLF, as
    /// Windows text mode writes); Cancel re-reads it.
    public private(set) var controlFile: [UInt8]
    public private(set) var savedSettings = 0
    public let overlay: OriginalMacRuntimeOverlay?
    /// A reserved 0x1f50 allocation offered for a front background reload;
    /// replaced once an iteration commits its `.allocate`.
    private var background: OriginalInterfaceAllocation?
    private let heap: OriginalMacRuntimeHeap
    /// GetKeyState(VK_CAPITAL): the Caps Lock toggle (1 on, 0 off), read from the host.
    public var capsLock: () -> Int32
    static func textRead(_ raw: [UInt8]) -> [UInt8] {
        var result: [UInt8] = [],index = 0
        while index < raw.count {
            if raw[index] == 13,index+1 < raw.count,raw[index+1] == 10 { index += 1 }
            result.append(raw[index]);index += 1
        }
        return result
    }
    static func textWrite(_ bytes: [UInt8]) -> [UInt8] { bytes.flatMap { $0 == 10 ? [13,10] : [$0] } }
    public let bitmap: OriginalMacBitmapService, front: OriginalMacFrontService
    /// Live Winsock for ONLINE GAME (NETWORK_PLAY_PLAN.md N2); nil keeps the
    /// declared no-network stand-in (WSAStartup wVersion 0).
    public var network: OriginalMacRuntimeNetwork?
    public let initialization: OriginalApplicationBootstrap.MenuInputs
    /// OutputDebugStringA text and MessageBoxA (text, caption) requests seen so far.
    public final class Diagnostics {
        public fileprivate(set) var debug: [[UInt8]] = [], messages: [[[UInt8]]] = []
        /// Presents MessageBoxA (text, caption); returns IDOK.
        public var present: ([UInt8],[UInt8]) -> Void
        init(present: @escaping ([UInt8],[UInt8]) -> Void) { self.present = present }
    }
    public let diagnostics: Diagnostics
    public private(set) var iterations = 0, requests = 0, textRequests = 0, emptyBlits = 0
    /// The request being served when a step last stopped, for boundary reports.
    public private(set) var lastRequest: OriginalApplicationIterationRequest?
    /// Serve message-queue requests and the window Blt inside the Host attempt
    /// (CORE_REALTIME M2); false keeps every request a permit (one attempt per
    /// request).
    public var servesQueueInline = true
    /// Idle iterations (no message, the timer not due) through the Host's
    /// kernel (CORE_REALTIME A1); false keeps the whole step for every
    /// iteration (the reference path for tests).
    public var servesIdleDirectly = true
    private let clock: () throws -> UInt32

    /// Runtime first-menu inputs. The worker thread named by the identities is
    /// not run (no network updater); lastError is 0; allocations come from the
    /// runtime heap; settings are the packaged text-mode control.txt bytes.
    public static func initialization(_ started: OriginalMacRuntimeStartup.Started,
        inputs: OriginalApplicationStartupInputs,milliseconds: UInt32,controlFile: [UInt8]? = nil) throws -> OriginalApplicationBootstrap.MenuInputs {
        let heap = started.runtime.heap,ids = started.windows.identities
        let file = try heap.allocate(32).address,scratch = try heap.allocate(4096).address
        let front = try (0..<24).map { _ in try heap.allocate(0x1f50) },background = try heap.allocate(0x1f50)
        return .init(settings:.init(bytes:try controlFile ?? inputs.controlBytes(),file:file,scratchAddress:scratch,closeResult:0),
            prefix:.init(drawTarget:0,milliseconds:milliseconds,threadHandle:try ids.take(),threadID:try ids.take(),
                lastError:0,fillResult:0,drawResults:[0]),
            body:.init(dcResult:0,dc:OriginalMacDisplayBackend.textDCHandle,methodResult:0,drawResults:[0],shellResult:42),
            frontAllocations:front,backgroundAllocation:background,frontResponses:[],backgroundResponses:[],
            bitmapResources:inputs.bitmaps)
    }
    public init(_ started: OriginalMacRuntimeStartup.Started,inputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32,point: @escaping () -> (Int32,Int32) = { (0,0) },overlay: OriginalMacRuntimeOverlay? = nil,
        capsLock: @escaping () -> Int32,messageBox: @escaping ([UInt8],[UInt8]) -> Void) throws {
        self.capsLock = capsLock; diagnostics = Diagnostics(present:messageBox)
        host = started.host; self.clock = clock; music = started.runtime.music; self.overlay = overlay; heap = started.runtime.heap
        let control = try overlay?.read("data\\control.txt").map(Self.textRead) ?? inputs.controlBytes()
        controlFile = control
        messages = OriginalMacRuntimeMessages(window:started.window,clock:clock,point:point)
        initialization = try Self.initialization(started,inputs:inputs,milliseconds:clock(),controlFile:control)
        // CreateWindowEx sends WM_SIZE then WM_MOVE; the startup model does not run
        // those synchronous WndProc calls, so they are delivered first here.
        let client = try started.windows.displayGeometry(started.window).clientInDesktop
        func word(_ low: CGFloat,_ high: CGFloat) -> UInt32 {
            UInt32(UInt16(truncatingIfNeeded:Int(low))) | UInt32(UInt16(truncatingIfNeeded:Int(high))) << 16
        }
        messages.post(5,0,word(client.width,client.height)); messages.post(3,0,word(client.minX,client.minY))
        let display = started.display,d = diagnostics
        front = OriginalMacFrontService(backend:display,diagnostic:{ q in d.debug.append(q.strings[0]); return .init(result:0) })
        bitmap = OriginalMacBitmapService(backend:display,inputs:.init(resources:inputs.bitmaps,
            files:Dictionary(uniqueKeysWithValues:inputs.bitmaps.keys.map { ($0,OriginalMacDisplayBackend.BitmapInputs.File.missing) })),
            diagnostic:{ q in
                if q.kind == "debug" { d.debug.append(q.strings[0]); return .init(result:0) }
                d.messages.append(q.strings); d.present(q.strings[0],q.strings[1]); return .init(result:1)
            })
        // Release on the quit path: DirectShow interfaces to the music runtime,
        // sound buffers stop their voices, the DirectSound device has no state.
        let music = started.runtime.music,audio = started.audio
        messages.release = { [weak self] token in
            if music.interface(token) != nil { _ = try music.answer(.init(.method,[token,8])); return }
            if (try? audio.observation(token)) != nil { self?.sounds?.release(token); return }
            guard audio.deviceTokens.contains(token) else { throw Boundary.unserved("Release \(token)") }
        }
    }
    func inputs(_ state: Host.Session.State) throws -> Host.Inputs {
        if state.settings != nil,background == nil { background = try heap.allocate(0x1f50) }
        return .init(initialization:state.settings == nil ? initialization : nil,
            responses:.init(draw:0,presentation:0,sound:0,release:0,dcResult:0,dc:OriginalMacDisplayBackend.textDCHandle,controlFile:controlFile,
                            capsLock:capsLock(),background:state.settings == nil ? nil : background),queue:[])
    }
    /// One committed iteration (or `.loading`). Committed batches are drained;
    /// their device effects were already performed when their permits were
    /// served, except sound methods, which have no permit and play on commit.
    public func step(maximumRequests: Int = 20000) throws -> Host.Outcome {
        let driver = Driver(host:host)
        // Message-queue requests and the window Blt are served inside the
        // attempt (CORE_REALTIME M2) instead of unwinding and re-running it for
        // each one; the same requests are counted and answered in the same
        // order. The bound is kept: the request that reaches it goes through
        // the permit path.
        var served = 0
        let inline = servesQueueInline ? Driver.Inline(accepts:{ q in
            switch q {
            case .queue: return served+1 < maximumRequests
            // The window Blt (M2b): the dispatch entry's back-buffer clear each
            // iteration, ArtSetup's and Alt+Enter's clears. It takes the permit
            // arm's generic graphics service, with no counter of its own; its
            // target is always the back buffer, so it fills and presents nothing.
            case .graphics(.window(let w)) where w.kind == "blt": return served+1 < maximumRequests
            default: return false
            }
        },serve:{ [unowned self] permit,exchange in
            served += 1; requests += 1; lastRequest = permit.request
            if case .graphics = permit.request { try front.serve(permit,on:exchange) }
            else { try messages.serve(permit,on:exchange) }
        },direct:{ [unowned self] q in
            // The idle attempt's queue requests without a permit (CORE_REALTIME
            // A3 L4a): the bound, counters and answer of the two closures above.
            guard served+1 < maximumRequests else { return nil }
            served += 1; requests += 1; lastRequest = .queue(q)
            return try messages.answer(q)
        }) : nil
        while served < maximumRequests {
            // No beforeCommit observer here: the menu session skips the merged
            // copy of its state made for one (CORE_REALTIME A0).
            let resumed = try servesQueueInline && servesIdleDirectly
                ? driver.resumeIdleFirst(prepare:{ _,state in try self.inputs(state) },network:network != nil,inline:inline)
                : driver.resume(prepare:{ _,state in try self.inputs(state) },observesCommit:false,network:network != nil,inline:inline)
            switch resumed {
            case .request(let permit):
                served += 1; requests += 1; lastRequest = permit.request
                switch permit.request {
                case .graphics(.bitmap): try bitmap.serve(permit,on:driver)
                case .graphics(.front(_,let q)) where q.kind == "getDC":
                    // GDI text through the display's surface DC (APPLICATION_GDI_TEXT_PLAN.md).
                    textRequests += 1; try front.serve(permit,on:driver)
                case .graphics(.window(let q)) where q.kind == "windowDefault":
                    // Lifecycle DefWindowProcA: WM_MOVE, and WM_SYSKEYUP other than
                    // Alt+Enter (SC_KEYMENU after Alt alone), on the queue's rules.
                    guard q.words.count == 4,q.words[0] == messages.window || messages.formerWindows.contains(q.words[0]),
                          [3,0x105].contains(q.words[1]) else { throw Boundary.unserved("DefWindowProc \(q.words)") }
                    let result = try messages.answer(OriginalWindowInput.Request(.windowDefault,q.words))
                    try driver.beginService(permit); try driver.answer(permit,response:.graphics(.window(.init(result:result))))
                case .graphics(.front(_,let q)) where q.kind == "blit" && Self.empty(q.blit):
                    // Zero-area draws follow from untouched zero wrapper words (+0c/negative frames).
                    emptyBlits += 1
                    try driver.beginService(permit); try driver.answer(permit,response:.graphics(.front(.init(result:Self.invalidRect))))
                case .graphics: try front.serve(permit,on:driver)
                case .queue,.windowDefault: try messages.serve(permit,on:driver)
                case .graph(let q):
                    try driver.beginService(permit)
                    do { try driver.answer(permit,response:.graph(try music.graph(q))) }
                    catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                case .network(let e):
                    guard let network else { throw Boundary.unserved("network \(e.kind)") }
                    try driver.beginService(permit)
                    do { try driver.answer(permit,response:.network(try network.answer(e))) }
                    catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                case .socket(let q):
                    guard let network else { throw Boundary.unserved("socket \(q.kind)") }
                    try driver.beginService(permit)
                    do { try driver.answer(permit,response:.socket(try network.answer(q))) }
                    catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                case .client(let q):
                    guard let network else { throw Boundary.unserved("client \(q.kind)") }
                    try driver.beginService(permit)
                    do { try driver.answer(permit,response:.client(try network.answer(q))) }
                    catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                case .networkExit(let q):
                    guard let network else { throw Boundary.unserved("network exit \(q.kind)") }
                    try driver.beginService(permit)
                    do { try driver.answer(permit,response:.networkExit(try network.answer(q))) }
                    catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
                }
            case .advanced(let outcome):
                iterations += 1
                while let batch = try host.takeCommitted() {
                    guard case .iteration(let committed) = batch.contents else { continue }
                    for case .allocate(let address,_) in committed.effects where address == background?.address { background = nil }
                    for case .settingsFile(let bytes) in committed.effects {
                        controlFile = bytes; savedSettings += 1
                        try overlay?.apply([.init(path:"data\\control.txt",bytes:Self.textWrite(bytes))])
                    }
                    if let sounds { for call in try OriginalMacSoundEffects.calls(committed.effects) { try sounds.perform(call) } }
                    // Window calls the original makes after this iteration's sounds; a
                    // ShellExecuteA waits for the Sleep time that precedes it.
                    var slept: UInt32 = 0
                    for effect in committed.effects {
                        switch effect {
                        case .sleep(let milliseconds): slept &+= milliseconds
                        case .deferredWindow(let q): try messages.deferred(q,afterMilliseconds:slept)
                        default: break
                        }
                    }
                }
                return outcome
            }
        }
        try driver.cancel(); throw Boundary.requestBound(maximumRequests)
    }
}
