#!/usr/bin/env python3
"""Data-only RGB/written-mask reference for the pinned 36 startup DIB resources.

No Original EXE, emulation, historical producer, or Native code is imported/run.
The Microsoft DIB/RLE8 format defines the conversion; device colors are separate.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import struct


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def decode(data, maximum_pixels=16777216):
    require(len(data) >= 40, 'header')
    size, w, h, planes, bits, compression, image_size, _, _, colors, _ = struct.unpack_from('<IiiHHIIiiII', data)
    require(size == 40 and planes == 1 and w > 0 and h > 0, 'dimensions/header')
    require((bits, compression) in [(24, 0), (8, 1)], 'format')
    require(0 < w*h <= maximum_pixels, 'pixel budget')
    rgb = bytearray(w*h*3)
    mask = bytearray(w*h)
    stats = {'width':w, 'height':h, 'bits':bits, 'compression':compression,
             'imageSize':image_size, 'colorsUsed':colors, 'commands':[],
             'paddingValues':{}, 'paletteReservedValues':{}, 'indices':[]}
    if bits == 24:
        require(colors == 0, 'RGB palette')
        stride = (w*3+3)//4*4
        extent = stride*h
        require(image_size in [0, extent] and 40+extent <= len(data), 'RGB extent')
        padding = collections.Counter()
        for y in range(h):
            row = data[40+y*stride:40+(y+1)*stride]
            target = (h-1-y)*w*3
            rgb[target:target+w*3:3] = row[2:w*3:3]
            rgb[target+1:target+w*3:3] = row[1:w*3:3]
            rgb[target+2:target+w*3:3] = row[:w*3:3]
            padding.update(row[w*3:])
        mask[:] = b'\x01'*(w*h)
        stats.update(stride=stride, dataOffset=40, consumedBytes=extent,
                     paddingValues=dict(padding), tailBytes=len(data)-40-extent)
    else:
        count = colors or 256
        require(count <= 256, 'palette count')
        start = 40+count*4
        require(start <= len(data), 'palette extent')
        require(image_size > 0 and start+image_size <= len(data), 'RLE extent')
        palette = [data[i:i+3][::-1] for i in range(40, start, 4)]
        stats['paletteReservedValues'] = dict(collections.Counter(data[43:start:4]))
        pos, end, x, y = start, start+image_size, 0, 0
        used = set(); pads = collections.Counter()
        def read(n):
            nonlocal pos
            require(pos+n <= end, 'truncated RLE')
            value = data[pos:pos+n]; pos += n
            return value
        def write(indices):
            nonlocal x
            require(y < h and x+len(indices) <= w, 'RLE output extent')
            for index in indices:
                require(index < count, 'palette index')
                at = (h-1-y)*w+x
                rgb[at*3:at*3+3] = palette[index]
                mask[at] = 1; x += 1; used.add(index)
        while True:
            offset = pos
            n, value = read(2)
            command = {'offset':offset-start, 'x':x, 'y':y}
            require(y < h or (n, value) == (0, 1), 'after final row')
            if n:
                command.update(kind='run', count=n, index=value)
                write([value]*n)
            elif value == 0:
                command.update(kind='eol'); x = 0; y += 1
                require(y <= h, 'EOL extent')
            elif value == 1:
                command.update(kind='eob'); stats['commands'].append(command)
                break
            elif value == 2:
                dx, dy = read(2); command.update(kind='delta', dx=dx, dy=dy)
                x += dx; y += dy
                require(x <= w and y < h, 'delta extent')
            else:
                literal = read(value)
                command.update(kind='absolute', count=value, indices=list(literal))
                write(literal)
                if value % 2:
                    pad = read(1)[0]; pads[pad] += 1; command['pad'] = pad
            stats['commands'].append(command)
        stats.update(dataOffset=start, consumedBytes=pos-start,
                     streamTailBytes=end-pos, tailBytes=len(data)-end,
                     indices=sorted(used), paddingValues=dict(pads))
    stats['writtenPixels'] = sum(mask)
    stats['unknownPixels'] = w*h-sum(mask)
    stats['commandCounts'] = dict(collections.Counter(x['kind'] for x in stats['commands']))
    stats['rows'] = [{'y':y, 'rgbSHA256':sha(rgb[y*w*3:(y+1)*w*3]),
                      'maskSHA256':sha(mask[y*w:(y+1)*w]),
                      'writtenPixels':sum(mask[y*w:(y+1)*w])} for y in range(h)]
    return bytes(rgb), bytes(mask), stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    manifest_raw = (args.package/'manifest.json').read_bytes()
    require(sha(manifest_raw) == 'f67aff089a95f230b4e7f5c381ac92b420a5541f7fea6b6a268986aa6b7ef177', 'package manifest pin')
    manifest = json.loads(manifest_raw)
    args.output.mkdir(exist_ok=False)
    records = []; payload = bytearray(); inventory = []
    for entry in manifest['entries']:
        if not entry['path'].startswith('bitmaps/'):
            continue
        raw = (args.package/entry['path']).read_bytes()
        require(len(raw) == entry['count'] and sha(raw) == entry['sha256'], entry['path'])
        rgb, mask, info = decode(raw)
        record = {'name':pathlib.Path(entry['path']).stem,'rawBytes':len(raw),
                  'rawSHA256':sha(raw),'width':info['width'],'height':info['height'],
                  'rgbOffset':len(payload),'rgbCount':len(rgb),'rgbSHA256':sha(rgb),
                  'maskOffset':len(payload)+len(rgb),'maskCount':len(mask),
                  'maskSHA256':sha(mask),'writtenPixels':info['writtenPixels'],
                  'unknownPixels':info['unknownPixels'],'rows':info['rows']}
        payload.extend(rgb); payload.extend(mask); records.append(record)
        inventory.append({'name':record['name'], **info})
    require(len(records) == 36, 'resource count')
    (args.output/'startup-dib-pixels.bin').write_bytes(payload)
    result = {'version':1,'reference':'Static original DIB format conversion; not Windows/device observation',
              'producerSHA256':sha(pathlib.Path(__file__).read_bytes()),
              'packageManifestSHA256':sha(manifest_raw),
              'payloadBytes':len(payload),'payloadSHA256':sha(payload),
              'pixelOrder':'top-left, row-major RGB8; one mask byte per pixel',
              'unknownBacking':'zero placeholder RGB with mask0; no known black claim',
              'resources':records}
    for name, value in [('startup-dib-pixels.json',result),('stream-inventory.json',inventory)]:
        (args.output/name).write_text(json.dumps(value,indent=2)+'\n')
    print(json.dumps({'resources':len(records),'pixels':sum(x['maskCount'] for x in records),
                      'writtenPixels':sum(x['writtenPixels'] for x in records),
                      'unknownPixels':sum(x['unknownPixels'] for x in records),
                      'payloadBytes':len(payload),'payloadSHA256':sha(payload)}))


if __name__ == '__main__':
    main()
