// The NDK interfaces the Android host uses (P8, docs/research/CROSS_PLATFORM.md).
#pragma once
#include <aaudio/AAudio.h>
#include <android/asset_manager.h>
#include <android/configuration.h>
#include <android/input.h>
#include <android/keycodes.h>
#include <android/log.h>
#include <android/looper.h>
#include <android/native_activity.h>
#include <android/native_window.h>
#include <sys/eventfd.h>
#include <sys/timerfd.h>
#include <unistd.h>

/// Pins the calling thread to the CPUs whose bits are set in `mask` (bit n is
/// CPU n); 0, or -1 with errno, as sched_setaffinity. A failure leaves the
/// thread where the scheduler puts it (CORE_REALTIME R2c: the presenter on
/// the cluster the main thread is not on).
int ntsd_pin_current_thread(unsigned long mask);
/// The CPUs faster than the slowest tier by maximum frequency (`fast`
/// nonzero), or the slowest tier (`fast` zero), as a bit mask (bit n is CPU
/// n); 0 when the frequencies cannot all be read or are all equal. Excluding
/// only the slowest tier keeps every big and prime core on three-tier chips
/// (CORE_REALTIME P0).
unsigned long ntsd_cpu_cluster_mask(int fast);
/// Sets the calling thread's nice value (setpriority on its thread id); 0, or
/// -1 with errno. Threads it creates afterwards inherit it (MEMORY_LOADING L13:
/// the read-ahead yields to the game and presenter threads).
int ntsd_set_current_thread_nice(int nice);

/// SHA-256 block compression with the ARMv8 SHA-2 instructions (MEMORY_LOADING
/// L11): `state` the eight hash words, `data` `blocks` 64-byte blocks. Use only
/// when ntsd_sha256_available() is nonzero (the CPU has them).
int ntsd_sha256_available(void);
void ntsd_sha256_blocks(uint32_t *_Nonnull state, const uint8_t *_Nonnull data, size_t blocks);

// libdispatch's main-queue hooks, the ones CoreFoundation's run loop uses: the
// host puts the main queue's eventfd on the main thread's ALooper and drains it.
extern int _dispatch_get_main_queue_handle_4CF(void);
extern void _dispatch_main_queue_callback_4CF(void *_Null_unspecified msg);

// Hides the status and navigation bars (immersive sticky) through the
// activity's decor view. Call on the main thread (activity->env is its JNIEnv).
void ntsd_android_hide_system_bars(ANativeActivity *_Nonnull activity);

// Implemented in Swift by the game's library (NTSD's NTSDAndroid), which hands
// the activity to RandoriAndroidHost; ANativeActivity_onCreate forwards to it.
extern void ntsd_android_on_create(ANativeActivity *_Nonnull activity);
