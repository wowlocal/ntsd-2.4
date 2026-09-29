#include <stdlib.h>
#include <string.h>
#include "include/NTSDReplayCodec.h"
#include "vendor/zlib.h"
#undef calloc
#undef free
#undef memcpy

typedef struct {
    NTSDReplayCodecResult *result;
    void *allocations[16];
    uint32_t allocationCount, failAt;
    uintptr_t destination;
    uint32_t capacity;
} CodecContext;

static _Thread_local CodecContext *current;

void ntsd114_longest_match_observed(void) {
    if (current) ++current->result->longestMatchCalls;
}

static void event(uint32_t kind, uint32_t ordinal, uint32_t count, uint32_t size) {
    NTSDReplayCodecResult *result = current->result;
    if (result->eventCount >= 16) { result->contractViolation = 1; return; }
    result->events[result->eventCount++] = (NTSDReplayCodecEvent){kind, ordinal, count, size};
}

void *ntsd114_allocator_calloc(size_t count, size_t size) {
    if (!current) return calloc(count, size);
    uint32_t ordinal = ++current->allocationCount;
    if (ordinal > 16) { current->result->contractViolation = 1; return NULL; }
    void *pointer = ordinal == current->failAt ? NULL : calloc(count, size);
    current->allocations[ordinal-1] = pointer;
    event(1, pointer ? ordinal : 0, (uint32_t)count, (uint32_t)size);
    return pointer;
}

void ntsd114_allocator_free(void *pointer) {
    if (current) {
        uint32_t ordinal = 0;
        if (pointer) {
            for (uint32_t i = 0; i < current->allocationCount; ++i) {
                if (current->allocations[i] == pointer) {
                    ordinal = i+1; current->allocations[i] = NULL; break;
                }
            }
            if (!ordinal) current->result->contractViolation = 1;
        }
        event(2, ordinal, 0, 0);
    }
    free(pointer);
}

void *ntsd114_allocator_memcpy(void *destination, const void *source, size_t count) {
    if (current && count) {
        uintptr_t address = (uintptr_t)destination;
        uintptr_t begin = current->destination, end = begin+current->capacity;
        if (address >= begin && address <= end) {
            if (address != begin+current->result->written || count > end-address) {
                current->result->contractViolation = 1;
                return destination;
            }
            current->result->written += (uint32_t)count;
        }
    }
    return memcpy(destination, source, count);
}

void ntsd_replay_codec_compress(uint8_t *destination, uint32_t capacity,
    const uint8_t *source, uint32_t sourceCount, int32_t level, uint32_t failAt,
    NTSDReplayCodecResult *result) {
    memset(result, 0, sizeof(*result));
    CodecContext context = {0};
    context.result = result; context.failAt = failAt;
    context.destination = (uintptr_t)destination; context.capacity = capacity;
    CodecContext *previous = current; current = &context;
    uLongf length = capacity;
    result->status = compress2(destination, &length, source, sourceCount, level);
    result->length = (uint32_t)length;
    current = previous;
    /* Capture original-library lifecycle before reclaiming private host memory.
     * deflateInit2_ 1.1.4 can leave four allocations live after a late failure.
     * This reclamation is not reported as an original free request.
     */
    for (uint32_t i = 0; i < context.allocationCount && i < 16; ++i) {
        if (context.allocations[i]) { ++result->unreleasedCount; free(context.allocations[i]); }
    }
}

int32_t ntsd_replay_codec_uncompress(uint8_t *destination, uint32_t *length,
    uint32_t *produced, const uint8_t *source, uint32_t sourceCount) {
    /* The body of the vendored uncompr.c uncompress, unchanged, with the
     * stream's total_out also reported on failure (bytes written before an
     * error are not otherwise visible). */
    CodecContext *previous = current; current = NULL;
    z_stream stream;
    int err;
    *produced = 0;
    stream.next_in = (Bytef*)source;
    stream.avail_in = (uInt)sourceCount;
    stream.next_out = destination;
    stream.avail_out = (uInt)*length;
    stream.zalloc = (alloc_func)0;
    stream.zfree = (free_func)0;
    err = inflateInit(&stream);
    if (err != Z_OK) { current = previous; return err; }
    err = inflate(&stream, Z_FINISH);
    *produced = (uint32_t)stream.total_out;
    if (err != Z_STREAM_END) {
        inflateEnd(&stream);
        current = previous;
        return err == Z_OK ? Z_BUF_ERROR : err;
    }
    *length = (uint32_t)stream.total_out;
    err = inflateEnd(&stream);
    current = previous;
    return err;
}
