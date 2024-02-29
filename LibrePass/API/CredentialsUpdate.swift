//
//  CredentialsUpdate.swift
//  LibrePass
//
//  Created by Zapomnij on 28/02/2024.
//

import Foundation

extension LibrePassClient {
    struct LibrePassChangePasswordRequest: Codable {
        var oldSharedKey: String
        var newPublicKey: String
        var newSharedKey: String
        var newPasswordHint: String
        var parallelism: Int
        var memory: Int
        var iterations: Int
    }
    
    mutating func changePassword(currentPassword: String, newPassword: String, newPasswordHint: String) throws {
        
    }
}
