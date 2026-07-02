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
    case copyOutput
    case replaceClipboard
}

@MainActor
final class TextCleanerModel: ObservableObject {
    @Published var input = ""
    @Published private(set) var output = ""
    @Published private(set) var status = "Paste or clean clipboard text."

    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
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
        copy(cleaned, status: "Cleaned clipboard and copied result.")
    }

    func perform(_ action: TextCleanerAction) {
        switch action {
        case .plainText:
            transform("Plain text ready.") { TextCleaner.normalizePlainText($0) }
        case .fixPDFLines:
            transform("Fixed PDF line breaks.") { TextCleaner.fixPDFLines($0) }
        case .smartClean:
            transform("Smart clean copied.") { TextCleaner.smartClean($0) }
            copyOutput()
        case .sentenceCase:
            transform("Converted to sentence case.") { TextCleaner.sentenceCase($0) }
        case .titleCase:
            transform("Converted to title case.") { TextCleaner.titleCase($0) }
        case .lowercase:
            transform("Converted to lowercase.") { $0.lowercased() }
        case .uppercase:
            transform("Converted to uppercase.") { $0.uppercased() }
        case .copyOutput:
            copyOutput()
        case .replaceClipboard:
            replaceClipboard()
        }
    }

    func isActionDisabled(_ action: TextCleanerAction) -> Bool {
        switch action {
        case .copyOutput, .replaceClipboard:
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

        copy(output, status: "Copied output.")
    }

    func replaceClipboard() {
        guard !output.isEmpty else {
            status = "Nothing to put on clipboard."
            NSSound.beep()
            return
        }

        copy(output, status: "Replaced clipboard.")
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

    private func copy(_ value: String, status: String) {
        pasteboard.clearContents()

        guard pasteboard.setString(value, forType: .string) else {
            self.status = "Could not copy text."
            NSSound.beep()
            return
        }

        self.status = status
    }
}
