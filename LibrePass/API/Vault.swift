//
//  Vault.swift
//  LibrePass
//
//  Created by Zapomnij on 22/02/2024.
//

import Foundation
import CryptoKit

struct LibrePassEncryptedVault: Codable {
    var vault: [LibrePassEncryptedCipher] = []
    var toSync: [Bool] = []
    var idsToDelete: [String] = []
    var lastSync: Int64
    
    static func loadVault() throws -> Self {
        let vaultJson = UserDefaults.standard.data(forKey: "vault")!
        
        return try JSONDecoder().decode(Self.self, from: vaultJson)
    }
    
    func saveVault() throws {
        let data = try JSONEncoder().encode(self)
        
        UserDefaults.standard.setValue(data, forKey: "vault")
    }
    
    func decryptVault(key: SymmetricKey) throws -> LibrePassDecryptedVault {
        var ciphers: LibrePassDecryptedVault = LibrePassDecryptedVault(toSync: self.toSync, idstoDelete: self.idsToDelete, lastSync: self.lastSync, key: key)
        for (i, encCipher) in self.vault.enumerated() {
            try ciphers.addOrReplace(cipher: try LibrePassCipher(encCipher: encCipher, key: key), toSync: self.toSync[i], save: false)
        }
        
        return ciphers
    }
    
    static func isVaultSavedLocally() -> Bool {
        return UserDefaults.standard.data(forKey: "vault") != nil
    }
}

struct LibrePassDecryptedVault {
    var vault: [LibrePassCipher] = []
    var toSync: [Bool] = []
    var idstoDelete: [String] = []
    var lastSync: Int64
    var key: SymmetricKey?
    
    mutating func addOrReplace(cipher: LibrePassCipher, toSync: Bool, save: Bool) throws {
        if let idx = self.vault.firstIndex(where: { ciph in ciph.id == cipher.id }) {
            self.vault[idx] = cipher
            self.toSync[idx] = toSync
        } else {
            self.vault.append(cipher)
            self.toSync.append(toSync)
        }
        
        if save {
            try self.encryptVault().saveVault()
        }
    }
    
    mutating func remove(id: String, save: Bool) throws {
        if let cipher = self.vault.first(where: { cipher in cipher.id == id }) {
            try self.remove(cipher: cipher, save: save)
        }
    }
    
    mutating func remove(cipher: LibrePassCipher, save: Bool) throws {
        if let idx = self.vault.firstIndex(where: { ciph in ciph.id == cipher.id }) {
            self.vault.remove(at: idx)
            self.toSync.remove(at: idx)
            
            if save {
                try self.encryptVault().saveVault()
            }
        }
    }
    
    func encryptVault() throws -> LibrePassEncryptedVault {
        var encCiphers: LibrePassEncryptedVault = LibrePassEncryptedVault(toSync: self.toSync, idsToDelete: self.idstoDelete, lastSync: self.lastSync)
        for cipher in self.vault {
            encCiphers.vault.append(try LibrePassEncryptedCipher(cipher: cipher, key: self.key!))
        }
        
        return encCiphers
    }
}
