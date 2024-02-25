//
//  LibrePassLoginWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI

struct LibrePassLoginWindow: View {
    @Binding var lClient: LibrePassClient
    
    @State private var email = String()
    @State private var password = String()
    @State private var apiServer = "https://api.librepass.org"
    
    @Binding var loggedIn: Bool
    
    var body: some View {
        List {
            TextField("Email", text: $email)
                .autocapitalization(.none)
            SecureField("Password", text: $password)
                .autocapitalization(.none)
            TextField("API Server", text: $apiServer)
                .autocapitalization(.none)
            
            ButtonWithSpinningWheel(text: "Log in", task: self.login)
        }
            
        .navigationTitle("Log in to LibrePass")
    }
    
    func login() throws {
        if self.email.isEmpty || self.password.isEmpty || self.apiServer.isEmpty {
            throw LibrePassApiErrors.WithMessage(message: "Empty fields")
        }
        
        lClient.unAuth()
        lClient.replaceApiClient(apiUrl: self.apiServer)
        
        try lClient.login(email: self.email, password: self.password)
        try self.lClient.fetchCiphers()
        self.loggedIn = true
    }
}
