import AppKit
import SwiftUI
import VocraCore

struct ExplanationPanelView: View {
  let capturedText: CapturedText?
  let document: LearningExplanationDocument?
  let errorMessage: String?
  let validationErrorMessage: String?
  let onSwitchMode: (ExplanationMode) -> Void
  var onSaveVocabulary: VocabularySaveAction? = nil
  let onClose: () -> Void

  @State private var wordSaved = false

  private var renderedSummary: String {
    document.map { LearningExplanationSummaryRenderer().render($0) } ?? ""
  }

  private var mode: ExplanationMode { capturedText?.mode ?? .sentence }

  private var title: String {
    switch mode {
    case .sentence: "长难句拆解"
    case .word: "单词解析"
    case .phrase: "词组解析"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      footer
    }
    .frame(minWidth: 420, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
    .background {
      VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
    }
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
    }
    .shadow(color: VocraTheme.shadow.opacity(0.32), radius: 26, x: 0, y: 18)
    .shadow(color: VocraTheme.shadow.opacity(0.16), radius: 6, x: 0, y: 4)
    .environment(\.colorScheme, .light)
    .tint(VocraTheme.accent)
    .onAppear(perform: autoSpeakIfEnabled)
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "square.stack.3d.up")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(VocraTheme.accent)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(VocraTheme.ink900)
        if let text = capturedText?.cleanedText, !text.isEmpty {
          Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(VocraTheme.ink500)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 16)

      VocraSegmented(
        options: [(.word, "单词"), (.phrase, "词组"), (.sentence, "句子")],
        selection: Binding(get: { mode }, set: { onSwitchMode($0) })
      )
      .frame(width: 220)

      if let text = capturedText?.cleanedText, !text.isEmpty {
        SpeakerButton(text: text, size: 15)
      }

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(VocraTheme.ink500)
          .frame(width: 30, height: 30)
          .background(VocraTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 13)
    .overlay(alignment: .bottom) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    if let errorMessage {
      errorText(errorMessage, color: VocraTheme.rolePredicateInk)
    } else if let validationErrorMessage {
      errorText(validationErrorMessage, color: VocraTheme.roleAdverbialInk)
    } else if let document {
      ScrollView {
        LearningExplanationView(document: document, onSaveVocabulary: onSaveVocabulary)
          .padding(.bottom, 6)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollContentBackground(.hidden)
    } else {
      VStack(spacing: 14) {
        ProgressView().controlSize(.large)
        Text("正在解析…")
          .font(.system(size: 13))
          .foregroundStyle(VocraTheme.ink500)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func errorText(_ message: String, color: Color) -> some View {
    ScrollView {
      Text(message)
        .font(.system(size: 13))
        .foregroundStyle(color)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }
  }

  // MARK: Footer

  private var footer: some View {
    HStack(spacing: 10) {
      Text("由模型即时解析 · 可在设置中切换模型")
        .font(.system(size: 11.5))
        .foregroundStyle(VocraTheme.ink400)
        .lineLimit(1)
      Spacer(minLength: 8)
      if (mode == .word || mode == .phrase), let onSaveVocabulary, let document, let captured = capturedText {
        SaveVocabularyButton(saved: wordSaved) {
          onSaveVocabulary(captured.cleanedText, mode == .word ? .word : .phrase, document)
          wordSaved = true
        }
      }
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderedSummary, forType: .string)
      } label: {
        Label("复制", systemImage: "doc.on.doc")
      }
      .buttonStyle(VocraGhostButtonStyle())
      .disabled(document == nil)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .overlay(alignment: .top) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
  }

  private func autoSpeakIfEnabled() {
    guard document != nil,
          mode == .word || mode == .phrase,
          UserDefaults.standard.object(forKey: "vocra.autoSpeak") as? Bool ?? true,
          let text = capturedText?.cleanedText, !text.isEmpty
    else { return }
    SpeechPlayer.shared.speak(text)
  }
}
