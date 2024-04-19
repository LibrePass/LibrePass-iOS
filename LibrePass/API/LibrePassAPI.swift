// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import CryptoKit
import SwiftUI

struct LibrePassClient {
    var client: ApiClient
    var loginData: LoginData?
    var argon2id: Argon2IdOptions?
    var sharedKey: SymmetricKey?
    
    init(apiUrl: String) {
        self.client = ApiClient(apiUrl: apiUrl)
    }
    
    init(credentials: LibrePassCredentialsDatabase, password: String) throws {
        self.init(apiUrl: credentials.apiUrl)
        self.client.accessToken = credentials.accessToken
        self.loginData = LoginData(userId: credentials.userId, apiKey: credentials.accessToken, verified: true)
        self.argon2id = credentials.argon2idParams
        
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
    
    mutating func login(email: String, password: String) throws -> LibrePassCredentialsDatabase {
        struct LoginRequestBody: Encodable {
            var email: String
            var sharedKey: String
        }
        
        self.argon2id = try self.preLogin(email: email)
        
        let (privateKeyData, _, sharedKeyData) = try self.getKeys(email: email, password: password, argon2options: self.argon2id!)
        
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
            
        return LibrePassCredentialsDatabase(userId: self.loginData!.userId, email: email, apiUrl: self.client.apiUrl, accessToken: self.client.accessToken!, publicKey: dataToHexString(data: privateKeySerialized), argon2idParams: self.argon2id!)
    }
    
    struct SyncRequest: Codable {
        var lastSyncTimestamp: Int64
        var updated: [LibrePassEncryptedCipher]
        var deleted: [String]
    }
    
    struct SyncResponse: Codable {
        var ids: [String]
        var ciphers: [LibrePassEncryptedCipher]
    }
    
    func syncVault(toPush: [LibrePassEncryptedCipher], toDelete: [String], lastSync: Int64) throws -> SyncResponse? {
        let syncRequest = SyncRequest(lastSyncTimestamp: lastSync, updated: toPush, deleted: toDelete)
        return try self.syncVault(request: syncRequest)
    }

    func syncVault(request: SyncRequest) throws -> SyncResponse? {
        if networkMonitor.isConnected {
            let syncRequestJSON = try JSONEncoder().encode(request)
            let resp = try self.client.request(path: "/api/cipher/sync", body: syncRequestJSON, method: "POST")
            let updated = try JSONDecoder().decode(SyncResponse.self, from: resp)
            
            return updated
        }
        
        return nil
    }
    
    func validatePassword(credentialsDatabase: LibrePassCredentialsDatabase, password: String) throws -> Bool {
        let (_, oldPublicData, _) = try self.getKeys(email: credentialsDatabase.email, password: password, argon2options: credentialsDatabase.argon2idParams)
        
        if dataToHexString(data: oldPublicData) != credentialsDatabase.publicKey {
            return false
        }
        
        return true
    }
    
    mutating func updateCredentials(credentialsDatabase: LibrePassCredentialsDatabase, oldPassword: String, newEmail: String, newPassword: String?, newPasswordHint: String?, vault: [LibrePassEncryptedCipher]) throws {
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
        
        let (_, oldPublicData, oldSharedData) = try self.getKeys(email: credentialsDatabase.email, password: oldPassword, argon2options: credentialsDatabase.argon2idParams)
        if dataToHexString(data: oldPublicData) != credentialsDatabase.publicKey {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        let preLogin = try self.preLogin(email: newEmail)
        let (newPrivateData, newPublicData, newSharedData) = try self.getKeys(email: newEmail, password: newPassword ?? oldPassword, argon2options: preLogin)
        
        let vaultEncryptionKey = SymmetricKey(data: try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: newPrivateData).sharedSecretFromKeyAgreement(with: try Curve25519.KeyAgreement.PublicKey(rawRepresentation: newPublicData)))
        
        var compactCiphers: [CompactCipher] = []
        for j in vault {
            let reencryptedCipher = try LibrePassEncryptedCipher(cipher: LibrePassCipher(encCipher: j, key: self.sharedKey!), key: vaultEncryptionKey)
            compactCiphers.append(CompactCipher(id: reencryptedCipher.id, data: reencryptedCipher.protectedData))
        }
        
        var requestBody: Data
        var path: String
        if newEmail != credentialsDatabase.email {
            let requestStruct = LibrePassChangeEmailRequest(newEmail: newEmail, oldSharedKey: dataToHexString(data: oldSharedData), newPublicKey: dataToHexString(data: newPublicData), newSharedKey: dataToHexString(data: newSharedData), ciphers: compactCiphers)
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/email"
        } else if let passwordHint = newPasswordHint, dataToHexString(data: newSharedData) != dataToHexString(data: oldSharedData) {
            let requestStruct = LibrePassChangePasswordRequest(oldSharedKey: dataToHexString(data: oldSharedData), newPublicKey: dataToHexString(data: newPublicData), newSharedKey: dataToHexString(data: newSharedData), passwordHint: passwordHint, parallelism: preLogin.parallelism, memory: preLogin.memory, iterations: preLogin.iterations, ciphers: compactCiphers)
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/password"
        } else {
            throw LibrePassApiErrors.WithMessage(message: "Nothing is to be changed")
        }
        
        _ = try self.client.request(path: path, body: requestBody, method: "PATCH")
    }
    
    func deleteAccount(password: String, credentialsDatabase: LibrePassCredentialsDatabase) throws {
        struct LibrePassDeleteAccountRequest: Codable {
            var sharedKey: String
            var code: String
        }
        
        let (_, oldPublicData, oldSharedData) = try self.getKeys(email: credentialsDatabase.email, password: password, argon2options: credentialsDatabase.argon2idParams)
        
        if dataToHexString(data: oldPublicData) != credentialsDatabase.publicKey {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        let request = LibrePassDeleteAccountRequest(sharedKey: dataToHexString(data: oldSharedData), code: "")
        let requestBody = try JSONEncoder().encode(request)
        
        _ = try self.client.request(path: "/api/user/delete", body: requestBody, method: "DELETE")
    }
    
    func generateId(vault: [LibrePassEncryptedCipher]) -> String {
        var uuid = UUID().uuidString.lowercased()
        while vault.firstIndex(where: { cipher in cipher.id == uuid }) != nil {
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
