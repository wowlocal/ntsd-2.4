import CAndroidNative
import Foundation
import NTSDCore
import NTSDRuntime

// NTSDAndroid (P8, docs/research/CROSS_PLATFORM.md): the original game through
// OriginalRuntimeSession in an Android NativeActivity. Android calls the
// activity's callbacks on the process main thread, which is also where the
// runtime's main actor runs: the dispatch main queue is drained from the main
// thread's ALooper.
//
// The game data ships as APK assets (assets/ntsd, listed in assets/ntsd/files.txt)
// and is extracted to the app's files folder on first launch; the session gets
// it through --resources. `files/args.txt` (one argument per line), when
// present, adds session options for scripted checks; `--events-file PATH`
// there sends the event lines to a file, and `--tz NAME` sets the process time
// zone (an app inherits the zygote's environment, not the harness's TZ).

@_cdecl("ntsd_android_on_create")
func ntsdAndroidOnCreate(_ activity: UnsafeMutablePointer<ANativeActivity>) {
    MainActor.assumeIsolated { NTSDAndroidApp.create(activity) }
}

@MainActor final class NTSDAndroidApp {
    static var shared: NTSDAndroidApp?
    let activity: UnsafeMutablePointer<ANativeActivity>, files: URL, data: URL
    private(set) var surface: OpaquePointer?
    private var input: OpaquePointer?
    private(set) var looper: OpaquePointer?
    private var dataReady = false, session: OriginalRuntimeSession?
    private(set) var host: NTSDAndroidSessionHost?

    init(_ activity: UnsafeMutablePointer<ANativeActivity>) {
        self.activity = activity
        files = URL(fileURLWithPath:String(cString:activity.pointee.internalDataPath),isDirectory:true)
        data = files.appendingPathComponent("ntsd-data",isDirectory:true)
    }

    static func create(_ activity: UnsafeMutablePointer<ANativeActivity>) {
        let app = NTSDAndroidApp(activity); shared = app
        app.looper = ALooper_forThread()
        // The main queue's eventfd on the main looper: each wake drains it.
        _ = ALooper_addFd(app.looper,_dispatch_get_main_queue_handle_4CF(),Int32(ALOOPER_POLL_CALLBACK),Int32(ALOOPER_EVENT_INPUT),
                          { fd,_,_ in var value: eventfd_t = 0; _ = eventfd_read(fd,&value); _dispatch_main_queue_callback_4CF(nil); return 1 },nil)
        let callbacks = activity.pointee.callbacks!
        callbacks.pointee.onNativeWindowCreated = { _,window in MainActor.assumeIsolated { NTSDAndroidApp.shared?.surfaceCreated(window) } }
        callbacks.pointee.onNativeWindowRedrawNeeded = { _,window in MainActor.assumeIsolated { NTSDAndroidApp.shared?.surfaceRedraw(window) } }
        callbacks.pointee.onNativeWindowDestroyed = { _,_ in
            MainActor.assumeIsolated { NTSDAndroidApp.shared?.surface = nil; NTSDAndroidApp.shared?.host?.windows.setSurface(nil) }
        }
        callbacks.pointee.onInputQueueCreated = { _,queue in MainActor.assumeIsolated { NTSDAndroidApp.shared?.inputCreated(queue) } }
        callbacks.pointee.onInputQueueDestroyed = { _,queue in MainActor.assumeIsolated { NTSDAndroidApp.shared?.inputDestroyed(queue) } }
        callbacks.pointee.onPause = { _ in MainActor.assumeIsolated { NTSDAndroidApp.shared?.host?.setForeground(false) } }
        callbacks.pointee.onResume = { _ in MainActor.assumeIsolated { NTSDAndroidApp.shared?.host?.setForeground(true) } }
        // Immersive mode is reset by dialogs and the keyboard: hide the bars again
        // whenever the window regains focus.
        callbacks.pointee.onWindowFocusChanged = { activity,focused in
            if focused != 0, let activity { ntsd_android_hide_system_bars(activity) }
            MainActor.assumeIsolated { NTSDAndroidApp.shared?.host?.setFocused(focused != 0) }
        }
        callbacks.pointee.onDestroy = { _ in Foundation.exit(0) }
        ntsd_android_hide_system_bars(activity)
        app.prepareData()
    }

    // MARK: data

    /// Extracts assets/ntsd to files/ntsd-data unless the copy already matches
    /// files.txt, on a background thread (the main thread must keep serving input).
    private func prepareData() {
        let manager = UncheckedSendableBox(activity.pointee.assetManager), data = data
        DispatchQueue.global(qos:.userInitiated).async {
            let result = Result { try Self.extract(manager.value,to:data) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let app = NTSDAndroidApp.shared else { return }
                    switch result {
                    case .success: app.dataReady = true; app.startIfReady()
                    case .failure(let error): NTSDAndroidSessionHost.report(["event":"androidDataError","error":String(reflecting:error)])
                    }
                }
            }
        }
    }
    struct DataError: Error { let path: String }
    nonisolated private static func asset(_ manager: OpaquePointer?,_ path: String) throws -> Data {
        guard let asset = AAssetManager_open(manager,"ntsd/"+path,Int32(AASSET_MODE_STREAMING)) else { throw DataError(path:path) }
        defer { AAsset_close(asset) }
        var out = Data(), chunk = [UInt8](repeating:0,count:1 << 16)
        while true {
            let n = chunk.withUnsafeMutableBytes { AAsset_read(asset,$0.baseAddress,$0.count) }
            if n < 0 { throw DataError(path:path) }
            if n == 0 { return out }
            out.append(contentsOf:chunk[0..<Int(n)])
        }
    }
    nonisolated private static func extract(_ manager: OpaquePointer?,to data: URL) throws {
        let list = try asset(manager,"files.txt"), marker = data.appendingPathComponent(".extracted")
        if (try? Data(contentsOf:marker)) == list { return }
        let fm = FileManager.default
        try? fm.removeItem(at:data)
        for line in String(decoding:list,as:UTF8.self).split(separator:"\n") {
            let path = String(line.split(separator:"\t")[0]), target = data.appendingPathComponent(path)
            try fm.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
            try asset(manager,path).write(to:target)
        }
        try list.write(to:marker)
    }

    // MARK: session

    private func surfaceCreated(_ window: OpaquePointer?) {
        surface = window; host?.windows.setSurface(window)
        startIfReady()
        host?.windows.redraw()
    }
    private func surfaceRedraw(_ window: OpaquePointer?) { host?.windows.redraw() }

    private func startIfReady() {
        guard session == nil,dataReady,let surface else { return }
        var arguments = ["NTSDAndroid"]
        if let extra = try? String(contentsOf:files.appendingPathComponent("args.txt"),encoding:.utf8) {
            arguments += extra.split(separator:"\n",omittingEmptySubsequences:true).map(String.init)
        }
        if let i = arguments.firstIndex(of:"--events-file"),i+1 < arguments.count {
            freopen(arguments[i+1],"w",stdout); setvbuf(stdout,nil,_IOLBF,0)
        }
        if let i = arguments.firstIndex(of:"--tz"),i+1 < arguments.count { setenv("TZ",arguments[i+1],1); tzset() }
        arguments += ["--resources",data.appendingPathComponent("NTSDNative_NTSDCore.bundle").path]
        let music = arguments.firstIndex(of:"--music-dir").flatMap { $0+1 < arguments.count ? arguments[$0+1] : nil }
            ?? data.appendingPathComponent("OriginalMusic").path
        let config = AConfiguration_new(); defer { AConfiguration_delete(config) }
        AConfiguration_fromAssetManager(config,activity.pointee.assetManager)
        let density = max(1,Double(AConfiguration_getDensity(config))/160)
        // The screen the game is told: the surface in density-independent pixels,
        // scaled up (same aspect) to at least 800x600, the desktop the original
        // was made for. A phone's 853x384 dp would leave the 794x550 window
        // partly above the screen, where the game's first blit is refused
        // (declared host policy; frames are letterboxed to the surface anyway).
        let dp = CGSize(width:Double(ANativeWindow_getWidth(surface))/density,height:Double(ANativeWindow_getHeight(surface))/density)
        let fit = max(1,800/dp.width,600/dp.height)
        let screen = CGSize(width:(dp.width*fit).rounded(.down),height:(dp.height*fit).rounded(.down))
        let host = NTSDAndroidSessionHost(arguments:arguments,screen:screen,density:density,musicDirectory:music,files:files)
        host.windows.app = self; host.windows.setSurface(surface)
        let session = OriginalRuntimeSession(arguments:arguments,host:host)
        host.session = session; self.host = host; self.session = session
        session.start()
    }

    // MARK: input

    private func inputCreated(_ queue: OpaquePointer?) {
        input = queue
        AInputQueue_attachLooper(queue,looper,Int32(ALOOPER_POLL_CALLBACK),{ _,_,_ in
            MainActor.assumeIsolated { NTSDAndroidApp.shared?.drainInput() }; return 1
        },nil)
    }
    private func inputDestroyed(_ queue: OpaquePointer?) { AInputQueue_detachLooper(queue); input = nil }
    private func drainInput() {
        guard let input else { return }
        var event: OpaquePointer?
        while AInputQueue_getEvent(input,&event) >= 0,let e = event {
            if AInputQueue_preDispatchEvent(input,e) != 0 { continue }
            AInputQueue_finishEvent(input,e,handle(e) ? 1 : 0)
        }
    }
    private func handle(_ event: OpaquePointer) -> Bool {
        guard let host else { return false }
        switch AInputEvent_getType(event) {
        case Int32(AINPUT_EVENT_TYPE_MOTION):
            guard let surface,let (x,y) = host.windows.clientPoint(AMotionEvent_getX(event,0),AMotionEvent_getY(event,0),surface:surface) else { return true }
            switch AMotionEvent_getAction(event) & Int32(AMOTION_EVENT_ACTION_MASK) {
            case Int32(AMOTION_EVENT_ACTION_DOWN): host.touch.began(x:x,y:y)
            case Int32(AMOTION_EVENT_ACTION_MOVE): host.touch.moved(x:x,y:y)
            case Int32(AMOTION_EVENT_ACTION_UP),Int32(AMOTION_EVENT_ACTION_CANCEL): host.touch.ended(x:x,y:y)
            default: break
            }
            return true
        case Int32(AINPUT_EVENT_TYPE_KEY):
            let code = AKeyEvent_getKeyCode(event)
            guard let usage = NTSDAndroidKeys.usage(code),let key = OriginalHIDKeys.key(usage:usage) else { return false }
            let down = AKeyEvent_getAction(event) == Int32(AKEY_EVENT_ACTION_DOWN)
            if down && AKeyEvent_getRepeatCount(event) > 0 { return true }
            let shift = AKeyEvent_getMetaState(event) & Int32(AMETA_SHIFT_ON) != 0
            host.key(key,down:down,characters:down ? NTSDAndroidKeys.characters(code,shift:shift) : nil)
            return true
        default:
            return false
        }
    }
}

/// Carries a value the compiler cannot prove sendable into a background task.
struct UncheckedSendableBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }
