import Foundation

public struct OriginalFrontScreenAlternateInput: Codable, Sendable {
    public let selector: Int32, drawTarget: UInt32, timers: [UInt32], methodResult: Int32, drawResults: [Int32], fillResult: Int32
    public let threadHandle: UInt32, threadID: UInt32, lastError: UInt32
    public init(selector: Int32,drawTarget: UInt32,timers: [UInt32],methodResult: Int32,drawResults: [Int32],fillResult: Int32,threadHandle: UInt32,threadID: UInt32,lastError: UInt32) {
        self.selector = selector;self.drawTarget = drawTarget;self.timers = timers;self.methodResult = methodResult;self.drawResults = drawResults
        self.fillResult = fillResult;self.threadHandle = threadHandle;self.threadID = threadID;self.lastError = lastError
    }
}

///4275cb..42790f: original information-panel settings and waiting screen.
///The first selector is the actual caller's EAX, not a fresh read of44d064.
///Shared writer/drawing/fill children receive the caller's own state/resources.
public enum OriginalFrontScreenAlternate {
    public enum Continuation: String, Codable, Sendable {
        case mainMenu, otherSelector, presentation, nullBitmap, nullDrawTarget, nullFillTarget, nullSettingsFile, unterminatedSettingsName
    }
    private struct Stop: Error { let end: Continuation }
    public static func advance(globals: inout OriginalStateRecord,input: OriginalFrontScreenAlternateInput,
        draw: ([UInt32]) throws -> Void,fill: ([UInt32]) throws -> Void,
        writeSettings: (inout OriginalStateRecord) throws -> OriginalSettingsWriting.Result,
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Continuation {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else { throw OriginalStateError.invalidStorage("Alternate globals extent") }
        var state = globals,timerIndex = 0
        let base = OriginalMatchPreparation.globalBase
        func bits(_ n: Int32) -> UInt32 { UInt32(bitPattern: n) }
        func word(_ address: Int) throws -> Int32 { try state.integer(at: address-base,as: Int32.self) }
        func store(_ address: Int,_ n: Int32) throws { try state.write(n,at: address-base);try observe(.init("write",[UInt32(address),4,bits(n)])) }
        func clicked() throws -> Bool { try word(0x44d060) == 0 && word(0x457580) == 1 }
        func timer() throws -> UInt32 {
            guard input.timers.indices.contains(timerIndex) else { throw OriginalStateError.invalidStorage("Missing alternate timer input") }
            let n = input.timers[timerIndex];timerIndex += 1;try observe(.init("timer",[n]));return n
        }
        func bitmap(_ slot: Int,_ x: Int32,_ y: Int32,_ frame: Int32) throws {
            let args = try [bits(word(slot)),bits(x),bits(y),bits(frame),1,0,input.drawTarget]
            try observe(.init("draw",args));guard args[0] != 0 else { throw Stop(end: .nullBitmap) }
            do { try draw(args) }
            catch OriginalStateError.invalidStorage(let detail) where detail == "Null bitmap target surface" { throw Stop(end: .nullDrawTarget) }
        }
        func sound(_ slot: Int) throws {
            try OriginalMatchPrelude.playSound(in: state,slot: slot) { e in
                switch e {
                case .soundRequest(let loop):try observe(.init("soundRequest",[loop ? 1 : 0]))
                case .soundMethod(let resource,let offset,let args):try observe(.init("soundMethod",[resource,UInt32(offset)]+args))
                default:throw OriginalStateError.invalidStorage("Alternate sound event")
                }
            }
        }
        func save() throws {
            try observe(.init("call",[0x423230]))
            switch try writeSettings(&state) {
            case .returned(let n):try observe(.init("return",[0x423230,n]))
            case .nullFile:throw Stop(end: .nullSettingsFile)
            case .unterminatedName:throw Stop(end: .unterminatedSettingsName)
            }
        }
        func finish(_ end: Continuation) -> Continuation { globals = state;return end }
        do {
            if input.selector == -3 {
                var y = try word(0x4511f4)
                if y == 0 { y = 96 }
                else {
                    let high = Int32((Int64(-715827883)*Int64(y &+ 90)) >> 32)
                    y = y &+ high &+ Int32(bits(high) >> 31);try store(0x4511f4,y)
                }
                try bitmap(0x4511a0,155,y,1);try bitmap(0x451188,75,y &+ 100,0)
                func option(_ x: Int32,_ extent: UInt32) throws -> Bool {
                    try bits(word(0x4546f0) &- x) <= extent && word(0x453cdc) > y &+ 174 && word(0x453cdc) < y &+ 203
                }
                if try option(209,233) {
                    try bitmap(0x451188,209,y &+ 174,3)
                    if try clicked() {
                        try store(0x457580,0);try store(0x450be8,1);try save();try store(0x44d064,0);try store(0x4511f4,0);try sound(0x455610)
                        try OriginalMenuWorkerRequest.run(globals: state,threadHandle: input.threadHandle,threadID: input.threadID,lastError: input.lastError,observe: observe)
                    }
                }
                if try option(465,87) {
                    try bitmap(0x451188,465,y &+ 174,4)
                    if try clicked() { try store(0x457580,0);try store(0x450be8,0);try save();try store(0x44d064,0);try store(0x4511f4,0);try sound(0x455614) }
                }
                if try word(0x4511f4) == 0 {
                    if try bits(word(0x4546f0) &- 203) <= 358 && word(0x453cdc) > y &+ 240 && word(0x453cdc) < y &+ 262 {
                        try bitmap(0x451188,202,y &+ 240,5)
                        if try clicked() { try store(0x457580,0);try store(0x4511f4,-17);try sound(0x455614) }
                    }
                    if try word(0x4511f4) == 0 { try bitmap(0x451188,75,y &+ 261,1);return finish(.presentation) }
                }
                try bitmap(0x451188,75,y &+ 262,2);try bitmap(0x451188,75,y &+ 542,1);return finish(.presentation)
            }
            if input.selector == -1 {
                try bitmap(0x45117c,258,205,5)
                if try word(0x4511f0) & 1 == 0 { try store(0x4511f0,word(0x4511f0) | 1);try store(0x4511ec,Int32(bitPattern: timer())) }
                if try timer() &- bits(word(0x4511ec)) > 150 {
                    try store(0x4511e8,(word(0x4511e8) &+ 1)%14);try store(0x4511ec,Int32(bitPattern: timer()))
                }
                var i: Int32 = 0,x: Int32 = 284
                while try i < word(0x4511e8) {
                    let args = try [bits(word(0x455608)),bits(x),290,5,12,0x577fd7]
                    try observe(.init("fillRequest",args));guard args[0] != 0 else { throw Stop(end: .nullFillTarget) }
                    try fill(args);i = i &+ 1;x = x &+ 20
                }
                if try word(0x4546f0) >= 331 && word(0x4546f0) < 482 && word(0x453cdc) >= 320 && word(0x453cdc) < 346 {
                    try bitmap(0x45117c,331,320,6)
                    if try clicked() { try sound(0x455614);try store(0x457580,0);try store(0x44d064,0) }
                }
                try store(0x4511e4,word(0x4511e4) &+ 1);return finish(.presentation)
            }
            return finish(input.selector == 0 ? .mainMenu : .otherSelector)
        } catch let stop as Stop { return finish(stop.end) }
    }
}
