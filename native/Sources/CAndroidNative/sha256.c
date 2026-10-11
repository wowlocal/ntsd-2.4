// SHA-256 block compression with the ARMv8 SHA-2 instructions, for the
// packaged-input digests (MEMORY_LOADING L11). The same function as
// PortableSHA256's Swift compression; NTSDAndroid installs it only after it
// gives the Swift digests on test inputs.
#include "CAndroidNative.h"
#include <stddef.h>
#include <stdint.h>
#if defined(__aarch64__)
#include <arm_neon.h>
#include <asm/hwcap.h>
#include <sys/auxv.h>

int ntsd_sha256_available(void) { return (getauxval(AT_HWCAP) & HWCAP_SHA2) != 0; }

static const uint32_t ntsd_sha256_k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

__attribute__((target("sha2")))
void ntsd_sha256_blocks(uint32_t *state, const uint8_t *data, size_t blocks) {
    uint32x4_t abcd = vld1q_u32(state), efgh = vld1q_u32(state + 4);
    for (; blocks > 0; blocks--, data += 64) {
        uint32x4_t message[4];
        for (int i = 0; i < 4; i++) message[i] = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data + 16 * i)));
        uint32x4_t a = abcd, e = efgh;
        // Four rounds per step; the schedule's next four words replace the
        // four just used, while words remain to be made (steps 0 to 11).
        for (int i = 0; i < 16; i++) {
            uint32x4_t wk = vaddq_u32(message[i & 3], vld1q_u32(ntsd_sha256_k + 4 * i));
            uint32x4_t previous = a;
            a = vsha256hq_u32(a, e, wk);
            e = vsha256h2q_u32(e, previous, wk);
            if (i < 12)
                message[i & 3] = vsha256su1q_u32(vsha256su0q_u32(message[i & 3], message[(i + 1) & 3]),
                                                 message[(i + 2) & 3], message[(i + 3) & 3]);
        }
        abcd = vaddq_u32(abcd, a);
        efgh = vaddq_u32(efgh, e);
    }
    vst1q_u32(state, abcd);
    vst1q_u32(state + 4, efgh);
}
#else
int ntsd_sha256_available(void) { return 0; }
void ntsd_sha256_blocks(uint32_t *state, const uint8_t *data, size_t blocks) { (void)state; (void)data; (void)blocks; }
#endif
