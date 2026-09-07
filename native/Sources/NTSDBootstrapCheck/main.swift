import Foundation
import NTSDReferenceChecks

do {
    guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
    let result = try BootstrapReference.compare(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    print("Swift matches original bootstrap: \(result.cases) cases, \(result.checkpoints) checkpoints, \(result.records) records, \(result.bytes) bytes and masks")
} catch {
    FileHandle.standardError.write(Data("Bootstrap comparison failed: \(error)\n".utf8)); exit(1)
}
