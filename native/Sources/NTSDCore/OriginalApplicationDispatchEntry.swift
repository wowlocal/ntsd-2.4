/// First43e9a0 prefix through its mode0 game entry, before executing4246b0.
/// Platform requests expose only owned structure fields; private caller-stack
/// bytes remain unknown. Other modes are explicit required dependencies. This
/// operation is a stage boundary, not a completed dispatcher or tick. Its caller
/// must stage the whole loop iteration and buffer external effects until commit.
public enum OriginalApplicationDispatchEntry {
    public static let globalSize = 0xc3a8
    public struct GameEntry: Equatable, Sendable {
        public let worldAddress: UInt32, target: UInt32
    }
    public enum Boundary: Error, Equatable { case requiredMode(UInt32) }
    public static func advance(incomingTarget _: UInt32,globals: inout OriginalStateRecord,
        perform: (OriginalWindowInitialization.Request,OriginalStateRecord) throws -> OriginalWindowInitialization.Response,
        store: OriginalWindowInput.Store = { _,_ in },
        beforeCommit: (GameEntry,OriginalStateRecord) throws -> Void = { _,_ in }) throws -> GameEntry {
        guard globals.bytes.count == globalSize else {
            throw OriginalStateError.invalidStorage("Application dispatcher globals extent")
        }
        var state = globals
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-0x44d000,as: UInt32.self) }
        func put(_ address: Int,_ value: UInt32) throws {
            try state.write(value,at: address-0x44d000)
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) })
        }
        var keys = try OriginalApplicationKeyScan(sequence: word(0x4593a4),diagnostics: word(0x450bec),mode: word(0x4593a0))
        let keyboard = Array(state.bytes[0x455378-0x44d000..<0x455378-0x44d000+300])
        guard state.defined[0x455378-0x44d000..<0x455378-0x44d000+250].allSatisfy({ $0 }) else {
            throw OriginalStateError.invalidStorage("Application keyboard backing is unknown")
        }
        try keys.apply(keyboard: keyboard) { try put(Int($0),$1) }
        if try word(0x44dce4) == 1 {
            let unknown = try OriginalStateRecord(bytes: [UInt8](repeating: 0,count: 32),defined: [Bool](repeating: false,count: 32))
            _ = try OriginalApplicationArtSetup.run(context: &state,queryBacking: unknown,clearBacking: [UInt8](repeating: 0,count: 100),
                querySurface: { try $0.integer(at: 0x455634-0x44d000,as: UInt32.self) },
                clearSurface: { try $0.integer(at: 0x455608-0x44d000,as: UInt32.self) },query: { q,g in
                    let record = try OriginalStateRecord(bytes:q.bytes,defined:q.defined)
                    let response = try perform(.init("pixelFormat",[q.target],structure:record),g)
                    return .init(result:response.result,writes:response.bytes.map { [.init(offset:0,bytes:$0)] } ?? [])
                },clear: { q,g in
                    try perform(.init("blt",[q.target,0,0,0,q.flags],structure:.init(bytes:q.effects,defined:q.defined)),g).result
                },debug: { bytes,g in _ = try perform(.init("debug",strings:[bytes]),g) })
            try put(0x458440,1);try put(0x44dce4,2);try put(0x4593a0,0)
        }
        _ = try OriginalSurfaceClearing.clear(target:word(0x455608),color:word(0x4593a0) == 1 ? 0x2945 : 0,
            backing:[UInt8](repeating:0,count:100)) { q in
                try perform(.init("blt",[q.target,0,0,0,q.flags],structure:.init(bytes:q.effects,defined:q.defined)),state).result
            }
        let mode = try word(0x4593a0)
        guard mode == 0 else { throw Boundary.requiredMode(mode) }
        let entry = try GameEntry(worldAddress:0x458b00,target:word(0x455608))
        try beforeCommit(entry,state);globals = state;return entry
    }
}
