import Foundation

/// Where Vocra keeps its on-disk state.
///
/// The dev and release builds use different folders (keyed off the bundle id) so a debug run
/// never touches the installed app's notebook, cache, or reading library.
enum AppStorageLocations {
  static var folderName: String {
    Bundle.main.bundleIdentifier == "com.indincys.Vocra.dev" ? "Vocra Dev" : "Vocra"
  }

  static func supportDirectory() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let folder = support.appending(path: folderName, directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  /// Vocabulary notebook + review scheduling.
  static func vocabularyDatabasePath() -> String {
    supportDirectory().appending(path: "vocra.sqlite").path
  }

  /// Collected articles and their cached per-sentence analyses.
  static func articleDatabasePath() -> String {
    supportDirectory().appending(path: "vocra-articles.sqlite").path
  }

  static func explanationCacheDirectory() -> URL {
    supportDirectory().appending(path: "ExplanationCache", directoryHint: .isDirectory)
  }
}
