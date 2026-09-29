/* Private symbol namespace; no compression algorithm changes. */
#ifndef NTSD_REPLAY_CODEC_PREFIX_H
#define NTSD_REPLAY_CODEC_PREFIX_H
/* SwiftPM defines DEBUG=1 for C in debug builds; zlib 1.1.4 would then add
 * debug-only deflate_state fields and its Assert/Trace code. The accepted
 * comparison is of the ordinary library, so the codec never sees DEBUG. */
#undef DEBUG
#include <stddef.h>
void *ntsd114_allocator_calloc(size_t count, size_t size);
void ntsd114_allocator_free(void *pointer);
/* Modern Darwin defines TARGET_OS_MAC without the classic MacTypes Byte. */
#if defined(__APPLE__) && defined(__MACH__)
typedef unsigned char Byte;
#endif
#define adler32 ntsd114_adler32
#define compress ntsd114_compress
#define compress2 ntsd114_compress2
#define deflateInit_ ntsd114_deflateInit_
#define deflateInit2_ ntsd114_deflateInit2_
#define deflate ntsd114_deflate
#define deflateEnd ntsd114_deflateEnd
#define deflateSetDictionary ntsd114_deflateSetDictionary
#define deflateCopy ntsd114_deflateCopy
#define deflateReset ntsd114_deflateReset
#define deflateParams ntsd114_deflateParams
#define deflate_copyright ntsd114_deflate_copyright
#define zcalloc ntsd114_zcalloc
#define zcfree ntsd114_zcfree
#define zlibVersion ntsd114_zlibVersion
#define zError ntsd114_zError
#define z_errmsg ntsd114_z_errmsg
#define _tr_init ntsd114_tr_init
#define _tr_tally ntsd114_tr_tally
#define _tr_flush_block ntsd114_tr_flush_block
#define _tr_align ntsd114_tr_align
#define _tr_stored_block ntsd114_tr_stored_block
#define _dist_code ntsd114_dist_code
#define _length_code ntsd114_length_code
/* Inflation (playback loading, 43f4d0 = uncompress). */
#define inflate ntsd114_inflate
#define inflateEnd ntsd114_inflateEnd
#define inflateInit_ ntsd114_inflateInit_
#define inflateInit2_ ntsd114_inflateInit2_
#define inflateReset ntsd114_inflateReset
#define inflateSetDictionary ntsd114_inflateSetDictionary
#define inflateSync ntsd114_inflateSync
#define inflateSyncPoint ntsd114_inflateSyncPoint
#define uncompress ntsd114_uncompress
#define inflate_blocks ntsd114_inflate_blocks
#define inflate_blocks_free ntsd114_inflate_blocks_free
#define inflate_blocks_new ntsd114_inflate_blocks_new
#define inflate_blocks_reset ntsd114_inflate_blocks_reset
#define inflate_blocks_sync_point ntsd114_inflate_blocks_sync_point
#define inflate_codes ntsd114_inflate_codes
#define inflate_codes_free ntsd114_inflate_codes_free
#define inflate_codes_new ntsd114_inflate_codes_new
#define inflate_copyright ntsd114_inflate_copyright
#define inflate_fast ntsd114_inflate_fast
#define inflate_flush ntsd114_inflate_flush
#define inflate_mask ntsd114_inflate_mask
#define inflate_set_dictionary ntsd114_inflate_set_dictionary
#define inflate_trees_bits ntsd114_inflate_trees_bits
#define inflate_trees_dynamic ntsd114_inflate_trees_dynamic
#define inflate_trees_fixed ntsd114_inflate_trees_fixed
/* Observe private allocations without altering deflate. */
#define calloc ntsd114_allocator_calloc
#define free ntsd114_allocator_free
#endif
