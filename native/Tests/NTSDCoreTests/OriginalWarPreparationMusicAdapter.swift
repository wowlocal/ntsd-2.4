import Foundation
import XCTest
import NTSDCore

/// Declared music responses for saved whole War callers. Numeric results,
/// optional output words and conversion writes are independent inputs. Defaults
/// come from the frozen music producer; expected events never supply responses.
final class OriginalWarPreparationMusicAdapter {
    typealias Test = OriginalLibWarPreparationTests
    struct Input: Decodable {
        let createResult: Int32,createPointer: UInt32?
        let queryResults: [Int32],queryPointers: [UInt32?]
        let methodResult: Int32,renderResult: Int32,getResult: Int32,setResult: Int32,fileResult: Int32
        let nullAllocation: Bool,conversion: String,conversionResult: Int32?
        static let defaults = Input(createResult:0,createPointer:0x2c002000,
            queryResults:[0,0,0,0],queryPointers:[0x2c002100,0x2c002200,0x2c002300,0x2c002400],
            methodResult:-2147467259,renderResult:0,getResult:0,setResult:-1,fileResult:-1,
            nullAllocation:false,conversion:"complete",conversionResult:nil)
    }
    let input: Input,control: Bool
    var allocationIndex: Int
    init(_ input: Input?,control: Bool,memory: OriginalMusicMemory) throws {
        self.input=input ?? .defaults;self.control=control
        allocationIndex=memory.allocations.keys.filter { $0>=0x2c020020 }.count
        guard self.input.queryResults.count==4,self.input.queryPointers.count==4,
              ["complete","none"].contains(self.input.conversion) else { throw Test.Stop.unexpected }
    }
    func response(_ q: OriginalMusicEvent) throws -> OriginalMusicResponse {
        switch q.kind {
        case .helper,.format,.closeHandle:return .init()
        case .message:return .init(result:7)
        case .createInstance:return .init(result:input.createResult,pointer:input.createPointer)
        case .queryInterface:
            guard let first=q.strings.first?.first,
                  let index=[UInt8(0xb1),0xb6,0xb2,0xb3].firstIndex(of:first) else { throw Test.Stop.unexpected }
            return .init(result:input.queryResults[index],pointer:input.queryPointers[index])
        case .audioVolumeRead:return .init(result:input.getResult,pointer:0xfffffb2e)
        case .method:
            guard q.arguments.count>=2 else { throw Test.Stop.unexpected }
            if q.arguments[0]==0x2c002000,q.arguments[1]==0x34 { return .init(result:input.renderResult) }
            if q.arguments[0]==0x2c002400,q.arguments[1]==0x1c { return .init(result:input.setResult) }
            return .init(result:input.methodResult)
        case .createFile:return .init(result:input.fileResult)
        case .allocate:
            guard q.arguments.count==1,q.arguments[0]>0,q.arguments[0]<0x1000 else { throw Test.Stop.unexpected }
            if input.nullAllocation { return .init(pointer:0) }
            let pointer=UInt32(0x2c020020)+UInt32(allocationIndex)*0x1000
            allocationIndex += 1
            return .init(pointer:pointer,bytes:(0..<Int(q.arguments[0])).map { control ? UInt8($0%256) : 0xa5 })
        case .convert:
            guard q.arguments.count==5,q.strings.count==1,q.strings[0].allSatisfy({ $0<128 }) else { throw Test.Stop.unexpected }
            let bytes: [UInt8]=q.arguments[3]==0 || input.conversion=="none" ? [] : (q.strings[0]+[0]).flatMap { [$0,UInt8(0)] }
            let result=input.conversionResult ?? (bytes.isEmpty ? 0 : Int32(q.strings[0].count+1))
            return .init(result:result,bytes:bytes)
        }
    }
    /// Each selected callback follows the target result's processing. Reaching
    /// this request is distinct from applying the response that it will return.
    static func rollbackKey(_ q: OriginalMusicEvent) -> String? {
        if q.kind == .message { return "message" }
        if q.kind == .queryInterface,q.strings.first?.first==0xb6 { return "eventQuery" }
        if q.kind == .method,q.arguments.count>=2 {
            if q.arguments[0]==0x2c002000,q.arguments[1]==0x34 { return "render" }
            if q.arguments[0]==0x2c002200,q.arguments[1]==0x34 { return "eventNotify" }
            if q.arguments[0]==0x2c002100,q.arguments[1]==0x1c { return "run" }
        }
        return nil
    }
}
