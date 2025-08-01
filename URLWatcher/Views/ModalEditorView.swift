import SwiftUI

struct ModalEditorView: View {
    let item: URLItem
    let monitor: URLMonitor
    let isNewItem: Bool
    let onSave: ((URLItem) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var urlString: String
    @State private var title: String?
    @State private var interval: Double
    @State private var isEnabled: Bool
    @State private var enabledNotifications: Set<URLItem.NotificationType>
    @State private var urlError: String?
    @State private var intervalError: String?
    
    init(item: URLItem, monitor: URLMonitor, isNewItem: Bool = false, onSave: ((URLItem) -> Void)? = nil) {
        self.item = item
        self.monitor = monitor
        self.isNewItem = isNewItem
        self.onSave = onSave
        self._urlString = State(initialValue: item.url.absoluteString)
        self._title = State(initialValue: item.title)
        self._interval = State(initialValue: item.interval)
        self._isEnabled = State(initialValue: item.isEnabled)
        self._enabledNotifications = State(initialValue: item.enabledNotifications)
    }
    
    private var isFormValid: Bool {
        return urlError == nil && intervalError == nil && !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                VStack(spacing: 20) {
                    // Editor Content
                    URLItemInputForm(
                        urlString: $urlString,
                        interval: $interval,
                        title: $title,
                        isEnabled: $isEnabled,
                        enabledNotifications: $enabledNotifications,
                        urlError: urlError,
                        intervalError: intervalError,
                        onSave: {
                            // Bei Return-Taste: Validieren und speichern
                            validateForm()
                            if isFormValid {
                                if saveChanges() {
                                    dismiss()
                                }
                            }
                        }
                    )
                    .padding()
                }
                .padding(.vertical)
            }
            
            Divider()
            
            // Footer mit Buttons
            HStack {
                Spacer()
                
                Button("Abbrechen") {
                    // Bei neuen Items wird nichts gelöscht, da sie nicht gespeichert sind
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fertig") {
                    // Validiere und speichere
                    validateForm()
                    if saveChanges() {
                        dismiss()
                    }
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
    }
    
    private func validateForm() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // URL-Validierung
        if trimmedURL.isEmpty {
            urlError = "URL darf nicht leer sein"
        } else if let url = URL(string: trimmedURL) {
            // URL-Validierung mit Helper
            if !url.isValidForMonitoring {
                urlError = "Ungültige URL-Struktur"
            } else {
                urlError = nil
            }
            
            // Interval-Validierung
            if interval < 1 {
                intervalError = "Intervall muss mindestens 1 Sekunde betragen"
            } else {
                intervalError = nil
            }
        } else {
            urlError = "Ungültige URL-Struktur"
            // Interval-Validierung auch bei ungültiger URL
            if interval < 1 {
                intervalError = "Intervall muss mindestens 1 Sekunde betragen"
            } else {
                intervalError = nil
            }
        }
    }
    
    private func saveChanges() -> Bool {
        // Validiere vor dem Speichern
        validateForm()
        
        if !isFormValid {
            if let urlError = urlError {
                // URL-Fehler vorhanden
            }
            if let intervalError = intervalError {
                // Interval-Fehler vorhanden
            }
            return false
        }
        
        // URL validieren
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isNewItem {
            // Neues Item erstellen und über Callback zurückgeben
            var newItem = item
            newItem.url = URL(string: trimmedURL)!
            newItem.title = title
            newItem.interval = interval
            newItem.isEnabled = isEnabled
            newItem.enabledNotifications = enabledNotifications
            
            onSave?(newItem)
            return true
        } else {
            // Existierendes Item bearbeiten - finde das aktuelle Item im Monitor
            if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                monitor.confirmEditingWithValues(for: currentItem, urlString: trimmedURL, title: title, interval: interval, isEnabled: isEnabled, enabledNotifications: enabledNotifications)
                return true
            } else {
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
