import AppKit

extension NSApplication {

    @MainActor
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        NSApp.windows.forEach { window in
            if window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

