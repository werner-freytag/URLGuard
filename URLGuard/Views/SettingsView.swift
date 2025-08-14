import SwiftUI

struct SettingsTitle : View {
    let title: LocalizedStringKey
    
    init(_ title: LocalizedStringKey) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryEntries: Int = 100
    @AppStorage("showStatusBarIcon") private var showStatusBarIcon: Bool = true
    @AppStorage("persistHistory") private var persistHistory: Bool = true
    
    // Temporärer Wert, damit Eingaben nicht schon während der Eingabe übernommen werden
    @State private var tempMaxHistoryEntries: String = ""
    @FocusState private var isMaxHistoryEntriesFocused: Bool
    
    // MARK: - Helper Functions
    
    private func validateAndUpdateMaxHistoryEntries() {
        if let newValue = Int(tempMaxHistoryEntries) {
            if newValue < 0 {
                tempMaxHistoryEntries = "0"
            } else if newValue > 999 {
                tempMaxHistoryEntries = "999"
            } else {
                maxHistoryEntries = newValue
            }
        } else {
            tempMaxHistoryEntries = "\(maxHistoryEntries)"
        }
    }
    
    var body: some View {
        Form {
            VStack(alignment: .leading) {
                SettingsTitle("History")
                
                HStack {
                    Text("Maximum length of history")
                    Stepper(value: $maxHistoryEntries, in: 1...999, step: 1) {
                        TextField("", text: $tempMaxHistoryEntries)
                            .frame(width: 60)
                            .focused($isMaxHistoryEntriesFocused)
                            .onAppear {
                                tempMaxHistoryEntries = "\(maxHistoryEntries)"
                            }
                            .onSubmit {
                                validateAndUpdateMaxHistoryEntries()
                            }
                            .onChange(of: tempMaxHistoryEntries) { _, newValue in
                                // Nur Zahlen erlauben und auf 3 Zeichen begrenzen (für Werte bis 999)
                                let numbersOnly = newValue.filter { $0.isNumber }
                                if numbersOnly.count <= 3 {
                                    tempMaxHistoryEntries = numbersOnly
                                }
                            }
                            .onChange(of: isMaxHistoryEntriesFocused) { _, isFocused in
                                // onBlur: Wenn das Feld den Fokus verliert, den Wert übernehmen
                                if !isFocused {
                                    validateAndUpdateMaxHistoryEntries()
                                }
                            }
                            .onDisappear {
                                // Beim Schließen des Fensters den Wert übernehmen
                                validateAndUpdateMaxHistoryEntries()
                            }
                    }
                }
                
                Toggle("Save history between app launches", isOn: $persistHistory)
                    .help("When enabled, all history entries are saved when the app is closed and reloaded the next time it is started.")
                
                Divider()
                    .padding(.vertical, 18)

                SettingsTitle("General")
                
                Toggle("Show status bar icon", isOn: $showStatusBarIcon)
            }
            .padding()
        }
        .padding()
        .frame(width: 340, height: 200)
        .onChange(of: maxHistoryEntries) { oldValue, newValue in
            if (newValue < 0 || newValue >= 1000) {
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
