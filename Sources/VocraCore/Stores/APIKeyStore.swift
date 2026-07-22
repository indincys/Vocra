import CryptoKit
import Foundation
import OSLog
import Security

private let secretsLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "com.indincys.Vocra",
  category: "Secrets"
)

/// Per-account API key storage.
///
/// The production implementation is ``FileAPIKeyStore``: keys live in a local encrypted file
/// under Application Support, **not** in the system Keychain.
///
/// # Why not the Keychain
///
/// Vocra ships without an Apple Developer certificate (ad-hoc / self-signed signing, see
/// docs/release.md). macOS ties a Keychain item's per-app ACL to the code-signing identity,
/// and an untrusted anchor means the "Always Allow" grant cannot survive a new build — every
/// app update, and every local rebuild, re-prompted for Keychain authorization. That is a
/// system limitation, not something configuration can fix.
///
/// # Security level (stated honestly)
///
/// Without a trusted signing identity every option collapses to "any process running as this
/// user can read the key". This store relies on file permissions 0600 + FileVault full-disk
/// encryption + a ChaCha20-Poly1305 layer on the file itself. That last layer **guards
/// against accidents, not attackers**: it keeps the key out of backups, screenshots, and
/// `grep`. The master key sits next to the ciphertext, so it is deliberately *not* an
/// independent security boundary. The blast radius is one rotatable third-party API key.
/// If Vocra ever gets an Apple certificate, moving back to the Data Protection Keychain is
/// just a different implementation of this protocol.
///
/// The key itself never reaches the databases, logs, or prompts — only account names do.
public protocol APIKeyStore: Sendable {
  func readAPIKey() throws -> String?
  func saveAPIKey(_ key: String) throws
  func deleteAPIKey() throws
}

public enum APIKeyStoreError: Error, Equatable, Sendable {
  case keychainStatus(OSStatus)
  case encryptionFailed
  case writeFailed(String)
}

/// Account naming. One account per API profile; the default profile keeps the original name
/// so keys stored by earlier versions migrate in place.
public enum APIKeyAccount {
  public static let `default` = "OpenAICompatibleAPIKey"

  public static func forProfile(id: UUID, isDefault: Bool) -> String {
    isDefault ? `default` : "\(`default`).\(id.uuidString)"
  }
}

// MARK: - Local encrypted file store

/// Production store: one shared encrypted vault file, addressed per account.
public struct FileAPIKeyStore: APIKeyStore {
  private let vault: SecretVault
  private let account: String

  public init(directory: URL = VocraStorageLocations.supportDirectory(), account: String = APIKeyAccount.default) {
    self.vault = SecretVault(directory: directory)
    self.account = account
  }

  public func readAPIKey() throws -> String? {
    try vault.value(for: account)
  }

  public func saveAPIKey(_ key: String) throws {
    try vault.setValue(key, for: account)
  }

  public func deleteAPIKey() throws {
    try vault.removeValue(for: account)
  }
}

/// The encrypted `account -> secret` map backing ``FileAPIKeyStore``.
///
/// Disk layout, both files 0600:
/// - `secrets.key` — 32 random bytes, generated on first use.
/// - `secrets.enc` — ChaCha20-Poly1305 sealed box (nonce + ciphertext + tag, re-randomized
///   on every write) whose plaintext is `{"version":1,"keys":{"<account>":"<secret>"}}`.
struct SecretVault: Sendable {
  static let keyFileName = "secrets.key"
  static let vaultFileName = "secrets.enc"

  private static let version = 1
  /// Serializes read-modify-write across every store instance in the process. Vaults in
  /// different directories share it; over-serializing a handful of file writes is free.
  private static let lock = NSLock()

  private let keyURL: URL
  private let vaultURL: URL

  init(directory: URL) {
    self.keyURL = directory.appending(path: Self.keyFileName)
    self.vaultURL = directory.appending(path: Self.vaultFileName)
  }

  private struct Payload: Codable {
    var version: Int
    var keys: [String: String]
  }

  func value(for account: String) throws -> String? {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    return try load(using: masterKey())[account]
  }

  func setValue(_ secret: String, for account: String) throws {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    let key = try masterKey()
    var keys = try load(using: key)
    keys[account] = secret
    try store(keys, using: key)
  }

  func removeValue(for account: String) throws {
    Self.lock.lock()
    defer { Self.lock.unlock() }
    let key = try masterKey()
    var keys = try load(using: key)
    guard keys.removeValue(forKey: account) != nil else { return }
    try store(keys, using: key)
  }

  // MARK: Master key

  /// Reads the master key, generating one on first use. A missing master key with a vault
  /// still present means the vault can never be decrypted again, so it is quarantined and
  /// rebuilt rather than reported as an error the user cannot act on.
  private func masterKey() throws -> SymmetricKey {
    guard let data = try? Data(contentsOf: keyURL) else {
      if FileManager.default.fileExists(atPath: vaultURL.path) {
        secretsLogger.warning("Master key missing but vault present; quarantining and rebuilding (API keys must be re-entered in Settings).")
        quarantine(vaultURL)
      }
      return try createMasterKey()
    }
    guard data.count == 32 else {
      secretsLogger.warning("Master key file has an invalid length; quarantining and rebuilding (API keys must be re-entered in Settings).")
      quarantine(keyURL)
      quarantine(vaultURL)
      return try createMasterKey()
    }
    return SymmetricKey(data: data)
  }

  private func createMasterKey() throws -> SymmetricKey {
    let key = SymmetricKey(size: .bits256)
    try key.withUnsafeBytes { try writePrivate(Data($0), to: keyURL) }
    return key
  }

  // MARK: Vault I/O

  /// Decrypts the vault. A missing file is an empty vault; anything unreadable is
  /// quarantined and rebuilt empty so a corrupt file can never block app startup.
  private func load(using key: SymmetricKey) throws -> [String: String] {
    guard let raw = try? Data(contentsOf: vaultURL) else { return [:] }

    guard let box = try? ChaChaPoly.SealedBox(combined: raw),
          let plaintext = try? ChaChaPoly.open(box, using: key)
    else {
      secretsLogger.warning("Vault could not be decrypted; quarantining and rebuilding (API keys must be re-entered in Settings).")
      quarantine(vaultURL)
      return [:]
    }

    guard let payload = try? JSONDecoder().decode(Payload.self, from: plaintext) else {
      secretsLogger.warning("Vault plaintext is malformed; quarantining and rebuilding (API keys must be re-entered in Settings).")
      quarantine(vaultURL)
      return [:]
    }
    // An unrecognized version means a newer format (a downgraded run). Decoding it as v1
    // would silently drop keys without leaving evidence, so treat it as corruption instead.
    guard payload.version == Self.version else {
      secretsLogger.warning("Vault version \(payload.version, privacy: .public) is unknown; quarantining and rebuilding (API keys must be re-entered in Settings).")
      quarantine(vaultURL)
      return [:]
    }
    return payload.keys
  }

  private func store(_ keys: [String: String], using key: SymmetricKey) throws {
    let plaintext = try JSONEncoder().encode(Payload(version: Self.version, keys: keys))
    guard let box = try? ChaChaPoly.seal(plaintext, using: key) else {
      throw APIKeyStoreError.encryptionFailed
    }
    try writePrivate(box.combined, to: vaultURL)
  }

  /// Renames a damaged file to `<name>.bak-<nanoseconds>` so the bytes survive for manual
  /// recovery. Nanosecond precision because a corrupt vault can be hit twice within the same
  /// second (startup migration + first lookup), and a second-resolution name would let the
  /// later quarantine overwrite the only evidence. Never logs file contents.
  private func quarantine(_ url: URL) {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    let stamp = DispatchTime.now().uptimeNanoseconds
    let backup = url.appendingPathExtension("bak-\(stamp)")
    do {
      try FileManager.default.moveItem(at: url, to: backup)
    } catch {
      secretsLogger.warning("Could not quarantine \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
    }
  }

  /// Atomic owner-only write: temp file in the same directory (created 0600) -> fsync ->
  /// `rename(2)` over the target. `rename` is atomic, so a crash mid-write leaves either the
  /// old file or the new one, never a truncated vault.
  private func writePrivate(_ bytes: Data, to url: URL) throws {
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // Append rather than replace the extension: secrets.key and secrets.enc must not share
    // a temp path. The pid only avoids colliding with another process's leftovers — writes
    // inside this process are already serialized by `lock`.
    let temporary = url.appendingPathExtension("tmp-\(ProcessInfo.processInfo.processIdentifier)")

    guard FileManager.default.createFile(
      atPath: temporary.path,
      contents: nil,
      attributes: [.posixPermissions: NSNumber(value: Int16(0o600))]
    ) else {
      throw APIKeyStoreError.writeFailed("could not create \(temporary.lastPathComponent)")
    }

    do {
      let handle = try FileHandle(forWritingTo: temporary)
      try handle.write(contentsOf: bytes)
      try handle.synchronize()
      try handle.close()
    } catch {
      try? FileManager.default.removeItem(at: temporary)
      throw error
    }

    guard rename(temporary.path, url.path) == 0 else {
      let code = errno
      try? FileManager.default.removeItem(at: temporary)
      throw APIKeyStoreError.writeFailed("rename failed with errno \(code)")
    }
  }
}

// MARK: - Legacy Keychain store (migration source only)

/// The pre-0.2 store. Kept **only** as a migration source for ``APIKeyMigrator``; nothing
/// reads or writes API keys through the Keychain any more (see ``APIKeyStore`` for why).
public struct KeychainAPIKeyStore: APIKeyStore {
  private let service: String
  private let account: String

  public init(service: String = "com.indincys.Vocra", account: String = APIKeyAccount.default) {
    self.service = service
    self.account = account
  }

  public func readAPIKey() throws -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw APIKeyStoreError.keychainStatus(status) }
    guard let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  public func saveAPIKey(_ key: String) throws {
    let attributes = [kSecValueData as String: Data(key.utf8)]
    let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw APIKeyStoreError.keychainStatus(updateStatus)
    }

    var item = baseQuery()
    item[kSecValueData as String] = Data(key.utf8)
    let addStatus = SecItemAdd(item as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw APIKeyStoreError.keychainStatus(addStatus) }
  }

  public func deleteAPIKey() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw APIKeyStoreError.keychainStatus(status)
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}

// MARK: - One-time migration

/// Moves API keys out of the system Keychain and into the local encrypted file.
///
/// Runs on every launch and is **idempotent** — an account already present in the
/// destination is skipped without touching the source.
public struct APIKeyMigrator: Sendable {
  private let makeSource: @Sendable (String) -> any APIKeyStore
  private let makeDestination: @Sendable (String) -> any APIKeyStore
  private let clearsSource: Bool

  /// - Parameter clearsSource: whether to delete the Keychain entry once the key is safely in
  ///   the file. Defaults to false for the **dev** build, which shares the Keychain service and
  ///   account with the installed release app while keeping a separate Application Support
  ///   folder — deleting there would migrate the key into the dev vault and leave the release
  ///   app with nothing.
  public init(
    makeSource: @escaping @Sendable (String) -> any APIKeyStore = { KeychainAPIKeyStore(account: $0) },
    makeDestination: @escaping @Sendable (String) -> any APIKeyStore = { FileAPIKeyStore(account: $0) },
    clearsSource: Bool = !VocraStorageLocations.isDevVariant
  ) {
    self.makeSource = makeSource
    self.makeDestination = makeDestination
    self.clearsSource = clearsSource
  }

  /// Migrates every account in `accounts`, returning how many keys actually moved.
  ///
  /// Per account: destination already populated -> skip (source untouched). Otherwise read
  /// the source, **write the destination first and only then delete the source** — the
  /// reverse order would lose the key if the process died in between. A read or write
  /// failure (including the user dismissing the final Keychain prompt) logs a warning,
  /// leaves the source in place for the next launch, and never interrupts the run.
  @discardableResult
  public func migrate(accounts: [String]) -> Int {
    var moved = 0
    for account in accounts {
      let destination = makeDestination(account)
      do {
        if try destination.readAPIKey() != nil { continue }
      } catch {
        secretsLogger.warning("Could not read local key file for \(account, privacy: .public); skipping migration this launch.")
        continue
      }

      let source = makeSource(account)
      let secret: String?
      do {
        secret = try source.readAPIKey()
      } catch {
        secretsLogger.warning("Could not read Keychain entry for \(account, privacy: .public); keeping it for the next launch.")
        continue
      }
      // Nothing in the Keychain either: the profile simply has no key yet.
      guard let secret else { continue }

      do {
        try destination.saveAPIKey(secret)
      } catch {
        secretsLogger.warning("Could not write local key file for \(account, privacy: .public); keeping the Keychain entry.")
        continue
      }
      if clearsSource {
        do {
          try source.deleteAPIKey()
        } catch {
          secretsLogger.warning("Migrated \(account, privacy: .public) but could not clear its Keychain entry; it can be removed manually.")
        }
      }
      moved += 1
    }
    if moved > 0 {
      secretsLogger.info("Migrated \(moved, privacy: .public) API key(s) from the Keychain to the local encrypted file.")
    }
    return moved
  }
}
