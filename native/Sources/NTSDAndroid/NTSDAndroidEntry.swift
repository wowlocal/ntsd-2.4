import CAndroidNative
import RandoriAndroidHost
import NTSDContent

// NTSDAndroid (P8, docs/research/CROSS_PLATFORM.md): NTSD in an Android
// NativeActivity through the engine's Android host (ENGINE_SPLIT E4b). The
// engine's ANativeActivity_onCreate (CAndroidNative) calls this on the process
// main thread; the content bundle is SwiftPM's NTSDNative_NTSDContent.bundle,
// which tools/crossplatform/android_app.py ships among the data.
@_cdecl("ntsd_android_on_create")
func ntsdAndroidOnCreate(_ activity: UnsafeMutablePointer<ANativeActivity>) {
    MainActor.assumeIsolated { RandoriAndroidHost.create(activity,game:NTSDContent.runtimeGame,resources:"NTSDNative_NTSDContent.bundle") }
}
