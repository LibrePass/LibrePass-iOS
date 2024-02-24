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
        self.client = ApiClient(apiUrl: credentials.apiUrl)
        self.client.accessToken = credentials.accessToken
        self.loginData = LoginData(userId: credentials.userId, apiKey: credentials.accessToken, verified: true)
        self.vault = LibrePassDecryptedVault(lastSync: 0)
        
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
        
        do {
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
        } catch ApiClientErrors.StatusCodeNot200(let statusCode) {
            if statusCode == 400 || statusCode == 401 {
                throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
            } else {
                throw LibrePassApiErrors.WithMessage(message: "Http error " + statusCode.formatted())
            }
        } catch ApiClientErrors.UnknownResponse {
            throw LibrePassApiErrors.WithMessage(message: "Unknown error")
        }
    }
    
    mutating func replaceApiClient(apiUrl: String) {
        self.client = ApiClient(apiUrl: apiUrl)
    }
    
    mutating func logOut() {
        UserDefaults.standard.removeObject(forKey: "credentialsDatabase")
        UserDefaults.standard.removeObject(forKey: "vault")
        
        self.unAuth()
    }
    
    mutating func unAuth() {
        self.client = ApiClient(apiUrl: self.client.apiUrl)
        self.loginData = nil
        self.sharedKey = nil
        self.credentialsDatabase = nil
        self.vault.vault = []
    }
    
    mutating func fetchCiphers() throws {
        let resp = try self.client.request(path: "/api/cipher", body: nil, method: "GET")
        
        let cryptedVault = LibrePassEncryptedVault(lastSync: Int64(Date().timeIntervalSince1970))
        cryptedVault.vault = try JSONDecoder().decode([LibrePassEncryptedCipher].self, from: resp)
        
        try cryptedVault.saveVault()
        
        self.vault = try cryptedVault.decryptVault(key: self.sharedKey!)
    }
    
    mutating func syncVault() throws {
        try self.vault.encryptVault(key: self.sharedKey!).saveVault()
        
        struct SyncResponse: Codable {
            var ids: [String]
            var ciphers: [LibrePassEncryptedCipher]
        }
        
        let encryptedVault = try LibrePassEncryptedVault.loadVault()
        self.vault = try encryptedVault.decryptVault(key: self.sharedKey!)
        
        do {
            let resp = try self.client.request(path: "/api/cipher/sync?lastSync=" + String(self.vault.lastSync), body: nil, method: "GET")
            
            let updated = try JSONDecoder().decode(SyncResponse.self, from: resp)
            
            var newVault: [LibrePassCipher] = []
            for (i, j) in self.vault.vault.enumerated() {
                if updated.ids.firstIndex(where: { id in j.id == id }) == nil {
                    continue
                }
                
                if let j = updated.ciphers.firstIndex(where: { cipher in cipher.id == j.id }) {
                    self.vault.vault[i] = try LibrePassCipher(encCipher: updated.ciphers[j], key: self.sharedKey!)
                }
                
                newVault.append(self.vault.vault[i])
            }
            
            for encCipher in updated.ciphers {
                if self.vault.vault.firstIndex(where: { cipher in encCipher.id == cipher.id }) == nil {
                    newVault.append(try LibrePassCipher(encCipher: encCipher, key: self.sharedKey!))
                }
            }
            
            self.vault.vault = newVault
            self.vault.lastSync = Int64(Date().timeIntervalSince1970)
            try self.vault.encryptVault(key: self.sharedKey!).saveVault()
        } catch {
            if let error = error as? URLError,  error.networkUnavailableReason == .none {
                return
            }
            
            throw error
        }
    }
    
    mutating func put(cipher: LibrePassCipher) throws {
        let encrypted = try LibrePassEncryptedCipher(cipher: cipher, key: self.sharedKey!)
        let req = try JSONEncoder().encode(encrypted)
        
        _ = try self.client.request(path: "/api/cipher", body: req, method: "PUT")
        
        if let idx = self.vault.vault.firstIndex(where: { ciph in ciph.id == cipher.id }) {
            self.vault.vault[idx] = cipher
        } else {
            self.vault.vault.append(cipher)
        }
        
        
        try self.syncVault()
    }
    
    mutating func delete(id: String) throws {
        _ = try self.client.request(path: "/api/cipher/" + id, body: nil, method: "DELETE")
        
        if let idx = self.vault.vault.firstIndex(where: { cipher in cipher.id == id }) {
            self.vault.vault.remove(at: idx)
        }
        
        try self.syncVault()
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
