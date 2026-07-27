// Thin async wrapper around the KeyPilot REST API.
import Foundation

enum APIError: LocalizedError {
    case badBaseURL(String)
    case sealed
    case wrongMasterKey
    case http(status: Int, detail: String)
    case offline(String)

    var errorDescription: String? {
        switch self {
        case .badBaseURL(let s): return "Invalid backend URL: \(s)"
        case .sealed: return "Vault is sealed."
        case .wrongMasterKey: return "Wrong master key."
        case .http(let status, let detail):
            return detail.isEmpty ? "Request failed (HTTP \(status))" : detail
        case .offline(let msg): return "Backend not reachable – \(msg)"
        }
    }
}

struct APIClient {
    let baseURL: URL

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 15
        cfg.httpShouldSetCookies = false
        cfg.urlCache = nil
        return URLSession(configuration: cfg)
    }()

    init(baseURLString: String) throws {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed),
              url.scheme != nil, url.host != nil else {
            throw APIError.badBaseURL(baseURLString)
        }
        self.baseURL = url
    }

    // MARK: - Vault

    func vaultStatus() async throws -> VaultStatus {
        try await send("GET", "/vault/status", decode: VaultStatus.self)
    }

    /// Unseals the vault. On first ever start this *sets* the master key.
    func unseal(masterKey: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["master_key": masterKey])
        _ = try await sendRaw("POST", "/vault/unseal", body: body)
    }

    func seal() async throws {
        _ = try await sendRaw("POST", "/vault/seal")
    }

    // MARK: - Credentials

    func credentials() async throws -> [Credential] {
        try await send("GET", "/credentials", decode: [Credential].self)
    }

    func secret(for id: Int) async throws -> String {
        try await send("GET", "/credentials/\(id)/secret", decode: CredentialWithSecret.self).secret
    }

    func create(_ draft: CredentialDraft) async throws -> Credential {
        try await send("POST", "/credentials", body: draft.createPayload(), decode: Credential.self)
    }

    func update(id: Int, _ draft: CredentialDraft) async throws -> Credential {
        try await send("PATCH", "/credentials/\(id)", body: draft.updatePayload(), decode: Credential.self)
    }

    func delete(id: Int) async throws {
        _ = try await sendRaw("DELETE", "/credentials/\(id)")
    }

    // MARK: - Transport

    private func send<T: Decodable>(_ method: String, _ path: String,
                                    body: [String: Any]? = nil,
                                    decode: T.Type) async throws -> T {
        var payload: Data?
        if let body { payload = try JSONSerialization.data(withJSONObject: body) }
        let data = try await sendRaw(method, path, body: payload)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.http(status: 200, detail: "Unexpected response from backend.")
        }
    }

    @discardableResult
    private func sendRaw(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw APIError.badBaseURL(baseURL.absoluteString)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: req)
        } catch {
            throw APIError.offline((error as NSError).localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.offline("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = Self.detail(from: data)
            switch http.statusCode {
            case 503 where detail.localizedCaseInsensitiveContains("sealed"): throw APIError.sealed
            case 403: throw APIError.wrongMasterKey
            default: throw APIError.http(status: http.statusCode, detail: detail)
            }
        }
        return data
    }

    /// FastAPI returns `{"detail": "..."}` or `{"detail":[{"msg": "..."}]}`.
    private static func detail(from data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let s = obj["detail"] as? String { return s }
        if let arr = obj["detail"] as? [[String: Any]], let msg = arr.first?["msg"] as? String { return msg }
        return ""
    }
}

/// Values used when creating or editing a credential.
struct CredentialDraft {
    var type: CredentialType = .password
    var name: String = ""
    var username: String = ""
    var category: String = ""
    var description: String = ""
    var secret: String = ""

    init() {}

    init(from c: Credential) {
        type = .from(c.type)
        name = c.name
        username = c.username
        category = c.category
        description = c.description
    }

    func createPayload() -> [String: Any] {
        ["type": type.rawValue, "name": name, "username": username,
         "category": category, "description": description, "secret": secret]
    }

    /// PATCH only sends the secret when a new one was entered (empty = keep current).
    func updatePayload() -> [String: Any] {
        var p: [String: Any] = ["name": name, "username": username,
                                "category": category, "description": description]
        if !secret.isEmpty { p["secret"] = secret }
        return p
    }
}
