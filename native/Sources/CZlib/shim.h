// The host SDK's zlib, used only to decode DEFLATE test fixtures where
// Apple's Compression framework is unavailable. Game replay compression keeps
// the pinned zlib 1.1.4 in NTSDReplayCodec.
#include <zlib.h>
