import SwiftUI

enum ExplanationPanelAppearance {
  static func backgroundOpacity(for colorScheme: ColorScheme) -> Double {
    switch colorScheme {
    case .dark:
      0.86
    case .light:
      0
    @unknown default:
      0.86
    }
  }
}
