// Local password generation using the system CSPRNG (SecRandomCopyBytes).
// Runs offline and allows character-set control, which the backend endpoint
// (/utils/generate-password, base64url only) does not offer.
import Foundation
import Security

enum PasswordGenerator {
    private static let lower = Array("abcdefghijkmnopqrstuvwxyz")      // no l
    private static let upper = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")       // no I, O
    private static let digits = Array("23456789")                      // no 0, 1
    private static let symbols = Array("!#$%&*+-=?@^_~")

    static func generate(length: Int, useDigits: Bool, useSymbols: Bool) -> String {
        let length = max(4, min(128, length))
        var sets: [[Character]] = [lower, upper]
        if useDigits { sets.append(digits) }
        if useSymbols { sets.append(symbols) }
        let alphabet = sets.flatMap { $0 }

        // Guarantee at least one character from every enabled set, then fill up.
        var chars = sets.map { pick(from: $0) }
        while chars.count < length { chars.append(pick(from: alphabet)) }
        shuffle(&chars)
        return String(chars.prefix(length))
    }

    /// Rough entropy in bits, for the strength hint in the UI.
    static func entropyBits(length: Int, useDigits: Bool, useSymbols: Bool) -> Int {
        var size = lower.count + upper.count
        if useDigits { size += digits.count }
        if useSymbols { size += symbols.count }
        return Int(Double(length) * log2(Double(size)))
    }

    // MARK: - CSPRNG helpers

    private static func randomIndex(below bound: Int) -> Int {
        precondition(bound > 0)
        // Rejection sampling keeps the distribution uniform.
        let limit = UInt32.max - (UInt32.max % UInt32(bound))
        while true {
            var raw: UInt32 = 0
            let status = withUnsafeMutableBytes(of: &raw) { buf in
                SecRandomCopyBytes(kSecRandomDefault, 4, buf.baseAddress!)
            }
            guard status == errSecSuccess else { return Int.random(in: 0..<bound) }
            if raw < limit { return Int(raw % UInt32(bound)) }
        }
    }

    private static func pick(from set: [Character]) -> Character {
        set[randomIndex(below: set.count)]
    }

    private static func shuffle(_ chars: inout [Character]) {
        guard chars.count > 1 else { return }
        for i in stride(from: chars.count - 1, to: 0, by: -1) {
            chars.swapAt(i, randomIndex(below: i + 1))
        }
    }
}
