//
//  CredentialsDatabase.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import Foundation

struct LibrePassCredentialsDatabase: Codable {
    var userId: String
    var email: String
    var apiUrl: String
    var accessToken: String
    var publicKey: String
    var argon2idParams: Argon2IdOptions
}
