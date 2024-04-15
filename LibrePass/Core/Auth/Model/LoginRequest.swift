//
//  LoginRequest.swift
//  LibrePass
//
//  Created by Nish on 2024-04-14.
//

import Foundation

struct LoginRequest: Codable {
    let email: String
    let sharedKey: String
}
