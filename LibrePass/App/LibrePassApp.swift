//
//  LibrePassApp.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI

@main
struct LibrePassApp: App {
    
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
