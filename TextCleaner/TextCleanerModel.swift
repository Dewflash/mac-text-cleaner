import AppKit
import Foundation

enum TextCleanerAction {
    case plainText
    case fixPDFLines
    case smartClean
    case sentenceCase
    case titleCase
    case lowercase
    case uppercase
    case markdownQuote
    case markdownBulletList
    case commaSeparatedLineList
    case markdownBold
    case markdownItalic
    case markdownInlineCode
    case chatBold
    case chatItalic
    case chatMonospace
    case chatStrikethrough
    case copyOutput
}

@MainActor
final class TextCleanerModel: ObservableObject {
    @Published var input = ""
    @Published private(set) var output = ""
    @Published private(set) var status = "Paste or clean clipboard text."
    @Published private(set) var recentOutputs: [String]

    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private let recentOutputsKey = "recentOutputs"

    init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        self.recentOutputs = defaults.stringArray(forKey: recentOutputsKey) ?? []
    }

    var canCleanClipboard: Bool {
        clipboardText?.isEmpty == false
    }

    func loadClipboardIfInputIsEmpty() {
        guard input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        loadClipboard()
    }

    func loadClipboard() {
        guard let text = clipboardText else {
            status = "Clipboard has no plain text."
            NSSound.beep()
            return
        }

        input = text
        output = text
        status = "Loaded clipboard text."
    }

    func cleanClipboard() {
        guard let text = clipboardText else {
            status = "Clipboard has no plain text."
            NSSound.beep()
            return
        }

        input = text
        let cleaned = TextCleaner.smartClean(text)
        output = cleaned
        copyCleanedOutput(cleaned, status: "Cleaned clipboard and copied result.")
    }

    func perform(_ action: TextCleanerAction) {
        switch action {
        case .plainText:
            transformAndCopy("Plain text copied.") { TextCleaner.normalizePlainText($0) }
        case .fixPDFLines:
            transformAndCopy("Fixed PDF line breaks and copied.") { TextCleaner.fixPDFLines($0) }
        case .smartClean:
            transformAndCopy("Smart clean copied.") { TextCleaner.smartClean($0) }
        case .sentenceCase:
            transformAndCopy("Sentence case copied.") { TextCleaner.sentenceCase($0) }
        case .titleCase:
            transformAndCopy("Title case copied.") { TextCleaner.titleCase($0) }
        case .lowercase:
            transformAndCopy("Lowercase copied.") { $0.lowercased() }
        case .uppercase:
            transformAndCopy("Uppercase copied.") { $0.uppercased() }
        case .markdownQuote:
            transformAndCopy("Markdown quote copied.") { TextCleaner.markdownQuote($0) }
        case .markdownBulletList:
            transformAndCopy("Markdown bullet list copied.") { TextCleaner.markdownBulletList($0) }
        case .commaSeparatedLineList:
            transformAndCopy("Comma list copied.") { TextCleaner.commaSeparatedLineList($0) }
        case .markdownBold:
            transformAndCopy("Markdown bold copied.") { TextCleaner.markdownBold($0) }
        case .markdownItalic:
            transformAndCopy("Markdown italic copied.") { TextCleaner.markdownItalic($0) }
        case .markdownInlineCode:
            transformAndCopy("Markdown code copied.") { TextCleaner.markdownInlineCode($0) }
        case .chatBold:
            transformAndCopy("Chat bold copied.") { TextCleaner.chatBold($0) }
        case .chatItalic:
            transformAndCopy("Chat italic copied.") { TextCleaner.chatItalic($0) }
        case .chatMonospace:
            transformAndCopy("Chat monospace copied.") { TextCleaner.chatMonospace($0) }
        case .chatStrikethrough:
            transformAndCopy("Chat strikethrough copied.") { TextCleaner.chatStrikethrough($0) }
        case .copyOutput:
            copyOutput()
        }
    }

    func isActionDisabled(_ action: TextCleanerAction) -> Bool {
        switch action {
        case .copyOutput:
            return output.isEmpty
        default:
            return input.isEmpty
        }
    }

    func copyOutput() {
        guard !output.isEmpty else {
            status = "Nothing to copy yet."
            NSSound.beep()
            return
        }

        _ = copy(output, status: "Copied output.")
    }

    func copyRecentOutput(_ value: String) {
        guard recentOutputs.contains(value) else {
            status = "Recent item is no longer available."
            NSSound.beep()
            return
        }

        output = value
        _ = copy(value, status: "Copied recent output.")
    }

    func clear() {
        input = ""
        output = ""
        status = "Cleared."
    }

    private var clipboardText: String? {
        pasteboard.string(forType: .string)
    }

    private func transform(_ successStatus: String, _ cleaner: (String) -> String) {
        let cleaned = cleaner(input)
        output = cleaned
        status = successStatus
    }

    private func transformAndCopy(_ successStatus: String, _ cleaner: (String) -> String) {
        transform(successStatus, cleaner)
        copyCleanedOutput(output, status: successStatus)
    }

    private func copyCleanedOutput(_ value: String, status: String) {
        if copy(value, status: status) {
            addRecentOutput(value)
        }
    }

    private func copy(_ value: String, status: String) -> Bool {
        pasteboard.clearContents()

        guard pasteboard.setString(value, forType: .string) else {
            self.status = "Could not copy text."
            NSSound.beep()
            return false
        }

        self.status = status
        return true
    }

    private func addRecentOutput(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        var updated = recentOutputs.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        recentOutputs = Array(updated.prefix(5))
        defaults.set(recentOutputs, forKey: recentOutputsKey)
    }
}
