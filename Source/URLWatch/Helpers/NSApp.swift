import AppKit

extension NSApplication {
    @MainActor
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        NSApp.windows.first {
            $0.canBecomeKey && $0.identifier == NSUserInterfaceItemIdentifier("MainWindow")
        }?.makeKeyAndOrderFront(nil)
    }
}
