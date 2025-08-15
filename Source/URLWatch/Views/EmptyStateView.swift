import SwiftUI

struct EmptyStateView: View {
    let icon: String?
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let content: AnyView?
    
    init(
        icon: String? = nil,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> some View = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let content {
                content
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.controlBackgroundColor)
    }
}
