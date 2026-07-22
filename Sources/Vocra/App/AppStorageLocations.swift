import Foundation
import VocraCore

/// Where Vocra keeps its on-disk state.
///
/// The directory itself is resolved by `VocraCore.VocraStorageLocations` so that VocraCore
/// types which need it on their own (the encrypted API key vault) land in the same folder.
enum AppStorageLocations {
  static func supportDirectory() -> URL {
    VocraStorageLocations.supportDirectory()
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
