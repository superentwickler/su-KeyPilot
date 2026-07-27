// Main screen: search field, credential list, footer actions.
import SwiftUI

struct CredentialListView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var settings: AppSettings
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.5)

            if let error = store.errorMessage {
                ErrorBanner(message: error) { store.errorMessage = nil }
                    .padding(.top, 8)
            }

            content

            Divider().opacity(0.5)
            footer
        }
        .onAppear { searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidOpen)) { _ in
            searchFocused = true
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .medium))

            TextField("Search credentials…", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .onSubmit {
                    if let credential = store.selected {
                        Task { await store.copySecret(credential) }
                    }
                }
                .onChange(of: store.query) { _ in
                    // Keep the selection on a visible row while typing.
                    if store.selected == nil || !store.filtered.contains(where: { $0.id == store.selectedID }) {
                        store.selectedID = store.filtered.first?.id
                    }
                }

            if !store.query.isEmpty {
                Button {
                    store.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            IconButton(symbol: "plus", help: "New credential", prominent: true) { store.startNew() }
            IconButton(symbol: "dice", help: "Password generator") { store.screen = .generator }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        let items = store.filtered
        if items.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: store.credentials.isEmpty ? "tray" : "magnifyingglass")
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
                Text(store.credentials.isEmpty ? "No credentials yet" : "No matches")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if store.credentials.isEmpty {
                    Button("Add your first credential") { store.startNew() }
                        .buttonStyle(.link)
                        .font(.callout)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { credential in
                            CredentialRow(credential: credential)
                                .id(credential.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onChange(of: store.selectedID) { id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text(hintText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            IconButton(symbol: "arrow.clockwise", help: "Reload") {
                Task { await store.loadCredentials() }
            }
            IconButton(symbol: "lock.fill", help: "Lock vault") {
                Task { await store.lock() }
            }
            IconButton(symbol: "gearshape", help: "Settings") { store.screen = .settings }
            IconButton(symbol: "power", help: "Quit KeyPilot Bar") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var hintText: String {
        if store.loading { return "Loading…" }
        let count = store.filtered.count
        let total = store.credentials.count
        let scope = store.query.isEmpty ? "\(total) entries" : "\(count) of \(total)"
        return "\(scope)  ·  ⏎ copy  ·  ⇧⏎ user  ·  ⌘⏎ show"
    }
}

// MARK: - Row

struct CredentialRow: View {
    let credential: Credential
    @EnvironmentObject var store: VaultStore
    @State private var hovering = false
    @State private var confirmDelete = false

    private var isSelected: Bool { store.selectedID == credential.id }
    private var isRevealed: Bool { store.revealedID == credential.id }
    private var type: CredentialType { .from(credential.type) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: type.symbol)
                    .font(.system(size: 12))
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(isSelected ? 0.22 : 0.12),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(credential.name.isEmpty ? "(no name)" : credential.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if hovering || isSelected {
                    HStack(spacing: 4) {
                        IconButton(symbol: isRevealed ? "eye.slash" : "eye", help: "Show secret (⌘⏎)") {
                            Task { await store.toggleReveal(credential) }
                        }
                        IconButton(symbol: "doc.on.doc", help: "Copy secret (⏎)", prominent: true) {
                            Task { await store.copySecret(credential) }
                        }
                    }
                }
            }

            if isRevealed, let secret = store.revealedSecret {
                Text(secret)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .lineLimit(type.isMultiline ? 8 : 3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16)
                                 : (hovering ? Color.primary.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.selectedID = credential.id }
        .contextMenu {
            Button("Copy secret") { Task { await store.copySecret(credential) } }
            Button("Copy username") { store.copyUsername(credential) }
            Button(isRevealed ? "Hide secret" : "Show secret") {
                Task { await store.toggleReveal(credential) }
            }
            Divider()
            Button("Edit…") { store.startEdit(credential) }
            Button("Delete…", role: .destructive) { confirmDelete = true }
        }
        .alert("Delete “\(credential.name)”?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await store.delete(credential) } }
        } message: {
            Text("This permanently removes the credential from the vault.")
        }
    }

    private var subtitle: String {
        [credential.username, credential.category, type.label]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
