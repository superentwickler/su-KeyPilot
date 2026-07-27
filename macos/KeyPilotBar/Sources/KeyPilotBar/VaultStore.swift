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

@MainActor
final class VaultStore: ObservableObject {
    @Published var screen: Screen = .list
    @Published var sealed = true
    @Published var credentials: [Credential] = []
    @Published var query = ""
    @Published var selectedID: Int?

    @Published var loading = false
    @Published var errorMessage: String?
    @Published var toast: String?
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
    var filtered: [Credential] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return credentials }
        return credentials.compactMap { c -> (Credential, Int)? in
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

    var selected: Credential? {
        guard let selectedID else { return nil }
        return credentials.first { $0.id == selectedID }
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
                if settings.rememberMasterKey, let stored = Keychain.read(baseURL: settings.baseURL) {
                    await unseal(masterKey: stored, remember: false, fromKeychain: true)
                    return
                }
                screen = .unlock
                unlockHint = nil
            } else {
                if screen == .unlock { screen = .list }
                await loadCredentials()
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
            errorMessage = nil
            if selectedID == nil || !credentials.contains(where: { $0.id == selectedID }) {
                selectedID = filtered.first?.id
            }
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
            revealedID = credential.id
            revealedSecret = secret
            scheduleAutoLock()
            revealTask?.cancel()
            revealTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.clearRevealed() }
            }
        } catch APIError.sealed {
            sealed = true
            screen = .unlock
        } catch {
            errorMessage = error.localizedDescription
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
        loading = true
        defer { loading = false }
        do {
            let saved: Credential
            if let id = editingID {
                saved = try await api.update(id: id, draft)
            } else {
                saved = try await api.create(draft)
            }
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

    // MARK: - Feedback

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.toast = nil }
        }
    }

    // MARK: - Auto lock

    /// Restarts the inactivity timer that seals the vault again.
    func scheduleAutoLock() {
        autoLockTask?.cancel()
        let minutes = settings.autoLockMinutes
        guard minutes > 0 else { return }
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.lock()
        }
    }
}
