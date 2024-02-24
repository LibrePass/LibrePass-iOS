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
    var version: Int = 1
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
    
    convenience init(encCipher: LibrePassEncryptedCipher, key: SymmetricKey) throws {
        self.init(id: encCipher.id, owner: encCipher.owner, type: CipherType.Card)
        self.collection = encCipher.collection
        self.favorite = encCipher.favorite
        self.rePrompt = encCipher.rePrompt
        self.version = encCipher.version
        self.created = encCipher.created
        self.lastModified = encCipher.lastModified
        
        let decoder = JSONDecoder()
        switch encCipher.type {
        case 0:
            self.loginData = try decoder.decode(CipherLoginData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            self.type = CipherType.Login
            break
        case 1:
            self.secureNoteData = try decoder.decode(CipherSecureNoteData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            self.type = CipherType.SecureNote
            break
        case 2:
            self.cardData = try decoder.decode(CipherCardData.self, from: aesGcmDecrypt(data: hexStringToData(string: encCipher.protectedData)!, key: key))
            self.type = CipherType.Card
            break
        default:
            break
        }
    }
    
    enum CipherType: Codable {
        case Login
        case SecureNote
        case Card
    }
    
    struct CipherLoginData: Codable {
        var name: String
        var username: String?
        var password: String?
        var passwordHistory: [PasswordHistory]?
        var uris: [String]?
        var twoFactor: [String]?
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
