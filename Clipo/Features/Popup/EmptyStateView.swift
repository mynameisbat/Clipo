import SwiftUI

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: DT.Spacing.l) {
            ZStack {
                Circle()
                    .fill(DT.Color.surfaceElevated.opacity(0.8))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(DT.Color.stroke, lineWidth: 1)
                    )

                Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DT.Color.accent)
            }

            VStack(spacing: DT.Spacing.xs) {
                Text(searchText.isEmpty ? "Clipboard is empty" : "No results")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)

                Text(searchText.isEmpty ? "Copy something to start collecting history" : "Try adjusting your filters or search terms")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DT.Color.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.xxl)
    }
}
