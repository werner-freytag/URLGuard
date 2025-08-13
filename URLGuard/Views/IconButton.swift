import SwiftUI

struct IconButton: View {
    let icon: String
    let title: String?
    let color: Color
    let helpText: String?
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        icon: String,
        title: String? = nil,
        color: Color,
        helpText: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.helpText = helpText
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: title != nil ? 6 : 0) {
                Image(systemName: icon)
                if let title {
                    Text(title)
                        .frame(minWidth: 60)
                }
            }
            .foregroundColor(isDisabled ? .secondary : color)
            .padding(.horizontal, title != nil ? 12 : 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isDisabled ? Color.secondary.opacity(0.1) : color.opacity(0.1))
                    .stroke(isDisabled ? Color.secondary.opacity(0.3) : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(helpText ?? title ?? "")
    }
}
