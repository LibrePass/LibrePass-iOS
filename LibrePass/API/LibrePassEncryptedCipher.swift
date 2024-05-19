//
//  LibrePassEncryptedCipher.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import Foundation
import Crypto
import LibCrypto

struct LibrePassEncryptedCipher: Codable {
    var id: String
    var owner: String
    var type: Int
    var protectedData: String
    var collection: String?
    var favorite: Bool
    var rePrompt: Bool
    var version: Int?
    var created: Int64?
    var lastModified: Int64?
    
    init(cipher: LibrePassCipher, key: SymmetricKey) throws {
        self.id = cipher.id
        self.owner = cipher.owner
        
        self.type = cipher.type.rawValue
        switch cipher.type {
        case .Login:
            self.protectedData = try AesGcm.encrypt(String(decoding: JSONEncoder().encode(cipher.loginData!), as: UTF8.self), key: key)
            break
        case .SecureNote:
            self.protectedData = try AesGcm.encrypt(String(decoding: JSONEncoder().encode(cipher.secureNoteData!), as: UTF8.self), key: key)
        case .Card:
            self.protectedData = try AesGcm.encrypt(String(decoding: JSONEncoder().encode(cipher.cardData!), as: UTF8.self), key: key)
            break
        }
        
        self.collection = cipher.collection
        self.favorite = cipher.favorite
        self.rePrompt = cipher.rePrompt
        self.version = cipher.version
        self.created = cipher.created
        self.lastModified = cipher.lastModified
    }
}
