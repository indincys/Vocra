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

  public init(text: String, sourceApp: String?) {
    self.text = text
    self.sourceApp = sourceApp
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
        "Accessibility selection succeeded in \(selectionElapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; characters: \(selected.text.count, privacy: .public)."
      )
      return selected
    }

    selectionReaderLogger.info("Accessibility selection unavailable; trying clipboard fallback.")
    if let copied = await readClipboardFallback(), !copied.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      selectionReaderLogger.info(
        "Clipboard fallback succeeded in \(selectionElapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; characters: \(copied.text.count, privacy: .public)."
      )
      return copied
    }

    selectionReaderLogger.error(
      "Selection read failed after \(selectionElapsedMilliseconds(from: readStart, clock: clock), privacy: .public) ms; selected text was empty or unavailable."
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
    return CapturedTextSelection(text: text, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName)
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
    try? await Task.sleep(for: .milliseconds(180))

    guard pasteboard.changeCount != previousChangeCount, let copied = pasteboard.string(forType: .string) else {
      selectionReaderLogger.info(
        "Clipboard fallback produced no string after \(selectionElapsedMilliseconds(from: fallbackStart, clock: clock), privacy: .public) ms."
      )
      return nil
    }

    pasteboard.clearContents()
    _ = pasteboard.writeObjects(previousItems)

    return CapturedTextSelection(text: copied, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName)
  }

  @MainActor
  private func sendCopyShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}

private func selectionElapsedMilliseconds(from start: ContinuousClock.Instant, clock: ContinuousClock) -> Int64 {
  let components = start.duration(to: clock.now).components
  return components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
}
