/// The shipped shape (NTSDCore/OriginalRetainedHistory.swift): a non-generic
/// link owns `next` and the tail walk, so the uniqueness check is specialised
/// for a concrete class; the generic node's deinit calls it before its own
/// element is released.
class HistoryLink {
    final var next: HistoryLink?
    init(next: HistoryLink?) { self.next = next }
    final func releaseTail() {
        var current = next; next = nil
        while var node = current {
            current = nil
            guard isKnownUniquelyReferenced(&node) else { break }
            current = node.next; node.next = nil
        }
    }
}
public struct LinkHistory<Element> {
    final class Node: HistoryLink {
        let element: Element, count: Int
        init(_ element: Element,_ next: Node?) { self.element = element; count = (next?.count ?? 0)+1; super.init(next:next) }
        deinit { releaseTail() }
    }
    var head: Node?
    public init() {}
    public mutating func append(_ element: Element) { head = Node(element,head) }
    public var count: Int { var n = 0; var node: HistoryLink? = head; while let x = node { n += 1; node = x.next }; return n }
}
