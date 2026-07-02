import AppKit
import SwiftUI

@main
struct TextCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TextCleanerModel()

    var body: some Scene {
        MenuBarExtra {
            TextCleanerMenu(model: model)
        } label: {
            Label("TextCleaner", systemImage: "text.badge.checkmark")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct TextCleanerMenu: View {
    @ObservedObject var model: TextCleanerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TextEditor(text: $model.input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(width: 430, height: 120)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button {
                    model.loadClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }

                Button {
                    model.cleanClipboard()
                } label: {
                    Label("Clean Clipboard", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCleanClipboard)

                Spacer()

                Button {
                    model.clear()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }

            HStack(spacing: 8) {
                cleanButton("Plain Text", systemImage: "textformat", action: .plainText)
                cleanButton("PDF Lines", systemImage: "text.alignleft", action: .fixPDFLines)
                cleanButton("Smart Clean", systemImage: "wand.and.stars", action: .smartClean)
            }

            HStack(spacing: 8) {
                caseMenu
                markdownMenu
                chatMenu
            }

            outputPanel

            recentPanel
        }
        .padding(14)
        .frame(width: 500)
        .onAppear {
            model.loadClipboardIfInputIsEmpty()
        }
    }

    private var caseMenu: some View {
        Menu {
            menuAction("Sentence", systemImage: "textformat.abc", action: .sentenceCase)
            menuAction("Title Case", systemImage: "character.cursor.ibeam", action: .titleCase)
            menuAction("lowercase", systemImage: "textformat.size.smaller", action: .lowercase)
            menuAction("UPPERCASE", systemImage: "textformat.size.larger", action: .uppercase)
        } label: {
            Label("Case", systemImage: "textformat")
                .frame(minWidth: 96, maxWidth: .infinity)
        }
        .disabled(model.input.isEmpty)
    }

    private var markdownMenu: some View {
        Menu {
            menuAction("Quote", systemImage: "quote.bubble", action: .markdownQuote)
            menuAction("Bullet List", systemImage: "list.bullet", action: .markdownBulletList)
            menuAction("Comma List", systemImage: "text.badge.plus", action: .commaSeparatedLineList)
            Divider()
            menuAction("Bold", systemImage: "bold", action: .markdownBold)
            menuAction("Italic", systemImage: "italic", action: .markdownItalic)
            menuAction("Code", systemImage: "chevron.left.forwardslash.chevron.right", action: .markdownInlineCode)
        } label: {
            Label("Markdown", systemImage: "number")
                .frame(minWidth: 136, maxWidth: .infinity)
        }
        .disabled(model.input.isEmpty)
    }

    private var chatMenu: some View {
        Menu {
            menuAction("Bold", systemImage: "bold", action: .chatBold)
            menuAction("Italic", systemImage: "italic", action: .chatItalic)
            menuAction("Monospace", systemImage: "chevron.left.forwardslash.chevron.right", action: .chatMonospace)
            menuAction("Strikethrough", systemImage: "strikethrough", action: .chatStrikethrough)
        } label: {
            Label("Chat", systemImage: "message")
                .frame(minWidth: 96, maxWidth: .infinity)
        }
        .disabled(model.input.isEmpty)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TextCleaner")
                    .font(.headline)
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
    }

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.recentOutputs.isEmpty {
                Text("Recent cleaned text will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.recentOutputs, id: \.self) { value in
                        Button {
                            model.copyRecentOutput(value)
                        } label: {
                            Label(recentPreview(value), systemImage: "clock.arrow.circlepath")
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !model.output.isEmpty {
                    Button {
                        model.copyOutput()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)
                }
            }

            ScrollView {
                Text(model.output.isEmpty ? "Cleaned text will appear here." : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 110)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cleanButton(_ title: String, systemImage: String, action: TextCleanerAction) -> some View {
        Button {
            model.perform(action)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(minWidth: 132, maxWidth: .infinity)
        }
        .disabled(model.isActionDisabled(action))
    }

    private func menuAction(_ title: String, systemImage: String, action: TextCleanerAction) -> some View {
        Button {
            model.perform(action)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func recentPreview(_ value: String) -> String {
        let singleLine = value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")

        if singleLine.count <= 72 {
            return singleLine
        }

        return String(singleLine.prefix(72)) + "..."
    }
}
