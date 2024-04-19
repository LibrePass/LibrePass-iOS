//
//  crypto.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import Foundation
import Argon2Swift
import CryptoKit

struct Argon2IdOptions: Codable {
    var parallelism: Int
    var memory: Int
    var iterations: Int
    var serverPublicKey: String
}

func argon2Hash(email: String, password: String, hashOptions: Argon2IdOptions) throws -> Data {
    guard let salt = email.data(using: .utf8) else {
        throw LibrePassApiErrors.WithMessage(message: "Invalid salt")
    }
    
    return try Argon2Swift.hashPasswordString(password: password, salt: Salt.init(bytes: salt), iterations: hashOptions.iterations, memory: hashOptions.memory, parallelism: hashOptions.parallelism, type: .id)
        .hashData()
}

func dataToHexString(data: Data) -> String {
    return data.map { String(format: "%02X", $0) }.joined()
}

func hexStringToData(string: String) -> Data? {
    guard string.count.isMultiple(of: 2) else {
        return nil
    }
    let chars = string.map { $0 }
    let bytes = stride(from: 0, to: chars.count, by: 2)
        .map { String(chars[$0]) + String(chars[$0 + 1]) }
        .compactMap { UInt8($0, radix: 16) }

    guard string.count / bytes.count == 2 else { return nil }

    return Data(bytes)
}

func aesGcmDecrypt(data: Data, key: SymmetricKey) throws -> Data {
    let sealedBoxRestored = try AES.GCM.SealedBox(combined: data)
    return try AES.GCM.open(sealedBoxRestored, using: key)
}

func aesGcmEncrypt(data: Data, key: SymmetricKey) throws -> Data {
    let sealed = try AES.GCM.seal(data, using: key)
    return sealed.combined!
}
