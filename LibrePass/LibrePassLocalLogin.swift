//
//  LibrePassLocalLogin.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftUI

struct LibrePassLocalLogin: View {
    @Binding var lClient: LibrePassClient
    @Binding var loggedIn: Bool
    
    @State private var password = String()
    
    @State private var showAlert = false
    @State private var errorIndicator = " "
    
    var body: some View {
        NavigationView {
            List {
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                Button("Log in") {
                    self.errorIndicator = " "
                    
                    do {
                        let credentials = try LibrePassCredentialsDatabase.load()
                        lClient = try LibrePassClient(credentials: credentials, password: self.password)
                        
                        try lClient.syncVault()
                        
                        self.loggedIn = true
                    } catch LibrePassApiErrors.WithMessage(let message) {
                        self.errorIndicator = message
                        if message == "Invalid credentials" {
                            self.password = ""
                        }
                        self.showAlert = true
                    } catch {
                        self.errorIndicator = error.localizedDescription
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
