import AppKit
import SwiftUI
import XCTest
@testable import calendar

@MainActor
final class PopoverSizingTests: XCTestCase {
    @Observable final class State {
        var days: [EventDay]
        init(_ days: [EventDay]) { self.days = days }
    }

    func testPanelShrinksWhenEventsAreHidden() {
        let fixture = EventPreviewFixture.empty()
        let entries = (0..<20).map { index in
            EventEntryMock.make(event: CalendarEventMock.today(compositeId: "size/\(index)"))
        }
        let state = State([EventDay(day: .now, entries: entries)])
        let content = Content(state: state)
            .environment(fixture.eventManager)
            .environment(fixture.eventManager.accounts)
        let panel = MenuBarPanel(rootView: AnyView(content))
        panel.anchor(below: NSRect(x: 200, y: 900, width: 100, height: 24), on: nil)
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        settle(panel)
        let expandedHeight = panel.frame.height
        XCTAssertEqual(expandedHeight, 600, accuracy: 2, "Long lists should scroll within the panel height limit")
        let top = panel.frame.maxY
        state.days = [EventDay(day: .now, entries: Array(entries.prefix(2)))]
        settle(panel)
        let fittedHeight = panel.contentView!.fittingSize.height
        XCTAssertLessThan(fittedHeight, expandedHeight - 100)
        XCTAssertEqual(panel.frame.height, fittedHeight, accuracy: 2, "Hidden rows must not leave blank space in the panel")
        XCTAssertEqual(panel.frame.maxY, top, accuracy: 1)

        state.days = [EventDay(day: .now, entries: entries)]
        settle(panel)
        XCTAssertEqual(panel.frame.height, expandedHeight, accuracy: 2)
        XCTAssertEqual(panel.frame.maxY, top, accuracy: 1)

        state.days = []
        settle(panel)
        XCTAssertLessThan(panel.frame.height, expandedHeight - 100)
        XCTAssertEqual(panel.frame.height, panel.contentView!.fittingSize.height, accuracy: 2)
        XCTAssertEqual(panel.frame.maxY, top, accuracy: 1)
    }

    private func settle(_ panel: NSPanel) {
        for _ in 0..<10 {
            panel.contentView?.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
    }

    private struct Content: View {
        let state: State
        var body: some View {
            PopoverContent(days: state.days, hasReadableAccounts: true, maxHeight: 600,
                           onSettings: {}, onRefresh: {}, isRefreshing: false)
        }
    }
}
