import Foundation
import OrderedCollections

struct RequestResult: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let status: URLItem.Status
    let httpStatusCode: Int?
    let httpMethod: String?
    let diffInfo: DiffInfo?
    let responseSize: Int?
    let responseTime: Double?
    let errorDescription: String?
    
    // HTTP-Header Informationen
    let headers: OrderedDictionary<String, String>? // Alle HTTP-Header als geordnetes Dictionary
    
    init(id: UUID = UUID(), date: Date, status: URLItem.Status, httpStatusCode: Int? = nil, httpMethod: String? = nil, diffInfo: DiffInfo? = nil, responseSize: Int? = nil, responseTime: Double? = nil, headers: OrderedDictionary<String, String>? = nil, errorDescription: String? = nil) {
        self.id = id
        self.date = date
        self.status = status
        self.httpStatusCode = httpStatusCode
        self.httpMethod = httpMethod
        self.diffInfo = diffInfo
        self.responseSize = responseSize
        self.responseTime = responseTime
        self.headers = headers
        self.errorDescription = errorDescription
    }
}
