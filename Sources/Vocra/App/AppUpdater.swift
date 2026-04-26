import Foundation
import Sparkle

@MainActor
final class AppUpdater {
  private let controller: SPUStandardUpdaterController?

  var isEnabled: Bool {
    controller != nil
  }

  init(bundle: Bundle = .main) {
    let hasFeedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") != nil
    let hasPublicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
    guard hasFeedURL, hasPublicKey else {
      self.controller = nil
      return
    }

    self.controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  func checkForUpdates() {
    controller?.checkForUpdates(nil)
  }
}
