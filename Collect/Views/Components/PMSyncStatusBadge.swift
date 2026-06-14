import SwiftUI

/// Small banner reflecting `PMSyncService`'s queue state, shown across
/// PM-mode screens. Renders nothing when there's no pending work — safe to
/// place unconditionally, including for homeowner accounts.
struct PMSyncStatusBadge: View {
    @EnvironmentObject private var pmSyncService: PMSyncService

    var body: some View {
        switch pmSyncService.syncState {
        case .error(let message):
            banner(icon: "exclamationmark.icloud", text: message, tint: .red) {
                Button("Retry") { pmSyncService.forceDrain() }
                    .font(.caption.weight(.medium))
            }
        case .syncing:
            banner(icon: "icloud.and.arrow.up", text: syncingText, tint: .blue) {
                ProgressView()
                    .controlSize(.small)
            }
        case .idle:
            if pmSyncService.pendingCount > 0 {
                banner(icon: "wifi.slash", text: pendingText, tint: .orange) {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }

    private var syncingText: String {
        "Syncing \(pmSyncService.pendingCount) change\(pmSyncService.pendingCount == 1 ? "" : "s")…"
    }

    private var pendingText: String {
        "\(pmSyncService.pendingCount) change\(pmSyncService.pendingCount == 1 ? "" : "s") will sync when you're back online"
    }

    @ViewBuilder
    private func banner<Trailing: View>(
        icon: String,
        text: String,
        tint: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
    }
}
