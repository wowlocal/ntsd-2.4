/// Whole43e890 including43e860,401ae0 and43bdd0 at declared platform and helper
/// backing boundaries. Context must own value state; buffer external effects
/// until this encompassing operation commits. Synchronous OS reentrancy and
/// actual Windows/device restoration remain separate integration requirements.
public enum OriginalApplicationRecovery {
    public typealias Request = OriginalWindowInitialization.Request
    public typealias Response = OriginalWindowInitialization.Response
    public static func recover<Context>(globals: inout OriginalStateRecord, context: inout Context,
        backing: (String,Int) throws -> [UInt8], perform: (Request,inout Context) throws -> Response,
        store: OriginalWindowInput.Store = { _,_ in },
        beforeCommit: (OriginalStateRecord,Context,Int32) throws -> Void = { _,_,_ in }) throws -> Int32 {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Application recovery globals extent")
        }
        var state = globals, staged = context
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-0x44d000,as: UInt32.self) }
        func call(_ request: Request) throws -> Response { try perform(request,&staged) }
        func put(_ address: Int,_ value: UInt32) throws {
            try state.write(value,at: address-0x44d000)
            try store(address,(0..<4).map { UInt8(truncatingIfNeeded: value >> ($0*8)) })
        }
        let primary = try word(0x455634)
        if primary != 0 { _ = try call(.init("restore",[primary])) }
        let back = try word(0x455608)
        guard back != 0 else {
            throw OriginalStateError.invalidStorage("Application recovery has no back surface at43e876")
        }
        let restored = try call(.init("restore",[back])).result
        let result: Int32
        if restored >= 0 || UInt32(bitPattern: restored) == 0x8876024c { result = 0 }
        else {
            try put(0x458434,1)
            try OriginalDisplayDestruction.destroy(globals: &state,perform: call,store: store)
            _ = try OriginalWindowInitialization.configure(globals: &state,backing: backing,perform: call,store: store)
            // Actual43bdd0 returns only0/1, so43e8b1's negative debug branch is
            // unreachable here. Its0 still reaches ShowWindow, even with HWND0.
            result = try call(.init("showWindow",[word(0x4546f4),5])).result
            try put(0x458434,0)
        }
        try beforeCommit(state,staged,result)
        globals = state;context = staged;return result
    }
}
