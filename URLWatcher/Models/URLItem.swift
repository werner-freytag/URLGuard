import Foundation

// Struktur für die Persistierung ohne Historie
struct PersistableURLItem: Codable {
    let id: UUID
    let urlString: String
    let title: String?
    let interval: Double
    let isEnabled: Bool
    let enabledNotifications: Set<URLItem.NotificationType>
    
    init(from item: URLItem) {
        self.id = item.id
        self.urlString = item.urlString
        self.title = item.title
        self.interval = item.interval
        self.isEnabled = item.isEnabled
        self.enabledNotifications = item.enabledNotifications
    }
    
    func toURLItem() -> URLItem {
        return URLItem(
            id: id,
            urlString: urlString,
            title: title,
            interval: interval,
            isEnabled: isEnabled,
            enabledNotifications: enabledNotifications
        )
    }
}

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
    
    struct DiffInfo: Codable, Equatable {
        let totalChangedLines: Int
        let previewLines: [String] // Erste 20 Zeilen
        
        init(totalChangedLines: Int, previewLines: [String]) {
            self.totalChangedLines = totalChangedLines
            self.previewLines = previewLines
        }
    }
    
    struct HistoryEntry: Codable, Equatable {
        let date: Date
        let status: Status
        let httpStatusCode: Int?
        let diffInfo: DiffInfo? // Optimierte Diff-Informationen
        let responseSize: Int? // Größe der Response in Bytes
        let responseTime: Double? // Response-Zeit in Sekunden
        
        init(date: Date, status: Status, httpStatusCode: Int? = nil, diffInfo: DiffInfo? = nil, responseSize: Int? = nil, responseTime: Double? = nil) {
            self.date = date
            self.status = status
            self.httpStatusCode = httpStatusCode
            self.diffInfo = diffInfo
            self.responseSize = responseSize
            self.responseTime = responseTime
        }
    }
    
    var id: UUID
    var urlString: String
    var title: String? // Optionaler Titel für die Anzeige
    var interval: Double
    var isEnabled: Bool
    var pendingRequests: Int // Anzahl der wartenden Requests
    var remainingTime: Double
    
    // Computed property für isWaiting
    var isWaiting: Bool {
        return pendingRequests > 0
    }
    
    // Computed property für currentStatus
    var currentStatus: Status? {
        return history.first?.status
    }
    
    var history: [HistoryEntry]
    var enabledNotifications: Set<NotificationType> = [.error, .change]
    
    init(id: UUID = UUID(), urlString: String = "", title: String? = nil, interval: Double = 5, isEnabled: Bool = true, pendingRequests: Int = 0, remainingTime: Double = 0, history: [HistoryEntry] = [], enabledNotifications: Set<NotificationType> = [.error, .change]) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.interval = interval
        self.isEnabled = isEnabled
        self.pendingRequests = pendingRequests
        self.remainingTime = remainingTime
        self.history = history
        self.enabledNotifications = enabledNotifications
    }
}
