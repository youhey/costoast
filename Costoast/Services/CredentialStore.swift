//
//  CredentialStore.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation
import Security

enum CredentialStoreError: Error, LocalizedError {
    case encodeFailed
    case decodeFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodeFailed:
            "Credentials could not be encoded."
        case .decodeFailed:
            "Credentials could not be decoded."
        case .keychain(let status):
            "Keychain error: \(status)"
        }
    }
}

final class CredentialStore {
    private let service = "youhey.Costoast.billingCredentials"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheLock = NSLock()
    private var credentialsCache: [UUID: CachedCredentials] = [:]

    func saveCredentials(_ credentials: BillingCredentials, for cardID: UUID) throws {
        if credentials.isEmpty {
            try deleteCredentials(for: cardID)
            return
        }

        guard let data = try? encoder.encode(credentials) else {
            throw CredentialStoreError.encodeFailed
        }

        let query = baseQuery(for: cardID)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            setCached(.credentials(credentials), for: cardID)
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.keychain(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CredentialStoreError.keychain(addStatus)
        }
        setCached(.credentials(credentials), for: cardID)
    }

    func loadCredentials(for cardID: UUID) throws -> BillingCredentials? {
        try loadCredentialsForRefresh(cardID: cardID)
    }

    func loadCredentialsForRefresh(cardID: UUID) throws -> BillingCredentials? {
        if let cached = cachedCredentials(for: cardID) {
            return cached.value
        }

        let credentials = try loadCredentialsFromKeychain(for: cardID)
        setCached(credentials.map(CachedCredentials.credentials) ?? .missing, for: cardID)
        return credentials
    }

    func loadCredentialsForDisplay(cardID: UUID) throws -> BillingCredentials? {
        let credentials = try loadCredentialsFromKeychain(for: cardID)
        setCached(credentials.map(CachedCredentials.credentials) ?? .missing, for: cardID)
        return credentials
    }

    func preloadCredentials(for cardIDs: [UUID]) {
        for cardID in cardIDs where cachedCredentials(for: cardID) == nil {
            do {
                guard let credentials = try loadCredentialsFromKeychain(for: cardID) else {
                    setCached(.missing, for: cardID)
                    continue
                }
                setCached(.credentials(credentials), for: cardID)
            } catch {
                continue
            }
        }
    }

    private func loadCredentialsFromKeychain(for cardID: UUID) throws -> BillingCredentials? {
        var query = baseQuery(for: cardID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw CredentialStoreError.keychain(status)
        }

        guard
            let data = item as? Data,
            let credentials = try? decoder.decode(BillingCredentials.self, from: data)
        else {
            throw CredentialStoreError.decodeFailed
        }

        return credentials
    }

    func deleteCredentials(for cardID: UUID) throws {
        let status = SecItemDelete(baseQuery(for: cardID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
        removeCachedCredentials(for: cardID)
    }

    private func baseQuery(for cardID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cardID.uuidString
        ]
    }

    private func cachedCredentials(for cardID: UUID) -> CachedCredentials? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return credentialsCache[cardID]
    }

    private func setCached(_ cachedCredentials: CachedCredentials, for cardID: UUID) {
        cacheLock.lock()
        credentialsCache[cardID] = cachedCredentials
        cacheLock.unlock()
    }

    private func removeCachedCredentials(for cardID: UUID) {
        cacheLock.lock()
        credentialsCache.removeValue(forKey: cardID)
        cacheLock.unlock()
    }
}

private enum CachedCredentials {
    case credentials(BillingCredentials)
    case missing

    var value: BillingCredentials? {
        switch self {
        case .credentials(let credentials):
            credentials
        case .missing:
            nil
        }
    }
}
