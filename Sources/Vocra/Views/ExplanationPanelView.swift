import AppKit
import SwiftUI
import VocraCore

struct ExplanationPanelView: View {
  @Environment(\.colorScheme) private var colorScheme

  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  let validationErrorMessage: String?
  let onSwitchMode: (ExplanationMode) -> Void
  let onClose: () -> Void

  private var renderedSummary: String {
    document.map { LearningExplanationSummaryRenderer().render($0) } ?? ""
  }

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
      .background {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(Color.black.opacity(ExplanationPanelAppearance.backgroundOpacity(for: colorScheme)))
      }
      .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
  }

  @ViewBuilder
  private var content: some View {
    if let errorMessage {
      errorText(errorMessage, color: .red)
    } else if let validationErrorMessage {
      errorText(validationErrorMessage, color: .orange)
    } else if let document {
      ScrollView {
        LearningExplanationView(document: document)
          .padding(.vertical, 2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(minHeight: 320)
    } else {
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 320)
    }
  }

  private func errorText(_ message: String, color: Color) -> some View {
    ScrollView {
      Text(message)
        .foregroundStyle(color)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minHeight: 320)
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
        NSPasteboard.general.setString(renderedSummary, forType: .string)
      }
      .disabled(document == nil)
      .buttonStyle(.glass)

      Spacer()
    }
  }
}
