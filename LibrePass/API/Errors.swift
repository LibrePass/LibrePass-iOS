//
//  Errors.swift
//  LibrePass
//
//  Created by Zapomnij on 18/05/2024.
//

import Foundation


enum LibrePassApiError: Error, LocalizedError {
    case invalidCredentials
    case unknown
    case other(_ error: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid credentials"
        case .unknown:
            return "Unknown error"
        case .other(let error):
            return error
        }
    }
}
