//
//  UserCredentialResponse.swift
//  LibrePass
//
//  Created by Nish on 2024-04-14.
//

import Foundation

class UserCredentialResponse: Decodable {
    let userId: UUID
    let apiKey: String
    let verified: Bool
}
