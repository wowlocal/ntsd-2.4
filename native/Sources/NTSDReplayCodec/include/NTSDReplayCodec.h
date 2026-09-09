#ifndef NTSD_REPLAY_CODEC_H
#define NTSD_REPLAY_CODEC_H
#include <stdint.h>

typedef struct {
    uint32_t kind; /* 1 calloc, 2 free */
    uint32_t ordinal;
    uint32_t count;
    uint32_t size; /* Native ABI allocation size, not an original x86 address. */
} NTSDReplayCodecEvent;

typedef struct {
    int32_t status;
    uint32_t length;
    uint32_t written;
    uint32_t eventCount;
    uint32_t unreleasedCount;
    uint32_t contractViolation;
    uint32_t longestMatchCalls;
    NTSDReplayCodecEvent events[16];
} NTSDReplayCodecResult;

/* Callers serialize access to the legacy library's lazily initialized tables.
 * failAt is a research allocator stimulus; use 0 for actual native allocation.
 * Events describe the algorithm's allocation/free calls. Private host storage
 * is reclaimed after recording any unfinished allocation lifecycle on error;
 * it is not exposed as reconstructed game memory or a Windows heap simulation.
 */
void ntsd_replay_codec_compress(uint8_t *destination, uint32_t capacity,
    const uint8_t *source, uint32_t sourceCount, int32_t level, uint32_t failAt,
    NTSDReplayCodecResult *result);
#endif
