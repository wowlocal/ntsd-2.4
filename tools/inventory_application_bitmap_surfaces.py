#!/usr/bin/env python3
"""Inventory saved NTSD startup image/DC/surface requests; execute no game code.

The pinned Unicorn corpora describe original game control flow under declared
Win32/DirectDraw replies. This data-only join recovers the full saved caller set
needed for Native pixel ownership. It preserves numeric failures, masks and
unmeasured device effects; request geometry is not a raster observation.
"""
import argparse
import base64
import collections
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import traceback
import zlib


def digest(data):
    return hashlib.sha256(data).hexdigest()


def key(value):
    return digest(json.dumps(value, sort_keys=True, separators=(',', ':')).encode())


def pin(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return dict(bytes=Path(path).stat().st_size, sha256=h.hexdigest())


def write(path, value):
    assert not path.exists(), str(path)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temporary.rename(path)


def requests(value, location=''):
    if isinstance(value, dict):
        if isinstance(value.get('request'), dict):
            yield location, value
        for name, child in value.items():
            if name not in ('request', 'response') and isinstance(child, (dict, list)):
                yield from requests(child, location + '/' + name)
    elif isinstance(value, list):
        for i, child in enumerate(value):
            if isinstance(child, (dict, list)):
                yield from requests(child, location + '/' + str(i))


def descriptor(raw, mask):
    assert len(raw) == len(mask) == 108
    def word(at):
        return int.from_bytes(bytes(raw[at:at+4]), 'little') if all(mask[at:at+4]) else None
    flags = word(4)
    return dict(size=word(0), flags=flags, height=word(8), width=word(12), caps=word(104),
                pixelFormatFlag=None if flags is None else bool(flags & 0x1000),
                pixelFormatWords=[word(i) for i in range(72, 104, 4)],
                initialPixelBytesObserved=False, actualDeviceFormatObserved=False)


def inventory(plan, started):
    pins = plan['inputPins']
    for path, expected in pins.items():
        assert pin(path) == expected, path
    docs = {name: json.loads(Path(path).read_bytes()) for name, path in plan['corpora'].items()}
    for document in docs.values():
        assert document['exeSHA256'] == plan['reference']['exeSHA256']
    indexes = {name: {key(case): i for i, case in enumerate(doc['cases'])} for name, doc in docs.items()}
    assert all(len(indexes[name]) == len(doc['cases']) for name, doc in docs.items())
    cases = {name: {h: doc['cases'][i] for h, i in indexes[name].items()} for name, doc in docs.items()}
    origins = {name: {h: dict(source=plan['corpora'][name], pointer='/cases/' + str(i))
                     for h, i in indexes[name].items()} for name in docs}
    joins = []
    # Check every retained parent, including rows not selected by a root chain.
    tables = dict(bitmapParents='bitmap', settingsParents='settings', frontParents='front',
                  bodyParents='body', menuParents='menu')
    for name, doc in docs.items():
        for table, target in tables.items():
            for h, value in doc.get(table, {}).items():
                assert key(value) == h, (name, table, h)
                if h in cases[target]:
                    assert value == cases[target][h]
                else:
                    # A retained alternate settings parent is absent from the
                    # older standalone corpus; never drop it or invent an index.
                    cases[target][h] = value
                    origins[target][h] = dict(source=plan['corpora'][name], pointer='/' + table + '/' + h)
                joins.append(dict(source=plan['corpora'][name], pointer='/' + table + '/' + h,
                                  target=origins[target][h], standaloneCaseIndex=indexes[target].get(h), caseSHA256=h))
    for h, value in docs['loading']['parents'].items():
        assert key(value) == h and h in indexes['input']
        assert value == docs['input']['cases'][indexes['input'][h]]
        joins.append(dict(source=plan['corpora']['loading'], pointer='/parents/' + h,
                          target=plan['corpora']['input'], caseIndex=indexes['input'][h], caseSHA256=h))
    stages = {}
    stage_cases = {}

    def stage(kind, case, location):
        h = key(case)
        identity = kind + ':' + h
        if identity not in stages:
            projected = []
            for i, event in enumerate(case.get('events', [])):
                for path, item in requests(event):
                    projected.append(dict(eventIndex=i, eventPointer='/events/' + str(i) + path,
                                          eventSHA256=key(event), key=item.get('key'),
                                          request=item['request'], response=item.get('response'),
                                          returnPC=item.get('returnPC')))
            categories = collections.Counter((event.get('kind') or '<none>') + '/' +
                (event.get('event', {}).get('kind') or '<none>') for event in case.get('events', []))
            stages[identity] = dict(kind=kind, caseSHA256=h, locations=[], end=case.get('end'),
                label=case.get('spec', {}).get('label'), eventCount=len(case.get('events', [])),
                eventCategories=dict(categories), requests=projected)
            stage_cases[identity] = case
        if location not in stages[identity]['locations']:
            stages[identity]['locations'].append(location)
        return identity

    def at(kind, h):
        return cases[kind][h], origins[kind][h]

    def chain(kind, h):
        case, location = at(kind, h)
        tail = [stage(kind, case, location)]
        if kind == 'loading':
            return chain('input', case['parent']) + tail
        if kind == 'input':
            return chain('menu', case['parent']) + tail
        if kind == 'menu':
            return chain(case['parentKind'], case['parent']) + tail
        if kind == 'body':
            return chain('front', case['parent']) + tail
        if kind == 'front':
            return chain('settings', case['parent']) + tail
        if kind == 'settings':
            return chain('bitmap', case['parent']) + tail
        assert kind == 'bitmap' and case['spec']['kind'] == 'own'
        p = case['parents']
        return [stage(name, p[name], dict(source=location['source'], pointer=location['pointer'] + '/parents/' + name))
                for name in ('parent', 'loop', 'entry')] + tail

    chains = []
    for kind, count in [('menu', 48), ('input', 50), ('loading', 12)]:
        assert len(docs[kind]['cases']) == count
        for i, case in enumerate(docs[kind]['cases']):
            assert time.monotonic() - started < plan['limits']['inventorySeconds']
            sequence = chain(kind, key(case))
            chains.append(dict(rootKind=kind, caseIndex=i, label=case['spec']['label'],
                               end=case['end'], stages=sequence))

    # Bitmap identities are shared between the front-resource and screen-prefix
    # stages. Other API families remain explicitly present in the stage catalog.
    lifetimes = {}
    verified_assets = {}
    for c in chains:
        selected = tuple(s for s in c['stages'] if stages[s]['kind'] in ('bitmap', 'front'))
        life_id = key(selected)
        c['bitmapLifetime'] = life_id
        if life_id in lifetimes:
            continue
        images, surfaces, source_dcs, target_dcs = {}, {}, {}, {}
        source_generations, target_generations = [], []
        operations, copies, observations = [], [], collections.Counter()
        for s in selected:
            source_case = stage_cases[s]
            for row in stages[s]['requests']:
                q, r = row['request'], row['response']
                if 'words' not in q:
                    continue
                assert r is not None, (s, row)
                kind, words = q['kind'], q['words']
                loc = dict(stage=s, eventPointer=row['eventPointer'])
                index = len(operations)
                operations.append(dict(index=index, location=loc, request=q, response=r))
                result = r['result']
                observations[kind + ':' + str(result)] += 1
                if kind == 'image' and result:
                    token = result & 0xffffffff
                    assert token not in images
                    saved = source_case['images'][str(token)]
                    asset = saved['asset']
                    assert q['strings'] == [list(asset['path'].encode())]
                    assert words[4] == 0x2000 and asset['kind'] == 'embedded'
                    images[token] = dict(asset=asset, created=index, deleted=False, deletions=[])
                    if asset['raw'] not in verified_assets:
                        blob = docs['front']['blobs'][asset['raw']]
                        raw = zlib.decompress(base64.b64decode(blob['deflate']), -15)
                        assert len(raw) == blob['count'] and digest(raw) == asset['raw'] == blob['sha256']
                        size, width, height, planes, bpp, compression = struct.unpack_from('<IiiHHI', raw)
                        assert size == 40 and [width, height, planes, bpp] == [asset[n] for n in ('width', 'height', 'planes', 'bpp')]
                        verified_assets[asset['raw']] = dict(asset=asset, dibBytes=len(raw), compression=compression)
                elif kind == 'createSurface' and r.get('output'):
                    token = r['output']
                    assert token not in surfaces
                    surfaces[token] = dict(description=q['bytes'], descriptionMask=q['defined'],
                        fields=descriptor(q['bytes'], q['defined']), created=index, createResult=result,
                        releaseRequests=[], copies=[])
                elif kind == 'createDC':
                    token = result & 0xffffffff
                    if token in source_dcs:
                        assert source_dcs[token]['deleteRequests'], ('DC reused before DeleteDC request', token)
                    source_dcs[token] = dict(token=token, generation=len(source_generations), created=index,
                        createResult=result, selected=None, selections=[], deleteRequests=[])
                    source_generations.append(source_dcs[token])
                elif kind == 'selectObject':
                    dc, token = words
                    assert dc in source_dcs and token in images and not images[token]['deleted']
                    source_dcs[dc]['selected'] = token
                    source_dcs[dc]['selections'].append(dict(index=index, image=token, result=result))
                elif kind in ('restore', 'description', 'getDC', 'colorKey', 'release'):
                    token = words[0]
                    assert token in surfaces
                    if kind == 'description':
                        for out in r['writes']:
                            assert out['offset'] == 0 and out['bytes'] == surfaces[token]['description']
                    elif kind == 'getDC' and r.get('output'):
                        dc = r['output']
                        if dc in target_dcs:
                            assert target_dcs[dc]['releases'], ('DC reacquired before ReleaseDC request', dc)
                        target_dcs[dc] = dict(token=dc, generation=len(target_generations), surface=token,
                            acquired=index, result=result, releases=[])
                        target_generations.append(target_dcs[dc])
                    elif kind == 'release':
                        surfaces[token]['releaseRequests'].append(dict(index=index, result=result))
                elif kind == 'stretch':
                    assert len(words) == 11
                    dc, x, y, width, height, src, sx, sy, sw, sh, rop = words
                    assert dc in target_dcs and src in source_dcs
                    image = source_dcs[src]['selected']
                    assert image in images and not images[image]['deleted']
                    surface = target_dcs[dc]['surface']
                    asset = images[image]['asset']; dest = surfaces[surface]['fields']
                    item = dict(index=index, sourceImage=image, sourceDC=src, targetDC=dc, surface=surface,
                        asset=asset['path'], rawDIB=asset['raw'], sourceRectangle=[sx, sy, sw, sh],
                        destinationRectangle=[x, y, width, height], rop=rop, result=result,
                        sourceDimensions=[asset['width'], asset['height']], destinationDimensions=[dest['width'], dest['height']],
                        equalRequestedExtents=width == sw and height == sh,
                        wholeSource=[sx, sy, sw, sh] == [0, 0, asset['width'], asset['height']],
                        wholeDestination=[x, y, width, height] == [0, 0, dest['width'], dest['height']],
                        selectedResult=source_dcs[src]['selections'][-1]['result'],
                        sourceDCGeneration=source_dcs[src]['generation'], targetDCGeneration=target_dcs[dc]['generation'],
                        getDCResult=target_dcs[dc]['result'], pixelEffectObserved=False)
                    copies.append(item); surfaces[surface]['copies'].append(index)
                elif kind == 'releaseDC':
                    token, dc = words
                    assert dc in target_dcs and target_dcs[dc]['surface'] == token
                    target_dcs[dc]['releases'].append(dict(index=index, result=result))
                elif kind == 'deleteDC':
                    assert words[0] in source_dcs
                    source_dcs[words[0]]['deleteRequests'].append(dict(index=index, result=result))
                elif kind == 'deleteObject':
                    image = images[words[0]]
                    assert not image['deleted']
                    image['deleted'] = bool(result)
                    image['deletions'].append(dict(index=index, result=result))
                elif kind == 'getObject':
                    assert words[0] in images and not images[words[0]]['deleted']
                    a = images[words[0]]['asset']
                    for out in r['writes']:
                        assert out['offset'] == 0 and len(out['bytes']) == 24
                        assert list(struct.unpack_from('<ii', bytes(out['bytes']), 4)) == [a['width'], a['height']]
                elif kind not in ('module', 'image', 'createSurface', 'message', 'debug'):
                    raise AssertionError(('unhandled bitmap request', kind, loc))
            assert set(map(str, images)) == set(source_case['images'])
            assert set(map(str, surfaces)) == set(source_case['surfaces'])
            assert set(map(str, source_dcs)) == set(source_case['dcs'])
            for token, image in images.items():
                assert image['asset'] == source_case['images'][str(token)]['asset']
                assert image['deleted'] == source_case['images'][str(token)]['deleted']
            for token, surface in surfaces.items():
                assert surface['description'] == source_case['surfaces'][str(token)]['description']
                assert bool(surface['releaseRequests']) == source_case['surfaces'][str(token)]['released']
            for token, dc in source_dcs.items():
                assert bool(dc['deleteRequests']) == source_case['dcs'][str(token)]
        lifetimes[life_id] = dict(stages=selected, operations=operations, copies=copies, images=images,
            surfaces=surfaces, sourceDCs=source_dcs, targetDCs=target_dcs, replies=dict(observations),
            sourceDCGenerations=source_generations, targetDCGenerations=target_generations,
            interpretation='DC deletion/surface Release fields match requests only, not Windows destruction. Pixel effects are unobserved.')

    def counts(items):
        summary = collections.Counter()
        for item in items:
            for op in item['operations']:
                summary[op['request']['kind']] += 1
        return dict(sorted(summary.items()))

    result = dict(schema=1, purpose=plan['purpose'], reference=plan['reference'], parentJoins=joins,
        chains=chains, stages=stages, bitmapLifetimes=lifetimes, assets=verified_assets,
        summary=dict(rootCounts=dict(collections.Counter(c['rootKind'] for c in chains)),
            distinctStageCounts=dict(collections.Counter(s['kind'] for s in stages.values())),
            distinctBitmapLifetimes=len(lifetimes), uniqueLifetimeOperations=counts(lifetimes.values()),
            uniqueBitmapStageRequests=dict(collections.Counter(row['request']['kind'] for s in stages.values()
                if s['kind'] in ('bitmap', 'front') for row in s['requests'] if 'words' in row['request'])),
            occurrenceOperations={kind: counts(lifetimes[c['bitmapLifetime']] for c in chains if c['rootKind'] == kind)
                                  for kind in ('menu', 'input', 'loading')},
            assets=len(verified_assets), scaledCopiesInDistinctLifetimes=sum(not copy['equalRequestedExtents'] for l in lifetimes.values() for copy in l['copies'])),
        unknowns=['No saved bitmap API writes include a pixel buffer.',
            'GetSurfaceDesc repeats requested descriptor bytes; omitted pixel-format flag is not evidence of RGB32 or RGB8 storage.',
            'GetDC/SelectObject/StretchBlt numeric replies are controlled harness responses, not measured GDI raster conversion.',
            'Other graphics/window/panel requests remain catalogued by stage; this bitmap lifetime model does not supply their pixels.',
            'Source DIB holes and initial/failed-copy surface contents remain unknown; no black, alpha or color-key inference.'],
        originalExecuted=False, nativeCompared=False, windowsVerified=False, fullGameComplete=False,
        inputPins=pins)
    for path, expected in pins.items():
        assert pin(path) == expected, path
    return result


def event_catalog(plan, inventory_path, started):
    """Complete exact non-request events without rerunning the accepted join."""
    saved = json.loads(inventory_path.read_bytes())
    for path, expected in plan['inputPins'].items():
        assert pin(path) == expected, path
    documents = {path: json.loads(Path(path).read_bytes()) for path in plan['corpora'].values()}
    def dereference(location):
        value = documents[location['source']]
        for part in location['pointer'].split('/')[1:]:
            value = value[int(part)] if isinstance(value, list) else value[part]
        return value
    stage_values = {s: dereference(v['locations'][0]) for s, v in saved['stages'].items()}
    input_values = {key(c): c for c in documents[plan['corpora']['input']]['cases']}
    output, front_graphics, blits = {}, [], []
    graphics = {'blit', 'fill', 'clear', 'getDC', 'releaseDC', 'textOut', 'method', 'setTextColor', 'setBackgroundMode'}
    for s, value in stage_values.items():
        assert time.monotonic() - started < plan['limits']['inventorySeconds']
        assert key(value) == saved['stages'][s]['caseSHA256']
        for location in saved['stages'][s]['locations']:
            assert dereference(location) == value
        kind, spec = saved['stages'][s]['kind'], value.get('spec', {})
        # These are original harness's declared result inputs. The event does
        # not itself contain a sampled device reply; keep that distinction.
        effective = input_values[value['parent']]['spec'] if kind == 'loading' else spec
        output[s] = dict(locations=saved['stages'][s]['locations'], spec=spec,
            events=value.get('events', []), eventSHA256=[key(e) for e in value.get('events', [])])
        for i, event in enumerate(value.get('events', [])):
            e = event.get('event', {})
            if event.get('kind') != 'front' or e.get('kind') not in graphics:
                continue
            operation = e['kind']; result = None; provenance = None; out = None
            if operation == 'blit':
                if kind == 'front': result, provenance = spec.get('drawResult', 0), 'front.fs.get(drawResult,0)'
                elif kind == 'body': result, provenance = spec['drawResults'][0], 'body.bs.drawResults[0]'
                else: result, provenance = effective['drawResult'], 'menu/input drawResult; loading inherits input parent'
            elif operation in ('fill', 'clear'):
                if kind == 'front': result, provenance = spec.get('fillResult', 0), 'front.fs.get(fillResult,0)'
                elif kind in ('input', 'loading'): result, provenance = effective['drawResult'], 'input.repeat_spec.drawResult'
            elif operation == 'getDC':
                result = spec['dcResult'] if kind == 'body' else 0 if kind == 'menu' else effective['dcResult']
                out = spec['dc'] if kind == 'body' else 0x12345678
                provenance = 'body.bs.dcResult/dc; menu resets0/12345678; input sets dcResult/12345678; loading inherits'
            elif operation in ('releaseDC', 'textOut', 'setTextColor', 'setBackgroundMode'):
                result = spec['methodResult'] if kind == 'body' else 0 if kind == 'menu' else effective['drawResult']
                provenance = 'body.bs.methodResult; menu resets0; input sets drawResult; loading inherits'
            elif operation == 'method':
                method = e['arguments'][1]
                if method == 0x14:
                    result, provenance = effective['presentResult'], 'menu.ns/input.repeat_spec.presentResult; loading inherits input'
                elif method == 8:
                    result, provenance = effective['releaseResult'], 'input.repeat_spec.releaseResult'
            item = dict(stage=s, eventIndex=i, eventPointer='/events/' + str(i), eventSHA256=key(event),
                        operation=e, declaredResult=result, declaredOutput=out, resultProvenance=provenance,
                        resultStatus='declared harness response from pinned producer' if provenance else 'not yet recovered',
                        actualPixelEffectObserved=False)
            front_graphics.append(item)
            if operation == 'blit':
                b = e['blit']; src, dst = b['source'], b['destination']
                item['sourceExtents'] = [src[2]-src[0], src[3]-src[1]]
                item['destinationExtents'] = [dst[2]-dst[0], dst[3]-dst[1]]
                item['equalRequestedExtents'] = item['sourceExtents'] == item['destinationExtents']
                blits.append(item)
    resources = {}
    for lifetime in saved['bitmapLifetimes'].values():
        for image in lifetime['images'].values():
            asset = image['asset']
            assert asset['path'] not in resources or resources[asset['path']] == asset
            resources[asset['path']] = asset
    pixel_ref = json.loads(Path('native/Tests/NTSDCoreTests/Fixtures/startup-dib-pixels.json').read_bytes())
    pixel_by_name = {r['name']: r for r in pixel_ref['resources']}
    for name, asset in resources.items():
        assert asset['raw'] == pixel_by_name[name]['rawSHA256']
    result = dict(schema=1, inventory=pin(inventory_path), stageEvents=output,
        frontGraphics=front_graphics, resources=resources,
        resourcePixels={name: {k: v for k, v in pixel_by_name[name].items() if k != 'rows'} for name in resources},
        summary=dict(stages=len(output), events=sum(len(v['events']) for v in output.values()),
            frontGraphics=len(front_graphics), frontGraphicsKinds=dict(collections.Counter(x['operation']['kind'] for x in front_graphics)),
            frontBlits=len(blits), frontBlitsByStage=dict(collections.Counter(saved['stages'][x['stage']]['kind'] for x in blits)),
            frontScaledBlits=sum(not b['equalRequestedExtents'] for b in blits),
            missingDeclaredReplies=sum(x['resultProvenance'] is None for x in front_graphics),
            resourceNames=len(resources), distinctDIBPayloads=len({a['raw'] for a in resources.values()})),
        interpretation='Exact original event payloads and defined masks; declared numeric replies reconstructed from pinned producer/spec, not measured Windows pixels. DC selections are inferred from ordered requests. Saved pixelFormat responses remain controlled inputs.',
        originalExecuted=False, nativeCompared=False, windowsVerified=False, fullGameComplete=False)
    for path, expected in plan['inputPins'].items():
        assert pin(path) == expected, path
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--inventory', type=Path, help='Catalog exact events for an already completed inventory; do not rerun it')
    args = parser.parse_args()
    assert not args.output.exists()
    job_path = args.output.with_suffix('.job.json')
    assert not job_path.exists()
    started = time.monotonic()
    job = dict(pid=os.getpid(), cwd=str(Path.cwd()), command=sys.argv, startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
               state='running', producer=pin(__file__), plan=pin(args.plan))
    write(job_path, job)
    try:
        plan = json.loads(args.plan.read_bytes())
        result = event_catalog(plan, args.inventory, started) if args.inventory else inventory(plan, started)
        result['producer'] = pin(__file__)
        result['plan'] = pin(args.plan)
        write(args.output, result)
        job.update(state='terminal', exit=0, output=pin(args.output))
        print(json.dumps(result['summary'], indent=2), flush=True)
    except BaseException:
        job.update(state='terminal', exit=1, error=traceback.format_exc())
        write(args.output.with_suffix('.failure.json'), job)
        raise
    finally:
        job.update(elapsedSeconds=time.monotonic()-started, endedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        job_path.write_text(json.dumps(job, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    main()
