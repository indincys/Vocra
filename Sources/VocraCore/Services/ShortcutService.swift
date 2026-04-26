import Carbon
import Foundation

public struct KeyboardShortcut: Codable, Equatable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public static let defaultShortcut = KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))

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

public final class ShortcutService: @unchecked Sendable {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var handler: (() -> Void)?

  public init() {}

  deinit {
    unregister()
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  public func register(shortcut: KeyboardShortcut = .defaultShortcut, handler: @escaping () -> Void) {
    unregister()
    self.handler = handler

    if eventHandlerRef == nil {
      var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      var installedHandler: EventHandlerRef?
      let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
        guard let userData else { return noErr }
        let service = Unmanaged<ShortcutService>.fromOpaque(userData).takeUnretainedValue()
        service.handler?()
        return noErr
      }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &installedHandler)

      guard installStatus == noErr else {
        self.handler = nil
        return
      }
      eventHandlerRef = installedHandler
    }

    let hotKeyID = EventHotKeyID(signature: OSType(0x566F6372), id: 1)
    let registerStatus = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    if registerStatus != noErr {
      self.handler = nil
    }
  }

  public func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }
}
