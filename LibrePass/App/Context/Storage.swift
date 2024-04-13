//
//  Storage.swift
//  LibrePass
//
//  Created by Zapomnij on 08/04/2024.
//

import Foundation
import SwiftData
import SwiftUI
import CryptoKit

@Model
class EncryptedCipherStorageItem {
    var encryptedCipher: LibrePassEncryptedCipher
    
    init(encryptedCipher: LibrePassEncryptedCipher) {
        self.encryptedCipher = encryptedCipher
    }
}

extension [LibrePassEncryptedCipher] {
    func toStorageItemsArray() -> [EncryptedCipherStorageItem] {
        var ret: [EncryptedCipherStorageItem] = []
        self.forEach {
            ret.append(EncryptedCipherStorageItem(encryptedCipher: $0))
        }
        
        return ret
    }
}

extension [EncryptedCipherStorageItem] {
    func toEncryptedVault() -> [LibrePassEncryptedCipher] {
        var ret: [LibrePassEncryptedCipher] = []
        self.forEach {
            ret.append($0.encryptedCipher)
        }
        
        return ret
    }
}

@Model
class CredentialsDatabaseStorageItem {
    var credentialsDatabase: LibrePassCredentialsDatabase
    
    init(credentialsDatabase: LibrePassCredentialsDatabase) {
        self.credentialsDatabase = credentialsDatabase
    }
}

@Model
class LastSyncStorage {
    var lastSync: Int64
    
    init(lastSync: Int64) {
        self.lastSync = lastSync
    }
    
    func update() {
        self.lastSync = Int64(Date().timeIntervalSince1970)
    }
}

@Model
class SyncQueueItem {
    enum Operation: Codable {
        case Delete(id: String)
        case Push(cipher: LibrePassEncryptedCipher)
    }
    
    var operation: Operation
    var id: String
    
    init(operation: Operation, id: String) {
        self.operation = operation
        self.id = id
    }
}

extension [SyncQueueItem] {
    func toSync() -> ([LibrePassEncryptedCipher], [String]) {
        var toPush: [LibrePassEncryptedCipher] = []
        var toDelete: [String] = []
        
        self.forEach {
            switch $0.operation {
            case .Push(let cipher):
                toPush.append(cipher)
                break
            case .Delete(let id):
                toDelete.append(id)
            }
        }
        
        return (toPush, toDelete)
    }
}
