import Cocoa
import SwiftUI
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotifications()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func setupMenuBar() {
        // Status Item erzeugen (Menüleisten-Icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)
            button.image?.isTemplate = true // passt sich Hell/Dunkelmodus an
        }
        
        // Menü erstellen
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Öffnen", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openApp() {
        // Hauptfenster wieder in den Vordergrund bringen
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Notifications auch anzeigen, wenn App im Vordergrund ist
        completionHandler([.banner])
    }
}
