#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["unicorn==2.1.4", "olefile==0.47"]
# ///
"""Accept both captured 43dfa0 corpora: add the base recordings, pack, compare through
NTSDCatalogCheck --replay-playback, then install fixtures and update reports.
Nothing is installed unless both comparisons pass."""
import base64
import json
import subprocess
from import_ntsd import ROOT
from oracle_catalog_sounds import pack
from oracle_wave_loader import digest


def main():
    subprocess.run(['xcrun', '--toolchain', 'XcodeDefault', 'swift', 'build', '--package-path', str(ROOT / 'native'),
                    '--scratch-path', str(ROOT / 'build/swiftpm-app'), '--build-system', 'native', '-c', 'release',
                    '--product', 'NTSDCatalogCheck'], check=True)
    pending = []
    fixture_root = ROOT / 'native/Tests/NTSDCoreTests/Fixtures'
    for suffix in ('', '-control'):
        report_path = ROOT / 'docs/evidence' / f'replay-playback{suffix}.json'
        report = json.loads(report_path.read_bytes())
        raw = (ROOT / 'build/original' / report['corpus']).read_bytes()
        assert digest(raw) == report['sha256']
        temporary = ROOT / 'build/original' / f'replay-playback{suffix}-check.json'
        doc = json.loads(raw)
        # The base recordings the corpus's cases edit, as the app wrote them.
        doc['recordings'] = {n: base64.b64encode((ROOT / f'build/research/playback/inputs/{n}.lfr').read_bytes()).decode()
                             for n in ('vs', 'war', 'mission')}
        temporary.write_text(pack(doc))
        parents = [str(fixture_root / f'original-{key}{suffix}.json') for key in ('initial-loading', 'initial-loading-catalog', 'initial-loading-sounds')]
        result = subprocess.run([str(ROOT / 'build/swiftpm-app/release/NTSDCatalogCheck'), '--replay-playback', str(temporary), *parents],
                                capture_output=True, text=True)
        print(result.stdout, end='', flush=True)
        if result.returncode:
            print(result.stderr, end='', flush=True)
            result.check_returncode()
        fixture = fixture_root / ('original-' + report['corpus'])
        data = temporary.read_bytes()
        report.update(nativeComparison=result.stdout.strip(), fixture=fixture.name, fixtureSHA256=digest(data), fixtureBytes=len(data))
        pending.append((report_path, report, fixture, data))
    for report_path, report, fixture, data in pending:
        fixture.write_bytes(data)
        report_path.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
