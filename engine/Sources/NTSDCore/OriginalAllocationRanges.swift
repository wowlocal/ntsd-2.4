/// The catalog attempt's allocation ranges and its overlap test: whether some
/// range r has `lo < r.hi && r.lo < hi` (half-open, an empty range counting
/// when it lies strictly inside), answered by binary search instead of a scan
/// over every earlier range (~15,000 by the end of the catalog; MEMORY_LOADING
/// L18). The ranges given at creation (the memory's live allocations) may be
/// empty or overlap one another: they are kept sorted by start with the
/// largest end of each prefix. Every range added later passed the test and is
/// not empty, so those are disjoint: kept sorted, a query looks at the first
/// whose end is past `lo`.
struct OriginalAllocationRanges {
    private let base: [(lo: UInt64, hi: UInt64)], baseMaxEnd: [UInt64]
    private var added: [(lo: UInt64, hi: UInt64)] = []

    init(base ranges: [(UInt64, UInt64)]) {
        base = ranges.map { (lo: $0.0, hi: $0.1) }.sorted { $0.lo < $1.lo }
        var running: UInt64 = 0
        baseMaxEnd = base.map { running = max(running, $0.hi); return running }
    }

    func overlaps(_ lo: UInt64, _ hi: UInt64) -> Bool {
        // Base ranges starting before hi: the largest of their ends past lo.
        var low = 0, high = base.count
        while low < high { let mid = (low + high) / 2; if base[mid].lo < hi { low = mid + 1 } else { high = mid } }
        if low > 0 && baseMaxEnd[low - 1] > lo { return true }
        // Added ranges: the first whose end is past lo, if it starts before hi.
        let i = firstAdded(endingAfter: lo)
        return i < added.count && added[i].lo < hi
    }

    /// Adds a non-empty range that `overlaps` rejected.
    mutating func insert(_ lo: UInt64, _ hi: UInt64) {
        precondition(lo < hi, "allocation range")
        added.insert((lo, hi), at: firstAdded(endingAfter: lo))
    }

    private func firstAdded(endingAfter lo: UInt64) -> Int {
        var low = 0, high = added.count
        while low < high { let mid = (low + high) / 2; if added[mid].hi > lo { high = mid } else { low = mid + 1 } }
        return low
    }
}
