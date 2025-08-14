import os

enum LoggerCategory {
    case network
    case app
}

let loggers: [LoggerCategory: Logger] = [
    .network: Logger(subsystem: "de.wfco.URLGuard", category: "Network"),
    .app: Logger(subsystem: "de.wfco.URLGuard", category: "App")
]
