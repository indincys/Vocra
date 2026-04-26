import Foundation

extension Notification.Name {
  static let vocraKeyboardShortcutDidChange = Notification.Name("vocraKeyboardShortcutDidChange")
}

enum VocraNotificationUserInfoKey {
  static let keyboardShortcut = "keyboardShortcut"
}
