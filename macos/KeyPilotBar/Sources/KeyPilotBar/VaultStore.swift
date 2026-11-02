// Central app state: vault status, credential list, search and all actions.
import Foundation
import Combine
import AppKit

enum Screen: Equatable {
    case unlock
    case list
    case editor
    case generator
    case settings
}

/// Optional button inside a toast, e.g. "Undo" after a password rotation.
struct ToastAction: Identifiable {
    let id = UUID()
    let label: String
    let perform: () -> Void
}

@MainActor
final class VaultStore: ObservableObject {
    @Published var screen: Screen = .list
    @Published var sealed = true

    @Published var credentials: [Credential] = [] {
        didSet { recomputeFiltered() }
    }
    @Published var query = "" {
        didSet { recomputeFiltered() }
    }
    /// Search result, recomputed only when the list or the query changes.
    /// It used to be a computed property that re-sorted on every view update.
    @Published private(set) var filtered: [Credential] = []
    @Published var selectedID: Int?

    @Published var loading = false
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published var toastAction: ToastAction?
    @Published var unlockHint: String?

    /// Secret currently shown in the list (auto-hides again).
    @Published var revealedID: Int?
    @Published var revealedSecret: String?

    /// Credential being edited; nil while creating a new one.
    @Published var editingID: Int?
    @Published var draft = CredentialDraft()

    private let settings = AppSettings.shared
    private var toastTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var autoLockTask: Task<Void, Never>?

    private var api: APIClient? {
        try? APIClient(baseURLString: settings.baseURL)
    }

    // MARK: - Search

    /// Case-insensitive match on name, username, category and type label.
    /// Prefix matches on the name rank first, then name matches, then the rest.
    private func recomputeFiltered() {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            filtered = credentials
        } else {
            filtered = credentials.compactMap { c -> (Credential, Int)? in
                let name = c.name.lowercased()
                if name.hasPrefix(q) { return (c, 0) }
                if name.contains(q) { return (c, 1) }
                if c.username.lowercased().contains(q) { return (c, 2) }
                if c.category.lowercased().contains(q) { return (c, 3) }
                if CredentialType.from(c.type).label.lowercased().contains(q) { return (c, 4) }
                if c.description.lowercased().contains(q) { return (c, 5) }
                return nil
            }
            .sorted { $0.1 == $1.1 ? $0.0.name.lowercased() < $1.0.name.lowercased() : $0.1 < $1.1 }
            .map(\.0)
        }
        // Keep the selection on a visible row.
        if selectedID == nil || !filtered.contains(where: { $0.id == selectedID }) {
            selectedID = filtered.first?.id
        }
    }

    var selected: Credential? {
        guard let selectedID else { return nil }
        return credentials.first { $0.id == selectedID }
    }

    // MARK: - Secret age

    /// When the secret was last changed, as far as we can tell. A local
    /// rotation timestamp wins over `updated_at`, which also moves on
    /// metadata-only edits. See SecretAge.swift.
    func secretChangedAt(_ credential: Credential) -> Date? {
        RotationLog.date(for: credential.id) ?? credential.updatedAtDate
    }

    func secretAgeDays(_ credential: Credential) -> Int? {
        guard let date = secretChangedAt(credential) else { return nil }
        return SecretAge.days(since: date)
    }

    /// True when a password entry is older than the configured warning threshold.
    func isStale(_ credential: Credential) -> Bool {
        let threshold = settings.passwordAgeWarningDays
        guard threshold > 0, credential.isRotatable, let days = secretAgeDays(credential) else { return false }
        return days >= threshold
    }

    // MARK: - Lifecycle

    /// Called every time the panel is opened: re-check the vault and refresh.
    func refresh() async {
        guard let api else {
            errorMessage = APIError.badBaseURL(settings.baseURL).localizedDescription
            screen = .settings
            return
        }
        do {
            let status = try await api.vaultStatus()
            sealed = status.sealed
            if status.sealed {
                autoLockTask?.cancel()
                if settings.rememberMasterKey, let stored = Keychain.read(baseURL: settings.baseURL) {
                    await unseal(masterKey: stored, remember: false, fromKeychain: true)
                    return
                }
                screen = .unlock
                unlockHint = nil
            } else {
                if screen == .unlock { screen = .list }
                await loadCredentials()
                // The vault can already be unsealed when the app starts (or after
                // the web UI unsealed it), in which case nothing had ever armed
                // the inactivity timer and the vault stayed open indefinitely.
                scheduleAutoLock()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCredentials() async {
        guard let api else { return }
        loading = true
        defer { loading = false }
        do {
            credentials = try await api.credentials()
            RotationLog.prune(keeping: Set(credentials.map(\.id)))
            errorMessage = nil
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Vault

    func unseal(masterKey: String, remember: Bool, fromKeychain: Bool = false) async {
        guard let api else { return }
        guard !masterKey.isEmpty else {
            unlockHint = "Please enter your master key."
            return
        }
        loading = true
        defer { loading = false }
        do {
            try await api.unseal(masterKey: masterKey)
            sealed = false
            unlockHint = nil
            errorMessage = nil
            if remember && settings.rememberMasterKey {
                Keychain.save(masterKey: masterKey, baseURL: settings.baseURL)
            }
            screen = .list
            await loadCredentials()
            scheduleAutoLock()
        } catch APIError.wrongMasterKey {
            screen = .unlock
            if fromKeychain {
                // Stored key no longer matches this vault – drop it and ask again.
                Keychain.delete(baseURL: settings.baseURL)
                unlockHint = "The saved master key was rejected. Please enter it again."
            } else {
                unlockHint = "Wrong master key."
            }
        } catch {
            screen = .unlock
            unlockHint = error.localizedDescription
        }
    }

    func lock() async {
        guard let api else { return }
        do {
            try await api.seal()
            sealed = true
            credentials = []
            clearRevealed()
            dismissToast()
            query = ""
            screen = .unlock
            unlockHint = nil
            autoLockTask?.cancel()
            showToast("Vault locked")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the stored key so the next unlock asks again.
    func forgetStoredKey() {
        Keychain.delete(baseURL: settings.baseURL)
        showToast("Saved master key removed")
    }

    var hasStoredKey: Bool { Keychain.hasKey(baseURL: settings.baseURL) }

    // MARK: - Copy / reveal

    func copySecret(_ credential: Credential) async {
        guard let api else { return }
        guard await confirmBiometrics(for: "copy the secret for “\(credential.name)”") else { return }
        do {
            let secret = try await api.secret(for: credential.id)
            Clipboard.copy(secret, clearAfter: settings.clipboardClearSeconds)
            let suffix = settings.clipboardClearSeconds > 0
                ? " – clears in \(settings.clipboardClearSeconds)s"
                : ""
            showToast("Copied \(CredentialType.from(credential.type).label.lowercased())\(suffix)")
            scheduleAutoLock()
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyUsername(_ credential: Credential) {
        guard !credential.username.isEmpty else {
            showToast("No username stored")
            return
        }
        Clipboard.copy(credential.username, clearAfter: 0, concealed: false)
        showToast("Copied username")
        scheduleAutoLock()
    }

    func toggleReveal(_ credential: Credential) async {
        if revealedID == credential.id {
            clearRevealed()
            return
        }
        guard let api else { return }
        guard await confirmBiometrics(for: "reveal the secret for “\(credential.name)”") else { return }
        do {
            let secret = try await api.secret(for: credential.id)
            reveal(secret, for: credential.id)
            scheduleAutoLock()
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reveal(_ secret: String, for id: Int, seconds: UInt64 = 20) {
        revealedID = id
        revealedSecret = secret
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.clearRevealed() }
        }
    }

    func clearRevealed() {
        revealTask?.cancel()
        revealedID = nil
        revealedSecret = nil
    }

    private func confirmBiometrics(for reason: String) async -> Bool {
        guard settings.requireBiometrics else { return true }
        let ok = await Biometrics.authenticate(reason: reason)
        if !ok { showToast("Authentication cancelled") }
        return ok
    }

    // MARK: - Rotation

    /// One-step password change for an existing entry: generate, store, copy.
    ///
    /// This is the fast path for "the site wants a new password". The new value
    /// is shown in the row and placed on the clipboard, and the previous one is
    /// kept in memory for the lifetime of the undo toast so a rotation can be
    /// rolled back if the site rejected the password.
    func rotatePassword(for credential: Credential) async {
        guard credential.isRotatable else {
            showToast("Only password entries can be rotated")
            return
        }
        guard await confirmBiometrics(for: "set a new password for “\(credential.name)”") else { return }

        let fresh: String
        do {
            fresh = try PasswordGenerator.generate(length: settings.generatorLength,
                                                   useDigits: settings.generatorDigits,
                                                   useSymbols: settings.generatorSymbols)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await writeSecret(fresh, to: credential)
    }

    /// Writes a password produced on the generator screen into an existing
    /// entry, so the value you looked at is the value that gets saved.
    func applyGeneratedPassword(_ password: String, to credential: Credential) async {
        guard !password.isEmpty else { return }
        guard credential.isRotatable else {
            showToast("Only password entries can be rotated")
            return
        }
        guard await confirmBiometrics(for: "set a new password for “\(credential.name)”") else { return }
        await writeSecret(password, to: credential)
        // writeSecret may have switched to the unlock screen on a sealed vault.
        if screen == .generator { screen = .list }
    }

    private func writeSecret(_ password: String, to credential: Credential) async {
        guard let api else { return }
        loading = true
        defer { loading = false }
        do {
            // Read the old secret first so the change stays undoable. A failure
            // here is not fatal; the rotation then simply has no undo.
            let previous = try? await api.secret(for: credential.id)
            _ = try await api.updateSecret(id: credential.id, secret: password)
            RotationLog.record(credentialID: credential.id)

            Clipboard.copy(password, clearAfter: settings.clipboardClearSeconds)
            reveal(password, for: credential.id)
            selectedID = credential.id
            errorMessage = nil
            scheduleAutoLock()

            let clears = settings.clipboardClearSeconds > 0
                ? " – clears in \(settings.clipboardClearSeconds)s"
                : ""
            if let previous {
                showToast("New password saved & copied\(clears)", seconds: 12,
                          action: ToastAction(label: "Undo") { [weak self] in
                              Task { await self?.restoreSecret(id: credential.id, secret: previous) }
                          })
            } else {
                showToast("New password saved & copied\(clears)", seconds: 6)
            }
            await loadCredentials()
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Writes a previous secret back after an unwanted rotation.
    func restoreSecret(id: Int, secret: String) async {
        guard let api else { return }
        dismissToast()
        do {
            _ = try await api.updateSecret(id: id, secret: secret)
            RotationLog.forget(credentialID: id)
            clearRevealed()
            Clipboard.copy(secret, clearAfter: settings.clipboardClearSeconds)
            showToast("Previous password restored & copied")
            await loadCredentials()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Editing

    func startNew() {
        editingID = nil
        draft = CredentialDraft()
        screen = .editor
    }

    func startEdit(_ credential: Credential) {
        editingID = credential.id
        draft = CredentialDraft(from: credential)
        screen = .editor
    }

    /// True while the editor holds changes that closing the panel would lose.
    var hasUnsavedDraft: Bool {
        guard screen == .editor else { return false }
        guard let id = editingID else { return !draft.isEmpty }
        guard let original = credentials.first(where: { $0.id == id }) else { return true }
        return !draft.secret.isEmpty || draft != CredentialDraft(from: original)
    }

    func saveDraft() async {
        guard let api else { return }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Please enter a name."
            return
        }
        if editingID == nil && draft.secret.isEmpty {
            errorMessage = "Please enter or generate a secret."
            return
        }
        draft.name = name
        let secretChanged = !draft.secret.isEmpty
        loading = true
        defer { loading = false }
        do {
            let saved: Credential
            if let id = editingID {
                saved = try await api.update(id: id, draft)
            } else {
                saved = try await api.create(draft)
            }
            // A secret entered by hand counts as a rotation for the age display.
            if secretChanged { RotationLog.record(credentialID: saved.id) }
            errorMessage = nil
            selectedID = saved.id
            screen = .list
            showToast(editingID == nil ? "Credential created" : "Credential updated")
            editingID = nil
            draft = CredentialDraft()
            await loadCredentials()
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ credential: Credential) async {
        guard let api else { return }
        do {
            try await api.delete(id: credential.id)
            RotationLog.forget(credentialID: credential.id)
            clearRevealed()
            showToast("Deleted “\(credential.name)”")
            await loadCredentials()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Keyboard navigation

    func moveSelection(by offset: Int) {
        let items = filtered
        guard !items.isEmpty else { return }
        guard let current = selectedID, let index = items.firstIndex(where: { $0.id == current }) else {
            selectedID = items.first?.id
            return
        }
        let next = min(max(index + offset, 0), items.count - 1)
        selectedID = items[next].id
    }

    // MARK: - Panel

    /// The panel closed: drop everything transient so the next open starts on
    /// the list with an empty search instead of resuming a stale screen.
    /// An editor with unsaved input is the one thing worth keeping.
    func panelDidClose() {
        clearRevealed()
        dismissToast()
        errorMessage = nil
        query = ""
        switch screen {
        case .unlock:
            break
        case .editor where hasUnsavedDraft:
            break
        default:
            screen = .list
        }
    }

    // MARK: - Feedback

    func showToast(_ message: String, seconds: Double = 2.5, action: ToastAction? = nil) {
        toast = message
        toastAction = action
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismissToast() }
        }
    }

    /// Clearing `toastAction` also releases the previous secret captured by an
    /// undo action, so it is not held in memory longer than the toast is shown.
    func dismissToast() {
        toastTask?.cancel()
        toast = nil
        toastAction = nil
    }

    // MARK: - Auto lock

    /// Restarts the inactivity timer that seals the vault again.
    func scheduleAutoLock() {
        autoLockTask?.cancel()
        guard !sealed else { return }
        let minutes = settings.autoLockMinutes
        guard minutes > 0 else { return }
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.lock()
        }
    }
}
