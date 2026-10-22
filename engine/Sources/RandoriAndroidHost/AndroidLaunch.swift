import CAndroidNative
import RandoriCore

/// The Android host (ENGINE_SPLIT E4b): a NativeActivity running a game given as
/// an OriginalGame (NTSDAndroidApp documents the data and the session options).
public enum RandoriAndroidHost {
    /// Takes over the activity: the game's `ntsd_android_on_create` (which
    /// CAndroidNative's ANativeActivity_onCreate calls) calls this on the main
    /// thread. `resources` names the game's content bundle folder among the
    /// extracted data.
    @MainActor public static func create(_ activity: UnsafeMutablePointer<ANativeActivity>,game: OriginalGame,resources: String) {
        NTSDAndroidApp.create(activity,game:game,resources:resources)
    }
}
