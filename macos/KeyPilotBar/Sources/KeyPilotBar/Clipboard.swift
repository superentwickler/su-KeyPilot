// Clipboard handling for secrets: marked as concealed, cleared after a timeout.
import AppKit

enum Clipboard {
    /// Convention respected by clipboard managers so they don't archive passwords.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private static var clearTask: Task<Void, Never>?

    /// Copies `value` and clears the pasteboard after `clearAfter` seconds (0 = keep).
    static func copy(_ value: String, clearAfter seconds: Int, concealed: Bool = true) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
        if concealed {
            pb.setString(value, forType: concealedType)
        }
        let stamp = pb.changeCount

        clearTask?.cancel()
        guard seconds > 0 else { return }
        clearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            // Only clear if nothing else was copied in the meantime.
            if NSPasteboard.general.changeCount == stamp {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
