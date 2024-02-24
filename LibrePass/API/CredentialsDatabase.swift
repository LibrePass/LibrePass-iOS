//
//  CredentialsDatabase.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import Foundation
import SwiftUI

struct LibrePassCredentialsDatabase: Codable {
    var userId: String
    var email: String
    var apiUrl: String
    var accessToken: String
    var publicKey: String
    
    var argon2idParams: Argon2IdOptions
    
    func save() throws {
        let encoded = try? JSONEncoder().encode(self)
        UserDefaults.standard.setValue(encoded, forKey: "credentialsDatabase")
    }
    
    static func load() throws -> Self {
        let data = UserDefaults.standard.data(forKey: "credentialsDatabase")!
        return try JSONDecoder().decode(Self.self, from: data)
    }
    
    static func isLocallyLoggedIn() -> Bool {
        return UserDefaults.standard.data(forKey: "credentialsDatabase") != nil
    }
}
