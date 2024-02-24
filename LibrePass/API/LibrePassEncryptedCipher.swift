//
//  LibrePassEncryptedCipher.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import Foundation
import CryptoKit

class LibrePassEncryptedCipher: Codable {
    var id: String
    var owner: String
    var type: Int
    var protectedData: String
    var collection: String?
    var favorite: Bool
    var rePrompt: Bool
    var version: Int
    var created: Int64?
    var lastModified: Int64?
    
    init(cipher: LibrePassCipher, key: SymmetricKey) throws {
        self.id = cipher.id
        self.owner = cipher.owner
        
        switch cipher.type {
        case .Login:
            self.type = 0
            self.protectedData = dataToHexString(data: try aesGcmEncrypt(data: JSONEncoder().encode(cipher.loginData!), key: key))
            break
        case .SecureNote:
            self.type = 1
            self.protectedData = dataToHexString(data: try aesGcmEncrypt(data: JSONEncoder().encode(cipher.secureNoteData!), key: key))
            break
        case .Card:
            self.type = 2
            self.protectedData = dataToHexString(data: try aesGcmEncrypt(data: JSONEncoder().encode(cipher.cardData!), key: key))
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
