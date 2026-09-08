import Foundation

/// Entire423840: timeGetTime%13+1, original resource name and43ee50 wrapper.
/// Shared by early and mode menus; no CRT/game RNG is consumed.
public enum OriginalMenuBackground {
    public struct Result {
        public let address: UInt32, bitmap: OriginalLoadedBitmap?, surface: UInt32
    }
    public static func load(globals: inout OriginalStateRecord, milliseconds: UInt32,
        allocate: () throws -> OriginalInterfaceAllocation,
        source: (String) throws -> (OriginalBitmapInput,UInt32,Int32),
        observe: (OriginalFrontScreenEvent) throws -> Void = { _ in }) throws -> Result {
        var state = globals
        let base = OriginalMatchPreparation.globalBase
        try observe(.init("timer",[milliseconds]))
        let number = milliseconds%13+1, path = "MENU_BACK\(number)"
        var formatted = Array("MENU_BACK0000\0".utf8)
        for (i,b) in (Array(path.utf8)+[0]).enumerated() { formatted[i] = b }
        try observe(.init("format",[number,UInt32(path.utf8.count)],[Array("MENU_BACK%d".utf8),formatted]))
        try observe(.init("allocate",[0x1f50]))
        let allocation = try allocate()
        var bitmap: OriginalLoadedBitmap?, retainedSurface: UInt32 = 0
        if allocation.address != 0 {
            try observe(.init("construct",[allocation.address,0x40,0],[Array(path.utf8)]))
            let (resource,surface,key) = try source(path)
            guard resource.path == path else { throw OriginalStateError.invalidStorage("Menu background resource binding") }
            bitmap = try OriginalBitmapConstructor.construct(resource,optional: false,backing: allocation.backing,
                device: state.integer(at: 0x457578-base,as: UInt32.self),flags: 0x40,surface: surface,colorKeyResult: key) {
                    try observe(.init($0.kind.rawValue,$0.arguments,$0.strings))
                }
            retainedSurface = surface != 0 && key >= 0 ? surface : 0
        }
        try state.write(allocation.address,at: 0x4511ac-base)
        try observe(.init("write",[0x4511ac,4,allocation.address]))
        globals = state
        return .init(address: allocation.address,bitmap: bitmap,surface: retainedSurface)
    }
}
