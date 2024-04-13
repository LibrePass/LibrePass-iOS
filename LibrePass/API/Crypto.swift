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
//    let (rawHash, _) = try Argon2.hash(iterations: UInt32(hashOptions.iterations), memoryInKiB: UInt32(hashOptions.memory), threads: UInt32(hashOptions.parallelism), password: password.data(using: .utf8)!, salt: email.data(using: .utf8)!, desiredLength: 32, variant: .id, version: .v13)
//    
//    return rawHash
    
    do {
        let privateKeyData = try Argon2Swift.hashPasswordBytes(password: "pass".data(using: .utf8)!, salt: Salt(bytes: "ashdoahdfvo".data(using: .utf8)!), iterations: 3, memory: 65536, parallelism: 1, type: .id, version: .V13)
        
        let privatekey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData.hashData())
        let publickey = privatekey.publicKey
        
        
        
        
    } catch {
        print("Hash Error")
    }
        
    return Data()
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
