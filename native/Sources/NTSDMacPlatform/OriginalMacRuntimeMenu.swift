import AppKit
import NTSDCore

/// Advances the recovered front menu one whole Host iteration at a time after
/// runtime startup. Every external request is a permit served by the display/
/// bitmap services or the runtime message queue. Declared runtime policies:
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
    public let bitmap: OriginalMacBitmapService, front: OriginalMacFrontService
    public let initialization: OriginalApplicationBootstrap.MenuInputs
    /// OutputDebugStringA text and MessageBoxA (text, caption) requests seen so far.
    public final class Diagnostics {
        public fileprivate(set) var debug: [[UInt8]] = [], messages: [[[UInt8]]] = []
        /// Presents MessageBoxA; returns IDOK.
        public var present: ([UInt8],[UInt8]) -> Void = { text,caption in
            let alert = NSAlert(); alert.messageText = String(decoding:caption,as:UTF8.self)
            alert.informativeText = String(decoding:text,as:UTF8.self); alert.runModal()
        }
    }
    public let diagnostics = Diagnostics()
    public private(set) var iterations = 0, requests = 0, textRequests = 0, emptyBlits = 0
    /// The request being served when a step last stopped, for boundary reports.
    public private(set) var lastRequest: OriginalApplicationIterationRequest?
    private let clock: () throws -> UInt32

    /// Runtime first-menu inputs. The worker thread named by the identities is
    /// not run (no network updater); lastError is 0; allocations come from the
    /// runtime heap; settings are the packaged text-mode control.txt bytes.
    public static func initialization(_ started: OriginalMacRuntimeStartup.Started,
        inputs: OriginalApplicationStartupInputs,milliseconds: UInt32) throws -> OriginalApplicationBootstrap.MenuInputs {
        let heap = started.runtime.heap,ids = started.windows.identities
        let file = try heap.allocate(32).address,scratch = try heap.allocate(4096).address
        let front = try (0..<24).map { _ in try heap.allocate(0x1f50) },background = try heap.allocate(0x1f50)
        return .init(settings:.init(bytes:try inputs.controlBytes(),file:file,scratchAddress:scratch,closeResult:0),
            prefix:.init(drawTarget:0,milliseconds:milliseconds,threadHandle:try ids.take(),threadID:try ids.take(),
                lastError:0,fillResult:0,drawResults:[0]),
            body:.init(dcResult:getDCFailure,dc:0,methodResult:0,drawResults:[0],shellResult:42),
            frontAllocations:front,backgroundAllocation:background,frontResponses:[],backgroundResponses:[],
            bitmapResources:inputs.bitmaps)
    }
    public init(_ started: OriginalMacRuntimeStartup.Started,inputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32,point: @escaping () -> (Int32,Int32) = { (0,0) }) throws {
        host = started.host; self.clock = clock; music = started.runtime.music
        messages = OriginalMacRuntimeMessages(window:started.window,clock:clock,point:point)
        initialization = try Self.initialization(started,inputs:inputs,milliseconds:clock())
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
    }
    func inputs(_ state: Host.Session.State) -> Host.Inputs {
        .init(initialization:state.settings == nil ? initialization : nil,
            responses:.init(draw:0,presentation:0,sound:0,release:0,dcResult:Self.getDCFailure,dc:0),queue:[])
    }
    /// One committed iteration (or `.loading`). Committed batches are drained;
    /// their device effects were already performed when their permits were
    /// served, except sound methods, which have no permit and play on commit.
    public func step(maximumRequests: Int = 20000) throws -> Host.Outcome {
        let driver = Driver(host:host)
        for _ in 0..<maximumRequests {
            switch try driver.resume(prepare:{ _,state in self.inputs(state) }) {
            case .request(let permit):
                requests += 1; lastRequest = permit.request
                switch permit.request {
                case .graphics(.bitmap): try bitmap.serve(permit,on:driver)
                case .graphics(.front(_,let q)) where q.kind == "getDC":
                    textRequests += 1
                    try driver.beginService(permit); try driver.answer(permit,response:.graphics(.front(.init(result:Self.getDCFailure))))
                case .graphics(.window(let q)) where q.kind == "windowDefault":
                    // Lifecycle DefWindowProcA; WM_MOVE is the only generated caller.
                    guard q.words.count == 4,q.words[0] == messages.window,q.words[1] == 3 else { throw Boundary.unserved("DefWindowProc \(q.words)") }
                    try driver.beginService(permit); try driver.answer(permit,response:.graphics(.window(.init(result:0))))
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
                }
            case .advanced(let outcome):
                iterations += 1
                while let batch = try host.takeCommitted() {
                    guard let sounds,case .iteration(let committed) = batch.contents else { continue }
                    for call in try OriginalMacSoundEffects.calls(committed.effects) { try sounds.perform(call) }
                }
                return outcome
            }
        }
        try driver.cancel(); throw Boundary.requestBound(maximumRequests)
    }
}
