import Foundation
import OrderedCollections

struct URLItem: Identifiable, Codable, Equatable {
    enum NotificationType: Codable, CaseIterable, Hashable {
        case error
        case change
        case success
        case httpCode(Int)
        
        var description: String {
            switch self {
            case .error:
                return "Bei Fehlern"
            case .change:
                return "Bei Änderungen"
            case .success:
                return "Bei Erfolg"
            case .httpCode(let code):
                return "Bei HTTP Code \(code)"
            }
        }
        
        // Für Codable
        private enum CodingKeys: String, CodingKey {
            case type, httpCode
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "error":
                self = .error
            case "change":
                self = .change
            case "success":
                self = .success
            case "httpCode":
                let code = try container.decode(Int.self, forKey: .httpCode)
                self = .httpCode(code)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown notification type")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .error:
                try container.encode("error", forKey: .type)
            case .change:
                try container.encode("change", forKey: .type)
            case .success:
                try container.encode("success", forKey: .type)
            case .httpCode(let code):
                try container.encode("httpCode", forKey: .type)
                try container.encode(code, forKey: .httpCode)
            }
        }
        
        // Für CaseIterable - statische Varianten ohne assoziierte Werte
        static var allCases: [NotificationType] {
            return [.error, .change, .success, .httpCode(404)] // 404 als Beispiel
        }
    }
        
    var id: UUID
    var url: URL
    var title: String?
    var interval: Double
    var isEnabled: Bool
    var history: [HistoryEntry]
    var enabledNotifications: Set<NotificationType>
    
    struct HistoryEntry: Codable, Equatable, Identifiable {
        let id: UUID
        let requestResult: RequestResult
        var isUnread: Bool
        var hasNotification: Bool
        
        init(id: UUID = UUID(), requestResult: RequestResult, isUnread: Bool = true, hasNotification: Bool = false) {
            self.id = id
            self.requestResult = requestResult
            self.isUnread = isUnread
            self.hasNotification = hasNotification
        }
        
        /// Markiert das Entry als gelesen
        mutating func markAsRead() {
            isUnread = false
        }
        
        /// Markiert das Entry als ungelesen
        mutating func markAsUnread() {
            isUnread = true
        }
    }
    
    init(id: UUID = UUID(), url: URL = URL(string: "https://")!, title: String? = nil, interval: Double = 10, isEnabled: Bool = true, history: [HistoryEntry] = [], enabledNotifications: Set<NotificationType> = []) {
        self.id = id
        self.url = url
        self.title = title
        self.interval = interval
        self.isEnabled = isEnabled
        self.history = history
        self.enabledNotifications = enabledNotifications
    }
    
    // MARK: - Persistierung ohne Historie
    
    /// Erstellt eine Kopie ohne Historie für die Persistierung
    var withoutHistory: URLItem {
        return URLItem(
            id: id,
            url: url,
            title: title,
            interval: interval,
            isEnabled: isEnabled,
            history: [],
            enabledNotifications: enabledNotifications
        )
    }
}

extension URLItem {
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        
        if let host = url.host {
            if !url.lastPathComponent.isEmpty {
                return "\(host) – \(url.lastPathComponent)"
            } else {
                return host
            }
        }
        
        return url.absoluteString
    }
}
