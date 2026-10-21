import XCTest

#if !canImport(ObjectiveC)
/// Without the Objective-C runtime there is no autorelease pool; run the body.
func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result { try body() }
#endif

#if !canImport(Darwin)
// swift-corelibs-xctest has no NSObject `init()`. These suites keep the
// Darwin-style initializer they had in the game's tests
// (native/Tests/NTSDCoreTests/CorelibsXCTestSupport.swift, until ENGINE_SPLIT E4c).
extension OriginalAllocationRangesTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalApplicationIterationDeliveryTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalAudioBytesUniformTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalCatalogChecksumTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalClosedStreamContentsTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalConcurrentInputsTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalConcurrentLoopTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalDIBValidationTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalDecimalMaterializationTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalDefinedBitsTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalFileTranslationTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalFrameHeapIndexTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalFrameRecordCompactTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalInPlaceObjectLoadTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalLZ4Tests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalLatin1Tests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalLoadingFilesInPlaceTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalLoadingReadAheadTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalPCMSamplesTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalPagedStageTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalPosixFileFactsTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalRequestSlotWordTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalRetainedHistoryTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalSharedFrameSlotTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalSurfaceUnknownTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension OriginalWord32BoundaryTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension PortableSHA256BlockFunctionTests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
extension PortableSHA256Tests { convenience init() { self.init(name: "helper", testClosure: { _ in }) } }
#endif
