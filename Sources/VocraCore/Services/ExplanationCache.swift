import CryptoKit
import Foundation

/// Caches structured explanations so repeated lookups of the same word/sentence
/// return instantly instead of re-calling the model.
public protocol ExplanationCaching: Sendable {
  func cached(text: String, mode: ExplanationMode, model: String) -> LearningExplanationDocument?
  func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String)
}

public final class DiskExplanationCache: ExplanationCaching, @unchecked Sendable {
  private let directory: URL
  private let lock = NSLock()
  private var memory: [String: LearningExplanationDocument] = [:]
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(directory: URL) {
    self.directory = directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  public func cached(text: String, mode: ExplanationMode, model: String) -> LearningExplanationDocument? {
    let key = Self.key(text: text, mode: mode, model: model)
    lock.lock()
    if let hit = memory[key] {
      lock.unlock()
      return hit
    }
    lock.unlock()

    let url = directory.appendingPathComponent(Self.filename(for: key))
    guard let data = try? Data(contentsOf: url),
          let document = try? decoder.decode(LearningExplanationDocument.self, from: data)
    else { return nil }

    lock.lock()
    memory[key] = document
    lock.unlock()
    return document
  }

  public func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String) {
    let key = Self.key(text: text, mode: mode, model: model)
    lock.lock()
    memory[key] = document
    lock.unlock()

    guard let data = try? encoder.encode(document) else { return }
    try? data.write(to: directory.appendingPathComponent(Self.filename(for: key)), options: .atomic)
  }

  static func key(text: String, mode: ExplanationMode, model: String) -> String {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .lowercased()
    return "\(mode.rawValue)|\(model)|\(normalized)"
  }

  static func filename(for key: String) -> String {
    let digest = SHA256.hash(data: Data(key.utf8))
    return digest.map { String(format: "%02x", $0) }.joined() + ".json"
  }
}

/// No-op cache for tests and injection points that should never persist.
public struct NoExplanationCache: ExplanationCaching {
  public init() {}
  public func cached(text: String, mode: ExplanationMode, model: String) -> LearningExplanationDocument? { nil }
  public func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String) {}
}
