// Settings: backend URL, clipboard, auto lock, master key handling.
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @State private var urlDraft = ""
    @State private var connectionState: String?

    private let clearOptions = [0, 15, 30, 60, 120]
    private let lockOptions = [0, 5, 15, 60, 480]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Settings") { store.screen = .list }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledField(label: "Backend URL") {
                        HStack(spacing: 6) {
                            TextField("http://localhost:8000", text: $urlDraft)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(applyURL)
                            Button("Apply", action: applyURL)
                                .disabled(urlDraft == settings.baseURL)
                        }
                    }
                    if let connectionState {
                        Text(connectionState)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    LabeledField(label: "Clear clipboard after") {
                        Picker("", selection: $settings.clipboardClearSeconds) {
                            ForEach(clearOptions, id: \.self) { seconds in
                                Text(seconds == 0 ? "Never" : "\(seconds) seconds").tag(seconds)
                            }
                        }
                        .labelsHidden()
                    }

                    LabeledField(label: "Lock vault after inactivity") {
                        Picker("", selection: $settings.autoLockMinutes) {
                            ForEach(lockOptions, id: \.self) { minutes in
                                Text(label(forMinutes: minutes)).tag(minutes)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: settings.autoLockMinutes) { _ in store.scheduleAutoLock() }
                    }
                    Text("Locking seals the vault in the backend – the web UI is locked as well.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Divider()

                    Toggle("Remember master key in keychain", isOn: $settings.rememberMasterKey)
                        .toggleStyle(.switch)
                    Text("The vault then unseals automatically after a backend restart. The key is stored in the macOS keychain, never on disk in plain text.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Toggle("Require Touch ID to show or copy secrets", isOn: $settings.requireBiometrics)
                        .toggleStyle(.switch)
                        .disabled(!Biometrics.isAvailable)
                    if !Biometrics.isAvailable {
                        Text("No biometrics available on this Mac.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if store.hasStoredKey {
                        Button("Forget saved master key") {
                            store.forgetStoredKey()
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                    }

                    Divider()

                    HStack {
                        Text("KeyPilot Bar").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Quit") { NSApp.terminate(nil) }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .onAppear { urlDraft = settings.baseURL }
    }

    private func label(forMinutes minutes: Int) -> String {
        switch minutes {
        case 0: return "Never (stays unlocked)"
        case 60: return "1 hour"
        case 480: return "8 hours"
        default: return "\(minutes) minutes"
        }
    }

    private func applyURL() {
        let trimmed = urlDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.baseURL = trimmed
        connectionState = "Checking…"
        Task {
            await store.refresh()
            connectionState = store.errorMessage ?? (store.sealed ? "Connected – vault is locked." : "Connected – vault is unlocked.")
        }
    }
}
