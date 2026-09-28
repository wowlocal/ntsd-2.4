import AppKit
import NTSDCore
import NTSDMacPlatform

/// `--original`: run the recovered WinMain on the real Mac services and runtime
/// providers. The front-menu message loop is not connected yet; after startup
/// the original window stays open without further game iterations.
final class OriginalRuntimeDelegate: NSObject, NSApplicationDelegate {
    let exitAfterStartup: Bool
    private var retained: Any?
    init(exitAfterStartup: Bool) { self.exitAfterStartup = exitAfterStartup }

    static func emit(_ value: [String:Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) else { return }
        print(String(decoding:data,as:UTF8.self)); fflush(stdout)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            do {
                let package = try OriginalApplicationStartupInputs.bundled()
                let overlay = try OriginalMacRuntimeOverlay.standard()
                let started = try OriginalMacRuntimeStartup.run(inputs:package,overlay:overlay)
                retained = started
                let dates = started.host.snapshot.startup?.dates?.dates.map { String(decoding:$0.dropLast(),as:UTF8.self) } ?? []
                let owners = Dictionary(grouping:started.requests,by:\.owner).mapValues(\.count)
                Self.emit(["event":"started","sequence":started.sequence,"window":started.window,"requests":started.requests.count,
                    "owners":owners,"attempts":started.attempts,"dates":dates,"overlay":overlay.root.path,
                    "musicOutput":"silent (WMA playback not implemented)","next":"front-menu message loop not connected"])
                if exitAfterStartup { NSApp.terminate(nil) } else { NSApp.activate(ignoringOtherApps:true) }
            } catch {
                Self.emit(["event":"failed","error":String(reflecting:error)])
                if !exitAfterStartup {
                    let alert = NSAlert(); alert.messageText = "NTSD startup stopped"
                    alert.informativeText = String(reflecting:error); alert.runModal()
                }
                exit(1)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
