import AppKit
import ApplicationServices
import Foundation
import OSLog

private let selectionReaderLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "SelectionReader"
)

public protocol SelectionReader: Sendable {
  func readSelection() async throws -> CapturedTextSelection
}

public struct CapturedTextSelection: Equatable, Sendable {
  public let text: String
  public let sourceApp: String?
  /// Text around the selection (selection included), for meaning disambiguation. Empty when
  /// unavailable.
  public let surroundingContext: String

  public init(text: String, sourceApp: String?, surroundingContext: String = "") {
    self.text = text
    self.sourceApp = sourceApp
    self.surroundingContext = surroundingContext
  }
}

public enum SelectionReaderError: Error, Equatable, Sendable {
  case accessibilityPermissionMissing
  case emptySelection
}

public final class MacSelectionReader: SelectionReader, @unchecked Sendable {
  public init() {}

  public func readSelection() async throws -> CapturedTextSelection {
    let clock = ContinuousClock()
    let readStart = clock.now
    if !AXIsProcessTrusted() {
      selectionReaderLogger.error("Accessibility permission is missing.")
      throw SelectionReaderError.accessibilityPermissionMissing
    }

    if let selected = readAccessibilitySelection(), !selected.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      selectionReaderLogger.info(
        "Accessibility selection succeeded in \(elapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; characters: \(selected.text.count, privacy: .public)."
      )
      return selected
    }

    selectionReaderLogger.info("Accessibility selection unavailable; trying clipboard fallback.")
    if let copied = await readClipboardFallback(), !copied.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      selectionReaderLogger.info(
        "Clipboard fallback succeeded in \(elapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; characters: \(copied.text.count, privacy: .public)."
      )
      return copied
    }

    selectionReaderLogger.error(
      "Selection read failed after \(elapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; selected text was empty or unavailable."
    )
    throw SelectionReaderError.emptySelection
  }

  private func readAccessibilitySelection() -> CapturedTextSelection? {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedValue: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success else {
      return nil
    }

    let focused = focusedValue as! AXUIElement
    var selectedValue: AnyObject?
    guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedValue) == .success else {
      return nil
    }

    guard let text = selectedValue as? String else { return nil }
    return CapturedTextSelection(
      text: text,
      sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
      surroundingContext: surroundingContext(for: focused, selectedText: text)
    )
  }

  /// Reads up to ~160 characters on either side of the selection from the focused element's
  /// full value, returning the selection embedded in its surrounding text. Best-effort: many
  /// elements (e.g. web areas) don't expose a range, in which case this returns "".
  private func surroundingContext(for element: AXUIElement, selectedText: String) -> String {
    var valueRef: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
          let fullText = valueRef as? String, !fullText.isEmpty
    else { return "" }

    var rangeRef: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
          CFGetTypeID(rangeRef as CFTypeRef) == AXValueGetTypeID()
    else { return "" }

    var selectedRange = CFRange()
    guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &selectedRange) else { return "" }

    let fullString = fullText as NSString
    let selectionStart = selectedRange.location
    let selectionEnd = selectedRange.location + selectedRange.length
    guard selectionStart >= 0, selectionEnd <= fullString.length, selectionStart <= selectionEnd else { return "" }

    let window = 160
    let contextStart = max(0, selectionStart - window)
    let contextEnd = min(fullString.length, selectionEnd + window)
    let before = fullString.substring(with: NSRange(location: contextStart, length: selectionStart - contextStart))
    let after = fullString.substring(with: NSRange(location: selectionEnd, length: contextEnd - selectionEnd))

    let context = (before + selectedText + after).trimmingCharacters(in: .whitespacesAndNewlines)
    // Only useful when there is actually surrounding text beyond the selection itself.
    return context == selectedText.trimmingCharacters(in: .whitespacesAndNewlines) ? "" : context
  }

  @MainActor
  private func readClipboardFallback() async -> CapturedTextSelection? {
    let clock = ContinuousClock()
    let fallbackStart = clock.now
    let pasteboard = NSPasteboard.general
    let previousItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
        }
      }
      return copy
    } ?? []
    let previousChangeCount = pasteboard.changeCount

    sendCopyShortcut()

    // Poll changeCount instead of a fixed sleep: fast apps return in ~30 ms (saving ~150 ms
    // over the old flat wait), slow apps get up to ~300 ms before we give up.
    var copiedString: String?
    for _ in 0..<16 {
      try? await Task.sleep(for: .milliseconds(18))
      if pasteboard.changeCount != previousChangeCount {
        copiedString = pasteboard.string(forType: .string)
        break
      }
    }

    guard let copied = copiedString else {
      selectionReaderLogger.info(
        "Clipboard fallback produced no string after \(elapsedMilliseconds(from: fallbackStart, clock: clock), privacy: .public) ms."
      )
      return nil
    }

    pasteboard.clearContents()
    _ = pasteboard.writeObjects(previousItems)

    return CapturedTextSelection(text: copied, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName)
  }

  @MainActor
  private func sendCopyShortcut() {
    // Use a private event source so the synthesized Cmd-C does NOT combine with modifiers
    // the user is still physically holding (the shortcut is Option-Space, so Option may
    // still be down). Setting flags to exactly `.maskCommand` then guarantees the target
    // app receives a clean Cmd-C rather than Cmd-Opt-C.
    let source = CGEventSource(stateID: .privateState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}
