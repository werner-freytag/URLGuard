import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // Callback für das Öffnen des Popovers
    var onNotificationTapped: ((UUID) -> Void)?
    
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
    
    func sendNotification(title: String, body: String, userInfo: [AnyHashable : Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
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
    
    func notification(for item: URLItem, status: URLItem.Status, httpStatusCode: Int?) -> URLItem.NotificationType? {
        // Prüfe zuerst HTTP-Code-Benachrichtigung (nur bei erfolgreichen Requests)
        if let httpCode = httpStatusCode, status == .success {
            for notification in item.enabledNotifications {
                if case .httpCode(let notifyCode) = notification, httpCode == notifyCode {
                    return notification
                }
            }
        }
        
        // Dann prüfe Status-basierte Benachrichtigungen
        switch status {
        case .error:
            return item.enabledNotifications.contains(.error) ? .error : nil
        case .changed:
            return item.enabledNotifications.contains(.change) ? .change : nil
        case .success:
            return item.enabledNotifications.contains(.success) ?.success : nil
        }
    }
    
    func notifyIfNeeded(for item: URLItem, status: URLItem.Status, httpStatusCode: Int?) {
        guard let notification = notification(for: item, status: status, httpStatusCode: httpStatusCode) else { return }

        let title = item.displayTitle
        let body: String = { () in
            switch notification {
            case .httpCode(let httpCode):
                return "HTTP status \(httpCode)"
            case .error:
                return "Fehler beim Abrufen der URL"
            case .change:
                return "Inhalt der URL hat sich geändert"
            case .success:
                return "URL erfolgreich abgerufen"
            }
        }()
        
        sendNotification(title: title, body: body, userInfo: ["itemId": item.id.uuidString])
    }
}
