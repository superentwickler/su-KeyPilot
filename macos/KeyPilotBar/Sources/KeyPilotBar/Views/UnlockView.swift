// Shown while the backend vault is sealed.
import SwiftUI

struct UnlockView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @State private var masterKey = ""
    @State private var remember = true
    @FocusState private var keyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 3) {
                    Text("Vault is locked").font(.headline)
                    Text("Enter your master key to unseal KeyPilot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                SecureField("Master key", text: $masterKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($keyFocused)
                    .onSubmit(unlock)
                    .frame(maxWidth: 260)

                Toggle("Remember in keychain", isOn: $remember)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Stores the master key in the macOS keychain so the vault unseals automatically.")

                Button(action: unlock) {
                    HStack(spacing: 6) {
                        if store.loading { ProgressView().controlSize(.small) }
                        Text("Unlock")
                    }
                    .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .disabled(masterKey.isEmpty || store.loading)

                if let hint = store.unlockHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 26)

            Spacer()

            HStack {
                Text(settings.baseURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                IconButton(symbol: "gearshape", help: "Settings") { store.screen = .settings }
                IconButton(symbol: "power", help: "Quit KeyPilot Bar") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .onAppear {
            remember = settings.rememberMasterKey
            keyFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidOpen)) { _ in
            keyFocused = true
        }
    }

    private func unlock() {
        let key = masterKey
        Task {
            await store.unseal(masterKey: key, remember: remember)
            if !store.sealed { masterKey = "" }
        }
    }
}
