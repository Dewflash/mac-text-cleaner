import Foundation

enum TextCleaner {
    static func smartClean(_ text: String) -> String {
        let normalized = normalizePlainText(text)
        let lineFixed = fixPDFLines(normalized)

        if looksMostlyUppercase(lineFixed) {
            return sentenceCase(lineFixed)
        }

        return lineFixed
    }

    static func normalizePlainText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { normalizeInlineWhitespace(String($0)) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fixPDFLines(_ text: String) -> String {
        let normalized = normalizePlainText(text)
        let lines = normalized.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var current = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                appendParagraph(current, to: &paragraphs)
                current = ""
                continue
            }

            if isListItem(trimmed) {
                appendParagraph(current, to: &paragraphs)
                current = ""
                appendListItem(trimmed, to: &paragraphs)
                continue
            }

            if current.isEmpty {
                current = trimmed
            } else if shouldJoin(previous: current, next: trimmed) {
                current = join(previous: current, next: trimmed)
            } else {
                appendParagraph(current, to: &paragraphs)
                current = trimmed
            }
        }

        appendParagraph(current, to: &paragraphs)

        return paragraphs.joined(separator: "\n\n")
    }

    static func sentenceCase(_ text: String) -> String {
        let lowercased = text.lowercased()
        var result = ""
        var shouldCapitalize = true

        for scalar in lowercased.unicodeScalars {
            let character = Character(scalar)

            if shouldCapitalize && CharacterSet.letters.contains(scalar) {
                result.append(String(character).uppercased())
                shouldCapitalize = false
            } else {
                result.append(character)
            }

            if ".!?".unicodeScalars.contains(scalar) {
                shouldCapitalize = true
            }
        }

        return result
    }

    static func titleCase(_ text: String) -> String {
        let smallWords: Set<String> = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "nor", "of", "on", "or", "per", "the", "to", "vs", "via"]
        let tokens = text.lowercased().split(separator: " ", omittingEmptySubsequences: false)

        return tokens.enumerated().map { index, token in
            let word = String(token)

            guard !word.isEmpty else {
                return word
            }

            if index > 0 && smallWords.contains(word) {
                return word
            }

            return capitalizeFirstLetter(word)
        }.joined(separator: " ")
    }

    private static func normalizeInlineWhitespace(_ line: String) -> String {
        line
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func appendParagraph(_ paragraph: String, to paragraphs: inout [String]) {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            paragraphs.append(trimmed)
        }
    }

    private static func appendListItem(_ item: String, to paragraphs: inout [String]) {
        guard let previous = paragraphs.last, previous.components(separatedBy: "\n").allSatisfy(isListItem) else {
            paragraphs.append(item)
            return
        }

        paragraphs[paragraphs.count - 1] = previous + "\n" + item
    }

    private static func shouldJoin(previous: String, next: String) -> Bool {
        guard !isListItem(previous), !isListItem(next) else {
            return false
        }

        if previous.hasSuffix("-") {
            return true
        }

        if let last = previous.last, ".!?;:".contains(last) {
            return false
        }

        return true
    }

    private static func join(previous: String, next: String) -> String {
        if previous.hasSuffix("-") {
            return String(previous.dropLast()) + next
        }

        return previous + " " + next
    }

    private static func isListItem(_ line: String) -> Bool {
        let bulletPrefixes = ["- ", "* ", "• ", "– ", "— "]

        if bulletPrefixes.contains(where: { line.hasPrefix($0) }) {
            return true
        }

        guard let first = line.first, first.isNumber else {
            return false
        }

        let prefix = line.prefix(while: { $0.isNumber })
        let remaining = line.dropFirst(prefix.count)

        return remaining.hasPrefix(". ") || remaining.hasPrefix(") ")
    }

    private static func looksMostlyUppercase(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 12 else {
            return false
        }

        let uppercase = letters.filter { CharacterSet.uppercaseLetters.contains($0) }
        return Double(uppercase.count) / Double(letters.count) > 0.72
    }

    private static func capitalizeFirstLetter(_ word: String) -> String {
        guard let first = word.first else {
            return word
        }

        return first.uppercased() + word.dropFirst()
    }
}
