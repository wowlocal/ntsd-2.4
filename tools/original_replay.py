"""Read the supplied Windows replay's RNG state. No replacement game RNG.

EXE 0x43e766..0x43e7d3 subtracts the prefix key (VA 0x44d7a0), then
0x43f4d0 inflates zlib. 0x43e3c5..0x43e3f8 restores the RNG state.
This is a fixed practice starting state, not replay playback or match spawning.
"""

import hashlib
import struct
import zlib

REPLAY = "recording/20260331_115445_Stage_1.lfr"


def replay_random(source, exe):
    # The identified PE has matching file/RVA offsets in its .data section.
    key = exe[0x4D7A0 : exe.index(b"\0", 0x4D7A0)]
    raw = (source / REPLAY).read_bytes()
    if struct.unpack_from("<I", raw)[0] != len(raw) - 4:
        raise ValueError("Invalid baseline replay length")
    compressed = bytearray(raw[4:])
    for i in range(min(len(key), len(compressed))):
        compressed[i] = (compressed[i] - key[i] + 48) & 255
    decoded = zlib.decompress(compressed)
    if len(decoded) != 0x630E18 or decoded[0x8C8 + 3000] != 0:
        raise ValueError("Unexpected original replay layout")
    table = list(decoded[0x8C8 : 0x8C8 + 3000])
    index = struct.unpack_from("<i", decoded, 0x8C4)[0]
    if not 0 <= index < 3000 or 0 in table:
        raise ValueError("Invalid original RNG state")
    return dict(
        table=table,
        index=index,
        counter=0,
        source=REPLAY,
        sourceSHA256=hashlib.sha256(raw).hexdigest(),
    )
