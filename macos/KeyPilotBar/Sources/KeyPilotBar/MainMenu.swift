// The application menu.
//
// KeyPilotBar is an LSUIElement/accessory app, so this menu is never drawn.
// It still has to exist: NSApplication routes ⌘-key equivalents through
// `NSApp.mainMenu` before the key window gets the event, and the standard
// editing actions (cut/copy/paste/select all/undo) are *only* reachable that
// way. Without this menu no text field in the panel reacts to ⌘V at all,
// which made pasting a password from somewhere else impossible.
import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(titled: "KeyPilot Bar", items: appItems()))
        main.addItem(submenu(titled: "Edit", items: editItems()))
        return main
    }

    // MARK: - Sections

    private static func appItems() -> [NSMenuItem] {
        [
            item("Hide KeyPilot Bar", "hide:", "h"),
            .separator(),
            item("Quit KeyPilot Bar", "terminate:", "q"),
        ]
    }

    private static func editItems() -> [NSMenuItem] {
        [
            item("Undo", "undo:", "z"),
            item("Redo", "redo:", "z", [.command, .shift]),
            .separator(),
            item("Cut", "cut:", "x"),
            item("Copy", "copy:", "c"),
            item("Paste", "paste:", "v"),
            item("Paste and Match Style", "pasteAsPlainText:", "v", [.command, .option, .shift]),
            item("Delete", "delete:", ""),
            item("Select All", "selectAll:", "a"),
        ]
    }

    // MARK: - Builders

    private static func submenu(titled title: String, items: [NSMenuItem]) -> NSMenuItem {
        let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        holder.submenu = menu
        return holder
    }

    /// Selectors are built from strings on purpose: `copy:` and `delete:` collide
    /// with `NSObject.copy()`/`NSFileManager` overloads when written as #selector.
    /// A nil target lets AppKit walk the responder chain to the focused field.
    private static func item(_ title: String,
                             _ selector: String,
                             _ key: String,
                             _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = modifiers }
        item.target = nil
        return item
    }
}
