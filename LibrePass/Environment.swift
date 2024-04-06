//
//  Environment.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import Foundation

public enum Environment {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
    
    static let rootURL: String = {
        guard let rootURLstring = Environment.infoDictionary["ROOT_URL"] as? String else {
            fatalError("Root URL not set in plist for this environment")
        }
        
        return rootURLstring
    }()
}

