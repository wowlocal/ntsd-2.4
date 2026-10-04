import AppKit
import NTSDCore
import UniformTypeIdentifiers

extension OriginalRuntimeLoadingDialogs {
    /// NSOpenPanel for recordings, an NSAlert titled "Error", NSWorkspace open.
    public static var mac: Self {
        .init(chooseRecording:{ directory in
                  let panel = NSOpenPanel()
                  panel.title = "Open"
                  panel.allowedContentTypes = ["lfr","txt"].compactMap { UTType(filenameExtension:$0) }
                  panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
                  if let directory { panel.directoryURL = directory }
                  return panel.runModal() == .OK ? panel.url?.path : nil
              },
              alert:{ text in
                  let alert = NSAlert()
                  alert.messageText = "Error"; alert.informativeText = text
                  alert.runModal()
              },
              open:{ path in _ = NSWorkspace.shared.open(URL(fileURLWithPath:path)) })
    }
}

extension OriginalMacRuntimeLoading {
    /// The bundled loading runtime with the Mac's dialogs.
    public static func bundled(_ started: OriginalMacRuntimeStartup.Started,startupInputs: OriginalApplicationStartupInputs,
        clock: @escaping () throws -> UInt32) throws -> OriginalMacRuntimeLoading {
        try bundled(started,startupInputs:startupInputs,clock:clock,dialogs:.mac)
    }
}
