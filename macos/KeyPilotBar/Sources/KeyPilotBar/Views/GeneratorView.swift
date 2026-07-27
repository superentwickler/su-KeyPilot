// Password generator. Generates locally with the system CSPRNG.
import SwiftUI

struct GeneratorView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @State private var password = ""

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

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Length").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(settings.generatorLength) characters · ~\(entropy) bits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.generatorLength) },
                            set: { settings.generatorLength = Int($0); regenerate() }
                        ),
                        in: 8...64, step: 1
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

                Text("Letters exclude look-alikes (l, I, O, 0, 1).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

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

                    Spacer()

                    Button("Use for new entry") {
                        store.startNew()
                        store.draft.secret = password
                    }
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

    private func regenerate() {
        password = PasswordGenerator.generate(length: settings.generatorLength,
                                              useDigits: settings.generatorDigits,
                                              useSymbols: settings.generatorSymbols)
    }
}
