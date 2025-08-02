import SwiftUI

struct NotificationSettingsView: View {
    @Binding var enabledNotifications: Set<URLItem.NotificationType>
    
    // Häufige HTTP-Codes für den Picker
    private let commonHttpCodes = [
        200, 201, 204, 301, 302, 304, 307, 400, 401, 403, 404, 405, 408, 429, 500, 502, 503, 504
    ]
    
    // Speichere den letzten verwendeten HTTP-Code
    @State private var lastUsedHttpCode: Int
    
    init(enabledNotifications: Binding<Set<URLItem.NotificationType>>) {
        self._enabledNotifications = enabledNotifications
        
        // Initialisiere lastUsedHttpCode mit dem aktuellen HTTP-Code oder 404
        var initialHttpCode = 404
        for notification in enabledNotifications.wrappedValue {
            if case .httpCode(let code) = notification {
                initialHttpCode = code
                break
            }
        }
        self._lastUsedHttpCode = State(initialValue: initialHttpCode)
    }
    
    // Aktueller HTTP-Code aus den enabledNotifications oder der letzte verwendete
    private var currentHttpCode: Int {
        for notification in enabledNotifications {
            if case .httpCode(let code) = notification {
                return code
            }
        }
        return lastUsedHttpCode // Verwende den letzten verwendeten Code statt 404
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(URLItem.NotificationType.allCases, id: \.self) { notificationType in
                if case .httpCode = notificationType {
                    // HTTP-Code mit Picker direkt daneben
                    HStack(spacing: 0) {
                        Toggle(notificationType.displayDescription, isOn: Binding(
                            get: { enabledNotifications.contains { 
                                if case .httpCode = $0 { return true }
                                return false
                            }},
                            set: { isEnabled in
                                if isEnabled {
                                    // Entferne alle bestehenden HTTP-Code-Notifications
                                    enabledNotifications = enabledNotifications.filter { 
                                        if case .httpCode = $0 { return false }
                                        return true
                                    }
                                    // Füge neue HTTP-Code-Notification hinzu
                                    enabledNotifications.insert(.httpCode(currentHttpCode))
                                } else {
                                    // Entferne alle HTTP-Code-Notifications
                                    enabledNotifications = enabledNotifications.filter { 
                                        if case .httpCode = $0 { return false }
                                        return true
                                    }
                                }
                            }
                        ))
                        .onChange(of: enabledNotifications) { oldValue, newValue in
                            // Aktualisiere lastUsedHttpCode wenn HTTP-Code-Notification hinzugefügt wird
                            for notification in newValue {
                                if case .httpCode(let code) = notification {
                                    lastUsedHttpCode = code
                                    break
                                }
                            }
                        }
                        
                        Picker("", selection: Binding(
                            get: { currentHttpCode },
                            set: { newCode in
                                // Aktualisiere lastUsedHttpCode
                                lastUsedHttpCode = newCode
                                // Entferne alle bestehenden HTTP-Code-Notifications
                                enabledNotifications = enabledNotifications.filter { 
                                    if case .httpCode = $0 { return false }
                                    return true
                                }
                                // Füge neue HTTP-Code-Notification mit neuem Code hinzu
                                enabledNotifications.insert(.httpCode(newCode))
                            }
                        )) {
                            ForEach(commonHttpCodes, id: \.self) { code in
                                Text("\(code)").tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                        
                        Spacer()
                    }
                } else {
                    // Normale Toggle-Switches für andere Notification-Typen
                    Toggle(notificationType.displayDescription, isOn: Binding(
                        get: { enabledNotifications.contains(notificationType) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledNotifications.insert(notificationType)
                            } else {
                                enabledNotifications.remove(notificationType)
                            }
                        }
                    ))
                }
            }
        }
        .font(.body)
    }
}

extension URLItem.NotificationType {
    var displayDescription: String {
        switch self {
        case .error:
            return "Bei Fehlern"
        case .change:
            return "Bei Änderungen"
        case .success:
            return "Bei Erfolg"
        case .httpCode:
            return "Bei HTTP Code"
        }
    }
}

#Preview {
    NotificationSettingsView(
        enabledNotifications: .constant([.error, .change, .httpCode(404)])
    )
    .frame(width: 300)
} 
