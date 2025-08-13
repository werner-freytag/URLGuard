import Cocoa
import SwiftUI
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // AppDelegate als Delegate für Dock-Klicks registrieren
        NSApp.delegate = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // App läuft weiter, auch wenn Fenster geschlossen wird
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.openMainWindow()
        }
        return true
    }
}
