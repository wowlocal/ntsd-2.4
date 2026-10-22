import AppKit
import RandoriCore

extension OriginalRuntimeStartupHost {
    /// AppKit windows, CoreText glyphs and NSAlert message boxes.
    public static var mac: Self {
        .init(windows:OriginalMacWindowHost(),textMask:OriginalMacDisplayBackend.textMask,messageBox:OriginalMacRuntimeMusic.alert)
    }
}

extension OriginalMacRuntimeOverlay {
    /// The Mac's writable user data: Application Support/`folder`.
    public static func standard(folder: String) throws -> Self {
        let support = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        return .init(root:support.appendingPathComponent(folder,isDirectory:true))
    }
}

extension OriginalMacRuntimeStartup {
    /// Startup on the Mac host; AppKit's application object exists first.
    public static func run(inputs package: OriginalApplicationStartupInputs,overlay: OriginalMacRuntimeOverlay?,
        environment: OriginalMacRuntimeStartupService.Environment = .init(),maximumAttempts: Int = 2000) throws -> Started {
        _ = NSApplication.shared
        return try run(inputs:package,overlay:overlay,environment:environment,maximumAttempts:maximumAttempts,host:.mac)
    }
}
