// Entry point. The app is an accessory (menu bar only, no Dock icon).
import AppKit

@main
enum KeyPilotBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // Invisible for an accessory app, but required: ⌘X/⌘C/⌘V/⌘A/⌘Z only
        // reach the focused text field through the main menu's key equivalents.
        app.mainMenu = MainMenu.build()
        // NSApplication.delegate is weak – keep the object alive for the app's lifetime.
        objc_setAssociatedObject(app, "KeyPilotBarDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        app.run()
    }
}
