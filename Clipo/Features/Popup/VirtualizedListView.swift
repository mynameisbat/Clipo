import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct VirtualizedListView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let bufferSize: Int
    let content: (Item) -> Content

    @State private var visibleRange: Range<Int> = 0..<10
    @State private var scrollOffset: CGFloat = 0

    init(
        items: [Item],
        itemHeight: CGFloat,
        bufferSize: Int = 5,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.itemHeight = itemHeight
        self.bufferSize = bufferSize
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Spacer for items above viewport
                    Color.clear.frame(height: CGFloat(visibleRange.lowerBound) * itemHeight)

                    // Render only visible items + buffer
                    ForEach(visibleItems) { item in
                        content(item)
                            .frame(height: itemHeight)
                    }

                    // Spacer for items below viewport
                    Color.clear.frame(height: CGFloat(max(0, items.count - visibleRange.upperBound)) * itemHeight)
                }
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: scrollGeometry.frame(in: .named("scroll")).origin.y
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                updateVisibleRange(offset: offset, viewportHeight: geometry.size.height)
            }
        }
    }

    private var visibleItems: ArraySlice<Item> {
        guard !items.isEmpty else { return [] }
        let safeRange = visibleRange.clamped(to: 0..<items.count)
        return items[safeRange]
    }

    private func updateVisibleRange(offset: CGFloat, viewportHeight: CGFloat) {
        guard itemHeight > 0, !items.isEmpty else { return }

        let firstVisible = max(0, Int(-offset / itemHeight) - bufferSize)
        let lastVisible = min(items.count, Int((-offset + viewportHeight) / itemHeight) + bufferSize + 1)

        let newRange = firstVisible..<lastVisible
        if newRange != visibleRange {
            visibleRange = newRange
        }
    }
}

extension Range where Bound == Int {
    func clamped(to limits: Range<Bound>) -> Range<Bound> {
        let lower = Swift.max(lowerBound, limits.lowerBound)
        let upper = Swift.min(upperBound, limits.upperBound)
        return lower..<Swift.max(lower, upper)
    }
}
