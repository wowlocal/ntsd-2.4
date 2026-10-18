// FreeType for the glyph masks of hosts without CoreText (NTSDFreeTypeText).
// The include path (include/freetype2) and the static library come from
// NTSD_FREETYPE_PREFIX.
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MULTIPLE_MASTERS_H

static const FT_Int32 NTSD_FT_LOAD_MONO = FT_LOAD_RENDER | FT_LOAD_TARGET_MONO;
static inline int ntsd_ft_has_kerning(FT_Face face) { return FT_HAS_KERNING(face) ? 1 : 0; }
