import XCTest
@testable import VocraCore

/// Test secrets deliberately use obviously-fake values (never an `sk-`-style prefix) so they
/// can't trip secret scanning and can't be mistaken for a real key.
private let fakeKey = "test-key-0001"

final class APIKeyStoreTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appending(path: "vocra-secrets-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  private func store(account: String = "acct-1") -> FileAPIKeyStore {
    FileAPIKeyStore(directory: directory, account: account)
  }

  func testSaveReadUpdateAndDeleteAPIKey() throws {
    let store = store()

    XCTAssertNil(try store.readAPIKey())

    try store.saveAPIKey(fakeKey)
    XCTAssertEqual(try store.readAPIKey(), fakeKey)

    try store.saveAPIKey("test-key-0002")
    XCTAssertEqual(try store.readAPIKey(), "test-key-0002")

    try store.deleteAPIKey()
    XCTAssertNil(try store.readAPIKey())
    // Deleting an account that isn't there is a no-op, not an error.
    XCTAssertNoThrow(try store.deleteAPIKey())
  }

  func testAccountsAreIsolatedWithinTheSharedVault() throws {
    try store(account: "acct-1").saveAPIKey(fakeKey)
    try store(account: "acct-2").saveAPIKey("test-key-0002")

    XCTAssertEqual(try store(account: "acct-1").readAPIKey(), fakeKey)
    XCTAssertEqual(try store(account: "acct-2").readAPIKey(), "test-key-0002")

    try store(account: "acct-1").deleteAPIKey()
    XCTAssertNil(try store(account: "acct-1").readAPIKey())
    XCTAssertEqual(try store(account: "acct-2").readAPIKey(), "test-key-0002", "deleting one account must not disturb another")
  }

  /// The key has to survive a relaunch — it is on disk, not cached in the instance.
  func testKeyPersistsAcrossStoreInstances() throws {
    try store().saveAPIKey(fakeKey)

    XCTAssertEqual(try FileAPIKeyStore(directory: directory, account: "acct-1").readAPIKey(), fakeKey)
  }

  /// The whole point of the file-level encryption: no plaintext key on disk.
  func testVaultFileContainsNoPlaintextKey() throws {
    try store().saveAPIKey(fakeKey)

    let raw = try Data(contentsOf: directory.appending(path: SecretVault.vaultFileName))
    XCTAssertFalse(
      raw.range(of: Data(fakeKey.utf8)) != nil,
      "the API key must not appear verbatim in secrets.enc"
    )
  }

  func testFilesAreOwnerReadableOnly() throws {
    try store().saveAPIKey(fakeKey)

    for name in [SecretVault.keyFileName, SecretVault.vaultFileName] {
      let attributes = try FileManager.default.attributesOfItem(atPath: directory.appending(path: name).path)
      let permissions = (attributes[.posixPermissions] as? NSNumber)?.int16Value ?? 0
      XCTAssertEqual(permissions, 0o600, "\(name) should be 0600")
    }
  }

  /// A corrupt vault must self-heal (quarantine + rebuild empty) rather than throw, so a
  /// damaged file can never wedge app startup.
  func testCorruptVaultQuarantinesAndRebuilds() throws {
    let store = store()
    try store.saveAPIKey(fakeKey)

    try Data("not a valid sealed box at all".utf8)
      .write(to: directory.appending(path: SecretVault.vaultFileName))

    XCTAssertNil(try store.readAPIKey(), "a corrupt vault reads as empty instead of failing")
    try store.saveAPIKey("test-key-0003")
    XCTAssertEqual(try store.readAPIKey(), "test-key-0003", "the store stays usable after corruption")

    let quarantined = try FileManager.default
      .contentsOfDirectory(atPath: directory.path)
      .filter { $0.contains(".bak-") }
    XCTAssertFalse(quarantined.isEmpty, "the damaged file should be kept for recovery")
  }

  /// Losing the master key makes the vault permanently undecryptable, so it is quarantined
  /// and rebuilt rather than reported as an error the user can't act on.
  func testMissingMasterKeyRebuildsVault() throws {
    let store = store()
    try store.saveAPIKey(fakeKey)
    try FileManager.default.removeItem(at: directory.appending(path: SecretVault.keyFileName))

    XCTAssertNil(try store.readAPIKey())
    try store.saveAPIKey(fakeKey)
    XCTAssertEqual(try store.readAPIKey(), fakeKey)
  }
}

// MARK: - Migration

final class APIKeyMigratorTests: XCTestCase {
  /// In-memory stand-in for either side of the migration.
  private final class MemoryStore: APIKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    private let readFails: Bool
    private let writeFails: Bool

    init(value: String? = nil, readFails: Bool = false, writeFails: Bool = false) {
      self.value = value
      self.readFails = readFails
      self.writeFails = writeFails
    }

    func readAPIKey() throws -> String? {
      if readFails { throw APIKeyStoreError.keychainStatus(-25293) }
      lock.lock(); defer { lock.unlock() }
      return value
    }

    func saveAPIKey(_ key: String) throws {
      if writeFails { throw APIKeyStoreError.encryptionFailed }
      lock.lock(); defer { lock.unlock() }
      value = key
    }

    func deleteAPIKey() throws {
      lock.lock(); defer { lock.unlock() }
      value = nil
    }
  }

  private func migrator(
    sources: [String: MemoryStore],
    destinations: [String: MemoryStore],
    clearsSource: Bool = true
  ) -> APIKeyMigrator {
    APIKeyMigrator(
      makeSource: { sources[$0] ?? MemoryStore() },
      makeDestination: { destinations[$0] ?? MemoryStore() },
      clearsSource: clearsSource
    )
  }

  /// The dev build shares the Keychain account with the installed release app but keeps its
  /// own vault, so it must copy the key rather than move it — otherwise running a dev build
  /// silently empties the release app's key.
  func testDevVariantCopiesWithoutClearingTheKeychain() {
    let sources = ["a": MemoryStore(value: fakeKey)]
    let destinations = ["a": MemoryStore()]

    let moved = migrator(sources: sources, destinations: destinations, clearsSource: false)
      .migrate(accounts: ["a"])

    XCTAssertEqual(moved, 1)
    XCTAssertEqual(try destinations["a"]?.readAPIKey(), fakeKey)
    XCTAssertEqual(try sources["a"]?.readAPIKey(), fakeKey, "the Keychain entry must survive for the release app")
  }

  func testMigratesEveryAccountAndClearsTheSource() {
    let sources = ["a": MemoryStore(value: fakeKey), "b": MemoryStore(value: "test-key-0002")]
    let destinations = ["a": MemoryStore(), "b": MemoryStore()]

    let moved = migrator(sources: sources, destinations: destinations).migrate(accounts: ["a", "b"])

    XCTAssertEqual(moved, 2)
    XCTAssertEqual(try destinations["a"]?.readAPIKey(), fakeKey)
    XCTAssertEqual(try destinations["b"]?.readAPIKey(), "test-key-0002")
    XCTAssertNil(try sources["a"]?.readAPIKey(), "the Keychain entry should be cleared once migrated")
    XCTAssertNil(try sources["b"]?.readAPIKey())
  }

  /// Idempotent: rerunning on an already-migrated account changes nothing and — importantly —
  /// does not overwrite a key the user re-entered by hand.
  func testSkipsAccountsAlreadyMigratedWithoutTouchingTheSource() {
    let sources = ["a": MemoryStore(value: "test-key-old")]
    let destinations = ["a": MemoryStore(value: "test-key-new")]

    let moved = migrator(sources: sources, destinations: destinations).migrate(accounts: ["a"])

    XCTAssertEqual(moved, 0)
    XCTAssertEqual(try destinations["a"]?.readAPIKey(), "test-key-new", "an existing local key must win")
    XCTAssertEqual(try sources["a"]?.readAPIKey(), "test-key-old", "a skipped account leaves the source alone")
  }

  /// If reading the Keychain fails (e.g. the user dismisses the final auth prompt), that
  /// account keeps its source entry for the next launch and the others still migrate.
  func testKeepsSourceWhenReadFailsAndStillMigratesTheRest() {
    let sources = ["a": MemoryStore(value: fakeKey, readFails: true), "b": MemoryStore(value: "test-key-0002")]
    let destinations = ["a": MemoryStore(), "b": MemoryStore()]

    let moved = migrator(sources: sources, destinations: destinations).migrate(accounts: ["a", "b"])

    XCTAssertEqual(moved, 1)
    XCTAssertNil(try destinations["a"]?.readAPIKey())
    XCTAssertEqual(try destinations["b"]?.readAPIKey(), "test-key-0002")
  }

  /// A failed local write must not delete the Keychain entry — that would lose the key.
  func testKeepsSourceWhenDestinationWriteFails() {
    let sources = ["a": MemoryStore(value: fakeKey)]
    let destinations = ["a": MemoryStore(writeFails: true)]

    let moved = migrator(sources: sources, destinations: destinations).migrate(accounts: ["a"])

    XCTAssertEqual(moved, 0)
    XCTAssertEqual(try sources["a"]?.readAPIKey(), fakeKey, "the key must survive a failed migration")
  }
}
