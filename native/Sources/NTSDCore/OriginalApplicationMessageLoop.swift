/// Original43d100..43d21f message-loop decisions and return value. Platform
/// delivery, dispatcher/recovery bodies and macOS event translation are explicit
/// operations. A Context must own value-semantic state; external effects are
/// buffered until this entire iteration commits.
public struct OriginalApplicationMessageLoop {
    public struct Write: Codable, Equatable, Sendable {
        public let offset: Int,bytes: [UInt8]
        public init(offset: Int,bytes: [UInt8]) { self.offset = offset;self.bytes = bytes }
    }
    public struct Request: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case peek,get,translate,dispatchMessage,time,gameDispatch,recoverSurface,sleep }
        public let kind: Kind,arguments: [UInt32],message: [UInt8]?,defined: [Bool]?
        public init(_ kind: Kind,_ arguments: [UInt32] = [],message: OriginalStateRecord? = nil) {
            self.kind = kind;self.arguments = arguments;self.message = message?.bytes;self.defined = message?.defined
        }
    }
    public struct Response: Codable, Equatable, Sendable {
        public let result: Int32,writes: [Write]
        public init(result: Int32 = 0,writes: [Write] = []) { self.result = result;self.writes = writes }
    }
    public enum Result: Equatable { case continued,quit(UInt32) }
    public private(set) var timer: OriginalApplicationTimer
    public private(set) var counter: UInt32
    public private(set) var message: OriginalStateRecord
    /// Baseline comes from own startup's timeGetTime/srand result. Counter is the
    /// separately owned458580 word. Native stack backing is initially unknown.
    public init(baseline: UInt32,counter: UInt32) throws {
        timer = .init(baseline:baseline);self.counter = counter
        message = try .init(bytes:[UInt8](repeating:0,count:28),defined:[Bool](repeating:false,count:28))
    }
    /// One complete iteration. GetMessage uses an exact zero test: a negative
    /// result still reaches TranslateMessage and DispatchMessage with retained
    /// MSG bytes. Zero reads wParam before the epilogue and skips counter update.
    public mutating func step<Context>(context: inout Context,
        speed: (Context) throws -> Int32,target: (Context) throws -> UInt32,
        perform: (Request,inout Context) throws -> Response,
        counterWritten: (UInt32) throws -> Void = { _ in },
        beforeCommit: (Self,Context,Result) throws -> Void = { _,_,_ in }) throws -> Result {
        var next = self,staged = context
        func call(_ kind: Request.Kind,_ args: [UInt32] = [],message: OriginalStateRecord? = nil) throws -> Response {
            let response = try perform(.init(kind,args,message:message),&staged)
            if kind != .peek && kind != .get && !response.writes.isEmpty {
                throw OriginalStateError.invalidStorage("Only message retrieval owns MSG output writes")
            }
            return response
        }
        func output(_ response: Response,_ record: inout OriginalStateRecord) throws {
            for w in response.writes {
                guard w.offset >= 0,w.offset <= 28-w.bytes.count else { throw OriginalStateError.invalidStorage("MSG output extent") }
                for (i,b) in w.bytes.enumerated() { try record.write(b,at:w.offset+i) }
            }
        }
        let peek = try call(.peek,[0,0,0,0],message:next.message);try output(peek,&next.message)
        let result: Result
        if peek.result != 0 {
            let get = try call(.get,[0,0,0],message:next.message);try output(get,&next.message)
            if get.result == 0 {
                result = .quit(try next.message.integer(at:8,as:UInt32.self))
                try beforeCommit(next,staged,result);self = next;context = staged;return result
            }
            _ = try call(.translate,message:next.message)
            _ = try call(.dispatchMessage,message:next.message)
        } else {
            try next.timer.iterate(speedFlag:speed(staged),time:{ UInt32(bitPattern:try call(.time).result) },target:{ try target(staged) },
                dispatch:{ try call(.gameDispatch,[$0]).result },recoverSurface:{ _ = try call(.recoverSurface) },sleep:{ _ = try call(.sleep,[$0]) })
        }
        next.counter &+= 1;try counterWritten(next.counter)
        if Int32(bitPattern:next.counter) > 60 { next.counter = 0;try counterWritten(0) }
        result = .continued
        try beforeCommit(next,staged,result);self = next;context = staged;return result
    }
}
