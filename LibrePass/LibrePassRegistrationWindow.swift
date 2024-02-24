//
//  LibrePassRegistrationWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 24/02/2024.
//

import SwiftUI

struct LibrePassRegistrationWindow: View {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var lClient: LibrePassClient
    
    @State var apiServer = "https://api.librepass.org"
    @State var email = String()
    @State var password = String()
    @State var confirmPassword = String()
    @State var passwordHint = String()
    @State var showAlert = false
    @State var registered = false
    
    @State var errorIndicator = " "
    
    var body: some View {
        NavigationView {
            List {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                SecureField("Confirm password", text: $confirmPassword)
                    .autocapitalization(.none)
                TextField("Password hint", text: $passwordHint)
                TextField("API server", text: $apiServer)
                    .autocapitalization(.none)
                
                Button("Register") {
                    if self.confirmPassword != self.password {
                        self.confirmPassword = ""
                        
                        self.errorIndicator = "Password doesn't match"
                        return
                    }
                    
                    do {
                        self.lClient.replaceApiClient(apiUrl: apiServer)
                        try self.lClient.register(email: self.email, password: self.password, passwordHint: self.passwordHint)
                        
                        self.errorIndicator = "Check your mailbox, verify email and log in"
                        self.registered = true
                        self.showAlert = true
                    } catch {
                        self.errorIndicator = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
            
            .navigationTitle("Registration")
        }
        
        .alert(self.errorIndicator, isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
                if self.registered {
                    self.registered = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

