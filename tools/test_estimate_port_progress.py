import unittest

from estimate_port_progress import collect, linear_remaining_hours, matches


class ProgressEstimateTests(unittest.TestCase):
    def test_compact_annotations_from_native_sources(self):
        examples = {
            'Whole421cdc..422218': {(0x421cdc, 0x422218)},
            'Entire421a15..421a2d caller and41ae60..41b12d HUD': {
                (0x421a15, 0x421a2d), (0x41ae60, 0x41b12d)},
            'EXE43d157..43d1ef': {(0x43d157, 0x43d1ef)},
            'interleaved41f550..4214d5': {(0x41f550, 0x4214d5)},
            '0x401000–0x401020': {(0x401000, 0x401020)},
        }
        for annotation, expected in examples.items():
            with self.subTest(annotation=annotation):
                self.assertEqual(matches(annotation), expected)

    def test_longer_hex_values_are_not_address_ranges(self):
        for text in ['ABC421cdc..422218', '1421cdc..422218',
                     '0x1421cdc..422218', '421cdc..422218f']:
            with self.subTest(text=text):
                self.assertEqual(matches(text), set())

    def test_compact_prose_does_not_expand_evidence_sources(self):
        files = {
            'native/Sources/NTSDCore/Example.swift':
                '/// Whole421cdc..422218\n'
                'let sample = "Whole401000..401020"\n'
                '// Globals450000..450010\n',
            'docs/research/UNREVIEWED.md': 'Whole402000..402100',
            'native/Sources/NTSDReferenceChecks/Example.swift':
                '// Whole403000..403100',
        }
        entries = collect(files, 0x401000, 0x44630a)
        self.assertEqual([(e['start'], e['stop']) for e in entries],
                         [(0x421cdc, 0x422218)])

    def test_unchanged_or_shrinking_envelope_has_no_forward_eta(self):
        self.assertIsNone(linear_remaining_hours(145127, 0))
        self.assertIsNone(linear_remaining_hours(145127, -100))

    def test_positive_growth_and_empty_remainder(self):
        self.assertEqual(linear_remaining_hours(100, 20), 5)
        self.assertEqual(linear_remaining_hours(0, 0), 0)


if __name__ == '__main__':
    unittest.main()
