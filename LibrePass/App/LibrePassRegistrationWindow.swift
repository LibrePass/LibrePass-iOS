//
//  LibrePassRegistrationWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 24/02/2024.
//

import SwiftUI

struct LibrePassRegistrationWindow: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var context: LibrePassContext
    
    @State var apiServer = "https://api.librepass.org"
    @State var email = String()
    @State var password = String()
    @State var confirmPassword = String()
    @State var passwordHint = String()
    @State var showAlert = false
    @State var registered = false
    
    @State var errorString = " "
    
    var body: some View {
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
            
            ButtonWithSpinningWheel(text: "Register") {
                if self.confirmPassword != self.password {
                    self.confirmPassword = ""
                    
                    self.errorString = "Password doesn't match"
                    self.showAlert = true
                } else {
                    try LibrePassClient.register(email: self.email, password: self.password, passwordHint: self.passwordHint, apiUrl: self.apiServer)
                        
                    self.errorString = "Check your mailbox, verify email and log in"
                    self.registered = true
                    self.showAlert = true
                }
            }
        }
            
        .navigationTitle("Registration")
        
        .alert(self.errorString, isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
                if self.registered {
                    self.registered = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

