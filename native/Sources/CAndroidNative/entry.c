#include "CAndroidNative.h"
#include <jni.h>

// The NativeActivity entry point (android.app.lib_name = NTSDAndroid). Android
// calls it on the process main thread; the Swift host takes over from there.
__attribute__((visibility("default"), used))
void ANativeActivity_onCreate(ANativeActivity *activity, void *savedState, size_t savedStateSize) {
    (void)savedState; (void)savedStateSize;
    ntsd_android_on_create(activity);
}

// View.setSystemUiVisibility(LAYOUT_STABLE | LAYOUT_HIDE_NAVIGATION |
// LAYOUT_FULLSCREEN | HIDE_NAVIGATION | FULLSCREEN | IMMERSIVE_STICKY) on
// getWindow().getDecorView(): the game covers the whole screen and a swipe
// from an edge shows the bars for a moment. Deprecated since API 30 but kept
// by the platform (minSdk 28). Any Java exception is cleared: the bars stay.
void ntsd_android_hide_system_bars(ANativeActivity *activity) {
    JNIEnv *env = activity->env;
    jclass activityClass = (*env)->GetObjectClass(env, activity->clazz);
    jmethodID getWindow = (*env)->GetMethodID(env, activityClass, "getWindow", "()Landroid/view/Window;");
    jobject window = getWindow ? (*env)->CallObjectMethod(env, activity->clazz, getWindow) : NULL;
    if (window && !(*env)->ExceptionCheck(env)) {
        jclass windowClass = (*env)->GetObjectClass(env, window);
        jmethodID getDecorView = (*env)->GetMethodID(env, windowClass, "getDecorView", "()Landroid/view/View;");
        jobject decor = getDecorView ? (*env)->CallObjectMethod(env, window, getDecorView) : NULL;
        if (decor && !(*env)->ExceptionCheck(env)) {
            jclass viewClass = (*env)->GetObjectClass(env, decor);
            jmethodID setVisibility = (*env)->GetMethodID(env, viewClass, "setSystemUiVisibility", "(I)V");
            if (setVisibility) (*env)->CallVoidMethod(env, decor, setVisibility, 0x100 | 0x200 | 0x400 | 0x2 | 0x4 | 0x1000);
            (*env)->DeleteLocalRef(env, viewClass);
            (*env)->DeleteLocalRef(env, decor);
        }
        (*env)->DeleteLocalRef(env, windowClass);
        (*env)->DeleteLocalRef(env, window);
    }
    (*env)->DeleteLocalRef(env, activityClass);
    if ((*env)->ExceptionCheck(env)) (*env)->ExceptionClear(env);
}
