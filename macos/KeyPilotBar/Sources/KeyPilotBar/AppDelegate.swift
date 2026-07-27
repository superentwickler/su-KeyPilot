// Status bar item + panel lifecycle.
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = VaultStore()
    private var panel: PanelController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.icon(sealed: true)
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "KeyPilot"
        }

        panel = PanelController(store: store, statusItem: statusItem)

        // Keep the menu bar icon in sync with the vault state.
        store.$sealed
            .removeDuplicates()
            .sink { [weak self] sealed in
                self?.statusItem.button?.image = Self.icon(sealed: sealed)
            }
            .store(in: &cancellables)

        Task { await store.refresh() }
    }

    /// Launching the app again (Finder, Spotlight, `open -a`, Raycast, Shortcuts…)
    /// opens the panel instead of doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel.show()
        return true
    }

    private static func icon(sealed: Bool) -> NSImage? {
        let name = sealed ? "lock.fill" : "key.fill"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "KeyPilot")
        image?.isTemplate = true
        return image
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            panel.toggle()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let lockItem = NSMenuItem(title: store.sealed ? "Vault is locked" : "Lock vault",
                                  action: store.sealed ? nil : #selector(lockVault), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit KeyPilot", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore click-to-toggle behaviour
    }

    @objc private func lockVault() {
        Task { await store.lock() }
    }

    @objc private func openSettings() {
        store.screen = .settings
        panel.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
