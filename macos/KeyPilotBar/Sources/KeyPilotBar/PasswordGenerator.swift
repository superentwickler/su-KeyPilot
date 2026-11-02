// Local password generation using the system CSPRNG (SecRandomCopyBytes).
// Runs offline and allows character-set control, which the backend endpoint
// (/utils/generate-password, base64url only) does not offer.
import Foundation
import Security

enum PasswordGeneratorError: LocalizedError {
    case randomUnavailable

    var errorDescription: String? {
        switch self {
        case .randomUnavailable:
            // Deliberately fatal for this operation: falling back to a
            // non-cryptographic RNG would silently weaken every password.
            return "The system random number generator is unavailable – no password was generated."
        }
    }
}

/// One required character class.
struct CharacterClass {
    let name: String
    let characters: [Character]
}

enum PasswordGenerator {
    // Look-alikes are left out so a password can be read off the screen and
    // typed on a different device without guessing l/I/1 or O/0.
    private static let lowercase = CharacterClass(name: "lowercase", characters: Array("abcdefghijkmnopqrstuvwxyz"))  // no l
    private static let uppercase = CharacterClass(name: "uppercase", characters: Array("ABCDEFGHJKLMNPQRSTUVWXYZ"))   // no I, O
    private static let digits    = CharacterClass(name: "digit",     characters: Array("23456789"))                   // no 0, 1
    private static let symbols   = CharacterClass(name: "symbol",    characters: Array("!#$%&*+-=?@^_~"))

    static let minLength = 8
    static let maxLength = 64

    /// The classes a generated password is guaranteed to contain.
    static func requiredClasses(useDigits: Bool, useSymbols: Bool) -> [CharacterClass] {
        var classes = [lowercase, uppercase]
        if useDigits { classes.append(digits) }
        if useSymbols { classes.append(symbols) }
        return classes
    }

    /// Generates a password containing at least one character from every
    /// enabled class. Previously the final `prefix(length)` could cut the
    /// guaranteed characters off again, so short passwords sometimes missed a
    /// class and were rejected by sites that enforce the rules.
    static func generate(length: Int, useDigits: Bool, useSymbols: Bool) throws -> String {
        let classes = requiredClasses(useDigits: useDigits, useSymbols: useSymbols)
        // A password shorter than the number of required classes cannot satisfy
        // all of them, so the lower bound depends on how many are enabled.
        let target = max(max(minLength, classes.count), min(maxLength, length))
        let alphabet = classes.flatMap(\.characters)

        var chars: [Character] = []
        chars.reserveCapacity(target)
        for characterClass in classes {
            chars.append(try pick(from: characterClass.characters))
        }
        while chars.count < target {
            chars.append(try pick(from: alphabet))
        }
        // The guaranteed characters are at the front until this shuffle.
        try shuffle(&chars)
        return String(chars)
    }

    /// True when `password` really contains every enabled class. Used to assert
    /// the guarantee in tests and to label an externally pasted password.
    static func satisfiesRules(_ password: String, useDigits: Bool, useSymbols: Bool) -> Bool {
        requiredClasses(useDigits: useDigits, useSymbols: useSymbols).allSatisfy { characterClass in
            let set = Set(characterClass.characters)
            return password.contains { set.contains($0) }
        }
    }

    /// Rough entropy in bits, for the strength hint in the UI.
    static func entropyBits(length: Int, useDigits: Bool, useSymbols: Bool) -> Int {
        let size = requiredClasses(useDigits: useDigits, useSymbols: useSymbols)
            .reduce(0) { $0 + $1.characters.count }
        let effective = max(max(minLength, 2), min(maxLength, length))
        return Int(Double(effective) * log2(Double(size)))
    }

    static func strengthLabel(bits: Int) -> String {
        switch bits {
        case ..<60:   return "weak"
        case ..<80:   return "fair"
        case ..<120:  return "strong"
        default:      return "very strong"
        }
    }

    // MARK: - CSPRNG helpers

    /// Uniform in `0..<bound` via rejection sampling. Throws instead of falling
    /// back to a non-cryptographic generator.
    private static func randomIndex(below bound: Int) throws -> Int {
        precondition(bound > 0)
        guard bound > 1 else { return 0 }
        let limit = UInt32.max - (UInt32.max % UInt32(bound))
        // Rejection probability is tiny for our alphabet sizes; the cap only
        // guarantees termination.
        for _ in 0..<128 {
            var raw: UInt32 = 0
            let status = withUnsafeMutableBytes(of: &raw) { buffer in
                SecRandomCopyBytes(kSecRandomDefault, 4, buffer.baseAddress!)
            }
            guard status == errSecSuccess else { throw PasswordGeneratorError.randomUnavailable }
            if raw < limit { return Int(raw % UInt32(bound)) }
        }
        throw PasswordGeneratorError.randomUnavailable
    }

    private static func pick(from set: [Character]) throws -> Character {
        set[try randomIndex(below: set.count)]
    }

    private static func shuffle(_ chars: inout [Character]) throws {
        guard chars.count > 1 else { return }
        for i in stride(from: chars.count - 1, to: 0, by: -1) {
            chars.swapAt(i, try randomIndex(below: i + 1))
        }
    }
}
