import Cocoa
import SwiftUI
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotifications()
        
        // AppDelegate als Delegate für Dock-Klicks registrieren
        NSApp.delegate = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // App läuft weiter, auch wenn Fenster geschlossen wird
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Wenn keine Fenster sichtbar sind, öffne das Hauptfenster
            openMainWindow()
        }
        return true
    }
    
    func openMainWindow() {
        // App in den Vordergrund bringen
        NSApp.activate(ignoringOtherApps: true)
        
        NSApp.windows.forEach { window in
            if window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func setupMenuBar() {
        // Status Item erzeugen (Menüleisten-Icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem?.button?.image = NSImage(named: "StatusbarIcon")
        
        // Menü erstellen
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Öffnen", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openApp() {
        openMainWindow()
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
