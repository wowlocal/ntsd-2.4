#!/usr/bin/env python3
"""Compare owned Lua ActorInput with all retained source cases, without EXE execution.

Only input patches and independently projected constructor fields reach Lua.
Expected after-state/masks stay in this comparator. The contract covers 46
scalars/88 initialized Actor bytes, not the remaining private/raw storage ABI.
Every run has immutable snapshots, provenance, a 90-second limit and a new label.
"""
import argparse
import base64
from collections import Counter
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import time
import zlib

ROOT = Path(__file__).resolve().parents[4]
EXE = '3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c'
RAW = 'f91a5cdab5ad8e52f3522e8eead6c7979492353103a5f6742c1326c84d0fffda'
SCALARS = {'frame': (0x70, 'i'), 'facing': (0x80, 'B'), 'status98': (0x98, 'i'),
           'hp': (0x2fc, 'i'), 'mp': (0x308, 'i'), 'field324': (0x324, 'i'),
           'field328': (0x328, 'i'), 'field338': (0x338, 'i'),
           'healthSpent': (0x34c, 'i'), 'chakraSpent': (0x350, 'i')}
BUFFERS = dict(zip(('attack', 'jump', 'defend', 'defendCooldown', 'right', 'left', 'up', 'down'), range(0xbe, 0xc6)))
PREVIOUS = dict(zip(('up', 'down', 'left', 'right', 'attack', 'jump', 'defend'), range(0xc6, 0xcd)))
CURRENT = {k: v + 7 for k, v in PREVIOUS.items()}
FRAME = dict(zip(('hit_a', 'hit_d', 'hit_j', 'hit_Fa', 'hit_Ua', 'hit_Da', 'hit_Fj', 'hit_Uj', 'hit_Dj', 'hit_ja', 'mp'), range(0x24, 0x50, 4)))


def sha(b):
    return hashlib.sha256(b).hexdigest()


def constructor(fill):
    # Final stores of the retained 4061d0 constructor. Unknown backing has mask0.
    b = bytearray([0xa5] * 0x420 if fill == 'a5' else [i % 256 for i in range(0x420)])
    m = bytearray(0x420)
    for lo, hi in ((0, 0x24), (0x58, 0x81), (0x84, 0xbd), (0xbe, 0xdd),
                   (0xe0, 0x31c), (0x320, 0x368), (0x36c, 0x370), (0x3e8, 0x41c)):
        b[lo:hi] = bytes(hi-lo); m[lo:hi] = bytes([1]) * (hi-lo)
    def write(offset, fmt, value):
        raw = struct.pack('<'+fmt, value)
        b[offset:offset+len(raw)] = raw; m[offset:offset+len(raw)] = bytes([1])*len(raw)
    for offset in range(0x28, 0x51, 8): write(offset, 'Q', 0x3fb999999999999a)
    for offset in (0x2e8, 0x2ec, 0x2f0): write(offset, 'i', 1000)
    for offset in (0x2f4, 0x2f8, 0x324, 0x328, 0x32c, 0x33c, 0x360, 0x3f8): write(offset, 'i', -1)
    for offset in (0x2fc, 0x300, 0x304, 0x308): write(offset, 'i', 500)
    write(0x354, 'i', 99)
    for offset in (0x3fc, 0x400): write(offset, 'i', -1000)
    return b, m


def project(b, mask):
    assert len(b) == len(mask) == 0x420
    def read(offset, fmt='B'):
        assert all(mask[offset:offset+struct.calcsize(fmt)]), ('unknown projection', offset)
        return struct.unpack_from('<'+fmt, b, offset)[0]
    a = {k: read(*spec) for k, spec in SCALARS.items()}
    for name, fields in (('buffers', BUFFERS), ('previous', PREVIOUS), ('current', CURRENT)):
        a[name] = {k: read(offset) for k, offset in fields.items()}
    a['history'] = [read(offset, 'i') for offset in range(0x408, 0x41c, 4)]
    a['progress'] = [read(offset) for offset in range(0xd4, 0xdd)]
    return a


def input_case(c):
    b, mask = constructor(c['fill'])
    for offset, encoded in c['actor']:
        raw = bytes.fromhex(encoded); b[offset:offset+len(raw)] = raw
        mask[offset:offset+len(raw)] = bytes([1])*len(raw)
    a = project(b, mask); a['sourceID'] = c.get('sourceID', 2)
    frames = {}
    for index in (0, 2, 3, 300):
        frames[index] = bytearray(0x178); frames[index][0] = 1
    struct.pack_into('<i', frames[2], 0x4c, 100)
    struct.pack_into('<i', frames[3], 0x4c, 20)
    for index, offset, encoded in c.get('frames', []):
        raw = bytes.fromhex(encoded)
        frames.setdefault(index, bytearray(0x178))[offset:offset+len(raw)] = raw
    frames = {index: {'present': b[0], **{k: struct.unpack_from('<i', b, offset)[0] for k, offset in FRAME.items()}} for index, b in frames.items()}
    g = dict(c['globals'])
    return {'label': c['label'], 'operation': c['operation'], 'actor': a, 'frames': frames,
            'globals': {'costEnabled': g[0x44d034], 'flag458428': g[0x458428]},
            **{k: c[k] for k in ('target', 'key', 'advanced') if k in c}}


def lua(v):
    if isinstance(v, dict): return '{'+','.join('['+lua(k)+']='+lua(x) for k, x in v.items())+'}'
    if isinstance(v, list): return '{'+','.join(map(lua, v))+'}'
    if isinstance(v, str): return json.dumps(v, ensure_ascii=True)
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    return str(v)


RUNNER = r'''
local json=require('json')
local input=require('actor_input')
function love.errorhandler(message)
 io.stderr:write(tostring(message)..'\n');io.stderr:flush()
 return function() return 1 end
end
function love.load()
 local out=assert(io.open(love.filesystem.getSource()..'/actual.jsonl','w'))
 local ops={edges=input.captureEdges,combos=input.recognizeCombos,actions=input.applyFrameInput,prefix=input.apply}
 for line in io.lines(love.filesystem.getSource()..'/inputs.lua-lines') do
  local c=assert(loadstring('return '..line))()
  local before=json:encode(c.actor)
  local ok,a,events=pcall(function()
   if c.operation=='invalidates' then return c.actor,input.invalidates(c.actor,c.key,c.advanced) end
   if c.operation=='transfer' then return input.transfer(c.actor,c.target,c.frames,c.globals) end
   return assert(ops[c.operation])(c.actor,c.frames,c.globals)
  end)
  out:write(json:encode({label=c.label,ok=ok,actor=ok and a or nil,error=not ok and tostring(a) or nil,
    result=c.operation=='invalidates' and (events and 1 or 0) or nil,inputUnchanged=before==json:encode(c.actor)})..'\n')
 end
 out:close()
 local c=assert(loadfile(love.filesystem.getSource()..'/rollback.lua'))()
 local before=json:encode(c.actor)
 local ok,message=pcall(input.apply,c.actor,c.frames,c.globals)
 local rollback=assert(io.open(love.filesystem.getSource()..'/rollback-result.json','w'))
 rollback:write(json:encode({rejected=not ok,error=not ok and tostring(message) or nil,inputUnchanged=before==json:encode(c.actor)}))
 rollback:close();love.event.quit(0)
end
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-root', type=Path, required=True)
    ap.add_argument('--label', required=True)
    args = ap.parse_args()
    assert args.label and all(c.isalnum() or c in '-_' for c in args.label)
    build = ROOT/'build/l2df-prototype'
    assert build.is_symlink() and str(build.resolve()).startswith('/Volumes/X5/ntsd-2.4-research/')
    import plistlib
    vol = plistlib.loads(subprocess.check_output(['diskutil', 'info', '-plist', '/Volumes/X5']))
    assert vol['VolumeUUID'].upper() == '3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548'
    assert shutil.disk_usage(build).free > 6*1024**3
    out = build/'chidori-compat-20260912'/args.label
    out.mkdir()  # Never overwrite a previous run.
    inputs = [args.reference_root/'native/Tests/NTSDCoreTests/Fixtures/original-actor-input.json',
              args.reference_root/'native/Sources/NTSDCore/OriginalStateRecord.swift',
              args.reference_root/'native/Sources/NTSDCore/OriginalActorInput.swift',
              ROOT/'prototypes/l2df/compat/actor_input.lua', Path(__file__),
              build/'game/l2df/external/json.lua']
    pins = []
    for p in inputs:
        raw = p.read_bytes(); (out/p.name).write_bytes(raw)
        pins.append({'path': str(p), 'sha256': sha(raw), 'bytes': len(raw)})
    envelope = json.loads(inputs[0].read_bytes())
    raw = zlib.decompress(base64.b64decode(envelope['deflate']), -15)
    assert len(raw) == envelope['count'] and sha(raw) == envelope['sha256'] == RAW
    corpus = json.loads(raw); assert corpus['exeSHA256'] == EXE and len(corpus['cases']) == 14624
    cases = corpus['cases']
    with (out/'inputs.lua-lines').open('w') as f:
        for c in cases: f.write(lua(input_case(c))+'\n')
    rollback = input_case(cases[0])
    rollback['actor']['buffers'] = {k: 0 for k in BUFFERS}
    rollback['actor']['previous'] = {k: 0 for k in PREVIOUS}
    rollback['actor']['current'] = {k: int(k == 'attack') for k in CURRENT}
    rollback['actor']['progress'] = [0]*9
    rollback['frames'] = {0: {'present': 1, 'hit_a': 400}}
    (out/'rollback.lua').write_text('return '+lua(rollback)+'\n')
    (out/'main.lua').write_text(RUNNER)
    (out/'conf.lua').write_text("function love.conf(t) t.identity='ntsd-input-reference'; t.window=false; t.modules.audio=false; t.modules.graphics=false; t.modules.joystick=false; t.modules.physics=false end\n")
    exe = build/'runtime/love.app/Contents/MacOS/love'
    command = [str(exe.resolve()), str(out.resolve())]
    started = time.monotonic()
    job = {'command': command, 'cwd': str(out.resolve()), 'startUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'pins': pins, 'executableSHA256': sha(exe.read_bytes()), 'timeoutSeconds': 90,
           'sourceExecution': False, 'status': 'starting'}
    with (out/'stdout.log').open('wb') as stdout, (out/'stderr.log').open('wb') as stderr:
        proc = subprocess.Popen(command, cwd=out, stdout=stdout, stderr=stderr)
        job.update(pid=proc.pid, status='running'); (out/'job.json').write_text(json.dumps(job, indent=2)+'\n')
        try: code = proc.wait(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill(); code = proc.wait(); job['timeout'] = True
    job.update(exitCode=code, elapsedSeconds=time.monotonic()-started, status='terminal')
    (out/'job.json').write_text(json.dumps(job, indent=2)+'\n')
    assert code == 0, job
    actual = [json.loads(line) for line in (out/'actual.jsonl').read_text().splitlines()]
    assert len(actual) == len(cases)
    failures = []
    for c, got in zip(cases, actual):
        assert got['label'] == c['label']
        expected = project(bytes.fromhex(c['after']), bytes.fromhex(c['defined']))
        expected['sourceID'] = c.get('sourceID', 2)
        diffs = {'actor': {k: {'actual': got.get('actor', {}).get(k), 'expected': v} for k, v in expected.items() if got.get('actor', {}).get(k) != v}}
        if not got['ok'] or not got['inputUnchanged'] or diffs['actor'] or (c['operation']=='invalidates' and got['result'] != c['result']):
            failures.append({'label': c['label'], 'ok': got['ok'], 'error': got.get('error'), 'inputUnchanged': got['inputUnchanged'],
                             'result': got.get('result'), 'expectedResult': c.get('result'), **diffs})
    (out/'failures.json').write_text(json.dumps(failures, indent=2)+'\n')
    rollback = json.loads((out/'rollback-result.json').read_text())
    assert rollback['rejected'] and rollback['inputUnchanged'] and 'outside Object' in rollback['error'], rollback
    for p, pin in zip(inputs, pins): assert sha(p.read_bytes()) == pin['sha256'], ('input changed during run', str(p))
    report = {'accepted': not failures, 'cases': len(cases), 'failures': len(failures), 'operations': dict(Counter(c['operation'] for c in cases)),
              'scalarsPerActor': 46, 'knownBytesPerActor': 88, 'wholeActorABICompared': False, 'sourceReexecuted': False,
              'fixtureSHA256': pins[0]['sha256'], 'unpackedSHA256': RAW, 'moduleSHA256': pins[3]['sha256'],
              'unsupportedFrameRollback': rollback,
              'job': job, 'actualSHA256': sha((out/'actual.jsonl').read_bytes()), 'directory': str(out.resolve())}
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ('accepted', 'cases', 'failures', 'operations', 'directory')}))
    raise SystemExit(0 if report['accepted'] else 1)


if __name__ == '__main__': main()
