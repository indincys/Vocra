import CryptoKit
import Foundation

/// Caches structured explanations so repeated lookups of the same word/sentence
/// return instantly instead of re-calling the model.
///
/// `variant` distinguishes cache entries that share text/mode/model but were produced under
/// different conditions — the prompt-template body, learning preferences, and document
/// schema version. Without it, changing a preference or shipping a new template would keep
/// serving stale results ("settings don't take effect").
public protocol ExplanationCaching: Sendable {
  func cached(text: String, mode: ExplanationMode, model: String, variant: String) -> LearningExplanationDocument?
  func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String, variant: String)
}

public final class DiskExplanationCache: ExplanationCaching, @unchecked Sendable {
  private let directory: URL
  private let lock = NSLock()
  private var memory: [String: LearningExplanationDocument] = [:]
  /// Insertion order of `memory` keys, for FIFO eviction once the in-memory cap is hit.
  private var memoryOrder: [String] = []
  private let memoryLimit: Int
  private let diskLimit: Int
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(directory: URL, memoryLimit: Int = 500, diskLimit: Int = 2000) {
    self.directory = directory
    self.memoryLimit = memoryLimit
    self.diskLimit = diskLimit
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  public func cached(text: String, mode: ExplanationMode, model: String, variant: String = "") -> LearningExplanationDocument? {
    let key = Self.key(text: text, mode: mode, model: model, variant: variant)
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
    rememberInMemory(key: key, document: document)
    lock.unlock()
    return document
  }

  public func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String, variant: String = "") {
    let key = Self.key(text: text, mode: mode, model: model, variant: variant)
    lock.lock()
    rememberInMemory(key: key, document: document)
    lock.unlock()

    guard let data = try? encoder.encode(document) else { return }
    try? data.write(to: directory.appendingPathComponent(Self.filename(for: key)), options: .atomic)
    pruneDiskIfNeeded()
  }

  /// Inserts/updates a memory entry, evicting the oldest key once the cap is exceeded.
  /// Caller holds `lock`.
  private func rememberInMemory(key: String, document: LearningExplanationDocument) {
    if memory[key] == nil {
      memoryOrder.append(key)
    }
    memory[key] = document
    while memoryOrder.count > memoryLimit, let oldest = memoryOrder.first {
      memoryOrder.removeFirst()
      memory.removeValue(forKey: oldest)
    }
  }

  /// Keeps the on-disk cache under `diskLimit` files, deleting the least-recently-modified
  /// entries when it grows past the cap.
  private func pruneDiskIfNeeded() {
    let keys: Set<URLResourceKey> = [.contentModificationDateKey]
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: [.skipsHiddenFiles]
    ), urls.count > diskLimit else { return }

    let byModificationDate = urls
      .map { url -> (URL, Date) in
        let date = (try? url.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
        return (url, date)
      }
      .sorted { $0.1 < $1.1 }

    for (url, _) in byModificationDate.prefix(urls.count - diskLimit) {
      try? FileManager.default.removeItem(at: url)
    }
  }

  static func key(text: String, mode: ExplanationMode, model: String, variant: String = "") -> String {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .lowercased()
    return "\(mode.rawValue)|\(model)|\(variant)|\(normalized)"
  }

  static func filename(for key: String) -> String {
    let digest = SHA256.hash(data: Data(key.utf8))
    return digest.map { String(format: "%02x", $0) }.joined() + ".json"
  }
}

/// No-op cache for tests and injection points that should never persist.
public struct NoExplanationCache: ExplanationCaching {
  public init() {}
  public func cached(text: String, mode: ExplanationMode, model: String, variant: String = "") -> LearningExplanationDocument? { nil }
  public func store(_ document: LearningExplanationDocument, text: String, mode: ExplanationMode, model: String, variant: String = "") {}
}
