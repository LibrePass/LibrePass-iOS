//
//  LibrePassCipher.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import Foundation
import CryptoKit
import SwiftUI

class LibrePassCipher: Codable {
    var id: String
    var owner: String
    var type: CipherType
    var loginData: CipherLoginData?
    var secureNoteData: CipherSecureNoteData?
    var cardData: CipherCardData?
    var collection: String?
    var favorite: Bool = false
    var rePrompt: Bool = false
    var version: Int?
    var created: Int64?
    var lastModified: Int64?
    
    init(id: String, owner: String, type: CipherType) {
        self.id = id
        self.owner = owner
        self.type = type
        self.created = Int64(Date().timeIntervalSince1970)
        self.lastModified = self.created
        
        switch self.type {
        case .Login:
            self.loginData = CipherLoginData(name: "New")
            break
        case .SecureNote:
            self.secureNoteData = CipherSecureNoteData(title: "New", note: "")
            break
        case .Card:
            self.cardData = CipherCardData(name: "New", cardholderName: "", number: "")
            break
        }
    }
    
    init(encCipher: LibrePassEncryptedCipher, key: SymmetricKey) throws {
        self.id = encCipher.id
        self.owner = encCipher.owner
        guard let type = LibrePassCipher.CipherType(rawValue: encCipher.type) else {
            throw LibrePassApiErrors.WithMessage(message: "Invalid cipher type")
        }
        self.type = type
        self.collection = encCipher.collection
        self.favorite = encCipher.favorite
        self.rePrompt = encCipher.rePrompt
        self.version = encCipher.version
        self.created = encCipher.created
        self.lastModified = encCipher.lastModified
        
        let decoder = JSONDecoder()
        switch self.type {
        case .Login:
            self.loginData = try decoder.decode(CipherLoginData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            break
        case .SecureNote:
            self.secureNoteData = try decoder.decode(CipherSecureNoteData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            break
        case .Card:
            self.cardData = try decoder.decode(CipherCardData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            break
        }
    }
    
    enum CipherType: Int, Codable {
        case Login = 0
        case SecureNote
        case Card
    }
    
    struct CipherLoginData: Codable {
        var name: String
        var username: String?
        var password: String?
        var passwordHistory: [PasswordHistory]?
        var uris: [String]?
        var twoFactor: String?
        var notes: String?
        var fields: [CustomField]?
    }
    
    struct CipherSecureNoteData: Codable {
        var title: String
        var note: String
        var fields: [CustomField]?
    }
    
    struct CipherCardData: Codable {
        var name: String
        var cardholderName: String
        var number: String
        var expMonth: Int?
        var expYear: Int?
        var code: String?
        var notes: String?
        var fields: [CustomField]?
    }
    
    struct CustomField: Codable {
        var name: String
        var type: CipherFieldType
        var value: String
    }
    
    enum CipherFieldType: Codable {
        case Text
        case Hidden
    }
    
    struct PasswordHistory: Codable {
        var password: String
        var lastUsed: Int
    }
}

extension [LibrePassEncryptedCipher] {
    mutating func addOrReplace(cipher: LibrePassEncryptedCipher) {
        if let index = self.firstIndex(where: { cipher.id == $0.id }) {
            self[index] = cipher
        } else {
            self.append(cipher)
        }
    }
    
    mutating func delete(id: String) {
        if let index = self.firstIndex(where: { id == $0.id }) {
            self.remove(at: index)
        }
    }
}
