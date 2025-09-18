//
//  KeychainHelper.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/9/25.
//

//
//  KeychainHelper.swift
//
//  Simple helper for storing tokens securely
//

import Foundation
import Security

//// Save token
//KeychainHelper.shared.save(
//    session.token,
//    service: "com.myapp.auth",
//    account: "accessToken"
//)
//
//// Read token
//let token = KeychainHelper.shared.readString(
//    service: "com.myapp.auth",
//    account: "accessToken"
//)
//
//// Delete token
//KeychainHelper.shared.delete(
//    service: "com.myapp.auth",
//    account: "accessToken"
//)

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    // MARK: - Save

    func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
        ]

        // Remove any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let attributes: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
            kSecValueData as String   : data,
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    // MARK: - Read

    func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
            kSecReturnData as String  : kCFBooleanTrue as Any,
            kSecMatchLimit as String  : kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    // MARK: - Delete

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience for Strings

    func save(_ string: String, service: String, account: String) {
        if let data = string.data(using: .utf8) {
            save(data, service: service, account: account)
        }
    }

    func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
