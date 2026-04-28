import AppKit
import SwiftUI
import VocraCore

struct ExplanationPanelView: View {
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
    VStack(alignment: .leading, spacing: 12) {
      header
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      footer
    }
    .padding(18)
    .frame(minWidth: 900, maxWidth: .infinity, minHeight: 720, maxHeight: .infinity)
    .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.16))
    .background {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color(red: 0.97, green: 0.985, blue: 1.0))
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 14)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color(red: 0.75, green: 0.82, blue: 0.9), lineWidth: 1)
    }
    .environment(\.colorScheme, .light)
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
          .padding(.vertical, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollContentBackground(.hidden)
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
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(capturedText?.mode.displayName ?? "Vocra")
          .font(.title3.weight(.heavy))
        if let text = capturedText?.cleanedText, !text.isEmpty {
          Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.5))
            .lineLimit(1)
        }
      }

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
      .frame(width: 250)
      .controlSize(.large)

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color(red: 0.82, green: 0.87, blue: 0.94), lineWidth: 1)
    }
  }

  private var footer: some View {
    HStack {
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderedSummary, forType: .string)
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
      .disabled(document == nil)
      .buttonStyle(.bordered)

      Spacer()
    }
    .padding(.horizontal, 4)
  }
}
