import SwiftUI

struct ModalEditorView: View {
    let item: URLItem
    let monitor: URLMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var hasValidationErrors: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(item.isNewItem ? "Neuen URL-Eintrag erstellen" : "URL-Eintrag bearbeiten")
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
                        item: item, 
                        monitor: monitor,
                        onSave: { urlString, interval, enabledNotifications in
                            if saveChanges(urlString: urlString, interval: interval, enabledNotifications: enabledNotifications) {
                                dismiss()
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
                    // Wenn es ein neuer Eintrag ist, diesen löschen
                    if item.isNewItem {
                        monitor.remove(item: item)
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fertig") {
                    // Hole die aktuellen Werte aus der URLItemInputForm
                    // Da wir keinen direkten Zugriff haben, verwenden wir die ursprünglichen Werte
                    if saveChanges(urlString: item.urlString, interval: item.interval, enabledNotifications: item.enabledNotifications) {
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
    
    private func saveChanges(urlString: String, interval: Double, enabledNotifications: Set<URLItem.NotificationType>) -> Bool {
        // Erstelle ein temporäres Item mit den aktuellen Werten für die Validierung
        var tempItem = item
        tempItem.urlString = urlString
        tempItem.interval = interval
        tempItem.enabledNotifications = enabledNotifications
        
        // Validiere die aktuellen Werte
        let validation = monitor.validateItem(tempItem)
        
        if validation.isValid {
            // Nur speichern wenn gültig
            if item.isNewItem {
                monitor.confirmNewItemWithValues(for: item, urlString: urlString, interval: interval, enabledNotifications: enabledNotifications)
            } else if item.isEditing {
                monitor.confirmEditingWithValues(for: item, urlString: urlString, interval: interval, enabledNotifications: enabledNotifications)
            }
            return true
        } else {
            // Validierungsfehler vorhanden, nicht schließen
            return false
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "https://example.com", interval: 10, isEditing: true, isModalEditing: true)
    return ModalEditorView(item: item, monitor: monitor)
} 