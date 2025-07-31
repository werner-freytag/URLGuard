import Foundation

struct URLItem: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case success, changed, error
    }
    
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
    
    struct HistoryEntry: Codable, Equatable {
        let date: Date
        let status: Status
        let httpStatusCode: Int?
        
        init(date: Date, status: Status, httpStatusCode: Int? = nil) {
            self.date = date
            self.status = status
            self.httpStatusCode = httpStatusCode
        }
    }
    
    let id: UUID
    var urlString: String
    var interval: Double
    var isPaused: Bool
    var isCollapsed: Bool
    var isEditing: Bool
    var isWaiting: Bool
    var remainingTime: Double
    var history: [HistoryEntry]
    var currentStatus: Status? // Aktueller Status unabhängig von Historie
    var isNewItem: Bool
    var urlError: String?
    var intervalError: String?
    var isModalEditing: Bool = false
    
    // Notification-Einstellungen
    var enabledNotifications: Set<NotificationType> = [.error, .change]
    
    init(id: UUID = UUID(), urlString: String = "", interval: Double = 5, isPaused: Bool = false, isCollapsed: Bool = true, isEditing: Bool = false, isWaiting: Bool = false, remainingTime: Double = 0, history: [HistoryEntry] = [], currentStatus: Status? = nil, isNewItem: Bool = false, urlError: String? = nil, intervalError: String? = nil, isModalEditing: Bool = false, enabledNotifications: Set<NotificationType> = [.error, .change]) {
        self.id = id
        self.urlString = urlString
        self.interval = interval
        self.isPaused = isPaused
        self.isCollapsed = isCollapsed
        self.isEditing = isEditing
        self.isWaiting = isWaiting
        self.remainingTime = remainingTime
        self.history = history
        self.currentStatus = currentStatus
        self.isNewItem = isNewItem
        self.urlError = urlError
        self.intervalError = intervalError
        self.isModalEditing = isModalEditing
        self.enabledNotifications = enabledNotifications
    }
}
