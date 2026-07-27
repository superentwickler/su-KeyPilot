// The dropdown panel below the menu bar icon, hosting the SwiftUI interface.
import AppKit
import SwiftUI

/// Borderless panel that can still take keyboard focus (needed for the search field).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 400, height: 560)

    private let store: VaultStore
    private weak var statusItem: NSStatusItem?
    private var panel: KeyablePanel!
    private var keyMonitor: Any?

    init(store: VaultStore, statusItem: NSStatusItem) {
        self.store = store
        self.statusItem = statusItem
        super.init()
        buildPanel()
    }

    private func buildPanel() {
        // Borderless: no title bar strip that would swallow clicks on the search field.
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        panel.animationBehavior = .utilityWindow

        let root = RootView()
            .environmentObject(store)
            .environmentObject(AppSettings.shared)
            .frame(width: Self.size.width, height: Self.size.height)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = hosting
    }

    // MARK: - Show / hide

    var isOpen: Bool { panel.isVisible }

    func toggle() {
        if isOpen { close() } else { show() }
    }

    func show() {
        positionBelowStatusItem()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        NotificationCenter.default.post(name: .panelDidOpen, object: nil)
        Task { await store.refresh() }
    }

    func close() {
        removeKeyMonitor()
        store.clearRevealed()
        panel.orderOut(nil)
    }

    private func positionBelowStatusItem() {
        guard let button = statusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var x = buttonFrame.midX - Self.size.width / 2
        // Keep the panel fully on screen.
        let visible = screen.visibleFrame
        x = min(max(x, visible.minX + 8), visible.maxX - Self.size.width - 8)
        let y = buttonFrame.minY - Self.size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated { self.handle(event) } ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let escape = 53, arrowDown = 125, arrowUp = 126, returnKey = 36, keypadEnter = 76

        // Escape works on every screen.
        if Int(event.keyCode) == escape {
            switch store.screen {
            case .list:
                if !store.query.isEmpty {
                    store.query = ""
                } else if store.revealedID != nil {
                    store.clearRevealed()
                } else {
                    close()
                }
            case .unlock:
                close()
            case .editor, .generator, .settings:
                store.errorMessage = nil
                store.screen = .list
            }
            return true
        }

        // The remaining shortcuts only apply to the credential list.
        guard store.screen == .list else { return false }

        switch Int(event.keyCode) {
        case arrowDown:
            store.moveSelection(by: 1)
            return true
        case arrowUp:
            store.moveSelection(by: -1)
            return true
        case returnKey, keypadEnter:
            guard let credential = store.selected else { return false }
            if event.modifierFlags.contains(.shift) {
                store.copyUsername(credential)
            } else if event.modifierFlags.contains(.command) {
                Task { await store.toggleReveal(credential) }
            } else {
                Task {
                    await store.copySecret(credential)
                    self.close()
                }
            }
            return true
        default:
            return false
        }
    }
}

extension Notification.Name {
    /// Lets the search field regain focus whenever the panel opens.
    static let panelDidOpen = Notification.Name("KeyPilotBarPanelDidOpen")
}
