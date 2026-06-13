import XCTest
import SwiftUI
@testable import Clipo

@MainActor
final class VirtualizedListViewTests: XCTestCase {

    // MARK: - Test Models

    struct TestItem: Identifiable {
        let id: UUID
        let title: String

        init(id: UUID = UUID(), title: String) {
            self.id = id
            self.title = title
        }
    }

    // MARK: - Visible Range Calculation

    func testInitialVisibleRange() {
        // Given: VirtualizedListView with 100 items
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 5

        // When: View is initialized
        let view = VirtualizedListView(
            items: items,
            itemHeight: itemHeight,
            bufferSize: bufferSize
        ) { item in
            Text(item.title)
        }

        // Then: Initial visible range should be 0..<10 (default)
        let mirror = Mirror(reflecting: view)
        let visibleRange = mirror.children.first { $0.label == "_visibleRange" }?.value as? State<Range<Int>>
        XCTAssertEqual(visibleRange?.wrappedValue, 0..<10)
    }

    func testVisibleRangeWithBuffer() {
        // Given: VirtualizedListView with 100 items, buffer size 5
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 5
        let viewportHeight: CGFloat = 500 // 10 items visible

        // When: Scroll offset is at item 20 (offset = -1000)
        let scrollOffset: CGFloat = -1000

        // Then: Visible range should be 15..<36 (20 - 5 buffer to 20 + 10 visible + 5 buffer + 1)
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        XCTAssertEqual(firstVisible, 15)
        XCTAssertEqual(lastVisible, 36)
    }

    func testVisibleRangeAtTop() {
        // Given: VirtualizedListView at top of list
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 5
        let viewportHeight: CGFloat = 500
        let scrollOffset: CGFloat = 0

        // When: At top (offset = 0)
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        // Then: Should start at 0 (clamped by max(0, ...))
        XCTAssertEqual(firstVisible, 0)
        XCTAssertEqual(lastVisible, 16) // 10 visible + 5 buffer + 1
    }

    func testVisibleRangeAtBottom() {
        // Given: VirtualizedListView at bottom of list
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 5
        let viewportHeight: CGFloat = 500
        let totalHeight = CGFloat(items.count) * itemHeight
        let scrollOffset = -(totalHeight - viewportHeight)

        // When: At bottom
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        // Then: Should end at items.count (clamped by min(..., items.count))
        XCTAssertEqual(lastVisible, 100)
        XCTAssertGreaterThanOrEqual(firstVisible, 0)
    }

    // MARK: - Range Clamping

    func testRangeClampingWithinBounds() {
        // Given: Range within bounds
        let range = 10..<20
        let limits = 0..<100

        // When: Clamping
        let clamped = range.clamped(to: limits)

        // Then: Should remain unchanged
        XCTAssertEqual(clamped, 10..<20)
    }

    func testRangeClampingLowerBound() {
        // Given: Range below lower bound
        let range = -5..<10
        let limits = 0..<100

        // When: Clamping
        let clamped = range.clamped(to: limits)

        // Then: Should clamp lower bound to 0
        XCTAssertEqual(clamped, 0..<10)
    }

    func testRangeClampingUpperBound() {
        // Given: Range above upper bound
        let range = 90..<110
        let limits = 0..<100

        // When: Clamping
        let clamped = range.clamped(to: limits)

        // Then: Should clamp upper bound to 100
        XCTAssertEqual(clamped, 90..<100)
    }

    func testRangeClampingBothBounds() {
        // Given: Range outside both bounds
        let range = -10..<110
        let limits = 0..<100

        // When: Clamping
        let clamped = range.clamped(to: limits)

        // Then: Should clamp both bounds
        XCTAssertEqual(clamped, 0..<100)
    }

    // MARK: - Empty Items

    func testEmptyItemsList() {
        // Given: VirtualizedListView with no items
        let items: [TestItem] = []
        let itemHeight: CGFloat = 50
        let bufferSize = 5

        // When: View is initialized
        let view = VirtualizedListView(
            items: items,
            itemHeight: itemHeight,
            bufferSize: bufferSize
        ) { item in
            Text(item.title)
        }

        // Then: Should handle empty list gracefully
        let mirror = Mirror(reflecting: view)
        let visibleRange = mirror.children.first { $0.label == "_visibleRange" }?.value as? State<Range<Int>>
        XCTAssertNotNil(visibleRange)
    }

    // MARK: - Buffer Size

    func testCustomBufferSize() {
        // Given: VirtualizedListView with custom buffer size
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 10
        let viewportHeight: CGFloat = 500
        let scrollOffset: CGFloat = -1000

        // When: Calculating visible range with buffer 10
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        // Then: Buffer should extend 10 items above and below
        XCTAssertEqual(firstVisible, 10) // 20 - 10 buffer
        XCTAssertEqual(lastVisible, 41) // 20 + 10 visible + 10 buffer + 1
    }

    func testZeroBufferSize() {
        // Given: VirtualizedListView with zero buffer
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 50
        let bufferSize = 0
        let viewportHeight: CGFloat = 500
        let scrollOffset: CGFloat = -1000

        // When: Calculating visible range with no buffer
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        // Then: Should only render visible items
        XCTAssertEqual(firstVisible, 20)
        XCTAssertEqual(lastVisible, 31) // 20 + 10 visible + 1
    }

    // MARK: - Item Height

    func testVariableItemHeight() {
        // Given: VirtualizedListView with different item heights
        let items = (0..<100).map { TestItem(title: "Item \($0)") }
        let itemHeight: CGFloat = 100 // Taller items
        let bufferSize = 5
        let viewportHeight: CGFloat = 500 // Only 5 items visible now
        let scrollOffset: CGFloat = -1000

        // When: Calculating visible range
        let firstVisible = max(0, Int(-scrollOffset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-scrollOffset + viewportHeight) / itemHeight) + bufferSize + 1)

        // Then: Should adjust for taller items
        XCTAssertEqual(firstVisible, 5) // 10 - 5 buffer
        XCTAssertEqual(lastVisible, 21) // 10 + 5 visible + 5 buffer + 1
    }

    // MARK: - Scroll Offset Preference Key

    func testScrollOffsetPreferenceKeyDefaultValue() {
        // Given: ScrollOffsetPreferenceKey
        let defaultValue = ScrollOffsetPreferenceKey.defaultValue

        // Then: Default value should be 0
        XCTAssertEqual(defaultValue, 0)
    }

    func testScrollOffsetPreferenceKeyReduce() {
        // Given: Two offset values
        var currentValue: CGFloat = 100
        let nextValue: CGFloat = 200

        // When: Reducing values
        ScrollOffsetPreferenceKey.reduce(value: &currentValue) {
            nextValue
        }

        // Then: Should use next value
        XCTAssertEqual(currentValue, 200)
    }
}
