import AppKit
import SwiftUI
import VocraCore

/// The 查词 section: where a shortcut lookup lands now that there is no floating panel.
///
/// It reads `AppModel`'s published lookup state directly, so a streamed analysis fills in here
/// exactly as it arrives.
struct LookupView: View {
  let appModel: AppModel

  @State private var wordSaved = false

  private var captured: CapturedText? { appModel.latestCapturedText }
  private var document: LearningExplanationDocument? { appModel.latestDocument }
  private var mode: ExplanationMode { captured?.mode ?? .sentence }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onChange(of: appModel.lookupRequestRevision) { _, _ in wordSaved = false }
  }

  // MARK: Header

  @ViewBuilder
  private var header: some View {
    if captured != nil || document != nil {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(VocraTheme.ink900)
          if let text = captured?.cleanedText, !text.isEmpty {
            Text(text)
              .font(.system(size: 12.5))
              .foregroundStyle(VocraTheme.ink500)
              .lineLimit(2)
          }
        }

        Spacer(minLength: 12)

        VocraSegmented(
          options: [(.word, "单词"), (.phrase, "词组"), (.sentence, "句子")],
          selection: Binding(
            get: { mode },
            set: { newMode in Task { await appModel.explainWithMode(newMode) } }
          )
        )
        .frame(width: 210)

        if let text = captured?.cleanedText, !text.isEmpty {
          SpeakerButton(text: text, size: 15)
        }

        if (mode == .word || mode == .phrase), let document, let captured {
          SaveVocabularyButton(saved: wordSaved) {
            appModel.addVocabularyEntry(
              text: captured.cleanedText,
              type: mode == .word ? .word : .phrase,
              document: document
            )
            wordSaved = true
          }
        }

        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(
            document.map { LearningExplanationSummaryRenderer().render($0) } ?? "",
            forType: .string
          )
        } label: {
          Label("复制", systemImage: "doc.on.doc")
        }
        .buttonStyle(VocraGhostButtonStyle())
        .disabled(document == nil)
      }
      .padding(.horizontal, 30)
      .padding(.vertical, 18)
      .overlay(alignment: .bottom) { Rectangle().fill(VocraTheme.hairline).frame(height: 1) }
    }
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    if let message = appModel.latestErrorMessage {
      errorState(message, color: VocraTheme.rolePredicateInk, recovery: appModel.latestErrorRecovery)
    } else if let message = appModel.latestValidationErrorMessage {
      errorState(message, color: VocraTheme.roleAdverbialInk)
    } else if let document {
      ScrollView {
        LearningExplanationView(
          document: document,
          onSaveVocabulary: { text, type, document in
            appModel.addVocabularyEntry(text: text, type: type, document: document)
          }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollContentBackground(.hidden)
    } else if captured != nil || appModel.isLookupInFlight {
      loadingState
    } else {
      emptyState
    }
  }

  private var loadingState: some View {
    VStack(spacing: 13) {
      ProgressView().controlSize(.large)
      Text("正在解析…")
        .font(.system(size: 13))
        .foregroundStyle(VocraTheme.ink500)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: 11) {
      Image(systemName: "text.magnifyingglass")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(VocraTheme.ink300)
      Text("在任意应用里选中英文，按 \(appModel.currentShortcut.displayString)")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(VocraTheme.ink700)
      Text("解析结果会显示在这里。")
        .font(.system(size: 12.5))
        .foregroundStyle(VocraTheme.ink400)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorState(_ message: String, color: Color, recovery: LookupErrorRecovery? = nil) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 13) {
        Text(message)
          .font(.system(size: 13))
          .foregroundStyle(color)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        if let recovery {
          Button(recovery.label) { performRecovery(recovery) }
            .buttonStyle(VocraAccentButtonStyle(horizontalPadding: 14, verticalPadding: 6))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(30)
    }
  }

  private func performRecovery(_ recovery: LookupErrorRecovery) {
    switch recovery {
    case .openSettings:
      NSApp.activate(ignoringOtherApps: true)
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    case .openAccessibilitySettings:
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
    }
  }
}
