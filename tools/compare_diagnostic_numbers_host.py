#!/usr/bin/env python3
"""Compare accepted VC80 outputs with this host's snprintf; never an acceptance gate."""
import base64
import ctypes
import json
import platform
import struct
import zlib
from collections import Counter
from accept_initialized_gameplay import ROOT, FIXTURES, digest


def main():
    evidence = json.loads((ROOT/'docs/evidence/diagnostic-numbers.json').read_bytes())
    packed = (FIXTURES/evidence['fixture']).read_bytes()
    assert digest(packed) == evidence['fixtureSHA256']
    transport = json.loads(packed)
    payload = zlib.decompress(base64.b64decode(transport['deflate']), -15)
    assert len(payload) == transport['count'] and digest(payload) == transport['sha256']
    doc = json.loads(payload)
    libc = ctypes.CDLL(None)
    snprintf = libc.snprintf
    snprintf.restype = ctypes.c_int
    snprintf.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_char_p]
    output = ctypes.create_string_buffer(4096)
    counts = Counter(); examples = []
    for item in doc['cases']:
        bits = int(item['bits'], 16)
        kind = 'nonfinite' if (bits >> 52) & 0x7ff == 0x7ff else 'finite'
        size = snprintf(output, len(output), f'%2.{item["precision"]}f'.encode(),
                        ctypes.c_double.from_buffer_copy(struct.pack('<Q', bits)))
        assert 0 <= size < len(output)
        actual = output.raw[:size].decode('ascii')
        if actual != item['output']:
            counts[kind] += 1
            if len(examples) < 8 or item['group'] == 'decimal-midpoint' and len(examples) < 15:
                examples.append(dict(bits=item['bits'], precision=item['precision'], source=item['output'], host=actual, group=item['group']))
    report = dict(platform=platform.platform(), fixtureSHA256=evidence['fixtureSHA256'], cases=len(doc['cases']),
                  differences=dict(counts), examples=examples)
    (ROOT/'build/research/diagnostic-numbers-host-differences.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'examples'}, indent=2))


if __name__ == '__main__':
    main()
