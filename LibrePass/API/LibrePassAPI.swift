// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Crypto
import LibCrypto
import SwiftUI

struct LibrePassClient {
    var client: ApiClient
    var loginData: LoginData
    var keys: Keys
    
    init(client: ApiClient, loginData: LoginData, keys: Keys) {
        self.client = client
        self.loginData = loginData
        self.keys = keys
    }
    
    init(credentials: LibrePassCredentialsDatabase, password: String) throws {
        self.client = ApiClient(apiUrl: credentials.apiUrl)
        self.client.accessToken = credentials.accessToken
        self.loginData = LoginData(userId: credentials.userId, apiKey: credentials.accessToken, verified: true)
        self.keys = try Keys(email: credentials.email, password: password, argon2: credentials.argon2idParams)
        
        guard credentials.publicKey == self.keys.publicKey else {
            throw LibrePassApiError.invalidCredentials
        }
    }
    
    static func preLogin(apiClient: ApiClient, email: String) throws -> Argon2IdOptions {
        let body = try apiClient.request(path: "/api/auth/preLogin?email=" + email, body: nil, method: "GET")
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Argon2IdOptions.self, from: body)
        } catch {
            throw error
        }
    }
    
    static func register(email: String, password: String, passwordHint: String, apiUrl: String) throws {
        struct RegisterRequestBody: Encodable {
            var email: String
            var passwordHint: String
            var sharedKey: String
            var publicKey: String
            var parallelism: Int
            var memory: Int
            var iterations: Int
        }
        
        let client = ApiClient(apiUrl: apiUrl)
        let preLogin = try preLogin(apiClient: client, email: "")
        let keys = try Keys(email: email, password: password, argon2: preLogin)
        
        let requestData = try JSONEncoder().encode(
            RegisterRequestBody(
                email: email,
                passwordHint: passwordHint,
                sharedKey: keys.authenticationSharedKey,
                publicKey: keys.publicKey,
                parallelism: preLogin.parallelism,
                memory: preLogin.memory,
                iterations: preLogin.iterations
            )
        )
        
        _ = try client.request(path: "/api/auth/register", body: requestData, method: "POST")
    }
    
    struct LoginData: Codable {
        var userId: String
        var apiKey: String
        var verified: Bool
    }
    
    static func login(email: String, password: String, apiUrl: String) throws -> (LibrePassCredentialsDatabase, Self) {
        struct LoginRequestBody: Encodable {
            var email: String
            var sharedKey: String
        }
        
        let client: ApiClient
        let preLogin: Argon2IdOptions
        let keys: Keys
        let loginResponse: Data
        do {
            client = ApiClient(apiUrl: apiUrl)
            preLogin = try Self.preLogin(apiClient: client, email: email)
            keys = try Keys(email: email, password: password, argon2: preLogin)
            
            let loginRequest = try JSONEncoder().encode(
                LoginRequestBody(
                    email: email,
                    sharedKey: keys.authenticationSharedKey
                )
            )
            
            loginResponse = try client.request(path: "/api/auth/oauth?grantType=login", body: loginRequest, method: "POST")
        } catch ApiClientErrors.StatusCodeNot200(let statusCode, let body) {
            print(body.error)
            if body.error == "LP-Invalid-Body" ||
                body.error == "LP-User-404" ||
                body.error == "LP-Invalid-Shared-Secret" {
                throw LibrePassApiError.invalidCredentials
            }
            throw ApiClientErrors.StatusCodeNot200(statusCode: statusCode, body: body)
        } catch {
            print(error)
            throw error
        }
        
        let loginData = try JSONDecoder().decode(LoginData.self, from: loginResponse)
        client.accessToken = loginData.apiKey
        
        let credentialsDatabase = LibrePassCredentialsDatabase(
            userId: loginData.userId,
            email: email,
            apiUrl: apiUrl,
            accessToken: loginData.apiKey,
            publicKey: keys.publicKey,
            argon2idParams: keys.argon2
        )
        
        return (credentialsDatabase, LibrePassClient(client: client, loginData: loginData, keys: keys))
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
    
    func validatePassword(email: String, password: String) -> Bool {
        guard let keys = try? Keys(email: email, password: password, argon2: self.keys.argon2) else {
            return false
        }
        
        return self.keys.publicKey == keys.publicKey
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
        
        guard self.validatePassword(email: credentialsDatabase.email, password: oldPassword) else {
            throw LibrePassApiError.invalidCredentials
        }
        
        let preLogin = try LibrePassClient.preLogin(apiClient: self.client, email: newEmail)
        let keys = try Keys(email: newEmail, password: newPassword ?? oldPassword, argon2: preLogin)
        
        var compactCiphers: [CompactCipher] = []
        for j in vault {
            let reencryptedCipher = try LibrePassEncryptedCipher(cipher: LibrePassCipher(encCipher: j, key: self.keys.sharedKey), key: keys.sharedKey)
            compactCiphers.append(CompactCipher(id: reencryptedCipher.id, data: reencryptedCipher.protectedData))
        }
        
        var requestBody: Data
        var path: String
        if newEmail != credentialsDatabase.email {
            let requestStruct = LibrePassChangeEmailRequest(
                newEmail: newEmail,
                oldSharedKey: self.keys.authenticationSharedKey,
                newPublicKey: keys.publicKey,
                newSharedKey: keys.authenticationSharedKey,
                ciphers: compactCiphers
            )
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/email"
        } else if let passwordHint = newPasswordHint, keys.publicKey != self.keys.publicKey {
            let requestStruct = LibrePassChangePasswordRequest(
                oldSharedKey: self.keys.authenticationSharedKey,
                newPublicKey: keys.publicKey,
                newSharedKey: keys.authenticationSharedKey,
                passwordHint: passwordHint,
                parallelism: preLogin.parallelism,
                memory: preLogin.memory,
                iterations: preLogin.iterations,
                ciphers: compactCiphers
            )
            
            requestBody = try JSONEncoder().encode(requestStruct)
            path = "/api/user/password"
        } else {
            throw LibrePassApiError.other("Nothing is to be changed")
        }
        
        _ = try self.client.request(path: path, body: requestBody, method: "PATCH")
    }
    
    func deleteAccount(credentialsDatabase: LibrePassCredentialsDatabase, password: String) throws {
        struct LibrePassDeleteAccountRequest: Codable {
            var sharedKey: String
            var code: String
        }
        
        guard self.validatePassword(email: credentialsDatabase.email, password: password) else {
            throw LibrePassApiError.invalidCredentials
        }
        
        let request = LibrePassDeleteAccountRequest(sharedKey: self.keys.authenticationSharedKey, code: "")
        let requestBody = try JSONEncoder().encode(request)
        
        _ = try self.client.request(path: "/api/user/delete", body: requestBody, method: "DELETE")
    }
}
