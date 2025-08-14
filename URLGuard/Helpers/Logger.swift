import os

public enum LoggerCategory: String, CaseIterable {
    case network = "Network"
    case app = "App"
}

public struct LoggerManager {
    public static let app = Logger(subsystem: "de.wfco.URLGuard", category: "General")
    public static let network = Logger(subsystem: "de.wfco.URLGuard", category: "Network")
}
