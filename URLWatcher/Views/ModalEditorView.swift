import SwiftUI

struct ModalEditorView: View {
    let item: URLItem
    let monitor: URLMonitor
    let isNewItem: Bool
    let onSave: ((URLItem) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    // ViewModels für URL und Interval
    @StateObject private var urlViewModel = URLInputViewModel()
    @StateObject private var intervalViewModel = IntervalInputViewModel()
    
    @State private var title: String?
    @State private var isEnabled: Bool
    @State private var enabledNotifications: Set<URLItem.NotificationType>
    
    init(item: URLItem, monitor: URLMonitor, isNewItem: Bool = false, onSave: ((URLItem) -> Void)? = nil) {
        self.item = item
        self.monitor = monitor
        self.isNewItem = isNewItem
        self.onSave = onSave
        self._title = State(initialValue: item.title)
        self._isEnabled = State(initialValue: item.isEnabled)
        self._enabledNotifications = State(initialValue: item.enabledNotifications)
    }
    
    private var isFormValid: Bool {
        return urlViewModel.error == nil && intervalViewModel.error == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNewItem ? "Neuen URL-Eintrag erstellen" : "URL-Eintrag bearbeiten")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                HStack(alignment: .top, spacing: 30) {
                    // Linke Spalte: Eingabefelder
                    VStack(alignment: .leading, spacing: 20) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Titel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Titel (optional)", text: Binding(
                                get: { title ?? "" },
                                set: { title = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // URL Input
                        URLInputView(
                            viewModel: urlViewModel,
                            onSubmit: onSubmit
                        )
                        
                        // Interval Input
                        IntervalInputView(viewModel: intervalViewModel)

                        // Enabled Toggle
                        Toggle("URL-Überwachung aktiviert", isOn: $isEnabled)

                    }
                    .frame(maxWidth: .infinity)
                    
                    // Rechte Spalte: Benachrichtigungen
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Benachrichtigungen")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        NotificationSettingsView(
                            enabledNotifications: $enabledNotifications
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            
            Divider()
            
            // Footer mit Buttons
            HStack {
                Spacer()
                
                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fertig") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(minWidth: 600)
        .background(Color.white)
        .preferredColorScheme(.light)
        .onAppear {
            // Initialisiere ViewModels mit den Item-Werten
            urlViewModel.urlString = item.url.absoluteString
            intervalViewModel.interval = item.interval
        }
    }
    
    private func validateForm() {
        urlViewModel.urlString = sanitizeURLString(urlViewModel.urlString)
        
        urlViewModel.performValidation()
        intervalViewModel.performValidation()
    }
    
    private func onSubmit() {
        validateForm()
        if isFormValid {
            if saveChanges() {
                dismiss()
            }
        }
    }
    
    private func saveChanges() -> Bool {
        // URL validieren
        let trimmedURL = urlViewModel.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isNewItem {
            // Neues Item erstellen und über Callback zurückgeben
            var newItem = item
            newItem.url = URL(string: trimmedURL)!
            newItem.title = title
            newItem.interval = intervalViewModel.interval
            newItem.isEnabled = isEnabled
            newItem.enabledNotifications = enabledNotifications
            
            onSave?(newItem)
            return true
        } else {
            // Existierendes Item bearbeiten - finde das aktuelle Item im Monitor
            if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                monitor.confirmEditingWithValues(for: currentItem, urlString: trimmedURL, title: title, interval: intervalViewModel.interval, isEnabled: isEnabled, enabledNotifications: enabledNotifications)
                return true
            } else {
                print("Fehler: Es wurde kein passendes Item im Monitor gefunden.")
                return false
            }
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10)
    return ModalEditorView(
        item: item, 
        monitor: monitor, 
        isNewItem: false,
        onSave: { _ in }
    )
} 
