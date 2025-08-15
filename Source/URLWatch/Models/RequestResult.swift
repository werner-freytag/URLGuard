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
    
    enum Status: Codable, Equatable {
        case `informational`
        case success(hasChanges: Bool)
        case redirection
        case transferError
        case clientError
        case serverError
    }
    
    var status: Status? {
        guard let statusCode
        else {
            return errorDescription?.isEmpty == false ? .transferError : nil
        }
        switch statusCode {
        case 100...199:
            return .informational
        case 200...299:
            return .success(hasChanges: diffInfo?.changedLines.isEmpty == false)
        case 300...399:
            return .redirection
        case 400...499:
            return .clientError
        case 500...599:
            return .serverError
        default:
            return nil
        }
    }

    var isSuccessful: Bool {
        return (100...399).contains(statusCode ?? 0)
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
