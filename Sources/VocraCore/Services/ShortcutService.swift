import Carbon
import Foundation
import OSLog

private let shortcutServiceLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "ShortcutService"
)

/// The independently-registrable global shortcuts. The raw value is the Carbon
/// `EventHotKeyID.id`, so the shared event handler can route a keypress back to the right
/// slot's handler.
public enum ShortcutSlot: UInt32, CaseIterable, Sendable {
  /// Look up / explain the current selection in the floating panel.
  case lookup = 1
  /// Collect the current selection into the reading library as an article.
  case collectArticle = 2
}

public protocol ShortcutRegistering: AnyObject {
  @discardableResult
  func register(shortcut: KeyboardShortcut, slot: ShortcutSlot, handler: @escaping () -> Void) -> ShortcutRegistrationResult
  func unregister(slot: ShortcutSlot)
  func unregisterAll()
}

public enum ShortcutRegistrationResult: Equatable, Sendable {
  case registered
  case failed(ShortcutRegistrationError)
}

public enum ShortcutRegistrationError: Error, Equatable, Sendable, CustomStringConvertible {
  case installEventHandler(OSStatus)
  case registerHotKey(OSStatus)

  public var description: String {
    switch self {
    case .installEventHandler(let status):
      return "Could not install global shortcut event handler (status \(status))."
    case .registerHotKey(let status):
      return "Could not register global shortcut (status \(status))."
    }
  }
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public static let defaultShortcut = KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))

  /// Collect-into-reading-library default: the lookup shortcut plus Shift, so the two stay
  /// muscle-memory adjacent.
  public static let defaultCollectArticleShortcut = KeyboardShortcut(
    keyCode: UInt32(kVK_Space),
    modifiers: UInt32(optionKey) | UInt32(shiftKey)
  )

  public var displayString: String {
    var parts: [String] = []
    if modifiers & UInt32(cmdKey) != 0 {
      parts.append("⌘")
    }
    if modifiers & UInt32(optionKey) != 0 {
      parts.append("⌥")
    }
    if modifiers & UInt32(controlKey) != 0 {
      parts.append("⌃")
    }
    if modifiers & UInt32(shiftKey) != 0 {
      parts.append("⇧")
    }
    parts.append(Self.keyDisplayName(for: keyCode))
    return parts.joined()
  }

  public var isValid: Bool {
    keyCode != 0 && modifiers != 0
  }

  private static func keyDisplayName(for keyCode: UInt32) -> String {
    switch Int(keyCode) {
    case kVK_Space:
      return "Space"
    case kVK_Return:
      return "Return"
    case kVK_Tab:
      return "Tab"
    case kVK_Escape:
      return "Esc"
    case kVK_Delete:
      return "Delete"
    case kVK_ForwardDelete:
      return "Forward Delete"
    case kVK_LeftArrow:
      return "←"
    case kVK_RightArrow:
      return "→"
    case kVK_UpArrow:
      return "↑"
    case kVK_DownArrow:
      return "↓"
    default:
      return ansiKeyDisplayNames[Int(keyCode)] ?? "Key \(keyCode)"
    }
  }

  private static let ansiKeyDisplayNames: [Int: String] = [
    kVK_ANSI_A: "A",
    kVK_ANSI_B: "B",
    kVK_ANSI_C: "C",
    kVK_ANSI_D: "D",
    kVK_ANSI_E: "E",
    kVK_ANSI_F: "F",
    kVK_ANSI_G: "G",
    kVK_ANSI_H: "H",
    kVK_ANSI_I: "I",
    kVK_ANSI_J: "J",
    kVK_ANSI_K: "K",
    kVK_ANSI_L: "L",
    kVK_ANSI_M: "M",
    kVK_ANSI_N: "N",
    kVK_ANSI_O: "O",
    kVK_ANSI_P: "P",
    kVK_ANSI_Q: "Q",
    kVK_ANSI_R: "R",
    kVK_ANSI_S: "S",
    kVK_ANSI_T: "T",
    kVK_ANSI_U: "U",
    kVK_ANSI_V: "V",
    kVK_ANSI_W: "W",
    kVK_ANSI_X: "X",
    kVK_ANSI_Y: "Y",
    kVK_ANSI_Z: "Z",
    kVK_ANSI_0: "0",
    kVK_ANSI_1: "1",
    kVK_ANSI_2: "2",
    kVK_ANSI_3: "3",
    kVK_ANSI_4: "4",
    kVK_ANSI_5: "5",
    kVK_ANSI_6: "6",
    kVK_ANSI_7: "7",
    kVK_ANSI_8: "8",
    kVK_ANSI_9: "9",
    kVK_ANSI_Minus: "-",
    kVK_ANSI_Equal: "=",
    kVK_ANSI_LeftBracket: "[",
    kVK_ANSI_RightBracket: "]",
    kVK_ANSI_Backslash: "\\",
    kVK_ANSI_Semicolon: ";",
    kVK_ANSI_Quote: "'",
    kVK_ANSI_Grave: "`",
    kVK_ANSI_Comma: ",",
    kVK_ANSI_Period: ".",
    kVK_ANSI_Slash: "/"
  ]
}

/// Owns every Carbon hot key the app registers. One shared `kEventHotKeyPressed` handler is
/// installed for the whole process; each keypress carries its `EventHotKeyID`, which routes
/// back to the slot that registered it.
public final class ShortcutService: ShortcutRegistering, @unchecked Sendable {
  private let lock = NSLock()
  private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
  private var handlers: [UInt32: () -> Void] = [:]
  private var eventHandlerRef: EventHandlerRef?

  public init() {}

  deinit {
    unregisterAll()
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  @discardableResult
  public func register(
    shortcut: KeyboardShortcut = .defaultShortcut,
    slot: ShortcutSlot = .lookup,
    handler: @escaping () -> Void
  ) -> ShortcutRegistrationResult {
    unregister(slot: slot)
    shortcutServiceLogger.info(
      "Registering global shortcut for slot \(slot.rawValue, privacy: .public): \(shortcut.displayString, privacy: .public)."
    )

    if let failure = installSharedEventHandlerIfNeeded() {
      return .failed(failure)
    }

    let hotKeyID = EventHotKeyID(signature: OSType(0x566F6372), id: slot.rawValue)
    var hotKeyRef: EventHotKeyRef?
    let registerStatus = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    guard registerStatus == noErr, let hotKeyRef else {
      shortcutServiceLogger.error("Global shortcut registration failed: \(registerStatus, privacy: .public).")
      return .failed(.registerHotKey(registerStatus))
    }

    lock.lock()
    hotKeyRefs[slot.rawValue] = hotKeyRef
    handlers[slot.rawValue] = handler
    lock.unlock()

    shortcutServiceLogger.info("Global shortcut registered: \(shortcut.displayString, privacy: .public).")
    return .registered
  }

  public func unregister(slot: ShortcutSlot) {
    lock.lock()
    let hotKeyRef = hotKeyRefs.removeValue(forKey: slot.rawValue)
    handlers.removeValue(forKey: slot.rawValue)
    lock.unlock()
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
  }

  public func unregisterAll() {
    lock.lock()
    let refs = Array(hotKeyRefs.values)
    hotKeyRefs.removeAll()
    handlers.removeAll()
    lock.unlock()
    for ref in refs {
      UnregisterEventHotKey(ref)
    }
  }

  /// Installs the process-wide hot-key event handler once. Returns a failure to report when
  /// installation didn't succeed.
  private func installSharedEventHandlerIfNeeded() -> ShortcutRegistrationError? {
    guard eventHandlerRef == nil else { return nil }

    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    var installedHandler: EventHandlerRef?
    let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
      guard let userData, let event else { return noErr }
      var hotKeyID = EventHotKeyID()
      let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
      )
      guard status == noErr else { return noErr }
      let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()
      shortcutServiceLogger.info("Global shortcut event received for slot \(hotKeyID.id, privacy: .public).")
      service.invokeHandler(id: hotKeyID.id)
      return noErr
    }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &installedHandler)

    guard installStatus == noErr else {
      shortcutServiceLogger.error("Global shortcut event handler installation failed: \(installStatus, privacy: .public).")
      return .installEventHandler(installStatus)
    }
    eventHandlerRef = installedHandler
    return nil
  }

  /// Copies the handler out from under the lock before calling it, so a handler that
  /// re-enters `register`/`unregister` can't deadlock.
  private func invokeHandler(id: UInt32) {
    lock.lock()
    let handler = handlers[id]
    lock.unlock()
    handler?()
  }
}
