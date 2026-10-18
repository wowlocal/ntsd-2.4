/* NTSD alteration: observe zlib's copies after platform string headers have
 * defined their own fortified memcpy. The wrapper performs the real memcpy.
 */
#include <stddef.h>
void *ntsd114_allocator_memcpy(void *destination, const void *source, size_t count);
void ntsd114_longest_match_observed(void);
#undef zmemcpy
#define zmemcpy ntsd114_allocator_memcpy
