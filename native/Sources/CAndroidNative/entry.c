#include "CAndroidNative.h"

// The NativeActivity entry point (android.app.lib_name = NTSDAndroid). Android
// calls it on the process main thread; the Swift host takes over from there.
__attribute__((visibility("default"), used))
void ANativeActivity_onCreate(ANativeActivity *activity, void *savedState, size_t savedStateSize) {
    (void)savedState; (void)savedStateSize;
    ntsd_android_on_create(activity);
}
