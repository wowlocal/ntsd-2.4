#!/usr/bin/env python3
"""Apply one scanner optimization and its bounded Native preservation control."""
from pathlib import Path

TEMPLATES = Path(__file__).resolve().parent / 'decimal_materialization_candidate'
EXISTING = {'Sources/NTSDCore/OriginalFrameLoader.swift'}
ADDED = {'Tests/NTSDCoreTests/OriginalDecimalMaterializationTests.swift'}
NEW = ['OriginalDecimalMaterializationTests/testMaterializationPreservesExistingNativeReadProtocol']
ADDITIONAL = [
    'OriginalCatalogPrecisionTests/testEveryActualDATDoubleScanAtExplicit53Bits',
    'OriginalCatalogPrecisionTests/testCompleteOriginalCatalogAtExplicit53Bits',
    'OriginalCRTTests/testIntegersAgainstMicrosoftInstructions',
    'OriginalObjectTests/testAllSourceObjectsAndRawFrameStorage',
    'OriginalObjectTests/testObjectStreamsWithMicrosoftScanf',
    'OriginalObjectTests/testCompleteObjectStreamsAgainstOriginalInstructions',
    'OriginalObjectTests/testFailedObjectDoesNotCommitSharedLoadingState',
    'OriginalStageTests/testWholeStageTableAgainstOriginalInstructions',
    'OriginalStageTests/testUnsupportedStageDoesNotCommitEarlierParsedStages',
    'OriginalLoadedCatalogTests/testCompleteOriginalCatalogWithTextFiles',
    'OriginalLoadedCatalogTests/testCompleteOriginalCatalogWithRawFilesAndZeroBacking',
    'OriginalLoadedCatalogTests/testInterleavedChildrenAndDuplicateSourceIDs',
    'OriginalFrameLoaderTests/testOriginalX86SnapshotsAfterEveryOccurrence',
    'OriginalFrameLoaderTests/testUnsupportedInputDoesNotCommitPartialState',
]

def apply(candidate):
    assert {p.name for p in TEMPLATES.glob('*.swift')} == {Path(n).name for n in EXISTING | ADDED}
    changes = {}
    for relative in sorted(EXISTING | ADDED):
        target = candidate / 'native' / relative
        assert target.exists() == (relative in EXISTING)
        before = target.read_text() if target.exists() else None
        after = (TEMPLATES / Path(relative).name).read_text()
        assert before != after
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(after)
        changes['native/' + relative] = dict(before=before, after=after)
    return changes
