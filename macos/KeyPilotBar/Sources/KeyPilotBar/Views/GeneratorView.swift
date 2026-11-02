// Password generator. Generates locally with the system CSPRNG.
import SwiftUI

struct GeneratorView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @State private var password = ""
    @State private var failure: String?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Password generator") { store.screen = .list }

            VStack(alignment: .leading, spacing: 16) {
                Text(password)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let failure {
                    ErrorBanner(message: failure) { self.failure = nil }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Length").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(settings.generatorLength) characters · ~\(entropy) bits · \(PasswordGenerator.strengthLabel(bits: entropy))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.generatorLength) },
                            set: { settings.generatorLength = Int($0); regenerate() }
                        ),
                        in: Double(PasswordGenerator.minLength)...Double(PasswordGenerator.maxLength),
                        step: 1
                    )
                }

                HStack(spacing: 18) {
                    Toggle("Digits", isOn: Binding(
                        get: { settings.generatorDigits },
                        set: { settings.generatorDigits = $0; regenerate() }
                    ))
                    Toggle("Symbols", isOn: Binding(
                        get: { settings.generatorSymbols },
                        set: { settings.generatorSymbols = $0; regenerate() }
                    ))
                }
                .toggleStyle(.checkbox)
                .font(.callout)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ruleSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Letters exclude look-alikes (l, I, O, 0, 1).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    Button {
                        regenerate()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }

                    Button {
                        Clipboard.copy(password, clearAfter: settings.clipboardClearSeconds)
                        store.showToast("Password copied")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty)

                    Spacer()

                    Button("Use for new entry") {
                        store.startNew()
                        store.draft.secret = password
                    }
                    .disabled(password.isEmpty)
                }

                // Shortcut back into the entry you came from: writes this exact
                // password into the selected credential instead of a fresh one.
                if let target = store.selected, target.isRotatable {
                    Button {
                        Task {
                            await store.applyGeneratedPassword(password, to: target)
                        }
                    } label: {
                        Label("Save for “\(target.name)” & copy", systemImage: "arrow.triangle.2.circlepath")
                            .lineLimit(1)
                    }
                    .disabled(password.isEmpty || store.loading)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .onAppear { if password.isEmpty { regenerate() } }
    }

    private var entropy: Int {
        PasswordGenerator.entropyBits(length: settings.generatorLength,
                                      useDigits: settings.generatorDigits,
                                      useSymbols: settings.generatorSymbols)
    }

    private var ruleSummary: String {
        let names = PasswordGenerator.requiredClasses(useDigits: settings.generatorDigits,
                                                      useSymbols: settings.generatorSymbols)
            .map(\.name)
        return "Always contains at least one: " + names.joined(separator: ", ") + "."
    }

    private func regenerate() {
        do {
            password = try PasswordGenerator.generate(length: settings.generatorLength,
                                                      useDigits: settings.generatorDigits,
                                                      useSymbols: settings.generatorSymbols)
            failure = nil
        } catch {
            password = ""
            failure = error.localizedDescription
        }
    }
}
