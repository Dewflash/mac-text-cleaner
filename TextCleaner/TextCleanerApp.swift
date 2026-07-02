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

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

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

            LazyVGrid(columns: columns, spacing: 8) {
                cleanButton("Plain Text", systemImage: "textformat", action: .plainText)
                cleanButton("PDF Lines", systemImage: "text.alignleft", action: .fixPDFLines)
                cleanButton("Smart Clean", systemImage: "wand.and.stars", action: .smartClean)
                cleanButton("Sentence", systemImage: "textformat.abc", action: .sentenceCase)
                cleanButton("Title Case", systemImage: "character.cursor.ibeam", action: .titleCase)
                cleanButton("lowercase", systemImage: "textformat.size.smaller", action: .lowercase)
                cleanButton("UPPERCASE", systemImage: "textformat.size.larger", action: .uppercase)
                cleanButton("Copy", systemImage: "doc.on.doc", action: .copyOutput)
                cleanButton("Replace Clip", systemImage: "arrow.left.arrow.right", action: .replaceClipboard)
            }

            outputPanel
        }
        .padding(14)
        .frame(width: 460)
        .onAppear {
            model.loadClipboardIfInputIsEmpty()
        }
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
                .frame(maxWidth: .infinity)
        }
        .disabled(model.isActionDisabled(action))
    }
}
