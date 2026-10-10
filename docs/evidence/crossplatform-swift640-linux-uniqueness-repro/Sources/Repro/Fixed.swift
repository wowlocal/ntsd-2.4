public struct FixedHistory<Element> {
    final class Node {
        let element: Element
        var next: Node?
        init(_ element: Element,_ next: Node?) { self.element = element; self.next = next }
        deinit {
            var current = next; next = nil
            while isKnownUniquelyReferenced(&current),let node = current {
                current = node.next; node.next = nil
            }
        }
    }
    var head: Node?
    public init() {}
    public mutating func append(_ element: Element) { head = Node(element,head) }
    public var count: Int { var n = 0, node = head; while let x = node { n += 1; node = x.next }; return n }
}
