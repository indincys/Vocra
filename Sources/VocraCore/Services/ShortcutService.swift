import Carbon
import Foundation

public struct KeyboardShortcut: Equatable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public static let defaultShortcut = KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
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
