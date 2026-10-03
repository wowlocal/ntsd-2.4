#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["capstone==5.0.3"]
# ///
"""Finite audit of the October 2 coverage report; no original code executes.

Read old aggregates, selected unchanged fixtures and the pinned EXE. Output
diagnostics, not a replacement completion percentage or an acceptance gate.
Run from the repository root with OLD_ARTIFACT_DIR NEW_OUTPUT.json.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_GRP_CALL, CS_GRP_JUMP
from capstone.x86 import X86_OP_IMM, X86_OP_MEM
import exe_coverage_executed as scanner
from exe_coverage_universe import sections


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main(old, output):
    assert 'EXE_COVERAGE_KEYS' not in os.environ, 'Use the original default scanner'
    old = Path(old)
    pins = {}

    def record(path):
        pins[str(path)] = sha(path)

    def read(path):
        record(path)
        return json.loads(Path(path).read_text())

    def fixture(name):
        path = Path('native/Tests/NTSDCoreTests/Fixtures') / name
        record(path)
        return json.loads(scanner.load_text(path))

    exe = Path('downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe')
    record(exe)
    assert pins[str(exe)] == '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
    image = exe.read_bytes()
    _, _, secs = sections(image)
    text = next(s for s in secs if s['name'] == '.text')

    def byte_at(a, n):
        offset = text['raw'] + a - text['va']
        return image[offset:offset + n]

    u = read(old / 'exe-universe.json')
    sizes = {int(a): n for a, n in u['sizes'].items()}
    starts = set(sizes)
    game = {a for a in starts if a < 0x43f37e}
    funcs = {int(a, 16): set(v) for a, v in u['functions'].items()}
    owner = {a: f for f, v in funcs.items() for a in v}
    union, fixtures = set(), set()
    for filename in ('executed-fixtures-evidence.json', 'entries-all.json',
                     'executed-raw-original.json', 'executed-catalog-trace-full.json'):
        for name, row in read(old / filename).items():
            union.update(row['starts'])
            if '/Fixtures/' in name:
                fixtures.update(row['starts'])
    historical = dict(gameInstructions=len(game), fixtureAddressUnion=len(fixtures & game),
                      allRecordsAddressUnion=len(union & game))
    assert historical == dict(gameInstructions=63694, fixtureAddressUnion=29965,
                              allRecordsAddressUnion=32735)
    largest = sorted((dict(function=hex(f), total=len(v & game),
                           absentFromFixtures=len((v & game) - fixtures),
                           inAllRecords=len(v & union & game))
                      for f, v in funcs.items() if f < 0x43f37e),
                     key=lambda r: r['absentFromFixtures'], reverse=True)[:15]

    # Deliberately synthetic documents: demonstrate schema confusions only.
    probe_docs = {
        'blockEntryIgnored': {'blocks': [0x403a40]},
        'staticInstructionAccepted': {'instructions': [{'address': 0x403a40,
                                                       'executed': False}]},
        'numericCounterAccepted': {'instructionCount': 0x403a40},
    }
    probes = {k: sorted(scanner.scan(json.dumps(v), starts)[0])
              for k, v in probe_docs.items()}
    assert probes == {'blockEntryIgnored': [], 'staticInstructionAccepted': [0x403a40],
                      'numericCounterAccepted': [0x403a40]}
    static_path = Path('docs/evidence/application-dispatch-static.json')
    static = read(static_path)
    accepted_static, _ = scanner.scan(static_path.read_text(), starts)
    static_result = dict(sourceCompared=static['sourceCompared'], nativeCompared=static['nativeCompared'],
                         countedAddresses=len(accepted_static), addresses=sorted(accepted_static))
    assert not static['sourceCompared'] and not static['nativeCompared']

    # Existing UC_HOOK_BLOCK output. Count starts only, without expanding bodies.
    blocks, block_rows = set(), []
    for family in ('character-ai', 'object-input', 'mission-stage', 'war-battle'):
        for suffix in ('', '-control'):
            name = f'original-{family}{suffix}.json'
            data = fixture(name)
            report_path = Path('docs/evidence') / f'{family}{suffix}.json'
            report = read(report_path)
            assert report['fixtureSHA256'] == pins[str(Path('native/Tests/NTSDCoreTests/Fixtures') / name)]
            assert report['cases'] == len(data['cases'])
            assert report['blocks'] == len(data['blocks'])
            assert isinstance(report['nativeComparison'], str) and 'matches original' in report['nativeComparison']
            b = set(data['blocks'])
            blocks |= b
            block_rows.append(dict(fixture=name, cases=len(data['cases']), blocks=len(b),
                                   outsideOldUniverse=sorted(b - starts)))
    block_result = dict(corpora=block_rows, uniqueStarts=len(blocks),
                        gameStarts=len(blocks & game), absentFromOldFixtures=len((blocks & game) - fixtures),
                        absentFromAllOldRecords=len((blocks & game) - union),
                        byOldFunction={hex(f): len(v & blocks) for f, v in funcs.items() if v & blocks})

    # Instruction records whose own producer saves address+bytes on code hooks.
    # Preserve hook/adapter limitations; do not reclassify them as CPU coverage.
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.detail = True
    omitted = []
    for name in ('original-window-input.json', 'original-network-notification.json'):
        data = fixture(name)
        pcs = {}
        for case in data['cases']:
            for ins in case['instructions']:
                a, raw = ins['address'], bytes.fromhex(ins['bytes'])
                if not u['text'][0] <= a < u['text'][1]:
                    continue
                assert byte_at(a, len(raw)) == raw, (name, hex(a))
                insns = list(md.disasm(raw, a))
                assert len(insns) == 1 and insns[0].size == len(raw), (name, hex(a))
                pcs[a] = len(raw)
        missing = set(pcs) - starts
        omitted.append(dict(fixture=name, recordedEXEStarts=len(pcs),
                            outsideOldUniverse=len(missing), addresses=sorted(missing),
                            outsideOldUniverseBytes=sum(pcs[a] for a in missing)))

    # Static references explain why the function walk missed the window callback.
    callbacks, diagnostics, helper_calls = [], [], []
    developer = {0x4151d0, 0x414b70, 0x4143d0, 0x40d0a0, 0x414450,
                 0x4146b0, 0x40bfb0, 0x415140, 0x40d940}
    for a, n in sizes.items():
        i = next(md.disasm(byte_at(a, n), a))
        row = dict(address=hex(a), function=hex(owner[a]), bytes=i.bytes.hex(),
                   instruction=f'{i.mnemonic} {i.op_str}')
        if any(o.type == X86_OP_IMM and o.imm == 0x43b3d0 for o in i.operands):
            callbacks.append(row)
        if any(o.type == X86_OP_MEM and o.mem.disp == 0x450bec for o in i.operands):
            diagnostics.append(row)
        if (i.group(CS_GRP_CALL) or i.group(CS_GRP_JUMP)) and i.operands[0].type == X86_OP_IMM:
            if i.operands[0].imm in developer:
                helper_calls.append(row)
    service = fixture('original-application-service-keys.json')
    chain = [{k: c[k] for k in ('index', 'pressed', 'before', 'after')}
             for c in service['cases'] if c.get('chain') == 'held-and-released']
    assert next(c for c in chain if c['index'] == 3943)['after'] == [3, 1, 0]
    assert next(c for c in chain if c['index'] == 3947)['after'] == [0, 1, 1]
    assert next(c for c in chain if c['index'] == 3948)['after'] == [0, 1, 2]
    value = service['stopExcluded']
    stop = int(value, 16) if isinstance(value, str) else value
    assert stop not in service['instructions'] and service['cases'][0]['end']['pc'] == stop
    entries = read(old / 'entries-all.json')
    assert stop in entries['native/Tests/NTSDCoreTests/Fixtures/original-application-service-keys.json']['starts']
    ending = fixture('original-stage-ending.json')
    occupied = set()
    for a, n in sizes.items():
        occupied.update(range(a, a + n))
    for path in ('tools/exe_coverage_universe.py', 'tools/exe_coverage_executed.py',
                 'tools/exe_coverage_report.py', 'tools/exe_coverage_traces.py', __file__,
                 'tools/oracle_character_ai.py', 'tools/oracle_object_input.py',
                 'tools/oracle_mission_stage.py', 'tools/oracle_war_battle.py',
                 'tools/oracle_window_input.py', 'tools/oracle_network_notification.py',
                 'tools/oracle_continuous_gameplay.py',
                 'native/Sources/NTSDCore/OriginalApplicationKeyScan.swift',
                 'native/Sources/NTSDCore/OriginalApplicationDispatchEntry.swift'):
        record(path)
    result = dict(audit='2026-10-03', revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                  originalExecuted=False, independentReview=False, historicalReproduction=historical,
                  denominator=dict(starts=len(starts), bytes=sum(sizes.values()), uniqueBytes=len(occupied),
                                   gapsBytes=sum(b-a for a, b in u['unreached']),
                                   callbackLiteralReferences=callbacks, omittedFixtureStarts=omitted),
                  scannerProbes=probes, actualStaticInventory=static_result,
                  excludedStopStillCountedByEntryScan=hex(stop), existingBlocks=block_result,
                  largestHistoricalFixtureGaps=largest,
                  developerModes=dict(instructions=sum(len(funcs[f]) for f in developer),
                                      functions={hex(f): len(funcs[f]) for f in sorted(developer)},
                                      serviceKeyChain=chain, diagnosticReferences=diagnostics,
                                      incomingDirectCalls=helper_calls),
                  stageEnding=dict(cases=len(ending['cases']),
                                   instructionsRecorded='instructions' in ending, blocksRecorded='blocks' in ending),
                  pins=pins)
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(historical=historical, existingBlockStarts=len(blocks),
                          previouslyAbsentBlockStarts=block_result['absentFromOldFixtures'],
                          omittedFixtureStarts=[(r['fixture'], r['outsideOldUniverse']) for r in omitted],
                          developerInstructions=result['developerModes']['instructions']), indent=2))


if __name__ == '__main__':
    main(*sys.argv[1:])
