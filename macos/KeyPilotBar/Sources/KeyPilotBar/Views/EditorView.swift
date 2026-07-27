// Create or edit a credential.
import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @State private var showSecret = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { store.editingID != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: isEditing ? "Edit credential" : "New credential") {
                store.errorMessage = nil
                store.screen = .list
            }

            if let error = store.errorMessage {
                ErrorBanner(message: error) { store.errorMessage = nil }
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledField(label: "Type") {
                        Picker("", selection: $store.draft.type) {
                            ForEach(CredentialType.allCases) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .labelsHidden()
                        .disabled(isEditing) // the backend does not allow changing the type
                    }

                    LabeledField(label: "Name") {
                        TextField("e.g. GitHub", text: $store.draft.name)
                            .textFieldStyle(.roundedBorder)
                            .focused($nameFocused)
                    }

                    LabeledField(label: "Username") {
                        TextField("optional", text: $store.draft.username)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledField(label: "Category") {
                        TextField("optional, e.g. work", text: $store.draft.category)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledField(label: secretLabel) {
                        VStack(alignment: .leading, spacing: 6) {
                            if store.draft.type.isMultiline || showSecret {
                                secretPlainField
                            } else {
                                SecureField(secretPlaceholder, text: $store.draft.secret)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(spacing: 8) {
                                if !store.draft.type.isMultiline {
                                    Button(showSecret ? "Hide" : "Show") { showSecret.toggle() }
                                        .buttonStyle(.link)
                                        .font(.caption)
                                }
                                if store.draft.type == .password {
                                    Button("Generate") {
                                        store.draft.secret = PasswordGenerator.generate(
                                            length: settings.generatorLength,
                                            useDigits: settings.generatorDigits,
                                            useSymbols: settings.generatorSymbols
                                        )
                                        showSecret = true
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                }
                                Spacer()
                            }
                        }
                    }

                    LabeledField(label: "Description") {
                        TextField("optional", text: $store.draft.description)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            Divider().opacity(0.5)

            HStack {
                if isEditing {
                    Text("Leave the secret empty to keep the current one.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    store.errorMessage = nil
                    store.screen = .list
                }
                Button(isEditing ? "Save" : "Create") {
                    Task { await store.saveDraft() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.loading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .onAppear { nameFocused = true }
    }

    private var secretLabel: String {
        switch store.draft.type {
        case .password: return "Password"
        case .sshKey:   return "Private key"
        case .apiKey:   return "API key"
        case .other:    return "Secret"
        }
    }

    private var secretPlaceholder: String {
        isEditing ? "unchanged" : "required"
    }

    private var secretPlainField: some View {
        Group {
            if store.draft.type.isMultiline {
                TextEditor(text: $store.draft.secret)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 96)
                    .padding(4)
                    .background(Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .scrollContentBackground(.hidden)
            } else {
                TextField(secretPlaceholder, text: $store.draft.secret)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
    }
}
