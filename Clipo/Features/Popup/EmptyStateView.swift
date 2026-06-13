import SwiftUI

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: DT.Spacing.m) {
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(DT.Color.textSecondary.opacity(0.6))

            VStack(spacing: DT.Spacing.xxs) {
                Text(searchText.isEmpty ? "Clipboard is empty" : "No results")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DT.Color.textPrimary)

                Text(searchText.isEmpty ? "Copy something to start collecting" : "Try a different search term")
                    .font(.system(size: 12))
                    .foregroundColor(DT.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Spacing.xxl)
    }
}
