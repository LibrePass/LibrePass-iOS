//
//  LibrePassLoginWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI

struct LibrePassLoginWindow: View {
    @EnvironmentObject var context: LibrePassContext
    @Environment(\.modelContext) var modelContext
    
    @State private var email = String()
    @State private var password = String()
    @State private var apiServer = "https://api.librepass.org"
    
    var body: some View {
        List {
            TextField("Email", text: $email)
                .autocapitalization(.none)
            SecureField("Password", text: $password)
                .autocapitalization(.none)
            TextField("API Server", text: $apiServer)
                .autocapitalization(.none)
            
            ButtonWithSpinningWheel(text: "Log in", task: {
                modelContext.insert(try self.context.logIn(email: self.email, password: self.password, apiUrl: self.apiServer))
                modelContext.insert(LastSyncStorage(lastSync: 0))
            })
        }
            
        .navigationTitle("Log in to LibrePass")
    }
}
