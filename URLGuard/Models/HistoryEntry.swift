import Foundation

enum HistoryEntry: Codable, Equatable {
    case requestResult(id: UUID = .init(), requestResult: RequestResult, isMarked: Bool = false)
    case gap
    
    private enum CodingKeys: String, CodingKey {
        case type, id, requestResult, isMarked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "entry":
            let id = try container.decode(UUID.self, forKey: .id)
            let requestResult = try container.decode(RequestResult.self, forKey: .requestResult)
            let isMarked = try container.decode(Bool.self, forKey: .isMarked)
            self = .requestResult(id: id, requestResult: requestResult, isMarked: isMarked)
        case "gap":
            self = .gap
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown history entry type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .requestResult(let id, let requestResult, let isMarked):
            try container.encode("entry", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(requestResult, forKey: .requestResult)
            try container.encode(isMarked, forKey: .isMarked)
        case .gap:
            try container.encode("gap", forKey: .type)
        }
    }
}

extension [HistoryEntry] {
    var markedCount: Int {
        filter {
            if case .requestResult(_, _, let isMarked) = $0 { return isMarked }
            return false
        }.count
    }

    var lastRequestResult: RequestResult? {
        var requestResult: RequestResult? = nil
        let _ = self.last { entry in
            if case .requestResult(_, let result, _) = entry {
                requestResult = result
                return true
            }
            return false
        }
        return requestResult
    }
}
