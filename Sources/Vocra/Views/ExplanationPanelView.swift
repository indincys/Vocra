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

        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        footer
      }
      .padding(20)
      .frame(minWidth: 480, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
      .foregroundStyle(.primary)
      .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
  }

  @ViewBuilder
  private var content: some View {
    if let errorMessage {
      ScrollView {
        Text(errorMessage)
          .foregroundStyle(.red)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 320)
    } else if markdown.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 320)
    } else {
      MarkdownWebView(markdown: markdown)
        .frame(minHeight: 320)
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
}
