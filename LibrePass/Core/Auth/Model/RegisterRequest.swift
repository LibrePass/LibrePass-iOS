//
//  RegisterRequest.swift
//  LibrePass
//
//  Created by Nish on 2024-04-15.
//

import Foundation

struct RegisterRequest: Codable {
    let email: String
    let passwordHint: String?
    let sharedKey: String
    let parallelism: Int
    let memory: Int
    let iterations: Int
    let publicKey: String
}
