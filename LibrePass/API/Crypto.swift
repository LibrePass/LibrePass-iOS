//
//  crypto.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import Foundation
import LibCrypto
import Crypto

struct Argon2IdOptions: Codable {
    var parallelism: Int
    var memory: Int
    var iterations: Int
    var serverPublicKey: String
    
    func hash(email: String, password: String) throws -> String {
        guard let salt = email.data(using: .utf8) else {
            throw LibrePassApiError.other("Invalid salt")
        }
        
        return try Argon2(parallelism: self.parallelism, memory: self.memory, iterations: self.iterations)
            .hashPasswordString(password: password, salt: Salt(bytes: salt))
            .hexString()
    }
}
