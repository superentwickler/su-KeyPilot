// Data models mirroring the KeyPilot backend API (backend/app/models/schemas.py).
import Foundation

/// Credential metadata. The secret is never part of this – it is fetched
/// on demand via `GET /credentials/{id}/secret`.
struct Credential: Identifiable, Hashable, Decodable {
    let id: Int
    let type: String
    let name: String
    let username: String
    let category: String
    let description: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, name, username, category, description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = (try? c.decode(String.self, forKey: .type)) ?? "other"
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        username = (try? c.decode(String.self, forKey: .username)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        updatedAt = (try? c.decode(String.self, forKey: .updatedAt)) ?? ""
    }
}

struct CredentialWithSecret: Decodable {
    let secret: String
}

struct VaultStatus: Decodable {
    let sealed: Bool
}

/// The four types the backend accepts for `Credential.type`.
enum CredentialType: String, CaseIterable, Identifiable {
    case password
    case sshKey = "ssh_key"
    case apiKey = "api_key"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .password: return "Password"
        case .sshKey: return "SSH key"
        case .apiKey: return "API key"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .password: return "key.fill"
        case .sshKey: return "terminal.fill"
        case .apiKey: return "curlybraces"
        case .other: return "doc.text.fill"
        }
    }

    /// Secrets of this type are usually multi-line (PEM blocks).
    var isMultiline: Bool { self == .sshKey }

    static func from(_ raw: String) -> CredentialType {
        CredentialType(rawValue: raw) ?? .other
    }
}
