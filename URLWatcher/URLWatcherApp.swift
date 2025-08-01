//
//  URLWatcherApp.swift
//  URLWatcher
//
//  Created by Freytag, Werner on 31.07.25.
//

import SwiftUI
import SwiftData

@main
struct URLWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    @State private var isButtonHovering = false

    var body: some Scene {
        Window("URL Monitor", id: "main") {
            ContentView(monitor: monitor)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: {
                            monitor.createNewItem()
                            // Das neu erstellte Item ist das letzte in der Liste
                            if let newItem = monitor.items.last {
                                editingItem = newItem
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Eintrag hinzufügen")
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(isButtonHovering ? .blue : .gray.opacity(0.55))
                            .animation(.easeInOut(duration: 0.2), value: isButtonHovering)
                            .cornerRadius(6)
                            .onHover(perform: { hovering in isButtonHovering = hovering })
                        }
                        .buttonStyle(.plain)
                        .help("Eintrag hinzufügen")
                        Spacer(minLength: 20)
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
                            // Neues Item hinzufügen
                            monitor.addItem(newItem)
                        }
                    )
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commands {
            // App beenden wenn Fenster geschlossen wird
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .toolbar) { }
        }

        Settings {
            EmptyView() // Keine extra Settings
        }
    }
}
