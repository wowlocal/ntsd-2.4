#!/usr/bin/env python3
"""Planning proxy, NOT instruction/branch coverage or gameplay equivalence.

Count the union of documented native address envelopes at pinned Git revisions.
No original assets, accepted evidence or existing research fixtures are changed.
Uses only the Python standard library and the installed llvm-objdump.
"""
import argparse
import datetime as dt
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / 'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe'
EXE_SHA = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
RANGE = re.compile(r'(?i)(?<![0-9a-f])(?:0x)?(4[0-4][0-9a-f]{4})\s*(?:\.\.|[–—])\s*(?:0x)?(4[0-4][0-9a-f]{4})(?![0-9a-f])')

# Manually reviewed positive scope descriptions, not all addresses in a study.
# The range must actually occur in that revision's study AND the native module
# must exist. Open-next-step ranges and global data addresses are not selected.
# Endpoints are documented inclusive address markers, not guessed function ends.
SUPPLEMENTS = [
    ('BACKGROUND_LOADER', 'OriginalBackgroundLoader', '40c160..40c901 40c030..40c0db 40c0e0..40c157'),
    ('BITMAP_DRAWING', 'OriginalBitmapDrawing', '43f010..43f2fe 43ef70..43f000 43ee50..43ef41'),
    ('CATALOG_REGISTRY', 'OriginalCatalogRegistry', '4122f0..4127fb'),
    ('STAGE_LOADER', 'OriginalStageLoader', '40c910..40d09d 414a30..414b6f'),
    ('OBJECT_LOADER', 'OriginalObjectLoader', '40ef70..4122e7'),
    ('WAVE_LOADING', 'OriginalWaveLoader', '4014e0..40195e'),
    ('MENU_CONTENT', 'OriginalMenuContent', '43c780..43cc53'),
    ('MENU_PANEL_BITMAP', 'OriginalMenuPanelBitmap', '43cc60..43cf3a'),
    ('MENU_INFO_WRITING', 'OriginalMenuInfoWriting', '43c690..43c708 43c710..43c77e'),
    ('SETTINGS_WRITING', 'OriginalSettingsWriting', '423230..423475'),
    ('MAIN_MENU', 'OriginalMainMenu', '427915..427ca7 422ac0..422af7 401a30..401a6f 402b60..402d63'),
    ('MATCH_CONTINUATION', 'OriginalMatchContinuation', '42d704..42e0f9'),
    ('MENU_PRESENTATION', 'OriginalMenuPresentation', '42873e..428805 4246b0..424736 423910..423938 43ef50..43ef68 402810..402893 401f30..401fff 4028a0..402a5f 401290..4012fe 43e940..43e99e 4019b0..401a26 401d30..401d90 43d2a0..43d2b7'),
    ('MODE_SCREEN', 'OriginalModeScreen', '429e5a..429eb2 431dcb..432137 432137..4322ad 43290a..4329a8 4329a8..432aaa'),
    ('MUSIC_PLAYBACK', 'OriginalMusicPlayback', '42976b..4297ae 402020..40207f 401d30..401d90 401c90..401d26 401da0..401e85 402080..4020bd 401f30..401fff 4020cf..4020f6'),
    ('MENU_RETURN', 'OriginalMenuReturn', '42e0d2..42e0f9 4229e2..422a95 422a95..422ab8 4287de..428805'),
]

# Studies specify whole functions but sometimes only print the entry address.
# The terminal RET is checked against the original bytes/disassembly below.
# Bounds also appear in the cited oracle's call/return hooks, except settings
# and local input where the terminal RET is a static boundary observation.
# These are body envelopes, including any explicitly unsupported subpaths.
WHOLE = [
    ('LOCAL_INPUT', 'OriginalLocalInput', 0x419a60, 0x419e2e, 'tools/oracle_local_input.py'),
    ('RECEIVED_INPUT', 'OriginalReceivedInput', 0x4197a0, 0x4198e9, 'tools/oracle_received_input.py'),
    ('RECEIVED_INPUT', 'OriginalReceivedInput', 0x4198f0, 0x419a50, 'tools/oracle_received_input.py'),
    ('MENU_PANEL_UPDATE', 'OriginalMenuPanelUpdate', 0x4236d0, 0x4237d3, 'tools/oracle_menu_panel_update.py'),
    ('SETTINGS_LOADING', 'OriginalSettingsLoading', 0x423480, 0x423673, 'tools/oracle_settings_loading.py'),
    ('MODE_SELECTION', 'OriginalMenuInput', 0x431b70, 0x431c64, 'tools/oracle_mode_selection.py'),
    ('REPLAY_TICK', 'OriginalReplayTick', 0x43db40, 0x43dc47, 'tools/oracle_replay_tick.py'),
    ('REPLAY_TICK', 'OriginalReplayTick', 0x43dc50, 0x43dd56, 'tools/oracle_replay_tick.py'),
]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def snapshot(rev):
    requested = ['native/Sources', 'docs/research']
    paths = git('ls-tree', '--name-only', rev, *requested).decode().splitlines()
    raw = git('archive', rev, *paths)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        return {m.name: archive.extractfile(m).read().decode('utf-8')
                for m in archive if m.isfile() and m.name.endswith(('.swift', '.md'))}


def matches(text):
    return {(int(m[1], 16), int(m[2], 16)) for m in RANGE.finditer(text)}


def collect(files, start, end, supplemental=True):
    found = []
    for path, text in files.items():
        if not path.startswith('native/Sources/NTSDCore/'):
            continue
        for line, value in enumerate(text.splitlines(), 1):
            # Source rules are annotated on // comments; do not mine arbitrary
            # literals, test inputs, strings or tools for evidence of transfer.
            if '//' not in value:
                continue
            for a, b in matches(value.split('//', 1)[1]):
                if start <= a <= b < end:
                    found.append(dict(start=a, stop=b, source=path, line=line, kind='native-comment'))
    if supplemental:
        for study, module, allowed in SUPPLEMENTS:
            path = f'docs/research/{study}.md'
            if path not in files or f'native/Sources/NTSDCore/{module}.swift' not in files:
                continue
            wanted = matches(allowed)
            for line, value in enumerate(files[path].splitlines(), 1):
                for a, b in matches(value) & wanted:
                    if start <= a <= b < end:
                        found.append(dict(start=a, stop=b, source=path, line=line, kind='reviewed-study'))
        for study, module, a, b, oracle in WHOLE:
            path = f'docs/research/{study}.md'
            if path in files and f'native/Sources/NTSDCore/{module}.swift' in files:
                found.append(dict(start=a, stop=b, source=path, line=1,
                                  kind='whole-body-envelope', terminalRetSource=oracle))
    return found


def mask_of(entries, start, end):
    mask = bytearray(end - start)
    for entry in entries:
        a, b = entry['start'], entry['stop']
        mask[a-start:b-start+1] = b'\1' * (b-a+1)
    return mask


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--revision', default='c2c2c91')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/estimates/2026-09-08-code-progress.json')
    args = parser.parse_args()
    revision = git('rev-parse', args.revision).decode().strip()
    exe = EXE.read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_SHA, 'Wrong original EXE'
    pe = struct.unpack_from('<I', exe, 0x3c)[0]
    count = struct.unpack_from('<H', exe, pe+6)[0]
    opt_size = struct.unpack_from('<H', exe, pe+20)[0]
    base = struct.unpack_from('<I', exe, pe+24+28)[0]
    for i in range(count):
        off = pe+24+opt_size+40*i
        if exe[off:off+8].rstrip(b'\0') == b'.text':
            size, rva, raw_size, raw_off = struct.unpack_from('<IIII', exe, off+8)
            break
    else:
        raise ValueError('No .text')
    start, end = base+rva, base+rva+size
    assembly = subprocess.check_output(['xcrun', 'llvm-objdump', '--disassemble', '--x86-asm-syntax=intel', str(EXE)], text=True)
    instructions = []
    for value in assembly.splitlines():
        m = re.match(r'\s*([0-9a-f]+):[ \t]+((?:[0-9a-f]{2}[ \t]+)+)(\S.*)', value)
        if m:
            a, raw, text = int(m[1], 16), bytes.fromhex(m[2]), m[3]
            if start <= a < end:
                file_off = raw_off + a-start
                assert exe[file_off:file_off+len(raw)] == raw
                if a + len(raw) <= end:
                    instructions.append((a, len(raw), text.split()[0]))

    indexed = {a:op for a, _, op in instructions}
    for _, _, a, b, _ in WHOLE:
        assert a in indexed and indexed[b] == 'ret', f'Invalid body boundary {a:x}..{b:x}'
    # Independent pre-existing static inventory, without changing its evidence.
    pinned_index = json.loads(git('show', f'{revision}:docs/evidence/tick-address-index.json'))
    for name, function in pinned_index['functions'].items():
        lo, hi = int(function['start'], 16), int(function['endExclusive'], 16)
        assert sum(lo <= a < hi for a, _, _ in instructions) == function['instructions'], name
    decoded = [i for i in instructions if i[2] not in ('int3', 'nop')]
    is_conditional = lambda i: (i[2].startswith('j') and i[2] != 'jmp') or i[2].startswith('loop')
    def inside_mask(mask):
        return [i for i in decoded if all(mask[i[0]-start:i[0]-start+i[1]])]

    history = git('log', '--reverse', '--since=2026-09-07T00:00:00+03:00', '--format=%H%x09%cI%x09%s', revision).decode().splitlines()
    timeline = []
    for line in history:
        commit, timestamp, subject = line.split('\t', 2)
        files = snapshot(commit)
        entries = collect(files, start, end)
        mask = mask_of(entries, start, end)
        source_mask = mask_of(collect(files, start, end, False), start, end)
        body = inside_mask(mask)
        counts = {}
        for folder in ['NTSDCore', 'NTSDApp', 'NTSDReferenceChecks']:
            selected = [text for path, text in files.items() if path.startswith('native/Sources/'+folder+'/') and path.endswith('.swift')]
            counts[folder] = dict(files=len(selected), lines=sum(len(t.splitlines()) for t in selected))
        timeline.append(dict(commit=commit, timestamp=timestamp, subject=subject,
                             documentedEnvelopeBytes=sum(mask), sourceCommentBytes=sum(source_mask), lines=counts,
                             insideEnvelopeInstructions=len(body), insideEnvelopeConditionalInstructions=sum(map(is_conditional, body))))
    final_files = snapshot(revision)
    final_entries = collect(final_files, start, end)
    final_mask = mask_of(final_entries, start, end)
    # Every indexed instruction must be entirely contained in the envelope.
    inside = inside_mask(final_mask)
    base_row = next(row for row in timeline if row['commit'].startswith('c9a5263'))
    last = timeline[-1]
    hours = (dt.datetime.fromisoformat(last['timestamp'])-dt.datetime.fromisoformat(base_row['timestamp'])).total_seconds()/3600
    growth = last['documentedEnvelopeBytes']-base_row['documentedEnvelopeBytes']
    speed = growth/hours
    remaining = size-last['documentedEnvelopeBytes']
    rolling = []
    for target_hours in [6, 12, 24]:
        cutoff = dt.datetime.fromisoformat(last['timestamp'])-dt.timedelta(hours=target_hours)
        first = min(timeline, key=lambda row: abs((dt.datetime.fromisoformat(row['timestamp'])-cutoff).total_seconds()))
        elapsed = (dt.datetime.fromisoformat(last['timestamp'])-dt.datetime.fromisoformat(first['timestamp'])).total_seconds()/3600
        rate = (last['documentedEnvelopeBytes']-first['documentedEnvelopeBytes'])/elapsed
        rolling.append(dict(targetHours=target_hours, actualHours=elapsed, startCommit=first['commit'],
                            bytesPerHour=rate, remainingLinearHours=remaining/rate))
    scenarios = []
    for label, rate, assumption in [
        ('historical-mean', speed, 'Observed 25.9h envelope-growth rate continues'),
        ('recent-rate', rolling[0]['bytesPerHour'], 'Observed approximately 6h envelope-growth rate continues'),
        ('recent-half-speed', rolling[0]['bytesPerHour']/2, 'Unmeasured risk assumption: further 2x slowdown relative to recent rate'),
    ]:
        remaining_hours = remaining/rate
        # A deliberate planning allowance, not a measured estimate of macOS/W.
        scenarios.append(dict(name=label, assumption=assumption, codeHours=remaining_hours,
                              withAssumed50PercentIntegrationAllowanceHours=remaining_hours*1.5,
                              continuousDays=remaining_hours*1.5/24,
                              eightHourDays=remaining_hours*1.5/8))
    projections = {}
    for key, total in [('documentedEnvelopeBytes', size), ('sourceCommentBytes', size), ('insideEnvelopeInstructions', len(decoded)),
                       ('insideEnvelopeConditionalInstructions', sum(map(is_conditional, decoded)))]:
        delta = last[key]-base_row[key]
        projections[key] = dict(total=total, start=base_row[key], current=last[key],
                                growthPerHour=delta/hours, remainingLinearHours=(total-last[key])/(delta/hours))
    # Describe gaps as contiguous address intervals, never as inferred functions.
    spans = []
    pos = 0
    while pos < size:
        a = pos
        value = final_mask[pos]
        while pos < size and final_mask[pos] == value:
            pos += 1
        spans.append(dict(start=hex(start+a), endExclusive=hex(start+pos), bytes=pos-a, inEnvelope=bool(value)))
    report = dict(
        schema=1, classification='Planning inference; documented native envelopes, NOT execution/branch coverage',
        revision=revision, exeSHA256=EXE_SHA,
        method='Inclusive documented address markers; union removes overlaps; all .text retained as denominator; native // ranges plus reviewed positive study ranges and eight statically bounded whole bodies; other single-address functions omitted',
        limitations=[
            'An envelope can include unsupported branches and excludes undocumented implemented code; it is neither a lower nor an upper bound on completed behavior.',
            'Date of documentation is not necessarily date of implementation. Changes in annotation granularity change the metric.',
            '.text contains runtime/platform/support code and possibly inline data. No proof all bytes need porting.',
            'Linear disassembly is not a recovered CFG. Conditional-instruction counts are not branch coverage.',
            'No unique executed-PC sets or per-branch native-equivalence map have been aggregated.',
            'Elapsed Git intervals do not measure active agent hours or prior work before the first commit.',
            'Cost multipliers and 50% integration allowance are explicit scenario assumptions, not fitted probabilities or confidence intervals.',
            'CRT DLL, native device behavior, OS input/network, full-mode validation and Windows comparisons cannot be sized from EXE bytes alone.',
        ],
        textSection=dict(start=hex(start), endExclusive=hex(end), virtualBytes=size, rawBytes=raw_size),
        current=dict(envelopeBytes=sum(final_mask), envelopePercent=sum(final_mask)/size*100,
                     sourceCommentBytes=last['sourceCommentBytes'],
                     nonpaddingLinearInstructions=len(decoded), insideEnvelopeInstructions=len(inside),
                     conditionalInstructions=sum(map(is_conditional, decoded)),
                     insideEnvelopeConditionalInstructions=sum(map(is_conditional, inside)),
                     lines=last['lines']),
        calibration=dict(startCommit=base_row['commit'], endCommit=revision, elapsedHours=hours,
                         startEnvelopeBytes=base_row['documentedEnvelopeBytes'], growthBytes=growth,
                         envelopeBytesPerHour=speed, outsideEnvelopeBytes=remaining,
                         literalLinearRemainingHours=remaining/speed),
        projections=projections, rollingWindows=rolling, scenarios=scenarios, timeline=timeline, spans=spans,
        rangeEvidence=[{**e, 'start':hex(e['start']), 'stop':hex(e['stop'])} for e in final_entries])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['revision','textSection','current','calibration','projections','scenarios']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
