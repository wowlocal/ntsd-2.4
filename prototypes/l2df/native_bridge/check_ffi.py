#!/usr/bin/env python3
"""One bounded native LÖVE FFI test against a completed isolated bridge build."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil

from build import HERE, ROOT, now, run_owned, sha, storage_check, verify_package, write_json

parser = argparse.ArgumentParser()
parser.add_argument('--build-label', required=True)
parser.add_argument('--label', required=True)
args = parser.parse_args()
for label in [args.build_label, args.label]:
    assert Path(label).name == label and label not in ('.', '..')
storage, volume = storage_check()
build = storage / 'native-bridge-20260912' / args.build_label
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
reference = ROOT / 'prototypes/l2df/tests/reference/check_actor_input.py'
copied_reference = project / 'constructor_reference.py'
shutil.copy2(reference, copied_reference)
pins.append({'path': str(reference), 'copy': str(copied_reference), 'bytes': reference.stat().st_size, 'sha256': sha(reference)})
runtime = storage / 'runtime/love.app/Contents/MacOS/love'
pins.extend({'path': str(p), 'sha256': sha(p), 'bytes': p.stat().st_size} for p in [library, runtime, build / 'artifact.json'])
write_json(project / 'inputs.json', {'createdAtUTC': now(), 'storage': volume, 'pins': pins,
    'allocatorBacking': 'Declared synthetic bytes (index*37+seed)%256, seeds 0xa5 and 0x51; never original heap or expected state',
    'scope': 'ABI ownership/constructor provenance/rollback only; headless native LÖVE, no device/gameplay claim'})
environment = dict(os.environ, NTSD_BRIDGE_LIBRARY=str(library))
job = run_owned([str(runtime), str(project)], ROOT, project / 'job', 90, env=environment)
if job['exitCode'] != 0 or job.get('terminationReason'):
    raise SystemExit('FFI run did not pass; inspect retained error before any new run')
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
write_json(project / 'verification.json', verification)
print(json.dumps({'verification': str(project / 'verification.json'), **verification}))
