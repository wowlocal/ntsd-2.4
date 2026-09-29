import AppKit
import NTSDCore

/// Windows keyboard identity of a macOS key: virtual key, set-1 scan code and
/// the extended-key flag. US layout; Command/Option/Function are not mapped.
public struct OriginalMacRuntimeKey: Equatable {
    public let vk: UInt32, scan: UInt32, extended: Bool
    public init(_ vk: UInt32,_ scan: UInt32,_ extended: Bool = false) { self.vk = vk; self.scan = scan; self.extended = extended }
    public static let table: [UInt16:OriginalMacRuntimeKey] = {
        var t: [UInt16:OriginalMacRuntimeKey] = [:]
        let letters: [(UInt16,Character,UInt32)] = [(0x00,"A",0x1e),(0x0b,"B",0x30),(0x08,"C",0x2e),(0x02,"D",0x20),(0x0e,"E",0x12),
            (0x03,"F",0x21),(0x05,"G",0x22),(0x04,"H",0x23),(0x22,"I",0x17),(0x26,"J",0x24),(0x28,"K",0x25),(0x25,"L",0x26),
            (0x2e,"M",0x32),(0x2d,"N",0x31),(0x1f,"O",0x18),(0x23,"P",0x19),(0x0c,"Q",0x10),(0x0f,"R",0x13),(0x01,"S",0x1f),
            (0x11,"T",0x14),(0x20,"U",0x16),(0x09,"V",0x2f),(0x0d,"W",0x11),(0x07,"X",0x2d),(0x10,"Y",0x15),(0x06,"Z",0x2c)]
        for (code,c,scan) in letters { t[code] = .init(UInt32(c.asciiValue!),scan) }
        let digits: [(UInt16,UInt32)] = [(0x1d,0),(0x12,1),(0x13,2),(0x14,3),(0x15,4),(0x17,5),(0x16,6),(0x1a,7),(0x1c,8),(0x19,9)]
        for (code,d) in digits { t[code] = .init(0x30+d,d == 0 ? 0x0b : d+1) }
        let others: [(UInt16,UInt32,UInt32,Bool)] = [
            (0x24,0x0d,0x1c,false),(0x30,0x09,0x0f,false),(0x31,0x20,0x39,false),(0x33,0x08,0x0e,false),(0x35,0x1b,0x01,false),
            (0x1b,0xbd,0x0c,false),(0x18,0xbb,0x0d,false),(0x21,0xdb,0x1a,false),(0x1e,0xdd,0x1b,false),(0x29,0xba,0x27,false),
            (0x27,0xde,0x28,false),(0x32,0xc0,0x29,false),(0x2a,0xdc,0x2b,false),(0x2b,0xbc,0x33,false),(0x2f,0xbe,0x34,false),
            (0x2c,0xbf,0x35,false),(0x38,0x10,0x2a,false),(0x3c,0x10,0x36,false),(0x3b,0x11,0x1d,false),(0x3e,0x11,0x1d,true),
            (0x39,0x14,0x3a,false),(0x7b,0x25,0x4b,true),(0x7c,0x27,0x4d,true),(0x7d,0x28,0x50,true),(0x7e,0x26,0x48,true),
            (0x73,0x24,0x47,true),(0x77,0x23,0x4f,true),(0x74,0x21,0x49,true),(0x79,0x22,0x51,true),(0x75,0x2e,0x53,true),
            (0x72,0x2d,0x52,true),(0x52,0x60,0x52,false),(0x53,0x61,0x4f,false),(0x54,0x62,0x50,false),(0x55,0x63,0x51,false),
            (0x56,0x64,0x4b,false),(0x57,0x65,0x4c,false),(0x58,0x66,0x4d,false),(0x59,0x67,0x47,false),(0x5b,0x68,0x48,false),
            (0x5c,0x69,0x49,false),(0x41,0x6e,0x53,false),(0x43,0x6a,0x37,false),(0x45,0x6b,0x4e,false),(0x4e,0x6d,0x4a,false),
            (0x4b,0x6f,0x35,true),(0x4c,0x0d,0x1c,true)]
        for (code,vk,scan,ext) in others { t[code] = .init(vk,scan,ext) }
        let functions: [(UInt16,UInt32)] = [(0x7a,0),(0x78,1),(0x63,2),(0x76,3),(0x60,4),(0x61,5),(0x62,6),(0x64,7),(0x65,8),(0x6d,9),(0x67,10),(0x6f,11)]
        for (code,i) in functions { t[code] = .init(0x70+i,i < 10 ? 0x3b+i : 0x57+(i-10)) }
        return t
    }()
}

/// The application thread's message queue for the original window, fed from
/// AppKit events and served to whole-iteration permits. Declared runtime
/// behavior; not a Windows observation. Only messages the recovered WndProc
/// accepts are generated: WM_KEYDOWN/KEYUP/CHAR, mouse 200/201/202/204/205,
/// the music graph notification registered with SetNotifyWindow (0x400), and
/// the quit path (APPLICATION_WINDOW_CLOSE_PLAN.md): WM_SYSCOMMAND(SC_CLOSE)
/// from the close button, WM_CLOSE, WM_DESTROY, WM_NCDESTROY and WM_QUIT.
@MainActor public final class OriginalMacRuntimeMessages {
    public typealias Loop = OriginalApplicationMessageLoop
    public enum Boundary: Error, Equatable { case unsupported(String), emptyGet, arguments(String) }
    public struct Message: Equatable {
        public let message: UInt32, wParam: UInt32, lParam: UInt32, time: UInt32, x: Int32, y: Int32
    }
    public let window: UInt32
    private let clock: () throws -> UInt32, point: () -> (Int32,Int32)
    public private(set) var queue: [Message] = []
    public private(set) var sleeps: [UInt32] = []
    public private(set) var delivered: [Message] = []
    private var down: Set<UInt32> = []
    public init(window: UInt32,clock: @escaping () throws -> UInt32,point: @escaping () -> (Int32,Int32) = { (0,0) }) {
        self.window = window; self.clock = clock; self.point = point
    }
    func now() -> UInt32 { (try? clock()) ?? 0 }
    public func post(_ message: UInt32,_ wParam: UInt32,_ lParam: UInt32) {
        // A destroyed window receives nothing; WM_QUIT belongs to the thread.
        guard !destroyed || message == 0x12 else { return }
        let (x,y) = point(); queue.append(.init(message:message,wParam:wParam,lParam:lParam,time:now(),x:x,y:y))
    }
    /// Messages Windows sends synchronously from DefWindowProcA; here they are
    /// the next queued messages, dispatched before any game tick.
    private func next(_ messages: [UInt32]) {
        let (x,y) = point()
        queue.insert(contentsOf:messages.map { Message(message:$0,wParam:0,lParam:0,time:now(),x:x,y:y) },at:0)
    }
    /// MessageBoxA(text, caption, type) → IDOK/IDYES/IDNO; set by the app.
    public var messageBox: (([UInt8],[UInt8],UInt32) throws -> Int32)?
    /// COM Release of a sound or music object (IUnknown::Release, offset 8).
    public var release: ((UInt32) throws -> Void)?
    /// DestroyWindow completed (WM_NCDESTROY answered): the app hides its window.
    public var destroyedWindow: () -> Void = {}
    public private(set) var destroyed = false
    /// The window's close button: WM_SYSCOMMAND with SC_CLOSE.
    public func close() { post(0x112,0xf060,0) }
    /// lParam: repeat 1, scan code, extended bit24, previous-state bit30, transition bit31.
    public func key(_ key: OriginalMacRuntimeKey,down isDown: Bool,repeated: Bool = false,characters: String? = nil) {
        let base = 1 | key.scan << 16 | (key.extended ? 1 << 24 : 0)
        if isDown {
            let previous = repeated || down.contains(key.vk)
            down.insert(key.vk)
            post(0x100,key.vk,base | (previous ? 1 << 30 : 0))
            pendingCharacter[key.vk] = Self.character(key,characters)
        } else {
            down.remove(key.vk); post(0x101,key.vk,base | 1 << 30 | 1 << 31)
        }
    }
    private var pendingCharacter: [UInt32:UInt32?] = [:]
    static func character(_ key: OriginalMacRuntimeKey,_ characters: String?) -> UInt32? {
        switch key.vk {
        case 0x08,0x09,0x0d,0x1b: return key.vk
        default: break
        }
        guard let scalar = characters?.unicodeScalars.first,characters?.unicodeScalars.count == 1 else { return nil }
        let v = scalar.value
        return (0x20...0x7e).contains(v) || (0x01...0x1a).contains(v) ? v : nil
    }
    /// WM_MOUSEMOVE is coalesced: at most one pending move keeps the latest point.
    public func mouse(_ message: UInt32,x: Int32,y: Int32,buttons: UInt32) {
        let packed = UInt32(UInt16(truncatingIfNeeded:x)) | UInt32(UInt16(truncatingIfNeeded:y)) << 16
        if message == 0x200,let i = queue.lastIndex(where: { $0.message == 0x200 }),i == queue.count-1 {
            queue[i] = .init(message:0x200,wParam:buttons,lParam:packed,time:now(),x:queue[i].x,y:queue[i].y); return
        }
        post(message,buttons,packed)
    }
    func bytes(_ m: Message) -> [UInt8] {
        [window,m.message,m.wParam,m.lParam,m.time,UInt32(bitPattern:m.x),UInt32(bitPattern:m.y)].flatMap { w in (0..<4).map { UInt8(truncatingIfNeeded:w >> ($0*8)) } }
    }
    public func answer(_ q: Loop.Request) throws -> Loop.Response {
        switch q.kind {
        case .peek:
            guard q.arguments == [0,0,0,0] else { throw Boundary.arguments("PeekMessage") }
            guard let head = queue.first else { return .init(result:0) }
            return .init(result:1,writes:[.init(offset:0,bytes:bytes(head))])
        case .get:
            guard q.arguments == [0,0,0] else { throw Boundary.arguments("GetMessage") }
            guard !queue.isEmpty else { throw Boundary.emptyGet }
            let head = queue.removeFirst(); delivered.append(head)
            return .init(result:head.message == 0x12 ? 0 : 1,writes:[.init(offset:0,bytes:bytes(head))])
        case .translate:
            guard let bytes = q.message,bytes.count == 28 else { throw Boundary.arguments("TranslateMessage") }
            let r = try OriginalStateRecord(bytes:bytes,defined:Array(repeating:true,count:28))
            let message = try r.integer(at:4,as:UInt32.self),wParam = try r.integer(at:8,as:UInt32.self),lParam = try r.integer(at:12,as:UInt32.self)
            guard (0x100...0x105).contains(message) else { return .init(result:0) }
            if message == 0x100,let value = pendingCharacter[wParam] ?? nil {
                // Posted WM_CHAR precedes later hardware input.
                let (x,y) = point()
                queue.insert(.init(message:0x102,wParam:value,lParam:lParam,time:now(),x:x,y:y),at:0)
            }
            return .init(result:1)
        case .dispatchMessage: return .init()
        case .time: return .init(result:Int32(bitPattern:try clock()))
        case .sleep:
            guard q.arguments.count == 1 else { throw Boundary.arguments("Sleep") }
            sleeps.append(q.arguments[0]); return .init()
        case .gameDispatch,.recoverSurface: throw Boundary.unsupported(q.kind.rawValue)
        }
    }
    /// DefWindowProcA for the generated key/char/mouse and graph messages
    /// returns 0. The quit path follows the declared Windows behaviour of
    /// APPLICATION_WINDOW_CLOSE_PLAN.md: SC_CLOSE delivers WM_CLOSE, WM_CLOSE
    /// destroys the window (WM_DESTROY, WM_NCDESTROY), messages queued for the
    /// destroyed window are dropped, PostQuitMessage queues WM_QUIT.
    public func answer(_ q: OriginalWindowInput.Request) throws -> Int32 {
        func require(_ valid: Bool) throws { if !valid { throw Boundary.arguments("\(q.kind) \(q.arguments)") } }
        switch q.kind {
        case .windowDefault:
            try require(q.arguments.count == 4 && q.arguments[0] == window)
            switch q.arguments[1] {
            case 0x100,0x101,0x102,0x200,0x201,0x202,0x204,0x205,0x400: return 0
            case 0x112 where q.arguments[2] & 0xfff0 == 0xf060: next([0x10]); return 0
            case 0x10:
                try require(!destroyed)
                destroyed = true; queue.removeAll { $0.message != 0x12 }; next([2,0x82]); return 0
            case 0x82: destroyedWindow(); return 0
            default: throw Boundary.unsupported("DefWindowProc \(q.arguments[1])")
            }
        case .message:
            try require(q.arguments.count == 2 && q.arguments[0] == window && q.strings.count == 2)
            guard let messageBox else { throw Boundary.unsupported("MessageBoxA") }
            return try messageBox(q.strings[0],q.strings[1],q.arguments[1])
        case .method:
            try require(q.arguments.count == 2 && q.arguments[1] == 8 && q.strings.isEmpty)
            guard let release else { throw Boundary.unsupported("Release") }
            try release(q.arguments[0]); return 0
        case .free: try require(q.arguments.count == 1); return 0
        case .postMessage:
            try require(q.arguments.count == 4 && q.arguments[0] == window)
            post(q.arguments[1],q.arguments[2],q.arguments[3]); return 1
        case .postQuit: try require(q.arguments.count == 1); post(0x12,q.arguments[0],0); return 0
        }
    }
    public func serve<P>(_ permit: OriginalApplicationIterationExchange.Permit,on driver: OriginalApplicationObservedIteration<P>) throws {
        if case .graphics = permit.request { throw Boundary.unsupported("graphics family") }
        try driver.beginService(permit)
        do {
            switch permit.request {
            case .queue(let q): try driver.answer(permit,response:.queue(try answer(q)))
            case .windowDefault(let q): try driver.answer(permit,response:.windowDefault(try answer(q)))
            case .graphics,.graph: throw Boundary.unsupported("graphics/graph family")
            }
        } catch { try driver.fail(permit,diagnostic:String(reflecting:error)); throw error }
    }
}
