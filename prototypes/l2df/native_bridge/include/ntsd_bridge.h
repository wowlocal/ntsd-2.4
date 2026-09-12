#ifndef NTSD_BRIDGE_H
#define NTSD_BRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/* ABI1 has only unbound Actor storage, never a loaded match. */
#define NTSD_BRIDGE_ABI_VERSION 1u
#define NTSD_BRIDGE_ACTOR_SIZE 1056u
#define NTSD_BRIDGE_CAP_ACTOR_STORAGE 1u
#define NTSD_BRIDGE_ACTOR_STORAGE 1u
enum ntsd_bridge_result {
    NTSD_BRIDGE_OK = 0, NTSD_BRIDGE_INVALID_ARGUMENT = 1,
    NTSD_BRIDGE_ABI_MISMATCH = 2, NTSD_BRIDGE_INVALID_HANDLE = 3,
    NTSD_BRIDGE_OUT_OF_BOUNDS = 4, NTSD_BRIDGE_UNDEFINED = 5,
    NTSD_BRIDGE_LIMIT = 7,
    NTSD_BRIDGE_INTERNAL_ERROR = 8
};

uint32_t ntsd_bridge_abi_version(void);
uint32_t ntsd_bridge_capabilities(void);
uint32_t ntsd_bridge_live_sessions(void);
/* Input backing is copied. Untouched bytes do not become known defaults. */
int32_t ntsd_bridge_create(uint32_t abi, const uint8_t *backing, uint32_t count,
                           uint64_t *out_handle);
int32_t ntsd_bridge_destroy(uint64_t handle);
int32_t ntsd_bridge_info(uint64_t handle, uint32_t *out_lifecycle,
                         uint64_t *out_revision);
/* Output buffers may not overlap; insufficient capacity writes nothing. */
int32_t ntsd_bridge_snapshot(uint64_t handle, uint8_t *bytes, uint8_t *defined,
                             uint32_t capacity, uint64_t *out_revision);
int32_t ntsd_bridge_read_i32(uint64_t handle, uint32_t offset, int32_t *out_value);
/* Developer/setup edits, NOT gameplay: aligned already-defined words only.
   Arrays hold count elements. Commit all edits and one revision, or none. */
int32_t ntsd_bridge_setup_apply_i32(uint64_t handle, const uint32_t *offsets,
                                   const int32_t *values, uint32_t count);

#ifdef __cplusplus
}
#endif
#endif
