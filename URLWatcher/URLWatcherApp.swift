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
                            // Erstelle ein neues Item nur für den Editor, ohne es zur Liste hinzuzufügen
                            editingItem = URLItem()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Eintrag hinzufügen")
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .foregroundColor(isButtonHovering ? .white : .primary)
                            .background(isButtonHovering ? .blue : .clear)
                            .animation(.easeInOut(duration: 0.15), value: isButtonHovering)
                            .cornerRadius(6)
                            .onHover(perform: { hovering in isButtonHovering = hovering })
                        }
                        .buttonStyle(.plain)
                        .help("Eintrag hinzufügen")
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
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .toolbar) { }
        }

        Settings {
            EmptyView() // Keine extra Settings
        }
    }
}
