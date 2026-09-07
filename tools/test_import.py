#!/usr/bin/env python3
import hashlib
import re
import struct
import unittest

from import_ntsd import DEFAULT_SOURCE, EXE_SHA256, EXE_KEY, KEY, decode_dat, fields, parse_object, parse_background, read_bytes
from inspect_original import PE, dib_to_bmp


class OriginalImportTests(unittest.TestCase):
    def test_rejects_lfs_and_truncated_headers(self):
        for data in [b'version https://git-lfs.github.com/spec/v1\n', b'short']:
            with self.assertRaises(ValueError): decode_dat(data)

    def test_preserves_original_strings_and_all_body_blocks(self):
        text = decode_dat(read_bytes(DEFAULT_SOURCE / 'chars/naruto.dat'))
        obj = parse_object(text)
        self.assertEqual(obj['header']['running_speed'], '15.000000')
        self.assertEqual(obj['frames']['0']['blocks']['bdy'][1]['y'], '80000')
        self.assertEqual(len(obj['frameOccurrences']), len(re.findall(r'<frame>\s+\d+', text)))
        duplicates = [f for f in obj['frameOccurrences'] if f['number'] == 123]
        self.assertEqual(len(duplicates), 2)
        self.assertEqual(duplicates[0]['frame']['fields']['dvy'], '550')
        self.assertEqual(duplicates[1]['frame']['fields']['dvy'], '0')
        self.assertEqual(duplicates[0]['frame']['fields']['hit_d'], '370')
        self.assertEqual(duplicates[1]['frame']['fields']['hit_d'], '0')

    def test_cipher_key_is_from_identified_windows_executable(self):
        exe = read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe')
        self.assertEqual(hashlib.sha256(exe).hexdigest(), EXE_SHA256)
        pe = PE(exe)
        self.assertEqual(pe.string(0x44892c - pe.base).encode(), EXE_KEY)
        self.assertEqual(KEY[0], EXE_KEY[123 % len(EXE_KEY)])

    def test_original_payload_roundtrip_keeps_every_byte(self):
        for relative in ['chars/naruto.dat', 'chars/sasuke.dat', 'chars/flash.dat', 'bg/sys/Valley/bg.dat']:
            with self.subTest(file=relative):
                raw = read_bytes(DEFAULT_SOURCE / relative)
                decoded = decode_dat(raw).encode('latin-1')
                encoded = bytes((b + KEY[i % len(KEY)]) & 255 for i, b in enumerate(decoded))
                self.assertEqual(raw[123:], encoded)

    def test_original_background_layers_and_cycles(self):
        text = decode_dat(read_bytes(DEFAULT_SOURCE / 'bg/sys/Valley/bg.dat'))
        bg = parse_background(text)
        self.assertEqual(bg['header']['zboundary'], '400 420')
        self.assertEqual(len(bg['layers']), 8)
        self.assertEqual(bg['layers'][0]['loop'], '497')
        self.assertEqual(bg['layers'][2]['cc'], '26')

    def test_numeric_overflow_and_repeated_blocks_are_not_sanitized(self):
        obj = parse_object('''<bmp_begin>\nname: fixture\n<bmp_end>
<frame> 0 still
pic: 0 state: 0 wait: 3 next: 0
itr:
kind: 0 injury: 99999999999999999999999
itr_end:
itr:
kind: 8 injury: -842150451
itr_end:
<frame_end>''')
        blocks = obj['frameOccurrences'][0]['frame']['blocks']['itr']
        self.assertEqual(blocks[0]['injury'], '99999999999999999999999')
        self.assertEqual(blocks[1]['injury'], '-842150451')

    def test_extracted_bitmap_preserves_original_dib(self):
        raw = read_bytes(DEFAULT_SOURCE / 'NTSD 2.4.exe')
        pe = PE(raw)
        bitmaps = [r for r in pe.resources() if r['path'][0] == 2]
        self.assertEqual(len(bitmaps), 64)
        for resource in bitmaps:
            dib = raw[resource['fileOffset']:resource['fileOffset'] + resource['size']]
            bmp = dib_to_bmp(dib)
            self.assertEqual(bmp[14:], dib)
            self.assertEqual(struct.unpack_from('<I', bmp, 2)[0], len(bmp))


if __name__ == '__main__': unittest.main()
