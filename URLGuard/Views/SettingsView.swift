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
    @AppStorage("persistHistory") private var persistHistory: Bool = false
    
    var body: some View {
        Form {
            VStack(alignment: .leading) {
                SettingsTitle("Historie")
                
                HStack {
                    Text("Maximale Länge der Historie")
                    Stepper(value: $maxHistoryEntries, in: 1...1000, step: 1) {
                        TextField("", value: $maxHistoryEntries, formatter: NumberFormatter())
                            .frame(width: 60)
                    }
                }
                
                Toggle("Historie zwischen App-Starts speichern", isOn: $persistHistory)
                    .help("Wenn aktiviert, werden alle History-Entries beim Beenden der App gespeichert und beim nächsten Start wieder geladen.")
                
                Divider()
                    .padding(.vertical, 18)

                SettingsTitle("Allgemein")
                
                Toggle("Statusbar-Icon anzeigen", isOn: $showStatusBarIcon)
            }
            .padding()
        }
        .padding()
        .frame(width: 340, height: 200)
        .onChange(of: maxHistoryEntries) { oldValue, newValue in
            if (newValue < 1 || newValue > 1000) {
                maxHistoryEntries = oldValue
            }
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
