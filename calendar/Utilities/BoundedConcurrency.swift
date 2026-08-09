import Foundation

/// Runs `operation` over `items` with at most `limit` tasks in flight,
/// collecting the non-`nil` results in completion order.
///
/// `withTaskGroup` alone starts every task immediately, which turns a user with
/// many calendars into a burst of simultaneous requests against a per-user quota.
/// This keeps the same total work but paces it: `limit` tasks start, and each
/// completion admits the next.
///
/// - Parameters:
///   - items: The work list. An empty list returns immediately.
///   - limit: Maximum concurrent tasks. Values below 1 are treated as 1.
///   - operation: Runs one item; returning `nil` drops it from the results.
///
/// - Important: Make sure `Output` is bound to a non-optional type. If the
///   compiler is left to infer it from a closure returning `T?`, it can bind
///   `Output` to `T?` — and then a returned `nil` is a *present* value that is
///   never dropped. Pin it with the caller's return type or an explicit
///   closure signature.
nonisolated func withBoundedConcurrency<Item: Sendable, Output: Sendable>(
    over items: [Item],
    limit: Int,
    operation: @escaping @Sendable (Item) async -> Output?
) async -> [Output] {
    guard !items.isEmpty else { return [] }
    let window = max(1, limit)

    return await withTaskGroup(of: Output?.self) { group in
        var pending = items.makeIterator()
        var started = 0

        while started < window, let item = pending.next() {
            group.addTask { await operation(item) }
            started += 1
        }

        var results: [Output] = []
        results.reserveCapacity(items.count)

        while let finished = await group.next() {
            if let finished { results.append(finished) }
            if let item = pending.next() {
                group.addTask { await operation(item) }
            }
        }
        return results
    }
}
