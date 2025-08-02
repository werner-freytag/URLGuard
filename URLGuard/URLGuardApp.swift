//
//  URLGuardApp.swift
//  URLGuard
//
//  Created by Freytag, Werner on 31.07.25.
//

import SwiftUI
import SwiftData

@main
struct URLGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    var body: some Scene {
        Window("URL Guard", id: "main") {
            ContentView(monitor: monitor)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // Pause/Start Button
                        Button(action: {
                            monitor.toggleGlobalPause()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: monitor.isGlobalPaused ? "play.fill" : "pause.fill")
                                Text(monitor.isGlobalPaused ? "Starten" : "Pausieren")
                            }
                            .foregroundColor(monitor.isGlobalPaused ? .white : .primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(monitor.isGlobalPaused ? Color.secondary : .clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        // Separator
                        Divider()
                            .frame(height: 20)
                        
                        Button(action: {
                            // Erstelle ein neues Item nur für den Editor, ohne es zur Liste hinzuzufügen
                            editingItem = URLItem()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Neuer Eintrag")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .toolbar(.visible, for: .windowToolbar)
                .toolbar(.automatic, for: .windowToolbar)
                .sheet(item: $editingItem) { item in
                    // Prüfe ob es ein neues Item ist (nicht in der Liste vorhanden)
                    let isNewItem = !monitor.items.contains { $0.id == item.id }
                    
                    ModalEditorView(
                        item: item, 
                        monitor: monitor, 
                        isNewItem: isNewItem,
                        onSave: { newItem in
                            if isNewItem {
                                // Neues Item hinzufügen
                                monitor.addItem(newItem)
                            }
                        }
                    )
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { 
                Button("Neuer Eintrag") {
                    editingItem = URLItem()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .windowSize) {
                Button("Fenster schließen") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Monitoring pausieren/starten") {
                    monitor.toggleGlobalPause()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("URL Guard", image: "StatusbarIcon") {
            Button("Öffnen") {
                NSApp.activate(ignoringOtherApps: true)

                NSApp.windows.forEach { window in
                    if window.canBecomeKey {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
            Divider()
            Button(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren") {
                monitor.toggleGlobalPause()
            }
            Divider()
            Button("Beenden") {
                NSApp.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
