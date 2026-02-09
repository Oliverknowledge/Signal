import Foundation
import Security

#if canImport(CryptoKit)
import CryptoKit
#endif

public enum KeychainID {
  private static let service = "com.signalapp.anonid"
  private static let account = "stable_uuid"
  
  public static func stableUUID() -> String {
    if let existing = read() { return existing }
    let uuid = UUID().uuidString
    save(uuid)
    return uuid
  }
  
  public static func userIdHash() -> String {
    let uuid = stableUUID()
    return sha256(uuid)
  }
  
  private static func sha256(_ s: String) -> String {
    guard let data = s.data(using: .utf8) else { return s }
    #if canImport(CryptoKit)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
    #else
    return s
    #endif
  }
  
  private static func read() -> String? {
    let query: [String:Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess,
       let data = item as? Data,
       let str = String(data: data, encoding: .utf8) {
      return str
    }
    return nil
  }
  
  private static func save(_ value: String) {
    let data = value.data(using: .utf8) ?? Data()
    let query: [String:Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data
    ]
    SecItemAdd(query as CFDictionary, nil)
  }
}
