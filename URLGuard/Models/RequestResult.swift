import Foundation
import OrderedCollections

struct RequestResult: Codable, Equatable {
    let date: Date
    let method: String
    let statusCode: Int?
    let dataSize: Int?
    let transferDuration: Double?
    let errorDescription: String?
    let headers: OrderedDictionary<String, String>?
    let diffInfo: DiffInfo?
    
    enum Status: String, Codable {
        case success, changed, error
    }

    /// Status wird automatisch basierend auf den RequestResult-Daten bestimmt
    var status: Status {
        // Wenn ein Fehler aufgetreten ist
        if let errorDescription, !errorDescription.isEmpty {
            return .error
        }
        
        // Wenn ein HTTP-Status-Code vorhanden ist, aber nicht im Erfolgsbereich liegt
        if let statusCode,  statusCode >= 400 {
            return .error
        }
        
        // Wenn Diff-Informationen vorhanden sind, war es eine Änderung
        if let diffInfo, diffInfo.totalChangedLines != 0 {
            return .changed
        }
        
        return .success
    }
    
    init(date: Date = Date(), method: String, statusCode: Int?, dataSize: Int? = nil, transferDuration: Double? = nil, errorDescription: String? = nil, headers: OrderedDictionary<String, String>? = nil, diffInfo: DiffInfo? = nil) {
        self.date = date
        self.method = method
        self.statusCode = statusCode
        self.dataSize = dataSize
        self.transferDuration = transferDuration
        self.errorDescription = errorDescription
        self.headers = headers
        self.diffInfo = diffInfo
    }
}
