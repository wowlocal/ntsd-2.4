// The NDK interfaces the Android host uses (P8, docs/research/CROSS_PLATFORM.md).
#pragma once
#include <android/asset_manager.h>
#include <android/configuration.h>
#include <android/input.h>
#include <android/keycodes.h>
#include <android/log.h>
#include <android/looper.h>
#include <android/native_activity.h>
#include <android/native_window.h>
#include <sys/eventfd.h>

// libdispatch's main-queue hooks, the ones CoreFoundation's run loop uses: the
// host puts the main queue's eventfd on the main thread's ALooper and drains it.
extern int _dispatch_get_main_queue_handle_4CF(void);
extern void _dispatch_main_queue_callback_4CF(void *_Null_unspecified msg);

// Implemented in Swift (NTSDAndroid); ANativeActivity_onCreate forwards to it.
extern void ntsd_android_on_create(ANativeActivity *_Nonnull activity);
