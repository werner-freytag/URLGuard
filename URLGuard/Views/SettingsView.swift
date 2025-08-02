import SwiftUI

struct SettingsTitle : View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryEntries: Int = 200
    @AppStorage("showStatusBarIcon") private var showStatusBarIcon: Bool = true
    
    var body: some View {
        Form {
            VStack(alignment: .leading) {
                SettingsTitle("Darstellung")
                
                HStack {
                    Text("Maximale Lönge der Historie")
                    Stepper(value: $maxHistoryEntries, in: 1...999, step: 1) {
                        TextField("", value: $maxHistoryEntries, formatter: NumberFormatter())
                            .frame(width: 60)
                    }
                }

                Divider()
                    .padding(.vertical, 18)

                SettingsTitle("Allgemein")
                
                Toggle("Statusbar-Icon anzeigen", isOn: $showStatusBarIcon)
            }
            .padding()
            .frame(maxWidth: 400)        }
        .padding()
        .frame(width: 300, height: 200)
        .onChange(of: maxHistoryEntries) { oldValue, newValue in
            maxHistoryEntries = newValue.clamped(to: 1...999)
        }
        .onChange(of: showStatusBarIcon) { oldValue, newValue in
            // Benachrichtige den AppDelegate über die Änderung
            NotificationCenter.default.post(
                name: NSNotification.Name("ToggleStatusBarIcon"),
                object: nil,
                userInfo: ["show": newValue]
            )
        }
    }
}

#Preview {
    SettingsView()
}
