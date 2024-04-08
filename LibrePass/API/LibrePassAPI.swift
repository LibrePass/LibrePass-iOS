// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import CryptoKit
import SwiftUI

struct LibrePassClient {
    var client: ApiClient
    var loginData: LoginData?
    var sharedKey: SymmetricKey?
    var credentialsDatabase: LibrePassCredentialsDatabase?
    var vault: LibrePassDecryptedVault
    
    init(apiUrl: String) {
        self.client = ApiClient(apiUrl: apiUrl)
        self.vault = LibrePassDecryptedVault(lastSync: 0)
    }
    
    init(credentials: LibrePassCredentialsDatabase, password: String) throws {
        self.init(apiUrl: credentials.apiUrl)
        self.client.accessToken = credentials.accessToken
        self.loginData = LoginData(userId: credentials.userId, apiKey: credentials.accessToken, verified: true)
        
        let publicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: hexStringToData(string: credentials.publicKey)!)
        let privateKeyData = try argon2Hash(email: credentials.email, password: password, hashOptions: credentials.argon2idParams)
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        if publicKey.rawRepresentation != privateKey.publicKey.rawRepresentation {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        let serializedSharedKey = try privateKey.sharedSecretFromKeyAgreement(with: publicKey).withUnsafeBytes {
            return Data(Array($0))
        }
        
        self.sharedKey = SymmetricKey(data: serializedSharedKey)
        self.credentialsDatabase = credentials
    }
    
    func getKeys(email: String, password: String, argon2options: Argon2IdOptions) throws -> (Data, Data, Data) {
        let privateKeyData = try argon2Hash(email: email, password: password, hashOptions: argon2options)
        
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        
        let sharedKey = try privateKey.sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: hexStringToData(string: argon2options.serverPublicKey)!))
        
        let sharedKeyData = sharedKey.withUnsafeBytes {
            return Data(Array($0))
        }
        
        let publicKeyData = privateKey.publicKey.rawRepresentation.withUnsafeBytes {
            return Data(Array($0))
        }
        
        return (privateKeyData, publicKeyData, sharedKeyData)
    }
    
    func preLogin(email: String) throws -> Argon2IdOptions {
        let body = try self.client.request(path: "/api/auth/preLogin?email=" + email, body: nil, method: "GET")
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Argon2IdOptions.self, from: body)
        } catch {
            throw error
        }
    }
    
    func register(email: String, password: String, passwordHint: String) throws {
        struct RegisterRequestBody: Encodable {
            var email: String
            var passwordHint: String
            var sharedKey: String
            var publicKey: String
            var parallelism: Int
            var memory: Int
            var iterations: Int
        }
        
        let preLogin = try self.preLogin(email: "")
        let (_, publicKeyData, sharedKeyData) = try self.getKeys(email: email, password: password, argon2options: preLogin)
        
        let request = RegisterRequestBody(email: email, passwordHint: passwordHint, sharedKey: dataToHexString(data: sharedKeyData), publicKey: dataToHexString(data: publicKeyData), parallelism: preLogin.parallelism, memory: preLogin.memory, iterations: preLogin.iterations)
        
        let requestData = try JSONEncoder().encode(request)
        
        _ = try self.client.request(path: "/api/auth/register", body: requestData, method: "POST")
    }
    
    mutating func login(email: String, password: String) throws {
        struct LoginRequestBody: Encodable {
            var email: String
            var sharedKey: String
        }
        
        let preLogin = try self.preLogin(email: email)
        
        let (privateKeyData, _, sharedKeyData) = try self.getKeys(email: email, password: password, argon2options: preLogin)
        
        let encoder = JSONEncoder()
        let loginRequestData = LoginRequestBody(email: email, sharedKey: dataToHexString(data: sharedKeyData))
        let loginRequestBody = try encoder.encode(loginRequestData)
        
        let loginResponse = try self.client.request(path: "/api/auth/oauth?grantType=login", body: loginRequestBody, method: "POST")
        
        let decoder = JSONDecoder()
        self.loginData = try decoder.decode(LoginData.self, from: loginResponse)
        self.client.accessToken = self.loginData!.apiKey
        
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        let sharedKeySerialized = try privateKey.sharedSecretFromKeyAgreement(with: privateKey.publicKey).withUnsafeBytes {
            return Data(Array($0))
        }
        self.sharedKey = SymmetricKey(data: sharedKeySerialized)
        
        let privateKeySerialized = privateKey.publicKey.rawRepresentation.withUnsafeBytes {
            return Data(Array($0))
        }
            
        self.credentialsDatabase = LibrePassCredentialsDatabase(userId: self.loginData!.userId, email: email, apiUrl: self.client.apiUrl, accessToken: self.client.accessToken!, publicKey: dataToHexString(data: privateKeySerialized), argon2idParams: preLogin)
        try self.credentialsDatabase!.save()
    }
    
    mutating func replaceApiClient(apiUrl: String) {
        self.client = ApiClient(apiUrl: apiUrl)
    }
    
    mutating func logOut() {
        UserDefaults.standard.removeObject(forKey: "credentialsDatabase")
        UserDefaults.standard.removeObject(forKey: "vault")
        UserDefaults.standard.removeObject(forKey: "queue")
        
        self.unAuth()
    }
    
    mutating func unAuth() {
        self.client = ApiClient(apiUrl: self.client.apiUrl)
        self.loginData = nil
        self.sharedKey = nil
        self.credentialsDatabase = nil
        self.vault = LibrePassDecryptedVault(lastSync: 0)
    }
    
    mutating func fetchCiphers() throws {
        UserDefaults.standard.removeObject(forKey: "vault")
        try self.syncVault(request: SyncRequest(lastSyncTimestamp: 0, updated: [], deleted: []))
    }
    
    struct SyncRequest: Codable {
        var lastSyncTimestamp: Int64
        var updated: [LibrePassEncryptedCipher]
        var deleted: [String]
    }
    
    mutating func syncVault() throws {
        var updated: [LibrePassEncryptedCipher] = []
        let encryptedVault = try LibrePassEncryptedVault.loadVault()
        
        for (index, element) in encryptedVault.toSync.enumerated() {
            if element {
                updated.append(encryptedVault.vault[index])
            }
        }
        
        let syncRequest = SyncRequest(lastSyncTimestamp: encryptedVault.lastSync, updated: updated, deleted: self.vault.idstoDelete)
        try self.syncVault(request: syncRequest)
    }
    
    mutating func syncVault(request: SyncRequest) throws {
        struct SyncResponse: Codable {
            var ids: [String]
            var ciphers: [LibrePassEncryptedCipher]
        }
        
        self.vault = try LibrePassEncryptedVault.loadVault().decryptVault(key: self.sharedKey!)
        
        var syncRequest = request
        if syncRequest.lastSyncTimestamp == -2 {
            syncRequest.lastSyncTimestamp = self.vault.lastSync
        }
        
        if networkMonitor.isConnected {
            let syncRequestJSON = try JSONEncoder().encode(syncRequest)
            let resp = try self.client.request(path: "/api/cipher/sync", body: syncRequestJSON, method: "POST")
            let updated = try JSONDecoder().decode(SyncResponse.self, from: resp)
            
            for id in updated.ids {
                if let newCipher = updated.ciphers.first(where: { $0.id == id }) {
                    if let cipher = self.vault.vault.first(where: { $0.id == id }), let last1 = cipher.lastModified, let last2 = newCipher.lastModified, last1 > last2 {
                        continue
                    }
                    
                    try self.vault.addOrReplace(cipher: try LibrePassCipher(encCipher: newCipher, key: self.sharedKey!), toSync: false, save: false)
                }
            }
            
            for cipher in self.vault.vault {
                if updated.ids.first(where: { $0 == cipher.id }) == nil {
                    try self.vault.remove(cipher: cipher, save: false)
                }
            }
            
            self.vault.lastSync = Int64(Date().timeIntervalSince1970)
            try self.vault.encryptVault().saveVault()
        }
    }
    
    mutating func put(encryptedCipher: LibrePassEncryptedCipher) throws {
        if networkMonitor.isConnected {
            try self.syncVault(request: SyncRequest(lastSyncTimestamp: -2, updated: [encryptedCipher], deleted: []))
        } else {
            try self.vault.addOrReplace(cipher: LibrePassCipher(encCipher: encryptedCipher, key: self.sharedKey!), toSync: true, save: true)
        }
    }
    
    mutating func put(cipher: LibrePassCipher) throws {
        let encrypted = try LibrePassEncryptedCipher(cipher: cipher, key: self.sharedKey!)
    
        try self.put(encryptedCipher: encrypted)
    }
    
    mutating func delete(id: String) throws {
        if networkMonitor.isConnected {
            try self.syncVault(request: SyncRequest(lastSyncTimestamp: -2, updated: [], deleted: [id]))
        } else {
            self.vault.idstoDelete.append(id)
            try self.vault.remove(id: id, save: true)
        }
    }
    
    mutating func updateCredentials(email: String, password: String, passwordHint: String, oldSharedKey: String) throws {
        struct CompactCipher: Codable {
            var id: String
            var data: String
        }
        
        struct LibrePassChangeEmailRequest: Codable {
            var newEmail: String
            var oldSharedKey: String
            var newPublicKey: String
            var newSharedKey: String
            var ciphers: [CompactCipher]
        }
        
        struct LibrePassChangePasswordRequest: Codable {
            var oldSharedKey: String
            var newPublicKey: String
            var newSharedKey: String
            var passwordHint: String
            var parallelism: Int
            var memory: Int
            var iterations: Int
            var ciphers: [CompactCipher]
        }
        
        let (newPrivateData, newPublicData, newSharedData) = try self.getKeys(email: email, password: password, argon2options: self.credentialsDatabase!.argon2idParams)
        
        let vaultEncryptionKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: newPrivateData).sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: newPublicData)).withUnsafeBytes {
            return Data(Array($0))
        }
        
        var newVault = self.vault
        newVault.key = SymmetricKey(data: vaultEncryptionKey)
        
        var encryptedVault = try newVault.encryptVault()
        var compactCiphers: [CompactCipher] = []
        for j in encryptedVault.vault {
            compactCiphers.append(CompactCipher(id: j.id, data: j.protectedData))
        }
        
        var requestBody: Data
        var path: String
        if email != self.credentialsDatabase!.email {
            let requestStruct = LibrePassChangeEmailRequest(newEmail: email, oldSharedKey: oldSharedKey, newPublicKey: dataToHexString(data: newPublicData), newSharedKey: dataToHexString(data: newSharedData), ciphers: compactCiphers)
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/email"
        } else if dataToHexString(data: newSharedData) != oldSharedKey {
            let requestStruct = LibrePassChangePasswordRequest(oldSharedKey: oldSharedKey, newPublicKey: dataToHexString(data: newPublicData), newSharedKey: dataToHexString(data: newSharedData), passwordHint: passwordHint, parallelism: self.credentialsDatabase!.argon2idParams.parallelism, memory: self.credentialsDatabase!.argon2idParams.memory, iterations: self.credentialsDatabase!.argon2idParams.iterations, ciphers: compactCiphers)
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/password"
        } else {
            throw LibrePassApiErrors.WithMessage(message: "Nothing is to be changed")
        }
        
        _ = try self.client.request(path: path, body: requestBody, method: "PATCH")
    }
    
    func deleteAccount(password: String) throws {
        struct LibrePassDeleteAccountRequest: Codable {
            var sharedKey: String
            var code: String
        }
        
        let (_, oldPublicData, oldSharedData) = try self.getKeys(email: self.credentialsDatabase!.email, password: password, argon2options: self.credentialsDatabase!.argon2idParams)
        
        if dataToHexString(data: oldPublicData) != self.credentialsDatabase!.publicKey {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        let request = LibrePassDeleteAccountRequest(sharedKey: dataToHexString(data: oldSharedData), code: "")
        let requestBody = try JSONEncoder().encode(request)
        
        _ = try self.client.request(path: "/api/user/delete", body: requestBody, method: "DELETE")
    }
    
    func generateId() -> String {
        var uuid = UUID().uuidString.lowercased()
        while self.vault.vault.firstIndex(where: { cipher in cipher.id == uuid }) != nil {
            uuid = UUID().uuidString.lowercased()
        }
        
        return uuid
    }
}

struct LoginData: Codable {
    var userId: String
    var apiKey: String
    var verified: Bool
}

enum LibrePassApiErrors: Error {
    case WithMessage(message: String)
}
