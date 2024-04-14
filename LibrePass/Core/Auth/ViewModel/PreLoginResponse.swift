//
//  PreLoginResponse.swift
//  LibrePass
//
//  Created by Nish on 2024-04-13.
//

import Argon2Swift

struct PreLoginResponse: Decodable {
    let parallelism: Int
    let memory: Int
    let iterations: Int
    let serverPublicKey: String
}
