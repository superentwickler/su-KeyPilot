// How old is the stored secret?
//
// The backend only keeps `updated_at`, and SQLAlchemy bumps that on *any*
// change – renaming an entry would make an ancient password look fresh. So the
// bar app additionally logs locally when it rotated a secret itself and
// prefers that timestamp. Entries rotated elsewhere fall back to `updated_at`,
// which can only ever make a password look *older* than it is, never fresher.
import Foundation

enum RotationLog {
    private static let storageKey = "secretRotatedAt"
    private static var defaults: UserDefaults { .standard }

    static func record(credentialID: Int, at date: Date = Date()) {
        var map = stored()
        map[String(credentialID)] = date.timeIntervalSince1970
        defaults.set(map, forKey: storageKey)
    }

    static func date(for credentialID: Int) -> Date? {
        guard let stamp = stored()[String(credentialID)] else { return nil }
        return Date(timeIntervalSince1970: stamp)
    }

    static func forget(credentialID: Int) {
        var map = stored()
        guard map.removeValue(forKey: String(credentialID)) != nil else { return }
        defaults.set(map, forKey: storageKey)
    }

    /// Drops timestamps of credentials that no longer exist, so the log does not
    /// grow forever and a recycled id cannot inherit an old date.
    static func prune(keeping ids: Set<Int>) {
        let map = stored()
        let kept = map.filter { key, _ in
            guard let id = Int(key) else { return false }
            return ids.contains(id)
        }
        guard kept.count != map.count else { return }
        defaults.set(kept, forKey: storageKey)
    }

    private static func stored() -> [String: Double] {
        defaults.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
    }
}

// MARK: - Backend timestamps

enum BackendDate {
    /// The backend writes naive UTC timestamps (`datetime.utcnow()`), which have
    /// no timezone designator, so a strict ISO8601 parser rejects them. These
    /// formats cover that plus the variants an offset-aware backend would send.
    private static let formatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

// MARK: - Age formatting

enum SecretAge {
    static func days(since date: Date, now: Date = Date()) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0)
    }

    /// Compact form for the credential row: "today", "4d", "7mo", "2y".
    static func short(days: Int) -> String {
        switch days {
        case 0:        return "today"
        case 1:        return "1d"
        case ..<31:    return "\(days)d"
        case ..<365:   return "\(max(1, days / 30))mo"
        default:       return "\(days / 365)y"
        }
    }

    /// Long form for tooltips: "Password is 7 months old".
    static func long(days: Int) -> String {
        switch days {
        case 0:      return "changed today"
        case 1:      return "changed yesterday"
        case ..<31:  return "changed \(days) days ago"
        case ..<365:
            let months = max(1, days / 30)
            return "changed \(months) month\(months == 1 ? "" : "s") ago"
        default:
            let years = days / 365
            return "changed over \(years) year\(years == 1 ? "" : "s") ago"
        }
    }
}
