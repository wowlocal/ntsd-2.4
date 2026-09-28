/// Append-only history with value semantics. Copies share immutable nodes, so
/// copying a platform or delivery context costs O(1) instead of O(history),
/// while every element stays alive as long as any copy holds it.
public struct OriginalRetainedHistory<Element> {
    private final class Node {
        let element: Element, count: Int
        var next: Node?
        init(_ element: Element,_ next: Node?) { self.element = element; self.next = next; count = (next?.count ?? 0)+1 }
        deinit {
            // Release uniquely owned tails iteratively: a long history must not
            // recurse once per node when its last holder goes away.
            var current = next; next = nil
            while var node = current {
                current = nil
                guard isKnownUniquelyReferenced(&node) else { break }
                current = node.next; node.next = nil
            }
        }
    }
    private var head: Node?
    public init() {}
    public var count: Int { head?.count ?? 0 }
    public mutating func append(_ element: Element) { head = Node(element,head) }
    /// Newest first.
    public var elements: [Element] {
        var out: [Element] = [], node = head
        while let n = node { out.append(n.element); node = n.next }
        return out
    }
}
