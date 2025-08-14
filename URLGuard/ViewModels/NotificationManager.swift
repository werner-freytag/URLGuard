import Foundation
import UserNotifications
import Combine
#if os(macOS)
import AppKit
#endif

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    // Combine-Publisher für Highlight-Requests (plattformübergreifend)
    let highlightRequestPublisher = PassthroughSubject<UUID, Never>()
    
    // Callback für das Öffnen des Popovers
    var onNotificationTapped: ((UUID) -> Void)?
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                LoggerManager.app.debug("Notification permission granted")
            } else if let error {
                LoggerManager.app.debug("Notification permission error: \(error)")
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
                LoggerManager.app.warning("Notification error: \(error)")
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
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Notifications auch anzeigen, wenn App im Vordergrund ist
        completionHandler([.banner])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Notification wurde angeklickt
        let userInfo = response.notification.request.content.userInfo
        
        if let itemIdString = userInfo["itemId"] as? String,
           let itemId = UUID(uuidString: itemIdString) {
            
            // Main-Fenster öffnen (nur unter macOS)
            #if os(macOS)
            DispatchQueue.main.async {
                NSApp.openMainWindow()
            }
            #endif
            
            // Item highlighten über Combine-Publisher (plattformübergreifend)
            highlightRequestPublisher.send(itemId)
        }
        
        completionHandler()
    }
}
