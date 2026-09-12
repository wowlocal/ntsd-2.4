#!/usr/bin/env python3
"""One bounded native LÖVE FFI test against a completed isolated bridge build."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil

from build import HERE, ROOT, now, run_owned, sha, storage_check, verify_package, write_json

parser = argparse.ArgumentParser()
parser.add_argument('--build-label', required=True)
parser.add_argument('--label', required=True)
parser.add_argument('--study', choices=['native-bridge-20260912', 'loaded-session-20260912'], default='native-bridge-20260912')
parser.add_argument('--resources', type=Path)
args = parser.parse_args()
for label in [args.build_label, args.label]:
    assert Path(label).name == label and label not in ('.', '..')
storage, volume = storage_check()
build = storage / args.study / args.build_label
artifact = json.loads((build / 'artifact.json').read_text())
library = Path(artifact['library'])
assert sha(library) == artifact['sha256']
assert 'ntsd_bridge_tick' not in artifact['exports'], 'Storage ABI must have no gameplay stub'
project = build / 'ffi' / args.label
project.mkdir(parents=True, exist_ok=False)
pins = []
package_verification = verify_package(build)
write_json(project / 'package-verification.json', package_verification)
for name, source in [('main.lua', HERE / 'tests/main.lua'), ('conf.lua', HERE / 'tests/conf.lua'),
                     ('ntsd_bridge.h', HERE / 'include/ntsd_bridge.h')]:
    target = project / name
    shutil.copy2(source, target)
    pins.append({'path': str(source), 'copy': str(target), 'bytes': source.stat().st_size, 'sha256': sha(target)})
for source in [HERE / 'check_ffi.py', HERE / 'build.py']:
    target = project / source.name
    shutil.copy2(source, target)
    pins.append({'path': str(source), 'copy': str(target), 'bytes': source.stat().st_size, 'sha256': sha(target)})
resource_environment = {}
if args.resources:
    resources = args.resources.resolve()
    metadata = json.loads((resources / 'manifest.json').read_text())
    pins.append({'path': str(resources / 'manifest.json'), 'sha256': sha(resources / 'manifest.json')})
    for source in [HERE / 'tests/loaded.lua', HERE / 'tests/front_screen.lua', HERE / 'loaded_reference.py',
                   HERE / 'front_screen_reference.py', HERE / 'front_screen_reference_v2.py']:
        target = project / source.name
        shutil.copy2(source, target)
        pins.append({'path': str(source), 'copy': str(target), 'bytes': source.stat().st_size, 'sha256': sha(target)})
    loaded_spec = importlib.util.spec_from_file_location('frozen_loaded_reference', project / 'loaded_reference.py')
    loaded_reference = importlib.util.module_from_spec(loaded_spec)
    loaded_spec.loader.exec_module(loaded_reference)
    screen_spec = importlib.util.spec_from_file_location('frozen_screen_reference', project / 'front_screen_reference_v2.py')
    screen_reference = importlib.util.module_from_spec(screen_spec)
    screen_spec.loader.exec_module(screen_reference)
    for name, expected_sha in loaded_reference.FIXTURES + screen_reference.FIXTURES:
        source = Path('/Users/michael/Developer/ntsd-2.4/native/Tests/NTSDCoreTests/Fixtures') / name
        assert sha(source) == expected_sha
        pins.append({'path': str(source), 'sha256': sha(source), 'bytes': source.stat().st_size})
    # A separately owned, deliberately mutable input copy proves that create
    # consumed its resources. It never modifies the exported original pack.
    owned = project / 'owned-input'
    owned.mkdir()
    selected = {'manifest.json', metadata['globals']['dataPath'], 'original/data/control.txt'}
    selected.update(item['dibPath'] for item in metadata['embedded'])
    owned_dib = next(x['dibPath'] for x in metadata['embedded'] if x['key'] == 'LF2_CURSOR')
    owned_background = next(x['dibPath'] for x in metadata['embedded'] if x['key'] == 'MENU_BACK1')
    for relative in sorted(selected):
        source, target = resources / relative, owned / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        pins.append({'path': str(source), 'copy': str(target), 'sha256': sha(source), 'bytes': source.stat().st_size,
                     'mutableTestCopy': relative in ('original/data/control.txt', owned_dib, owned_background)})
    bad = project / 'bad-input'
    (bad / 'static').mkdir(parents=True)
    forged = bytearray((resources / metadata['globals']['dataPath']).read_bytes()); forged[0] ^= 1
    (bad / metadata['globals']['dataPath']).write_bytes(forged)
    altered = json.loads(json.dumps(metadata)); altered['globals']['sha256'] = hashlib.sha256(forged).hexdigest()
    write_json(bad / 'manifest.json', altered)
    for path in [bad / 'manifest.json', bad / metadata['globals']['dataPath']]:
        pins.append({'path': str(path), 'sha256': sha(path), 'bytes': path.stat().st_size, 'declaredForgedTestInput': True})
    resource_environment = {'NTSD_BRIDGE_RESOURCE_ROOT': str(resources), 'NTSD_BRIDGE_OWNED_INPUT': str(owned),
                            'NTSD_BRIDGE_BAD_INPUT': str(bad), 'NTSD_BRIDGE_OWNED_DIB': str(owned / owned_dib),
                            'NTSD_BRIDGE_OWNED_BACKGROUND': str(owned / owned_background)}
reference = ROOT / 'prototypes/l2df/tests/reference/check_actor_input.py'
copied_reference = project / 'constructor_reference.py'
shutil.copy2(reference, copied_reference)
pins.append({'path': str(reference), 'copy': str(copied_reference), 'bytes': reference.stat().st_size, 'sha256': sha(reference)})
runtime = storage / 'runtime/love.app/Contents/MacOS/love'
pins.extend({'path': str(p), 'sha256': sha(p), 'bytes': p.stat().st_size} for p in [library, runtime, build / 'artifact.json'])
write_json(project / 'inputs.json', {'createdAtUTC': now(), 'storage': volume, 'pins': pins,
    'allocatorBacking': 'Declared synthetic bytes (index*37+seed)%256, seeds 0xa5 and 0x51; never original heap or expected state',
    'scope': 'ABI ownership/constructor provenance/rollback only; headless native LÖVE, no device/gameplay claim'})
environment = dict(os.environ, NTSD_BRIDGE_LIBRARY=str(library), **resource_environment)
job = run_owned([str(runtime), str(project)], ROOT, project / 'job', 90, env=environment)
if job['exitCode'] != 0 or job.get('terminationReason'):
    raise SystemExit('FFI run did not pass; inspect retained error before any new run')
def verify_inputs():
    for pin in pins:
        assert sha(Path(pin['path'])) == pin['sha256'], 'Immutable FFI input changed: ' + pin['path']
        if 'copy' in pin and not pin.get('mutableTestCopy'):
            assert sha(Path(pin['copy'])) == pin['sha256'], 'Frozen FFI copy changed: ' + pin['copy']
    if args.resources:
        assert (owned / 'original/data/control.txt').read_bytes() == b'changed after create'
        assert not (owned / owned_dib).exists()
        assert not (owned / owned_background).exists()
verify_inputs()
result = json.loads((project / 'result.json').read_text())
assert result['pass'] and result['abi'] == 1 and result['lifecycle'] == 'ACTOR_STORAGE'
assert result['gameplayCapability'] is False
spec = importlib.util.spec_from_file_location('constructor_reference', copied_reference)
reference_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference_module)
constructed, mask = reference_module.constructor('a5')
assert len(constructed) == len(mask) == 1056 and set(mask) == {0, 1} and sum(mask) == 913
compared = []
for label, seed in [('constructor-a', 0xa5), ('constructor-b', 0x51)]:
    # Known bytes come from the independent retained constructor projection;
    # unknown backing comes solely from this declared synthetic input.
    expected = bytes(constructed[i] if mask[i] else (i * 37 + seed) % 256 for i in range(1056))
    actual = (project / (label + '.bytes')).read_bytes()
    actual_mask = (project / (label + '.mask')).read_bytes()
    assert actual == expected, label + ' complete constructor bytes differ'
    assert actual_mask == mask, label + ' complete constructor mask differs'
    compared.append({'label': label, 'bytes': 1056, 'maskBytes': 1056, 'knownBytes': 913,
                     'actualSHA256': sha(project / (label + '.bytes')), 'maskSHA256': sha(project / (label + '.mask'))})
assert verify_package(build) == package_verification
assert sha(library) == artifact['sha256']
verification = {'pass': True, 'ffiAssertions': result['checks'], 'fullConstructorComparisons': compared,
                'referenceSHA256': sha(copied_reference), 'packageFilesVerified': package_verification['compiledFiles'],
                'resultSHA256': sha(project / 'result.json'), 'scope': 'Native C ABI foundation, not gameplay'}
if args.resources:
    verification['loadedSessionComparisons'] = loaded_reference.compare(project,
        Path('/Users/michael/Developer/ntsd-2.4/native/Tests/NTSDCoreTests/Fixtures'), sha(resources / 'manifest.json'))
    verification['frontScreenComparisons'] = screen_reference.compare(project,
        Path('/Users/michael/Developer/ntsd-2.4/native/Tests/NTSDCoreTests/Fixtures'), sha(resources / 'manifest.json'), loaded_reference)
    verification['decoderControls'] = screen_reference.decoder_checks(loaded_reference.typed_equal)
    verification['scope'] = 'Owned boot/front-settings/first menu return, two natural retained profiles; no gameplay/device claim'
verify_inputs()
write_json(project / 'verification.json', verification)
print(json.dumps({'verification': str(project / 'verification.json'), **verification}))
