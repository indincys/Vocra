import Foundation
import Security

public protocol APIKeyStore: Sendable {
  func readAPIKey() throws -> String?
  func saveAPIKey(_ key: String) throws
  func deleteAPIKey() throws
}

public enum APIKeyStoreError: Error, Equatable, Sendable {
  case keychainStatus(OSStatus)
}

public struct KeychainAPIKeyStore: APIKeyStore {
  private let service = "com.indincys.Vocra"
  private let account = "OpenAICompatibleAPIKey"

  public init() {}

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
    try deleteAPIKey()
    var item = baseQuery()
    item[kSecValueData as String] = Data(key.utf8)
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw APIKeyStoreError.keychainStatus(status) }
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
