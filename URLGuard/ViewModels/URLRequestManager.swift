import Foundation
import OrderedCollections
import os

private let logger = Logger(subsystem: "de.wfco.URLGuard", category: "Network")

actor URLRequestManager: ObservableObject {
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
    func checkURL(for item: URLItem) async -> RequestResult {
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
    
    private let redirectHeaders = [
        "Location",
        "Refresh",
    ]
    
    /// Array der HTTP-Header, die extrahiert werden sollen
    private let trackedHeaders = [
        "Content-Type",
        "Last-Modified",
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
                let transferDuration = Date().timeIntervalSince(startTime)
                continuation.resume(returning: (data, response, error, transferDuration))
            }.resume()
        }
    }
    
    private func hasModifiedData(httpResponse: HTTPURLResponse, item: URLItem) -> Bool {
        if lastResponses[item.id] == nil {
            return true
        }
        
        if httpResponse.statusCode == 304 {
            return false
        }
        
        if let currentETag = httpResponse.value(forHTTPHeaderField: "ETag"),
           let lastETag = lastETags[item.id], currentETag == lastETag {
            return false
        }
        
        return true
    }
    
    private func performHEADRequest(item: URLItem) async -> RequestResult {
        let (data, httpResponse, error, transferDuration) = await performRequest(for: item, method: "HEAD")
        
        guard let httpResponse = httpResponse as? HTTPURLResponse,
              !hasModifiedData(httpResponse: httpResponse, item: item),
              let data,
              error == nil else {
            return await performGETRequest(item: item)
        }
        
        return RequestResult(
            method: "HEAD",
            statusCode: httpResponse.statusCode,
            dataSize: data.count,
            transferDuration: transferDuration,
            headers: extractHeaders(from: httpResponse)
        )
    }
    
    private func performGETRequest(item: URLItem) async -> RequestResult {
        let (data, httpResponse, error, transferDuration) = await performRequest(for: item, method: "GET")
        
        guard let httpResponse = httpResponse as? HTTPURLResponse,
              let data,
              error == nil else {
            return RequestResult(
                method: "GET",
                statusCode: nil,
                transferDuration: transferDuration,
                errorDescription: error?.localizedDescription
            )
        }
        
        let diffInfo: DiffInfo? = {
            if hasModifiedData(httpResponse: httpResponse, item: item),
               let lastData = lastResponses[item.id],
               lastData != data,
               let lastContent = String(data: lastData, encoding: .utf8),
               let currentContent = String(data: data, encoding: .utf8) {
                return DiffInfo(from: lastContent, to: currentContent)
            }

            return nil
        }()

        lastResponses[item.id] = data
        lastETags[item.id] = httpResponse.value(forHTTPHeaderField: "ETag")
        
        return RequestResult(
            method: "HEAD",
            statusCode: httpResponse.statusCode,
            dataSize: data.count,
            transferDuration: transferDuration,
            headers: extractHeaders(from: httpResponse),
            diffInfo: diffInfo,
        )
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
