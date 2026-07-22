import Foundation

/// Where Vocra keeps its on-disk state.
///
/// The dev and release builds use different folders (keyed off the bundle id) so a debug run
/// never touches the installed app's notebook, cache, reading library, or API keys.
public enum VocraStorageLocations {
  public static var isDevVariant: Bool {
    Bundle.main.bundleIdentifier == "com.indincys.Vocra.dev"
  }

  public static var folderName: String {
    isDevVariant ? "Vocra Dev" : "Vocra"
  }

  public static func supportDirectory() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let folder = support.appending(path: folderName, directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }
}
