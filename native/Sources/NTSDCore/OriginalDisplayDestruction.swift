/// Whole401ae0/401a80 display destruction shared by mode changes and recovery.
/// A null DirectDraw skips both surface releases; DestroyWindow still uses the
/// retained live HWND. Numeric results are ignored. Buffer external effects.
public enum OriginalDisplayDestruction {
    public static func destroy(globals: inout OriginalStateRecord,
        perform: (OriginalWindowInitialization.Request) throws -> OriginalWindowInitialization.Response,
        store: OriginalWindowInput.Store = { _,_ in }) throws {
        guard globals.bytes.count == OriginalMatchPreparation.globalSize else {
            throw OriginalStateError.invalidStorage("Display destruction globals extent")
        }
        var state = globals
        func word(_ address: Int) throws -> UInt32 { try state.integer(at: address-0x44d000,as: UInt32.self) }
        func clear(_ address: Int) throws {
            try state.write(UInt32(0),at: address-0x44d000);try store(address,[0,0,0,0])
        }
        if try word(0x457578) != 0 {
            for address in [0x455608,0x455634] {
                let pointer = try word(address)
                if pointer != 0 { _ = try perform(.init("release",[pointer]));try clear(address) }
            }
            _ = try perform(.init("release",[word(0x457578)]));try clear(0x457578)
        }
        let window = try word(0x4546f4)
        if window != 0 { _ = try perform(.init("destroyWindow",[window])) }
        globals = state
    }
}
