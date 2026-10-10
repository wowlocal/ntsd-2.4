/// Append-only history with value semantics. Copies share immutable nodes, so
/// copying a platform or delivery context costs O(1) instead of O(history),
/// while every element stays alive as long as any copy holds it.
public struct OriginalRetainedHistory<Element> {
    private final class Node: OriginalRetainedHistoryLink {
        let element: Element, count: Int
        init(_ element: Element,_ next: Node?) { self.element = element; count = (next?.count ?? 0)+1; super.init(next) }
        deinit { releaseTail() }
    }
    private var head: Node?
    public init() {}
    public var count: Int { head?.count ?? 0 }
    public mutating func append(_ element: Element) { head = Node(element,head) }
    /// Newest first.
    public var elements: [Element] {
        var out: [Element] = [], node = head
        while let n = node { out.append(n.element); node = n.next.map { unsafeDowncast($0,to:Node.self) } }
        return out
    }
}

/// The links of every history. Not generic on purpose: the open-source Swift
/// 6.4.0 toolchain for Linux drops the store into the inout slot of an
/// unspecialised generic `isKnownUniquelyReferenced` call and hoists the call
/// out of the loop, so a generic node's tail walk read an uninitialised slot.
/// On a concrete class the check is specialised to the loaded reference.
private class OriginalRetainedHistoryLink {
    final var next: OriginalRetainedHistoryLink?
    init(_ next: OriginalRetainedHistoryLink?) { self.next = next }
    /// Release uniquely owned tails iteratively: a long history must not
    /// recurse once per node when its last holder goes away.
    final func releaseTail() {
        var current = next; next = nil
        while var node = current {
            current = nil
            guard isKnownUniquelyReferenced(&node) else { break }
            current = node.next; node.next = nil
        }
    }
}
