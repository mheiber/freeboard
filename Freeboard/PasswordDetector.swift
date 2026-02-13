import AppKit

struct PasswordDetector {
    /// Checks if the given text looks like a password.
    /// Criteria: no spaces, >= 5 chars, has lowercase letter, has special character.
    /// Excludes hex-only strings (likely git/hg commit hash portions).
    static func isPasswordLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains(" ") else { return false }
        guard trimmed.count >= 5 else { return false }
        guard trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil else { return false }

        let notSpecial = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "/.:-_~"))
        let specialCharacters = notSpecial.inverted
        guard trimmed.unicodeScalars.contains(where: { specialCharacters.contains($0) }) else {
            return false
        }

        if isLikelyCommitHash(trimmed) { return false }

        return true
    }

    /// Hex-only strings are likely commit hash portions.
    static func isLikelyCommitHash(_ text: String) -> Bool {
        let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return text.unicodeScalars.allSatisfy { hexChars.contains($0) }
    }

    /// Checks if the pasteboard contains Bitwarden's concealed type marker.
    static func isBitwardenContent(pasteboardTypes: [NSPasteboard.PasteboardType]?) -> Bool {
        guard let types = pasteboardTypes else { return false }
        return types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }
}
