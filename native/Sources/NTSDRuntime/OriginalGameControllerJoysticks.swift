#if canImport(GameController)
import Foundation
import GameController

/// The original's joysticks from GameController (APPLICATION_JOYSTICKS_PLAN.md):
/// the first two extended game controllers connected at launch (Bluetooth
/// Xbox, PlayStation or MFi gamepads), sampled every 25 ms as joySetCapture
/// asks, the left stick or the d-pad as the WinMM X/Y axes and A/B/X/Y as
/// buttons 1–4. The original probes its joysticks only at startup, so the
/// set is fixed. One implementation for the AppKit, iPad and Apple TV hosts
/// (TVOS_WEB T1b; it was the AppKit host's own).
@MainActor public final class OriginalGameControllerJoysticks {
    public init() {}
    /// Already-connected controllers are enumerated asynchronously after
    /// launch; give GameController up to 0.5 s to report one before 43bf10's
    /// single probe.
    public private(set) lazy var controllers: [GCController] = {
        func found() -> [GCController] { GCController.controllers().filter { $0.extendedGamepad != nil } }
        let deadline = Date().addingTimeInterval(0.5)
        while found().isEmpty && Date() < deadline { RunLoop.current.run(mode:.default,before:Date().addingTimeInterval(0.05)) }
        return Array(found().prefix(2))
    }()
    public var count: Int { controllers.count }
    private weak var session: OriginalRuntimeSession?
    public func startSampling(_ session: OriginalRuntimeSession) {
        self.session = session
        // Common modes: sampling continues while a window is dragged or a menu tracks.
        let timer = Timer(timeInterval:0.025,repeats:true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(timer,forMode:.common)
    }
    /// joySetCapture's 25 ms period: sample each controller and let the runtime
    /// post the MM_JOY messages its threshold and button changes call for.
    private func sample() {
        guard let session,let messages = session.messages,!session.stopped else { return }
        for (id,controller) in controllers.enumerated() {
            guard let pad = controller.extendedGamepad else { continue }
            var dx = pad.leftThumbstick.xAxis.value,dy = pad.leftThumbstick.yAxis.value
            if pad.dpad.xAxis.value != 0 { dx = pad.dpad.xAxis.value }
            if pad.dpad.yAxis.value != 0 { dy = pad.dpad.yAxis.value }
            func axis(_ v: Float) -> UInt32 { UInt32(((max(-1,min(1,v))+1)/2*65535).rounded()) }
            let buttons = [pad.buttonA,pad.buttonB,pad.buttonX,pad.buttonY].enumerated().reduce(UInt32(0)) { $0 | ($1.element.isPressed ? 1 << UInt32($1.offset) : 0) }
            messages.joystick(UInt32(id),x:axis(dx),y:axis(-dy),buttons:buttons)
        }
    }
}
#endif
