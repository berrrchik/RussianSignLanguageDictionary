import SwiftUI

struct OfflineStatusToolbarItem: View {
    @EnvironmentObject private var appStatusViewModel: AppStatusViewModel
    @State private var isPopoverPresented = false

    var body: some View {
        if let indicatorStatus = appStatusViewModel.indicatorStatus {
            Button {
                isPopoverPresented = true
            } label: {
                Image(systemName: indicatorStatus.systemImageName)
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel(indicatorStatus.title)
            .accessibilityHint(ErrorMessageMapper.message(for: indicatorStatus))
            .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                statusPopover(for: indicatorStatus)
            }
        }
    }

    private func statusPopover(for status: OfflineIndicatorStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: status.systemImageName)
                    .foregroundStyle(.orange)
                    .imageScale(.medium)
                    .accessibilityHidden(true)
                
                Text(status.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text(ErrorMessageMapper.message(for: status))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(minWidth: 220, maxWidth: 340, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .presentationCompactAdaptation(.popover)
        .presentationSizing(.fitted)
    }
}

#if DEBUG
struct OfflineStatusToolbarItem_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            Color.clear
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        OfflineStatusToolbarItem()
                    }
                }
        }
        .environmentObject(AppStatusViewModel(
            signRepository: {
                let repository = MockSignRepository()
                repository.setDataStatus(.usingCachedData(.serverUnavailable))
                return repository
            }(),
            networkMonitor: PreviewData.networkMonitor
        ))
    }
}
#endif
