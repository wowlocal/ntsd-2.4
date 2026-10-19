import CAndroidNative
import Foundation
import NTSDRuntime

/// Gamepads as the original's joysticks on Android (TVOS_WEB T1c), mapped as
/// the SDL host maps them: the first two gamepads present at launch (the
/// original probes its joysticks only at startup), sampled every 25 ms as
/// joySetCapture asks; the d-pad (hat axes or keys) over the left stick as
/// the WinMM X/Y axes, y down, and A/B/X/Y (BUTTON_1–4 on generic pads) as
/// buttons 1–4.
///
/// A gamepad's stick motion and buttons never reach the touch and key paths
/// (its d-pad keys and Back neither, for a gamepad found at launch): a
/// stick's motion is not a touch, and an unhandled B would come back from
/// Android as Back, which is Esc here (the quit question).
@MainActor final class NTSDAndroidGamepads {
    private struct State {
        var x: Float = 0, y: Float = 0, hatX: Float = 0, hatY: Float = 0
        var left = false, right = false, up = false, down = false
        var buttons: UInt32 = 0
    }
    private var probed = false
    private(set) var devices: [Int32] = []
    private var states: [Int32:State] = [:]
    private var timer: DispatchSourceTimer?
    private weak var session: OriginalRuntimeSession?

    /// The first two input devices whose sources include SOURCE_GAMEPAD (as
    /// the other hosts take only gamepads: not a lone motion-sensor or flight
    /// stick node), from InputDevice.getDeviceIds and getSources through JNI
    /// on the activity's (main) thread. A JNI failure finds none.
    func probe(_ activity: UnsafeMutablePointer<ANativeActivity>) -> Int {
        if probed { return devices.count }
        probed = true
        let gamepad = Int32(AINPUT_SOURCE_GAMEPAD)
        devices = Array(Self.inputDevices(activity).filter { $0.sources & gamepad == gamepad }.prefix(2).map(\.id))
        for id in devices { states[id] = State() }
        return devices.count
    }

    /// Whether a keyboard or gamepad is connected — an input device, external
    /// (InputDevice.isExternal, API 29; where it is absent, not virtual),
    /// whose sources include SOURCE_GAMEPAD or that is an alphabetic keyboard
    /// (KEYBOARD_TYPE_ALPHABETIC) — with what they are (kind and USB vendor:
    /// product, not their names, which may be the owner's) and the ids of all
    /// devices listed (TOUCH_CONTROLS: the on-screen controls hide while one is). A
    /// phone's own parts (a fingerprint sensor's uinput node, its keys) are
    /// not external. A JNI failure finds none.
    static func connectedHardware(_ activity: UnsafeMutablePointer<ANativeActivity>) -> (connected: Bool,kinds: [String],devices: Set<Int32>) {
        let gamepad = Int32(AINPUT_SOURCE_GAMEPAD),list = inputDevices(activity)
        let found = list.filter { $0.external && ($0.sources & gamepad == gamepad || $0.keyboard == 2) }
        let kinds = found.map { ($0.sources & gamepad == gamepad ? "gamepad " : "keyboard ")+String(format:"%04x:%04x",$0.vendor,$0.product) }
        return (!found.isEmpty,kinds,Set(list.map(\.id)))
    }

    /// InputDevice.getDeviceIds, in its order, with each device's getSources
    /// (a device whose call fails is left out), whether it is external
    /// (isExternal; without it, not isVirtual; false when a call fails),
    /// getKeyboardType and getVendorId/getProductId (0 when they fail), through JNI on the
    /// activity's (main) thread. A failure before the devices finds none.
    private static func inputDevices(_ activity: UnsafeMutablePointer<ANativeActivity>) -> [(id: Int32,sources: Int32,external: Bool,keyboard: Int32,vendor: Int32,product: Int32)] {
        guard let env = activity.pointee.env,let jni = env.pointee?.pointee else { return [] }
        func failed() -> Bool {
            guard jni.ExceptionCheck(env) != 0 else { return false }
            jni.ExceptionClear(env); return true
        }
        guard let type = jni.FindClass(env,"android/view/InputDevice"),!failed() else { _ = failed(); return [] }
        defer { jni.DeleteLocalRef(env,type) }
        guard let getIds = jni.GetStaticMethodID(env,type,"getDeviceIds","()[I"),
              let getDevice = jni.GetStaticMethodID(env,type,"getDevice","(I)Landroid/view/InputDevice;"),
              let getSources = jni.GetMethodID(env,type,"getSources","()I"),
              let isVirtual = jni.GetMethodID(env,type,"isVirtual","()Z"),
              let getKeyboardType = jni.GetMethodID(env,type,"getKeyboardType","()I"),
              let getVendorId = jni.GetMethodID(env,type,"getVendorId","()I"),
              let getProductId = jni.GetMethodID(env,type,"getProductId","()I"),!failed() else { _ = failed(); return [] }
        let isExternal = jni.GetMethodID(env,type,"isExternal","()Z")   // API 29
        if failed() || isExternal == nil { _ = failed() }
        guard let ids = jni.CallStaticObjectMethodA(env,type,getIds,nil),!failed() else { _ = failed(); return [] }
        defer { jni.DeleteLocalRef(env,ids) }
        let count = jni.GetArrayLength(env,ids)
        var list = [jint](repeating:0,count:Int(max(0,count)))
        if count > 0 { jni.GetIntArrayRegion(env,ids,0,count,&list) }
        if failed() { return [] }
        var found: [(id: Int32,sources: Int32,external: Bool,keyboard: Int32,vendor: Int32,product: Int32)] = []
        for id in list {
            var argument = jvalue(i:id)
            guard let device = withUnsafePointer(to:&argument,{ jni.CallStaticObjectMethodA(env,type,getDevice,$0) }),!failed() else { _ = failed(); continue }
            defer { jni.DeleteLocalRef(env,device) }
            let sources = jni.CallIntMethodA(env,device,getSources,nil)
            if failed() { continue }
            var external: Bool
            if let isExternal { external = jni.CallBooleanMethodA(env,device,isExternal,nil) != 0 }
            else { external = jni.CallBooleanMethodA(env,device,isVirtual,nil) == 0 }
            if failed() { external = false }
            var keyboard = jni.CallIntMethodA(env,device,getKeyboardType,nil)
            if failed() { keyboard = 0 }
            var vendor = jni.CallIntMethodA(env,device,getVendorId,nil)
            if failed() { vendor = 0 }
            var product = jni.CallIntMethodA(env,device,getProductId,nil)
            if failed() { product = 0 }
            found.append((id:id,sources:sources,external:external,keyboard:keyboard,vendor:vendor,product:product))
        }
        return found
    }

    func startSampling(_ session: OriginalRuntimeSession) {
        guard timer == nil else { return }
        self.session = session
        let source = DispatchSource.makeTimerSource(queue:.main)
        source.schedule(deadline:.now() + .milliseconds(25),repeating:.milliseconds(25))
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.sample() } }
        source.resume(); timer = source
    }

    /// Every gamepad back at rest: the window lost focus, so the releases
    /// may go to another window (TVOS_WEB T1c review).
    func reset() { for id in states.keys { states[id] = State() } }

    /// Takes a gamepad's event (true: consumed). Joystick motion and gamepad
    /// buttons from any device are consumed; d-pad keys and Back only from a
    /// gamepad found at launch, whose state they update. A cancelled motion
    /// (focus moved, the pad disconnected) carries the last axes, not rest.
    func handle(_ event: OpaquePointer) -> Bool {
        let device = AInputEvent_getDeviceId(event),known = states[device] != nil
        switch AInputEvent_getType(event) {
        case Int32(AINPUT_EVENT_TYPE_MOTION):
            guard AInputEvent_getSource(event) & Int32(AINPUT_SOURCE_CLASS_JOYSTICK) != 0 else { return false }
            if known && AMotionEvent_getAction(event) & Int32(AMOTION_EVENT_ACTION_MASK) == Int32(AMOTION_EVENT_ACTION_CANCEL) {
                states[device] = State()
            } else if known {
                func axis(_ a: Int32) -> Float { AMotionEvent_getAxisValue(event,a,0) }
                states[device]!.x = axis(Int32(AMOTION_EVENT_AXIS_X)); states[device]!.y = axis(Int32(AMOTION_EVENT_AXIS_Y))
                states[device]!.hatX = axis(Int32(AMOTION_EVENT_AXIS_HAT_X)); states[device]!.hatY = axis(Int32(AMOTION_EVENT_AXIS_HAT_Y))
            }
            return true
        case Int32(AINPUT_EVENT_TYPE_KEY):
            let code = AKeyEvent_getKeyCode(event)
            let button = (Int32(AKEYCODE_BUTTON_A)...Int32(AKEYCODE_BUTTON_MODE)).contains(code)
                || (Int32(AKEYCODE_BUTTON_1)...Int32(AKEYCODE_BUTTON_16)).contains(code)
            let dpad = (Int32(AKEYCODE_DPAD_UP)...Int32(AKEYCODE_DPAD_CENTER)).contains(code) || code == Int32(AKEYCODE_BACK)
            guard button || (known && dpad) else { return false }
            guard known else { return true }
            let down = AKeyEvent_getAction(event) == Int32(AKEY_EVENT_ACTION_DOWN)
            switch code {
            case Int32(AKEYCODE_DPAD_LEFT): states[device]!.left = down
            case Int32(AKEYCODE_DPAD_RIGHT): states[device]!.right = down
            case Int32(AKEYCODE_DPAD_UP): states[device]!.up = down
            case Int32(AKEYCODE_DPAD_DOWN): states[device]!.down = down
            default:
                let bit: UInt32
                switch code {
                case Int32(AKEYCODE_BUTTON_A),Int32(AKEYCODE_BUTTON_1): bit = 1
                case Int32(AKEYCODE_BUTTON_B),Int32(AKEYCODE_BUTTON_2): bit = 2
                case Int32(AKEYCODE_BUTTON_X),Int32(AKEYCODE_BUTTON_3): bit = 4
                case Int32(AKEYCODE_BUTTON_Y),Int32(AKEYCODE_BUTTON_4): bit = 8
                default: bit = 0
                }
                states[device]!.buttons = down ? states[device]!.buttons | bit : states[device]!.buttons & ~bit
            }
            return true
        default:
            return false
        }
    }

    /// joySetCapture's 25 ms period: each gamepad's state, as the runtime's
    /// MM_JOY threshold and button changes call for.
    private func sample() {
        guard let session,let messages = session.messages,!session.stopped else { return }
        for (id,device) in devices.enumerated() {
            guard let s = states[device] else { continue }
            var dx = s.x,dy = s.y
            if s.hatX != 0 { dx = s.hatX } else if s.left != s.right { dx = s.left ? -1 : 1 }
            if s.hatY != 0 { dy = s.hatY } else if s.up != s.down { dy = s.up ? -1 : 1 }
            func word(_ v: Float) -> UInt32 { UInt32(((max(-1,min(1,v))+1)/2*65535).rounded()) }
            messages.joystick(UInt32(id),x:word(dx),y:word(dy),buttons:s.buttons)
        }
    }
}
