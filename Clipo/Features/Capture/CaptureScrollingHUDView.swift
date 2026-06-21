import SwiftUI

struct CaptureScrollingHUDView: View {
    let capturedCount: Int
    let onStop: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                
                Text("Đang chụp cuộn: \(capturedCount) trang")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(DT.Color.textPrimary)
            }
            
            Spacer()
            
            // Stop & Stitch Button
            Button(action: onStop) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Ghép ảnh")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DT.Color.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Cancel Button
            Button(action: onCancel) {
                Text("Hủy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DT.Color.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 320, height: 44)
    }
}
