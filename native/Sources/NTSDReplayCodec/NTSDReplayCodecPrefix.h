/* Private symbol namespace; no compression algorithm changes. */
#ifndef NTSD_REPLAY_CODEC_PREFIX_H
#define NTSD_REPLAY_CODEC_PREFIX_H
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
/* Observe private allocations without altering deflate. */
#define calloc ntsd114_allocator_calloc
#define free ntsd114_allocator_free
#endif
