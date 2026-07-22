import AppKit
import VocraCore

/// Routes lookup results into the main window instead of a floating panel.
///
/// The result itself is already published on `AppModel` (`latestDocument`, `latestCapturedText`,
/// the error fields), and `LookupView` renders straight from there — so this presenter's only
/// job for a result is to make sure the window is actually in front and showing 查词.
///
/// Notices stay a small self-dismissing toast: the collect-article flow deliberately does not
/// open a window (the user is mid-read in another app), so its confirmation must not either.
@MainActor
final class MainWindowLookupPresenter: ExplanationPanelPresenting {
  /// Brings the main window up and switches it to the lookup section. Wired by `VocraApp`.
  var onPresentWindow: (() -> Void)?

  private let notices = NoticeToastController()
  /// True between the first `show` of a lookup and its `close`. Focus is taken once per
  /// lookup, not on every progressive update — otherwise streaming would repeatedly yank the
  /// window forward while the user is reading.
  private var isPresenting = false

  func show(
    content: ExplanationPanelContent,
    onSwitchMode: @escaping (ExplanationMode) -> Void,
    onSaveVocabulary: @escaping VocabularySaveAction,
    onClose: @escaping () -> Void
  ) {
    // A lookup supersedes a collect confirmation that is still on screen.
    notices.close()
    guard !isPresenting else { return }
    isPresenting = true
    onPresentWindow?()
  }

  func close() {
    isPresenting = false
    notices.close()
  }

  func presentNotice(_ notice: PanelNotice) {
    notices.present(notice)
  }
}
