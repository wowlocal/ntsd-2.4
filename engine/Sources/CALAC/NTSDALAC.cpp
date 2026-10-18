#include "NTSDALAC.h"
#include "vendor/ALACDecoder.h"
#include "vendor/ALACBitUtilities.h"
#include <new>

struct NTSDALACDecoder { ALACDecoder decoder; };

NTSDALACDecoder *ntsd_alac_create(const uint8_t *cookie, uint32_t cookieSize) {
    NTSDALACDecoder *result = new (std::nothrow) NTSDALACDecoder();
    if (!result) return nullptr;
    if (result->decoder.Init(const_cast<uint8_t *>(cookie), cookieSize) != ALAC_noErr) { delete result; return nullptr; }
    return result;
}
void ntsd_alac_destroy(NTSDALACDecoder *decoder) { delete decoder; }
uint32_t ntsd_alac_frame_length(const NTSDALACDecoder *decoder) { return decoder->decoder.mConfig.frameLength; }
uint32_t ntsd_alac_channels(const NTSDALACDecoder *decoder) { return decoder->decoder.mConfig.numChannels; }
uint32_t ntsd_alac_bit_depth(const NTSDALACDecoder *decoder) { return decoder->decoder.mConfig.bitDepth; }
int32_t ntsd_alac_decode(NTSDALACDecoder *decoder, const uint8_t *packet, uint32_t packetSize,
                         int16_t *output, uint32_t maxFrames) {
    if (decoder->decoder.mConfig.bitDepth != 16 || maxFrames < decoder->decoder.mConfig.frameLength) return -1;
    BitBuffer bits;
    BitBufferInit(&bits, const_cast<uint8_t *>(packet), packetSize);
    uint32_t frames = 0;
    int32_t status = decoder->decoder.Decode(&bits, reinterpret_cast<uint8_t *>(output), decoder->decoder.mConfig.frameLength,
                                             decoder->decoder.mConfig.numChannels, &frames);
    return status == ALAC_noErr ? static_cast<int32_t>(frames) : -1;
}
