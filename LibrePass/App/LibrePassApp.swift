//
//  LibrePassApp.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI
import SwiftData
import KeychainSwift

@main
struct LibrePassApp: App {
    let keychain = KeychainSwift()
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .modelContainer(for: Credentials.self)
        }
    }
    
    
}

class KeychainManager {
    static let shared = KeychainSwift()
}
