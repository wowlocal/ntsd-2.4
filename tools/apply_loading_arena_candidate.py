#!/usr/bin/env python3
"""Relocate only the complete loading test's declared front wrapper storage."""
from pathlib import Path

TEMPLATES = Path(__file__).resolve().parent / 'loading_arena_candidate'
EXISTING = {'Tests/NTSDCoreTests/OriginalApplicationObservedBitmapTests.swift',
            'Tests/NTSDCoreTests/OriginalMacLoadingAudioTests.swift'}
ADDED = set()
NEW = ['OriginalMacLoadingAudioTests/testFrontStorageAvoidsCompleteLoadingAllocations']

def apply(candidate):
    assert {p.name for p in TEMPLATES.glob('*.swift')} == {Path(n).name for n in EXISTING}
    changes = {}
    for relative in sorted(EXISTING):
        target = candidate / 'native' / relative
        before = target.read_text()
        after = (TEMPLATES / Path(relative).name).read_text()
        assert before != after
        target.write_text(after)
        changes['native/' + relative] = dict(before=before, after=after)
    return changes
