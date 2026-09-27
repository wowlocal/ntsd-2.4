"""Retain PCM test owners through raw-pointer access; preserve all comparisons."""
from pathlib import Path


def apply(candidate):
    name = 'native/Tests/NTSDCoreTests/OriginalMacAudioBackendTests.swift'
    path = Path(candidate) / name
    before = path.read_text()
    first = '''        let channels = try XCTUnwrap(pcm.floatChannelData)
        for channel in 0..<file.channels {
            XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:file.frames)),file.samples(channel))
        }
        channels[0][0] = 123 // exported snapshot must not alias the retained owner
        XCTAssertEqual(try XCTUnwrap(b.pcmSnapshot(token).floatChannelData)[0][0],file.samples(0)[0])'''
    retained = '''        try withExtendedLifetime(pcm) {
            let channels = try XCTUnwrap(pcm.floatChannelData)
            for channel in 0..<file.channels {
                XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:file.frames)),file.samples(channel))
            }
            channels[0][0] = 123 // exported snapshot must not alias the retained owner
            let independent = try b.pcmSnapshot(token)
            try withExtendedLifetime(independent) {
                XCTAssertEqual(try XCTUnwrap(independent.floatChannelData)[0][0],file.samples(0)[0])
            }
        }'''
    offline = '''                let channels = try XCTUnwrap(output.floatChannelData)
                for channel in 0..<f.channels {
                    XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:request)),Array(expected[channel][position..<(position+request)]))
                }'''
    retained_offline = '''                try withExtendedLifetime(output) {
                    let channels = try XCTUnwrap(output.floatChannelData)
                    for channel in 0..<f.channels {
                        XCTAssertEqual(Array(UnsafeBufferPointer(start:channels[channel],count:request)),Array(expected[channel][position..<(position+request)]))
                    }
                }'''
    assert before.count(first) == 1 and before.count(offline) == 1
    after = before.replace(first, retained).replace(offline, retained_offline)
    assert after.count('withExtendedLifetime(') == before.count('withExtendedLifetime(') + 3
    assert after.count('XCTAssert') == before.count('XCTAssert')
    path.write_text(after)
    return {name: dict(before=before, after=after)}
