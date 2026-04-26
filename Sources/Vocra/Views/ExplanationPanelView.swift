import AppKit
import SwiftUI
import VocraCore

struct ExplanationPanelView: View {
  let capturedText: CapturedText?
  let markdown: String
  let errorMessage: String?
  let onSwitchMode: (ExplanationMode) -> Void
  let onClose: () -> Void

  var body: some View {
    GlassEffectContainer {
      VStack(alignment: .leading, spacing: 14) {
        header

        Divider()
          .opacity(0.35)

        ScrollView {
          if let errorMessage {
            Text(errorMessage)
              .foregroundStyle(.red)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else if markdown.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity, minHeight: 320)
          } else {
            Text(renderedMarkdown)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        footer
      }
      .padding(20)
      .frame(minWidth: 480, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
      .foregroundStyle(.primary)
      .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
  }

  private var header: some View {
    HStack {
      Text(capturedText?.mode.displayName ?? "Vocra")
        .font(.headline)

      Spacer()

      Picker("Mode", selection: Binding(
        get: { capturedText?.mode ?? .sentence },
        set: { onSwitchMode($0) }
      )) {
        Text("Word").tag(ExplanationMode.word)
        Text("Term").tag(ExplanationMode.phrase)
        Text("Sentence").tag(ExplanationMode.sentence)
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 220)

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.glass)
    }
  }

  private var footer: some View {
    HStack {
      Button("Copy") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
      }
      .disabled(markdown.isEmpty)
      .buttonStyle(.glass)

      Spacer()
    }
  }

  private var renderedMarkdown: AttributedString {
    (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
  }
}
