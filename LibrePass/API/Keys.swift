//
//  Keys.swift
//  LibrePass
//
//  Created by Zapomnij on 18/05/2024.
//

import Foundation
import Crypto
import LibCrypto
import hsauth_swift

class Keys {
    var argon2: Argon2IdOptions
    var privateKey: String
    var publicKey: String
    var sharedKey: SymmetricKey
    var authenticationSharedKey: String
    
    init(email: String, password: String, argon2: Argon2IdOptions) throws {
        self.privateKey = try argon2.hash(email: email, password: password)
        self.publicKey = try X25519.fromPrivateKey(privateKey: self.privateKey).publicKey
        self.sharedKey = try X25519.computeSharedSecret(ourPrivate: self.privateKey, theirPublic: self.publicKey)
        self.authenticationSharedKey = try KeyV1(ourPrivateKey: self.privateKey, theirPublicKey: argon2.serverPublicKey).getKey()
        
        self.argon2 = argon2
    }
}
