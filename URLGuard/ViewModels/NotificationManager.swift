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
            } else if let error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func sendNotification(title: String, body: String, userInfo: [AnyHashable : Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Notification error: \(error)")
            }
        }
    }
    
    func notifyIfNeeded(for item: URLItem, result: RequestResult) {
        guard let notification = item.notification(for: result) else { return }

        let title = item.displayTitle
        let body: String = { () in
            switch notification {
            case .httpCode(let httpCode):
                return "HTTP status \(httpCode)"
            case .error:
                return "Fehler beim Abrufen"
            case .change:
                return "Geänderter Inhalt"
            case .success:
                return "Erfolgreich abgerufen"
            }
        }()
        
        sendNotification(title: title, body: body, userInfo: ["itemId": item.id.uuidString])
    }
}
