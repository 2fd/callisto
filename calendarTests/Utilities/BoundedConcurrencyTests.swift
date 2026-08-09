import Foundation
import Testing

@testable import calendar

/// Pacing the fan-out is only useful if the bound actually holds and no work is
/// dropped on the way.
@Suite("Bounded concurrency")
struct BoundedConcurrencyTests {

    /// Tracks how many tasks were in flight at once.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var current = 0
        private(set) var peak = 0

        func enter() {
            lock.withLock {
                current += 1
                peak = max(peak, current)
            }
        }

        func leave() {
            lock.withLock { current -= 1 }
        }
    }

    @Test("Never exceeds the limit")
    func respectsLimit() async {
        let counter = Counter()

        _ = await withBoundedConcurrency(over: Array(1...50), limit: 4) { value in
            counter.enter()
            try? await Task.sleep(for: .milliseconds(5))
            counter.leave()
            return value
        }

        #expect(counter.peak <= 4)
    }

    @Test("Every item is processed")
    func processesEverything() async {
        let results = await withBoundedConcurrency(over: Array(1...50), limit: 4) { $0 * 2 }

        #expect(results.count == 50)
        #expect(Set(results) == Set((1...50).map { $0 * 2 }))
    }

    @Test("Dropped items are excluded rather than crashing")
    func dropsNilResults() async {
        // The result type is stated explicitly: left to inference, `Output`
        // binds to `Int?` and the `nil` becomes a *present* `Optional<Int>`,
        // so nothing is dropped.
        let results: [Int] = await withBoundedConcurrency(over: Array(1...10), limit: 3) {
            (value: Int) -> Int? in
            value.isMultiple(of: 2) ? value : nil
        }

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.isMultiple(of: 2) })
    }

    @Test("An empty work list returns immediately")
    func handlesEmptyInput() async {
        let results = await withBoundedConcurrency(over: [Int](), limit: 4) { $0 }
        #expect(results.isEmpty)
    }

    @Test("A limit below one still makes progress instead of deadlocking")
    func clampsInvalidLimit() async {
        let results = await withBoundedConcurrency(over: Array(1...5), limit: 0) { $0 }
        #expect(results.count == 5)
    }

    @Test("More workers than items is harmless")
    func handlesLimitAboveCount() async {
        let results = await withBoundedConcurrency(over: Array(1...3), limit: 100) { $0 }
        #expect(results.count == 3)
    }
}
