import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func sendNotification(title: String, body: String, url: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // content.sound = .default  // Sound deaktiviert
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    func shouldNotify(for item: URLItem, status: URLItem.Status, httpStatusCode: Int? = nil) -> Bool {
        // Prüfe zuerst HTTP-Code-Benachrichtigung (nur bei erfolgreichen Requests)
        if let httpCode = httpStatusCode, status == .success {
            for notification in item.enabledNotifications {
                if case .httpCode(let notifyCode) = notification, httpCode == notifyCode {
                    return true
                }
            }
        }
        
        // Dann prüfe Status-basierte Benachrichtigungen
        switch status {
        case .error:
            return item.enabledNotifications.contains(.error)
        case .changed:
            return item.enabledNotifications.contains(.change)
        case .success:
            return item.enabledNotifications.contains(.success)
        }
    }
    
    func notifyIfNeeded(for item: URLItem, status: URLItem.Status, httpStatusCode: Int?) {
        guard shouldNotify(for: item, status: status, httpStatusCode: httpStatusCode) else { return }
        
        let title: String
        let body: String
        
        // Prüfe zuerst HTTP-Code-Benachrichtigung (nur bei erfolgreichen Requests)
        if let httpCode = httpStatusCode, status == .success {
            for notification in item.enabledNotifications {
                if case .httpCode(let notifyCode) = notification, httpCode == notifyCode {
                    title = "HTTP Code \(httpCode)"
                    body = "\(item.urlString) - HTTP \(httpCode) empfangen"
                    sendNotification(title: title, body: body, url: item.urlString)
                    return
                }
            }
        }
        
        // Status-basierte Benachrichtigungen
        switch status {
        case .error:
            title = "URL Fehler"
            body = "\(item.urlString) ist nicht erreichbar"
        case .changed:
            title = "URL Geändert"
            body = "\(item.urlString) hat sich geändert"
        case .success:
            title = "URL Erfolgreich"
            body = "\(item.urlString) ist erreichbar"
        }
        
        sendNotification(title: title, body: body, url: item.urlString)
    }
} 