import AppKit
import Foundation

// Minimal dependency-free test runner. Compiled together with the app sources
// by `make verify`; exits 0 when every expectation passes, 1 otherwise.

var failures: [String] = []
var passCount = 0

func expectEqual(_ actual: String, _ expected: String, _ name: String) {
    if actual == expected {
        passCount += 1
    } else {
        failures.append("\(name)\n  expected: \(expected.debugDescription)\n  actual:   \(actual.debugDescription)")
    }
}

func expectTrue(_ condition: Bool, _ name: String) {
    if condition {
        passCount += 1
    } else {
        failures.append("\(name)\n  expected true, got false")
    }
}

func runTransformTests() {
    // normalizePlainText
    expectEqual(TextCleaner.normalizePlainText("a\r\nb\rc"), "a\nb\nc", "normalizePlainText converts CRLF and CR to LF")
    expectEqual(TextCleaner.normalizePlainText("a\u{00A0}b"), "a b", "normalizePlainText replaces non-breaking spaces")
    expectEqual(TextCleaner.normalizePlainText("  hello \t  world  "), "hello world", "normalizePlainText collapses inline whitespace and trims")
    expectEqual(TextCleaner.normalizePlainText("line1  \n\n  line2"), "line1\n\nline2", "normalizePlainText keeps blank lines")

    // fixPDFLines
    expectEqual(TextCleaner.fixPDFLines("This is a\nwrapped sentence."), "This is a wrapped sentence.", "fixPDFLines joins wrapped lines")
    expectEqual(TextCleaner.fixPDFLines("Para one.\n\nPara two."), "Para one.\n\nPara two.", "fixPDFLines keeps paragraph breaks")
    expectEqual(TextCleaner.fixPDFLines("hyphen-\nated word"), "hyphenated word", "fixPDFLines rejoins hyphenated line breaks")
    expectEqual(TextCleaner.fixPDFLines("Ends with period.\nNew sentence starts"), "Ends with period.\n\nNew sentence starts", "fixPDFLines breaks after sentence punctuation")
    expectEqual(TextCleaner.fixPDFLines("- item one\n- item two"), "- item one\n- item two", "fixPDFLines keeps bullet items on separate lines")
    expectEqual(TextCleaner.fixPDFLines("1. first\n2. second"), "1. first\n2. second", "fixPDFLines keeps numbered items on separate lines")
    expectEqual(TextCleaner.fixPDFLines("Intro line\n- First item.\n- Second item.\nOutro text here"), "Intro line\n\n- First item.\n- Second item.\n\nOutro text here", "fixPDFLines separates lists from surrounding paragraphs")

    // smartClean
    expectEqual(TextCleaner.smartClean("THIS IS ALL UPPERCASE TEXT. SECOND SENTENCE HERE."), "This is all uppercase text. Second sentence here.", "smartClean sentence-cases mostly-uppercase text")
    expectEqual(TextCleaner.smartClean("Normal mixed case text stays as it is written."), "Normal mixed case text stays as it is written.", "smartClean leaves normal text alone")

    // sentenceCase
    expectEqual(TextCleaner.sentenceCase("hello there. how are you? fine!"), "Hello there. How are you? Fine!", "sentenceCase capitalizes after . ? !")
    expectEqual(TextCleaner.sentenceCase("WHAT IS THIS"), "What is this", "sentenceCase lowercases the rest")

    // titleCase
    expectEqual(TextCleaner.titleCase("the quick brown fox and the lazy dog"), "The Quick Brown Fox and the Lazy Dog", "titleCase keeps small words lowercase")
    expectEqual(TextCleaner.titleCase("a tale of two cities"), "A Tale of Two Cities", "titleCase capitalizes the first word")

    // markdown
    expectEqual(TextCleaner.markdownQuote("line one\n\nline two"), "> line one\n>\n> line two", "markdownQuote prefixes every line")
    expectEqual(TextCleaner.markdownBulletList("apple\nbanana\n\ncherry"), "- apple\n- banana\n- cherry", "markdownBulletList bullets non-empty lines")
    expectEqual(TextCleaner.commaSeparatedLineList("apple\nbanana\ncherry"), "apple, banana, cherry", "commaSeparatedLineList joins lines with commas")
    expectEqual(TextCleaner.markdownBold("hello\nworld"), "**hello**\n**world**", "markdownBold wraps each line")
    expectEqual(TextCleaner.markdownItalic("hello"), "*hello*", "markdownItalic wraps each line")
    expectEqual(TextCleaner.markdownInlineCode("let x = 1"), "`let x = 1`", "markdownInlineCode wraps in backticks")
    expectEqual(TextCleaner.markdownInlineCode("use `git` here"), "`` use `git` here ``", "markdownInlineCode escapes embedded backticks")

    // chat
    expectEqual(TextCleaner.chatBold("hi there"), "*hi there*", "chatBold uses single asterisks")
    expectEqual(TextCleaner.chatItalic("hi there"), "_hi there_", "chatItalic uses underscores")
    expectEqual(TextCleaner.chatMonospace("hi there"), "`hi there`", "chatMonospace uses backticks")
    expectEqual(TextCleaner.chatStrikethrough("hi there"), "~hi there~", "chatStrikethrough uses tildes")
}

@MainActor
func runModelTests() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.dewflash.TextCleaner.tests"))
    let suiteName = "com.dewflash.TextCleaner.tests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    func freshModel() -> TextCleanerModel {
        TextCleanerModel(pasteboard: pasteboard, defaults: defaults)
    }

    // loadClipboard reads the injected pasteboard
    pasteboard.clearContents()
    pasteboard.setString("  spaced   input  ", forType: .string)
    let model = freshModel()
    model.loadClipboard()
    expectEqual(model.input, "  spaced   input  ", "loadClipboard copies pasteboard text into input")

    // perform(.plainText) cleans, publishes output, and writes it back to the pasteboard
    model.perform(.plainText)
    expectEqual(model.output, "spaced input", "perform(.plainText) normalizes input")
    expectEqual(pasteboard.string(forType: .string) ?? "", "spaced input", "perform(.plainText) copies output to pasteboard")
    expectEqual(model.recentOutputs.first ?? "", "spaced input", "cleaned output lands at the front of recents")

    // cleanClipboard runs smartClean on pasteboard content
    pasteboard.clearContents()
    pasteboard.setString("SHOUTED CLIPBOARD TEXT. SECOND SENTENCE HERE.", forType: .string)
    model.cleanClipboard()
    expectEqual(pasteboard.string(forType: .string) ?? "", "Shouted clipboard text. Second sentence here.", "cleanClipboard smart-cleans and copies back")

    // recents: dedupe and cap at 5, newest first
    let capModel = freshModel()
    for index in 1...6 {
        capModel.input = "recent item \(index)"
        capModel.perform(.plainText)
    }
    expectTrue(capModel.recentOutputs.count == 5, "recents keep at most 5 entries")
    expectEqual(capModel.recentOutputs.first ?? "", "recent item 6", "recents put the newest entry first")
    expectTrue(!capModel.recentOutputs.contains("recent item 1"), "recents evict the oldest entry")

    capModel.input = "recent item 4"
    capModel.perform(.plainText)
    expectTrue(capModel.recentOutputs.filter { $0 == "recent item 4" }.count == 1, "recents dedupe repeated outputs")
    expectEqual(capModel.recentOutputs.first ?? "", "recent item 4", "recents move repeated output to the front")

    // copyRecentOutput restores a stored value to output and pasteboard
    pasteboard.clearContents()
    capModel.copyRecentOutput("recent item 3")
    expectEqual(pasteboard.string(forType: .string) ?? "", "recent item 3", "copyRecentOutput copies the stored value")
    expectEqual(capModel.output, "recent item 3", "copyRecentOutput shows the value in output")

    // recents persist through UserDefaults
    let secondModel = freshModel()
    expectEqual(secondModel.recentOutputs.first ?? "", "recent item 4", "recents persist across model instances")

    // clear resets input and output
    capModel.clear()
    expectEqual(capModel.input, "", "clear empties input")
    expectEqual(capModel.output, "", "clear empties output")

    // canCleanClipboard tracks pasteboard state
    pasteboard.clearContents()
    expectTrue(!capModel.canCleanClipboard, "canCleanClipboard is false for an empty pasteboard")
    pasteboard.setString("something", forType: .string)
    expectTrue(capModel.canCleanClipboard, "canCleanClipboard is true when text is available")

    defaults.removePersistentDomain(forName: suiteName)
}

@main
struct TextCleanerTests {
    @MainActor
    static func main() {
        runTransformTests()
        runModelTests()

        if failures.isEmpty {
            print("ALL TESTS PASSED (\(passCount) checks)")
            exit(0)
        }

        print("FAILED \(failures.count) of \(failures.count + passCount) checks:\n")
        for failure in failures {
            print("- \(failure)\n")
        }
        exit(1)
    }
}
