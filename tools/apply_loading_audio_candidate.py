#!/usr/bin/env python3
"""Apply the finite loading-audio templates to a fresh exact-clone candidate."""
from pathlib import Path

TEMPLATES = Path(__file__).resolve().parent / 'loading_audio_candidate'
EXISTING = {
    'Sources/NTSDCore/' + name + '.swift' for name in [
        'OriginalInitialSoundLoading', 'OriginalInitialLoadingCommon',
        'OriginalInitialLoading', 'OriginalApplicationLoadingSession',
        'OriginalRegisteredSoundLoading', 'OriginalApplicationCatalogControls',
        'OriginalApplicationCatalogSession', 'OriginalApplicationPoolSession',
        'OriginalApplicationLoadedMenuSession']
} | {
    'Sources/NTSDMacPlatform/' + name + '.swift' for name in [
        'OriginalMacAudioBackend', 'OriginalMacAudioService']
} | {
    'Sources/NTSDReferenceChecks/' + name + '.swift' for name in [
        'CatalogSoundsReference', 'InitialLoadingReference']
} | {
    'Tests/NTSDCoreTests/' + name + '.swift' for name in [
        'OriginalApplicationLoadingPrefixTests', 'OriginalApplicationCatalogFullReference']
}
ADDED = {
    'Sources/NTSDCore/' + name + '.swift' for name in [
        'OriginalWaveOwnership', 'OriginalWavePreparation',
        'OriginalLoadingAudioExchange', 'OriginalApplicationObservedLoadingAudio']
} | {
    'Tests/NTSDCoreTests/' + name + '.swift' for name in [
        'OriginalLoadingAudioTests', 'OriginalMacLoadingAudioTests']
}

def apply(candidate):
    actual = {str(p.relative_to(TEMPLATES)) for p in TEMPLATES.rglob('*.swift')}
    assert actual == EXISTING | ADDED and len(actual) == 21
    changes = {}
    for relative in sorted(actual):
        source = TEMPLATES / relative
        target = candidate / 'native' / relative
        assert target.exists() == (relative in EXISTING), str(target)
        before = target.read_text() if target.exists() else None
        after = source.read_text()
        assert before != after
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(after)
        changes['native/' + relative] = dict(before=before, after=after)
    return changes
