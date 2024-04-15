//
//  Credentials.swift
//  LibrePass
//
//  Created by Nish on 2024-04-15.
//

import Foundation
import SwiftData

@Model
class Credentials {
    @Attribute(.unique) var userId: UUID
    var email: String
    var apiUrl: String?
    var apiKey: String
    var publicKey: String
    var lastSync: Int64?
    var memory: Int
    var iterations: Int
    var parallelism: Int
    
    init(
        userId: UUID,
        email: String,
        apiUrl: String? = nil,
        apiKey: String,
        publicKey: String,
        lastSync: Int64? = nil,
        memory: Int,
        iterations: Int,
        parallelism: Int
    ) {
        self.userId = userId
        self.email = email
        self.apiUrl = apiUrl
        self.apiKey = apiKey
        self.publicKey = publicKey
        self.lastSync = lastSync
        self.memory = memory
        self.iterations = iterations
        self.parallelism = parallelism
    }
    
}

