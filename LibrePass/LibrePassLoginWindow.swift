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
    
    @State private var errorIndicator = " "
    @State private var showAlert = false
    
    @Binding var loggedIn: Bool
    
    var body: some View {
        NavigationView {
            List {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                TextField("API Server", text: $apiServer)
                    .autocapitalization(.none)
                
                Button("Log in") {
                    if self.email.isEmpty || self.password.isEmpty || self.apiServer.isEmpty {
                        self.errorIndicator = "Empty fields"
                        return
                    }
                    self.errorIndicator = " "
                    
                    do {
                        lClient.unAuth()
                        lClient.replaceApiClient(apiUrl: self.apiServer)
                        
                        try lClient.login(email: self.email, password: self.password)
                        try self.lClient.fetchCiphers()
                        self.loggedIn = true
                    } catch LibrePassApiErrors.WithMessage(let message) {
                        self.errorIndicator = message
                        if message == "Invalid credentials" {
                            self.password = ""
                        }
                        self.showAlert = true
                    } catch {
                        self.errorIndicator = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
            
            .navigationTitle("Log in to LibrePass")
        }
        
        .alert(self.errorIndicator, isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
