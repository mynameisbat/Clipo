import SwiftUI

struct FilterChipStrip: View {
    @Binding var activeFilters: Set<HistoryFilter>
    let pinboards: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DT.Spacing.xs) {
                ForEach(HistoryFilter.commonFilters) { filter in
                    chip(for: filter)
                }

                if !pinboards.isEmpty {
                    Rectangle()
                        .fill(DT.Color.stroke)
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)

                    ForEach(pinboards, id: \.self) { name in
                        chip(for: .pinboard(name))
                    }
                }

                if !activeFilters.isEmpty {
                    Button {
                        activeFilters.removeAll()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DT.Color.textSecondary)
                            .padding(.horizontal, DT.Spacing.s)
                            .padding(.vertical, 5)
                            .background(Color.clear)
                            .overlay(
                                Capsule().stroke(DT.Color.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DT.Spacing.m)
            .padding(.vertical, DT.Spacing.s)
        }
    }

    @ViewBuilder
    private func chip(for filter: HistoryFilter) -> some View {
        let isActive = activeFilters.contains(filter)
        Button {
            if isActive {
                activeFilters.remove(filter)
            } else {
                activeFilters.insert(filter)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(filter.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isActive ? DT.Color.accent : DT.Color.textSecondary)
            .padding(.horizontal, DT.Spacing.s)
            .padding(.vertical, 5)
            .background(isActive ? DT.Color.accentMuted : Color.primary.opacity(0.05))
            .overlay(
                Capsule().stroke(isActive ? DT.Color.accent.opacity(0.4) : DT.Color.stroke, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
