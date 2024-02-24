//
//  Vault.swift
//  LibrePass
//
//  Created by Zapomnij on 22/02/2024.
//

import Foundation
import CryptoKit

class LibrePassEncryptedVault: Codable {
    var vault: [LibrePassEncryptedCipher] = []
    var lastSync: Int64
    
    init(lastSync: Int64) {
        self.lastSync = lastSync
    }
    
    static func loadVault() throws -> Self {
        let vaultJson = UserDefaults.standard.data(forKey: "vault")!
        
        return try JSONDecoder().decode(Self.self, from: vaultJson)
    }
    
    func saveVault() throws {
        let data = try JSONEncoder().encode(self)
        
        UserDefaults.standard.setValue(data, forKey: "vault")
    }
    
    func decryptVault(key: SymmetricKey) throws -> LibrePassDecryptedVault {
        var ciphers: LibrePassDecryptedVault = LibrePassDecryptedVault(lastSync: self.lastSync)
        for encCipher in self.vault {
            ciphers.vault.append(try LibrePassCipher(encCipher: encCipher, key: key))
        }
        
        return ciphers
    }
    
    static func isVaultSavedLocally() -> Bool {
        return UserDefaults.standard.data(forKey: "vault") != nil
    }
}

class LibrePassDecryptedVault {
    var vault: [LibrePassCipher] = []
    var lastSync: Int64
    
    init(lastSync: Int64) {
        self.lastSync = lastSync
    }
    
    func encryptVault(key: SymmetricKey) throws -> LibrePassEncryptedVault {
        var encCiphers: LibrePassEncryptedVault = LibrePassEncryptedVault(lastSync: self.lastSync)
        for cipher in self.vault {
            encCiphers.vault.append(try LibrePassEncryptedCipher(cipher: cipher, key: key))
        }
        
        return encCiphers
    }
}
