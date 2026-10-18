// C interface to Apple's ALAC reference decoder (vendor/, Apache-2.0) for
// NTSDMusicDecoder: decodes the packaged original tracks without AVFoundation.
#ifndef NTSD_ALAC_H
#define NTSD_ALAC_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct NTSDALACDecoder NTSDALACDecoder;
/// A decoder for the CAF/MP4 magic cookie, or NULL when it is not valid ALAC.
NTSDALACDecoder *ntsd_alac_create(const uint8_t *cookie, uint32_t cookieSize);
void ntsd_alac_destroy(NTSDALACDecoder *decoder);
uint32_t ntsd_alac_frame_length(const NTSDALACDecoder *decoder);
uint32_t ntsd_alac_channels(const NTSDALACDecoder *decoder);
uint32_t ntsd_alac_bit_depth(const NTSDALACDecoder *decoder);
/// Decodes one packet into interleaved samples (16-bit for 16-bit streams);
/// returns the frame count, or -1 on a decoder error.
int32_t ntsd_alac_decode(NTSDALACDecoder *decoder, const uint8_t *packet, uint32_t packetSize,
                         int16_t *output, uint32_t maxFrames);
#ifdef __cplusplus
}
#endif
#endif
