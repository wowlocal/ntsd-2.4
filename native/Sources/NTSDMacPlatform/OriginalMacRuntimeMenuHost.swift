import AppKit
import NTSDCore

extension OriginalMacRuntimeMenu {
    /// The Mac menu runtime: Caps Lock from AppKit's modifier flags and
    /// MessageBoxA as a modal alert.
    public convenience init(_ started: OriginalMacRuntimeStartup.Started,inputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32,point: @escaping () -> (Int32,Int32) = { (0,0) },overlay: OriginalMacRuntimeOverlay? = nil) throws {
        try self.init(started,inputs:inputs,clock:clock,point:point,overlay:overlay,
                      capsLock:{ NSEvent.modifierFlags.contains(.capsLock) ? 1 : 0 },messageBox:OriginalMacRuntimeMusic.alert)
    }
}
