import SwiftUI

struct URLItemInputForm: View {
    @Binding var urlString: String
    @Binding var interval: Double
    @Binding var title: String?
    @Binding var isEnabled: Bool
    @Binding var enabledNotifications: Set<URLItem.NotificationType>
    let urlError: String?
    let intervalError: String?
    let onSave: () -> Void // Callback für Return-Taste
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case url
    }
    
    init(urlString: Binding<String>, interval: Binding<Double>, title: Binding<String?>, isEnabled: Binding<Bool>, enabledNotifications: Binding<Set<URLItem.NotificationType>>, urlError: String?, intervalError: String?, onSave: @escaping () -> Void) {
        self._urlString = urlString
        self._interval = interval
        self._title = title
        self._isEnabled = isEnabled
        self._enabledNotifications = enabledNotifications
        self.urlError = urlError
        self.intervalError = intervalError
        self.onSave = onSave
    }
    
    private var titlePlaceholder: String {
        if !urlString.isEmpty && urlString != "https://" {
            // Host + letzte Pfadkomponente als Platzhalter verwenden
            let correctedURL = urlString.hasPrefix("http") ? urlString : "https://" + urlString
            
            if let url = URL(string: correctedURL), let host = url.host {
                let path = url.path
                if !path.isEmpty && path != "/" {
                    let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
                    if let lastComponent = pathComponents.last {
                        return "\(host) - \(lastComponent)"
                    }
                }
                // Nur Host falls kein Pfad
                return host
            }
            
            // Fallback: URL verwenden
            return urlString
        } else {
            return "Titel eingeben..."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // URL, Intervall und Benachrichtigungen nebeneinander
            HStack(alignment: .top, spacing: 12) {
                // URL, Titel und Intervall links untereinander
                VStack(alignment: .leading, spacing: 12) {
                    
                    
                    // Titel Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Titel (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(titlePlaceholder, text: Binding(
                            get: { title ?? "" },
                            set: { title = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // URL Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com", text: $urlString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .url)
                            .onSubmit {
                                // Validiere vor dem Speichern
                                onSave()
                            }
                        
                        // URL-Fehlermeldung mit fester Höhe
                        if let urlError = urlError {
                            Text(urlError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(height: 16, alignment: .topLeading)
                        } else {
                            // Platzhalter für konsistente Höhe
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                    
                    // Interval Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intervall (Sekunden)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("5", value: $interval, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            
                            Stepper("", value: $interval, in: 1...3600, step: 1)
                                .labelsHidden()
                        }
                        
                        // Interval-Fehlermeldung mit fester Höhe
                        if let intervalError = intervalError {
                            Text(intervalError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(height: 16, alignment: .topLeading)
                        } else {
                            // Platzhalter für konsistente Höhe
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                    
                    // isEnabled Toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Toggle("URL-Überwachung aktiviert", isOn: $isEnabled)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                }
                
                // Notification-Einstellungen rechts
                VStack(alignment: .leading, spacing: 4) {
                    Text("Benachrichtigungen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    NotificationSettingsView(
                        enabledNotifications: $enabledNotifications
                    )
                }
            }
        }
        .onAppear {
            // Fokussiere automatisch auf das URL-Feld beim Öffnen
            focusedField = .url
        }
    }
}

#Preview {
    return URLItemInputForm(
        urlString: .constant("https://example.com"),
        interval: .constant(10),
        title: .constant("Test"),
        isEnabled: .constant(true),
        enabledNotifications: .constant([]),
        urlError: nil,
        intervalError: nil,
        onSave: {}
    )
    .frame(width: 600)
}

#Preview("Invalid URL") {
    return URLItemInputForm(
        urlString: .constant("invalid-url"),
        interval: .constant(10),
        title: .constant("Test"),
        isEnabled: .constant(true),
        enabledNotifications: .constant([]),
        urlError: "Ungültige URL-Struktur",
        intervalError: nil,
        onSave: {}
    )
    .frame(width: 600)
} 
