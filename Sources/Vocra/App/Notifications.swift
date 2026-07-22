import Foundation

extension Notification.Name {
  static let vocraKeyboardShortcutDidChange = Notification.Name("vocraKeyboardShortcutDidChange")
  static let vocraArticleRetentionDidChange = Notification.Name("vocraArticleRetentionDidChange")
}

enum VocraNotificationUserInfoKey {
  static let keyboardShortcut = "keyboardShortcut"
  static let collectArticleShortcut = "collectArticleShortcut"
}
