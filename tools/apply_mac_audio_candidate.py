"""Add the owned Native PCM service; preserve recovered source rules and tests."""
from pathlib import Path
R=Path('/Users/michael/Developer/ntsd-2.4')
def once(s,a,b):
    assert s.count(a)==1,(a,s.count(a));return s.replace(a,b)
def apply(root):
    root=Path(root);changes={}
    def put(name,text):
        p=root/name;before=p.read_text() if p.exists() else None
        assert before!=text,name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
        changes[name]=dict(before=before,after=text)
    name='native/Sources/NTSDCore/OriginalStartupAudio.swift';s=(root/name).read_text()
    addition='''/// Device-independent file/MMIO preparation. Identity is bound only after the
/// actual device reply; no future device token or audio result is stored here.
public struct OriginalWaveFileInput: Codable, Equatable, Sendable {
    public let stream: UInt32
    public let descendResults: [Int32], formatReadResult: Int32, ascendResult: Int32, dataReadResult: Int32, closeResult: Int32
    public let storage: OriginalWaveStorage
    public init(_ input: OriginalWaveInput) {
        stream = input.stream;descendResults = input.descendResults;formatReadResult = input.formatReadResult
        ascendResult = input.ascendResult;dataReadResult = input.dataReadResult;closeResult = input.closeResult;storage = input.storage
    }
    public func bind(destination: UInt32,device: UInt32) -> OriginalWaveInput {
        .init(destination:destination,device:device,stream:stream,descendResults:descendResults,
            formatReadResult:formatReadResult,ascendResult:ascendResult,dataReadResult:dataReadResult,
            closeResult:closeResult,storage:storage)
    }
}

'''
    s=once(s,'public struct OriginalWaveBinding:',addition+'public struct OriginalWaveBinding:');put(name,s)
    name='native/Sources/NTSDCore/OriginalApplicationPreparedStartupPlatform.swift';s=(root/name).read_text()
    addition='''    public struct WaveFile: Equatable {
        public let index: Int, path: String, destination: UInt32
        public init(_ index: Int,_ path: String,_ destination: UInt32) {
            self.index = index;self.path = path;self.destination = destination
        }
    }
'''
    s=once(s,'    public struct Wave: Equatable {',addition+'    public struct Wave: Equatable {')
    s=once(s,'        public var waveInputs: [Reply<OriginalWaveBinding,OriginalWaveInput>] = []','        public var waveInputs: [Reply<OriginalWaveBinding,OriginalWaveInput>] = []\n        public var waveFiles: [Reply<WaveFile,OriginalWaveFileInput>] = []')
    s=once(s,'.wave:prepared.observesAudio ? prepared.waveInputs.count : prepared.waves.count]', '.wave:prepared.observesAudio ? prepared.waveInputs.count+prepared.waveFiles.count : prepared.waves.count]')
    s=once(s,'guard prepared.observesAudio ? prepared.waves.isEmpty : prepared.waveInputs.isEmpty else {\n            throw Boundary.unconsumed(.wave,prepared.waves.count+prepared.waveInputs.count)', 'guard prepared.observesAudio ? (prepared.waves.isEmpty && (prepared.waveInputs.isEmpty || prepared.waveFiles.isEmpty)) : (prepared.waveInputs.isEmpty && prepared.waveFiles.isEmpty) else {\n            throw Boundary.unconsumed(.wave,prepared.waves.count+prepared.waveInputs.count+prepared.waveFiles.count)')
    s=once(s,'        guard observesAudio else { throw Boundary.invalidResponse }\n        return try take(.wave,prepared.waveInputs,OriginalWaveBinding(index,path,destination,device))','''        guard observesAudio,prepared.waves.isEmpty,
              prepared.waveInputs.isEmpty || prepared.waveFiles.isEmpty else { throw Boundary.invalidResponse }
        if !prepared.waveFiles.isEmpty {
            return try take(.wave,prepared.waveFiles,WaveFile(index,path,destination)).bind(destination:destination,device:device)
        }
        return try take(.wave,prepared.waveInputs,OriginalWaveBinding(index,path,destination,device))''')
    put(name,s)
    for name,folder in [('OriginalMacAudioBackend.swift','native/Sources/NTSDMacPlatform'),('OriginalMacAudioService.swift','native/Sources/NTSDMacPlatform'),('OriginalMacAudioBackendTests.swift','native/Tests/NTSDCoreTests')]:
        path=folder+'/'+name;assert not (root/path).exists();put(path,(R/'tools'/name).read_text())
    return changes
