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
// `--original-window` there shows the original window: the frame at one
// device pixel per pixel, centred (WINDOW_SCALING S5). `--touch-controls
// on|off` there forces the on-screen controls, which otherwise show while no
// keyboard or gamepad is connected (TOUCH_CONTROLS).

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
        callbacks.pointee.onResume = { _ in MainActor.assumeIsolated {
            // A move between cpusets (background and back) can reset the pin
            // on some kernels: apply it again (P0).
            if NTSDAndroidApp.shared?.session != nil { NTSDAndroidApp.pinToFastCores() }
            NTSDAndroidApp.shared?.host?.setForeground(true)
        } }
        // Immersive mode is reset by dialogs and the keyboard: hide the bars again
        // whenever the window regains focus.
        callbacks.pointee.onWindowFocusChanged = { activity,focused in
            if focused != 0, let activity { ntsd_android_hide_system_bars(activity) }
            MainActor.assumeIsolated { NTSDAndroidApp.shared?.host?.setFocused(focused != 0) }
        }
        // A keyboard plugged in or out changes the configuration (the manifest
        // keeps the activity): the on-screen controls follow (TOUCH_CONTROLS).
        callbacks.pointee.onConfigurationChanged = { _ in MainActor.assumeIsolated { NTSDAndroidApp.shared?.host?.checkInputDevices() } }
        callbacks.pointee.onDestroy = { _ in Foundation.exit(0) }
        ntsd_android_hide_system_bars(activity)
        // The packaged inputs' SHA-256 with the CPU's SHA-2 instructions, after
        // they give the Swift digests (MEMORY_LOADING L11).
        if ntsd_sha256_available() != 0 { PortableSHA256.install(ntsd_sha256_blocks) }
        // The packages load on every core: Dispatch's workers inherit the game
        // thread's fast-cluster mask (pinToFastCores), which left half of the
        // A12's cores idle while it read and verified them (MEMORY_LOADING L12).
        OriginalConcurrentInputs.parallelLoop = { count,body in
            let all = ntsd_cpu_cluster_mask(1) | ntsd_cpu_cluster_mask(0)
            OriginalConcurrentInputs.threadLoop(count,workers:ProcessInfo.processInfo.activeProcessorCount,
                threadStart:{ if all != 0 { _ = ntsd_pin_current_thread(all) } },body)
        }
        // The loading packages are read ahead while the menu runs (MEMORY_LOADING
        // L13), on every core but below the game and presenter threads' priority
        // (nice 10, which its package threads inherit), so the menu keeps its pace.
        OriginalConcurrentInputs.backgroundStart = {
            let all = ntsd_cpu_cluster_mask(1) | ntsd_cpu_cluster_mask(0)
            if all != 0 { _ = ntsd_pin_current_thread(all) }
            _ = ntsd_set_current_thread_nice(10)
        }
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
        let paths = String(decoding:list,as:UTF8.self).split(separator:"\n").map { String($0.split(separator:"\t")[0]) }
        // The directories first, in the list's order; then the files on every
        // core: one after another the A12 took ~25 s for the 726 MB (MEMORY_LOADING
        // S2). The first failing file in the list's order is reported, as
        // before, and the marker is still written last.
        var made = Set<String>()
        for path in paths {
            let directory = data.appendingPathComponent(path).deletingLastPathComponent()
            if made.insert(directory.path).inserted { try fm.createDirectory(at:directory,withIntermediateDirectories:true) }
        }
        var results = [Result<Void,Error>?](repeating:nil,count:paths.count)
        let all = ntsd_cpu_cluster_mask(1) | ntsd_cpu_cluster_mask(0)
        results.withUnsafeMutableBufferPointer { slots in
            OriginalConcurrentInputs.threadLoop(paths.count,workers:ProcessInfo.processInfo.activeProcessorCount,
                threadStart:{ if all != 0 { _ = ntsd_pin_current_thread(all) } }) { i in
                slots[i] = Result { try copyAsset(manager,paths[i],to:data.appendingPathComponent(paths[i])) }
            }
        }
        for result in results { try result!.get() }
        try list.write(to:marker)
    }
    /// One asset to its file, read into a buffer of the asset's length: its
    /// bytes up to that length or an earlier empty read (Android's reader
    /// stops at the length; `asset` read until an empty read).
    nonisolated private static func copyAsset(_ manager: OpaquePointer?,_ path: String,to target: URL) throws {
        guard let asset = AAssetManager_open(manager,"ntsd/"+path,Int32(AASSET_MODE_STREAMING)) else { throw DataError(path:path) }
        defer { AAsset_close(asset) }
        let length = max(0,Int(AAsset_getLength64(asset)))
        var bytes = try [UInt8](unsafeUninitializedCapacity:length) { buffer,count in
            var filled = 0
            while filled < length {
                let n = AAsset_read(asset,buffer.baseAddress! + filled,length - filled)
                if n < 0 { throw DataError(path:path) }
                if n == 0 { break }
                filled += Int(n)
            }
            count = filled
        }
        try bytes.withUnsafeMutableBytes { raw in
            try (raw.isEmpty ? Data() : Data(bytesNoCopy:raw.baseAddress!,count:raw.count,deallocator:.none)).write(to:target)
        }
    }

    // MARK: session

    private func surfaceCreated(_ window: OpaquePointer?) {
        surface = window; host?.windows.setSurface(window)
        startIfReady()
        host?.windows.redraw()
    }
    private func surfaceRedraw(_ window: OpaquePointer?) { host?.windows.redraw() }

    /// The main thread (the game's) on the cores faster than the slowest tier:
    /// with the render thread busy too the scheduler often ran it on the A12's
    /// slower cluster (CPUs 4–7 at 1.8 GHz against 2.3), which costs time per
    /// tick and changes nothing the game computes. Threads created from it
    /// afterwards (the render queue's workers, audio callbacks) inherit the
    /// mask. Equal cores, unreadable frequencies or a refused mask leave the
    /// thread where the scheduler puts it (CORE_REALTIME P0).
    static func pinToFastCores() {
        let fast = ntsd_cpu_cluster_mask(1)
        if fast != 0 { _ = ntsd_pin_current_thread(fast) }
        // The release thread frees on the slowest tier, as the presenter draws
        // (CORE_REALTIME R3); threads otherwise inherit the main thread's mask.
        OriginalDeferredRelease.threadStart = {
            let slow = ntsd_cpu_cluster_mask(0)
            if slow != 0 { _ = ntsd_pin_current_thread(slow) }
        }
    }
    private func startIfReady() {
        guard session == nil,dataReady,let surface else { return }
        Self.pinToFastCores()
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
        host.checkInputDevices(); host.windows.showControls(host.controls.picture)
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
        host.noteInputDevice(AInputEvent_getDeviceId(event))
        if host.gamepads.handle(event) { return true }
        switch AInputEvent_getType(event) {
        case Int32(AINPUT_EVENT_TYPE_MOTION):
            guard let surface else { return true }
            // The touch screen through the on-screen controls; a mouse or
            // touchpad stays the touch mouse by its first pointer, as before.
            let touchscreen = Int32(AINPUT_SOURCE_TOUCHSCREEN)
            if AInputEvent_getSource(event) & touchscreen == touchscreen { touches(event,host:host,surface:surface); return true }
            guard let p = host.windows.canvasPoint(AMotionEvent_getX(event,0),AMotionEvent_getY(event,0),surface:surface),
                  let (x,y) = host.windows.clientPoint(canvas:p.x,p.y,width:Float(p.width),height:Float(p.height)) else { return true }
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
    /// A motion event's pointers to the on-screen controls, as pixels of the
    /// drawn buffer (TOUCH_CONTROLS): a finger that begins on empty screen —
    /// every first finger while they are hidden — is the touch mouse, as
    /// before; a second finger there is ignored.
    private func touches(_ event: OpaquePointer,host: NTSDAndroidSessionHost,surface: OpaquePointer) {
        let action = AMotionEvent_getAction(event),controls = host.controls
        let index = Int((action & Int32(AMOTION_EVENT_ACTION_POINTER_INDEX_MASK)) >> Int32(AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT))
        func pointer(_ i: Int) -> (id: Int,x: Float,y: Float)? {
            guard i < Int(AMotionEvent_getPointerCount(event)),
                  let p = host.windows.canvasPoint(AMotionEvent_getX(event,i),AMotionEvent_getY(event,i),surface:surface) else { return nil }
            controls.layout(width:Float(p.width),height:Float(p.height),
                            maxUnit:NTSDAndroidWindowHost.controlsUnit(width:Int(p.width),height:Int(p.height),surface:surface,host.windows.target.density))
            return (Int(AMotionEvent_getPointerId(event,i)),p.x,p.y)
        }
        let all = 0..<Int(AMotionEvent_getPointerCount(event))
        switch action & Int32(AMOTION_EVENT_ACTION_MASK) {
        case Int32(AMOTION_EVENT_ACTION_DOWN),Int32(AMOTION_EVENT_ACTION_POINTER_DOWN):
            if controls.hardwareConnected { host.checkInputDevices() }   // hidden: the keyboard or gamepad may be gone
            // The first finger down: any finger still held lost its lift (an
            // event while the surface was gone).
            if action & Int32(AMOTION_EVENT_ACTION_MASK) == Int32(AMOTION_EVENT_ACTION_DOWN) { controls.liftAll() }
            if let p = pointer(index) { controls.began(p.id,x:p.x,y:p.y) }
        case Int32(AMOTION_EVENT_ACTION_MOVE):
            for i in all { if let p = pointer(i) { controls.moved(p.id,x:p.x,y:p.y) } }
        case Int32(AMOTION_EVENT_ACTION_UP),Int32(AMOTION_EVENT_ACTION_POINTER_UP):
            if let p = pointer(index) { controls.ended(p.id,x:p.x,y:p.y) }
        case Int32(AMOTION_EVENT_ACTION_CANCEL):
            for i in all { if let p = pointer(i) { controls.ended(p.id,x:p.x,y:p.y) } }
        default: break
        }
    }
}

/// Carries a value the compiler cannot prove sendable into a background task.
struct UncheckedSendableBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }
