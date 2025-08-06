import Foundation
import OrderedCollections
import os

private let logger = Logger(subsystem: "de.wfco.URLGuard", category: "Network")

// MARK: - Response Structure

struct URLCheckResponse {
    let httpMethod: String
    let responseTime: Double
    var responseSize: Int?
    var httpStatusCode: Int?
    var headers: OrderedDictionary<String, String>?
    var diff: String?
    var status: URLItem.Status
    var error: String?

    init(httpMethod: String, responseTime: Double, responseSize: Int? = nil, httpStatusCode: Int? = nil, headers: OrderedDictionary<String, String>? = nil,  diff: String? = nil, status: URLItem.Status, error: String? = nil) {
        self.httpMethod = httpMethod
        self.responseTime = responseTime
        self.responseSize = responseSize
        self.httpStatusCode = httpStatusCode
        self.headers = headers
        self.diff = diff
        self.status = status
        self.error = error
    }
}

class URLRequestManager {
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
    // MARK: - Public Interface
    
    func checkURL(for item: URLItem) async -> URLCheckResponse {
        // Intelligente HEAD/GET-Strategie
        let hasInitialData = lastResponses[item.id] != nil
        let hasETag = lastETags[item.id] != nil
        
        if hasInitialData && hasETag {
            return await performHEADRequest(item: item)
        } else {
            return await performGETRequest(item: item)
        }
    }
    
    func resetHistory(for itemID: UUID) {
        lastResponses.removeValue(forKey: itemID)
        lastETags.removeValue(forKey: itemID)
    }
    
    // MARK: - Private Request Methods
    
    /// Gemeinsame Response-Verarbeitung für HTTP Responses
    private func processHTTPResponse(_ httpResponse: HTTPURLResponse, for item: URLItem) {
        // ETag aus Response extrahieren
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            lastETags[item.id] = etag
        }
    }
    
    private let redirectHeaders = [
        "Location",
        "Refresh",
    ]
    
    /// Array der HTTP-Header, die extrahiert werden sollen
    private let trackedHeaders = [
        "Content-Type",
        "Last-Modified",
        "ETag",
    ]
    
    /// Extrahiert wichtige HTTP-Header aus der Response
    private func extractHeaders(from httpResponse: HTTPURLResponse) -> OrderedDictionary<String, String> {
        var headers = OrderedDictionary<String, String>()
        
        for headerName in redirectHeaders {
            if let headerValue = httpResponse.value(forHTTPHeaderField: headerName) {
                headers[headerName] = headerValue
            }
        }
        
        if !headers.isEmpty {
            return headers
        }
        
        for headerName in trackedHeaders {
            if let headerValue = httpResponse.value(forHTTPHeaderField: headerName) {
                headers[headerName] = headerValue
            }
        }
        
        return headers
    }
    
    private func performRequest(for item: URLItem, method: String) async -> (Data?, URLResponse?, Error?, TimeInterval) {
        logger.debug("\(method) \(item.url)")
        
        var request = URLRequest(url: item.url)
        request.httpMethod = method
        
        // ETag aus vorherigem Request hinzufügen
        if let etag = lastETags[item.id] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let delegate = RedirectHandler()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                let responseTime = Date().timeIntervalSince(startTime)
                continuation.resume(returning: (data, response, error, responseTime))
            }.resume()
        }
    }
    
    private func hasModifiedData(httpResponse: HTTPURLResponse, item: URLItem) -> Bool {
        if httpResponse.statusCode == 304 {
            return false
        }
        
        if let currentETag = httpResponse.value(forHTTPHeaderField: "ETag"),
           let lastETag = lastETags[item.id],
           currentETag == lastETag {
            return false
        }
        
        return true
    }
    
    private func performHEADRequest(item: URLItem) async -> URLCheckResponse {
        let (data, httpResponse, error, responseTime) = await performRequest(for: item, method: "HEAD")

        guard let httpResponse = httpResponse as? HTTPURLResponse,
              !hasModifiedData(httpResponse: httpResponse, item: item),
              let data,
              error == nil else {
            return await performGETRequest(item: item)
        }

        return URLCheckResponse(
            httpMethod: "HEAD",
            responseTime: responseTime,
            responseSize: data.count,
            httpStatusCode: httpResponse.statusCode,
            headers: extractHeaders(from: httpResponse),
            status: .success,
        )
    }
    
    private func performGETRequest(item: URLItem) async -> URLCheckResponse {
        let (data, httpResponse, error, responseTime) = await performRequest(for: item, method: "GET")
        
        guard let httpResponse = httpResponse as? HTTPURLResponse,
              let data,
              error == nil else {
            return URLCheckResponse(
                httpMethod: "GET",
                responseTime: responseTime,
                status: .error,
                error: error?.localizedDescription
            )
        }
        
        var response = URLCheckResponse(
            httpMethod: "GET",
            responseTime: responseTime,
            responseSize: data.count,
            httpStatusCode: httpResponse.statusCode,
            headers: extractHeaders(from: httpResponse),
            status: .success
        )
        
        if (lastResponses[item.id] == nil) || hasModifiedData(httpResponse: httpResponse, item: item) {
            // lastResponses wird automatisch gesetzt - kein separater Flag nötig
            if let lastData = lastResponses[item.id],
               lastData != data,
               let lastContent = String(data: lastData, encoding: .utf8),
               let currentContent = String(data: data, encoding: .utf8) {
                response.diff = createIntelligentDiff(from: lastContent, to: currentContent)
                response.status = .changed
            }
        }
        
        lastResponses[item.id] = data
        lastETags[item.id] = httpResponse.value(forHTTPHeaderField: "ETag")

        return response
    }
    
    // MARK: - Helper Methods
    
    /// Erstellt einen Diff zwischen zwei Strings
    private func createDiff(from oldContent: String, to newContent: String) -> String {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)
        
        var diffLines: [String] = []
        diffLines.append("=== DIFF ===")
        diffLines.append("Alte Version: \(oldLines.count) Zeilen")
        diffLines.append("Neue Version: \(newLines.count) Zeilen")
        diffLines.append("")
        
        // Einfacher Zeilen-für-Zeilen Vergleich
        let maxLines = max(oldLines.count, newLines.count)
        
        for i in 0..<maxLines {
            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""
            
            if oldLine != newLine {
                diffLines.append("Zeile \(i + 1):")
                if !oldLine.isEmpty {
                    diffLines.append("- \(oldLine)")
                }
                if !newLine.isEmpty {
                    diffLines.append("+ \(newLine)")
                }
                diffLines.append("")
            }
        }
        
        // Zusätzliche Statistiken
        let addedLines = newLines.count - oldLines.count
        if addedLines > 0 {
            diffLines.append("📈 \(addedLines) Zeilen hinzugefügt")
        } else if addedLines < 0 {
            diffLines.append("📉 \(abs(addedLines)) Zeilen entfernt")
        }
        
        let changedLines = zip(oldLines, newLines).filter { $0 != $1 }.count
        if changedLines > 0 {
            diffLines.append("🔄 \(changedLines) Zeilen geändert")
        }
        
        return diffLines.joined(separator: "\n")
    }

    /// Erstellt einen intelligenten Diff mit begrenzter Datenmenge
    private func createIntelligentDiff(from oldContent: String, to newContent: String) -> String {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)

        var diffLines: [String] = []
        diffLines.append("=== INTELLIGENTER DIFF ===")
        diffLines.append("Alte Version: \(oldLines.count) Zeilen")
        diffLines.append("Neue Version: \(newLines.count) Zeilen")
        diffLines.append("")

        // Intelligente Zeilen-für-Zeilen Analyse mit Begrenzung
        let maxLines = max(oldLines.count, newLines.count)
        var changedLinesCount = 0
        let maxChangedLines = 20 // Maximale Anzahl zu analysierender Zeilen

        for i in 0..<maxLines {
            // Stoppe, wenn genug Unterschiede gefunden wurden
            if changedLinesCount >= maxChangedLines {
                diffLines.append("... (weitere Änderungen vorhanden)")
                break
            }

            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""

            if oldLine != newLine {
                changedLinesCount += 1
                diffLines.append("Zeile \(i + 1):")
                if !oldLine.isEmpty {
                    diffLines.append("- \(oldLine)")
                }
                if !newLine.isEmpty {
                    diffLines.append("+ \(newLine)")
                }
                diffLines.append("")
            }
        }

        // Zusätzliche Statistiken
        let addedLines = newLines.count - oldLines.count
        if addedLines > 0 {
            diffLines.append("📈 \(addedLines) Zeilen hinzugefügt")
        } else if addedLines < 0 {
            diffLines.append("📉 \(abs(addedLines)) Zeilen entfernt")
        }

        let totalChangedLines = zip(oldLines, newLines).filter { $0 != $1 }.count
        if totalChangedLines > 0 {
            diffLines.append("🔄 \(totalChangedLines) Zeilen geändert (max. \(maxChangedLines) angezeigt)")
        }

        return diffLines.joined(separator: "\n")
    }
}

private class RedirectHandler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
