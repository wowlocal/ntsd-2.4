#!/usr/bin/env python3
"""Inventory the retained NTSD War resource-error capture2 evidence, read-only.

The pinned game's existing Unicorn reports establish arena/resource ownership
and terminal failure boundaries for compatibility research. This tool checks
the finite report set, job/config/input pins, prefix-proof sidecars, failure
sidecars and live flags across calls; the separate frozen auditor reconstructs
bytes/masks/reads/stores. It executes no game code and imports no source harness.
Recorded memory faults remain faults. No Native, Windows or full-game claim.
"""

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path


LABELS = (
    'normal-primary', 'normal-control', 'wrapperNull-0', 'wrapperNull-4',
    'imageMissing-0', 'imageMissing-4', 'createSurface-0', 'createSurface-4',
    'colorKey-0', 'colorKey-4', 'getObject-first', 'description-first',
    'getDC-first', 'restore-first', 'createDC-first', 'selectObject-first',
    'stretch-first', 'releaseDC-first', 'deleteDC-first', 'deleteObject-first',
    'music-create', 'music-query-0', 'music-query-1', 'music-query-2',
    'music-query-3', 'music-wide-null', 'music-render', 'music-conversion',
    'replay-null',
)


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def file_pin(path):
    digest = hashlib.sha256()
    size = 0
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(block)
            size += len(block)
    return dict(bytes=size, sha256=digest.hexdigest())


def inventory(directory, audit_path):
    pins = {}

    def read(path, expected=None):
        path = Path(path).resolve()
        actual = file_pin(path)
        if expected is not None:
            require(actual == {k: expected[k] for k in actual}, str(path))
        pins[str(path)] = actual
        return json.loads(path.read_bytes())

    audit = read(audit_path)
    require(audit['sourceAudited'] and not audit['nativeCompared'], 'audit status')
    require(audit['counts']['scenarios'] == 29 and audit['counts']['calls'] == 37,
            'audit finite scope')
    observed = []
    scenarios = []
    source_inputs = {}
    prefix_paths = set()
    counts = Counter()
    for number, label in enumerate(LABELS):
        report_path = directory / f'war-preparation-fs-errors-s{number:02d}-capture2.json'
        report = read(report_path, audit['pins'][str(report_path.resolve())])
        require(report['scenarioIndex'] == number and report['scenario']['label'] == label,
                'scenario identity')
        job = read(report_path.with_suffix('.job.json'))
        config = read(report_path.with_suffix('.config.json'))
        input_pins = read(report_path.with_suffix('.pins.json'))
        require(job['status'] == 'terminal' and job['exitCode'] == 0
                and job['inputsUnchanged'], 'source job terminal')
        require(job['command'] == config['command'], 'job/config command')
        require(Path(job['command'][-1]).resolve() == report_path.resolve(), 'job output')
        require(datetime.fromisoformat(job['startedUTC']) <= datetime.fromisoformat(report['timeUTC'])
                <= datetime.fromisoformat(job['endedUTC']), 'publication interval')
        require(set(config['inputs']).issubset(input_pins), 'configured input pins')
        for name, expected in input_pins.items():
            if name not in source_inputs:
                source_inputs[name] = file_pin(Path(name))
            require(source_inputs[name]['sha256'] == expected, 'source input: ' + name)
        require(report['prefixCalls'] == len(report['prefixProof']) == 10, 'prefix count')
        parts = report_path.with_suffix('.parts')
        for ordinal, proof in enumerate(report['prefixProof']):
            require(read(parts / f'prefix-{ordinal:02d}.json') == proof, 'prefix sidecar')
            prefix_paths.add(proof['path'])
            counts['prefixProofSidecars'] += 1
        previous = read(report['prefixProof'][-1]['path'], report['prefixProof'][-1])['case']
        require(len(report['calls']) == (2 if 2 <= number <= 9 else 1), 'call count')
        scenario_calls = []
        for ordinal, part_pin in enumerate(report['calls']):
            path = Path(part_pin['path'])
            require(path.resolve() == (parts / f'call-{ordinal:02d}.json').resolve(), 'atomic path')
            document = read(path, part_pin)
            case = document['case']
            require(previous['end'] == 'returned', 'continuation after fault')
            live = lambda records: {r['address']: r['live'] for r in records if r['live'] is not None}
            require(live(previous['after']) == live(case['before']), 'live owner join')
            counts['liveOwnerJoins'] += 1
            outcome = dict(scenario=number, label=case['spec']['label'], end=case['end'],
                           pc=case['endPC'], records=len(case['after']), events=len(case['events']),
                           sourceFault=case.get('sourceFault'))
            require(outcome == audit['outcomes'][len(observed)], 'audited outcome order')
            observed.append(outcome)
            if case['end'] == 'sourceFault':
                failure = case['sourceFault']
                sidecar = read(failure['failureFile'])
                require(int(sidecar['pc'], 16) == case['endPC'], 'failure PC')
                for key in ('spec', 'before', 'after', 'events', 'writes', 'reads',
                            'apiReads', 'helpers', 'pending', 'instructions'):
                    require(sidecar[key] == case[key], 'failure sidecar: ' + key)
                for key in ('error', 'errorText'):
                    require(sidecar[key] == failure[key], 'failure error')
                for key, blob in sidecar['blobs'].items():
                    require(document['blobs'].get(key) == blob, 'failure blob: ' + key)
                    counts['failureBlobComparisons'] += 1
                require(ordinal == len(report['calls']) - 1, 'fault terminal position')
                counts['failureSidecars'] += 1
            graphics = case['preparationGraphics']
            release_events = [e['request'] for e in graphics['events']
                              if e.get('request', {}).get('kind') in ('release', 'free')]
            scenario_calls.append(dict(ordinal=ordinal, **part_pin,
                                       graphicsReleaseFree=release_events,
                                       wrapperLive=graphics['wrapperLive']))
            counts[case['end']] += 1
            previous = case
        counts['terminalJobs'] += 1
        row = dict(scenario=number, label=label, report=str(report_path.resolve()),
                         reportPin=pins[str(report_path.resolve())], startedUTC=job['startedUTC'],
                         endedUTC=job['endedUTC'], calls=scenario_calls)
        # Retain rows separately from the full auditor outcomes (which include faults).
        scenarios.append(row)
    require(len(observed) == len(audit['outcomes']) == 37, 'complete outcome set')
    require(counts['returned'] == 28 and counts['sourceFault'] == 9, 'terminal totals')
    return dict(scope=__doc__, timeUTC=datetime.now(timezone.utc).isoformat(),
                counts=dict(counts), scenarios=scenarios, pins=pins, sourceInputs=source_inputs,
                distinctPrefixFiles=len(prefix_paths), originalExecuted=False,
                nativeCompared=False, fullPreparationComplete=False, fullGameComplete=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--audit', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    require(not args.output.exists(), 'output already exists')
    result = inventory(args.directory.resolve(), args.audit)
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(result['counts'])


if __name__ == '__main__':
    main()
