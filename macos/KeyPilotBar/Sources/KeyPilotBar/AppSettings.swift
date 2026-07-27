// User preferences, persisted in UserDefaults.
import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    /// Backend base URL. Docker/local default is the FastAPI port.
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: "baseURL") }
    }

    /// Seconds after which a copied secret is removed from the clipboard. 0 = never.
    @Published var clipboardClearSeconds: Int {
        didSet { defaults.set(clipboardClearSeconds, forKey: "clipboardClearSeconds") }
    }

    /// Minutes of inactivity after which the vault is sealed again. 0 = stay unlocked.
    @Published var autoLockMinutes: Int {
        didSet { defaults.set(autoLockMinutes, forKey: "autoLockMinutes") }
    }

    /// Store the master key in the keychain and unseal automatically.
    @Published var rememberMasterKey: Bool {
        didSet { defaults.set(rememberMasterKey, forKey: "rememberMasterKey") }
    }

    /// Ask for Touch ID before a secret is revealed or copied. Off by default.
    @Published var requireBiometrics: Bool {
        didSet { defaults.set(requireBiometrics, forKey: "requireBiometrics") }
    }

    @Published var generatorLength: Int {
        didSet { defaults.set(generatorLength, forKey: "generatorLength") }
    }

    @Published var generatorSymbols: Bool {
        didSet { defaults.set(generatorSymbols, forKey: "generatorSymbols") }
    }

    @Published var generatorDigits: Bool {
        didSet { defaults.set(generatorDigits, forKey: "generatorDigits") }
    }

    private init() {
        defaults.register(defaults: [
            "baseURL": "http://localhost:8000",
            "clipboardClearSeconds": 30,
            "autoLockMinutes": 0,
            "rememberMasterKey": true,
            "requireBiometrics": false,
            "generatorLength": 24,
            "generatorSymbols": true,
            "generatorDigits": true,
        ])
        baseURL = defaults.string(forKey: "baseURL") ?? "http://localhost:8000"
        clipboardClearSeconds = defaults.integer(forKey: "clipboardClearSeconds")
        autoLockMinutes = defaults.integer(forKey: "autoLockMinutes")
        rememberMasterKey = defaults.bool(forKey: "rememberMasterKey")
        requireBiometrics = defaults.bool(forKey: "requireBiometrics")
        generatorLength = defaults.integer(forKey: "generatorLength")
        generatorSymbols = defaults.bool(forKey: "generatorSymbols")
        generatorDigits = defaults.bool(forKey: "generatorDigits")
    }
}
