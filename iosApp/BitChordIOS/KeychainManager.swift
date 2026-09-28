import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.music.bitchord"
    private let accessGroup: String? = nil
    
    private init() {}
    
    // MARK: - Generic Password Operations
    func set(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        try set(data, for: key)
    }
    
    func get(for key: String) throws -> String? {
        guard let data = try getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func setData(_ data: Data, for key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }
    
    func getData(for key: String) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        
        return result as? Data
    }
    
    func delete(for key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
    
    func deleteAll() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Codable Support
    func setCodable<T: Codable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder().encode(value)
        try setData(data, for: key)
    }
    
    func getCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T? {
        guard let data = try getData(for: key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Errors
enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unexpectedStatus(OSStatus)
    
    init(status: OSStatus) {
        switch status {
        case errSecDuplicateItem: self = .duplicateItem
        case errSecItemNotFound: self = .itemNotFound
        case errSecParam: self = .invalidData
        default: self = .unexpectedStatus(status)
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Item already exists in keychain"
        case .itemNotFound: return "Item not found in keychain"
        case .invalidData: return "Invalid data for keychain operation"
        case .unexpectedStatus(let status): return "Keychain error: \(status)"
        }
    }
}