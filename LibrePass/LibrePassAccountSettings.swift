//
//  LibrePassAccountSettings.swift
//  LibrePass
//
//  Created by Zapomnij on 29/02/2024.
//

import SwiftUI
import CryptoKit

struct LibrePassAccountSettings: View {
    @Binding var lClient: LibrePassClient
    @Binding var locallyLoggedIn: Bool
    @Binding var loggedIn: Bool
    
    @State var password = String()
    @State var email = String()
    @State var newPassword = String()
    @State var newPasswordConfirm = String()
    @State var newPasswordHint = String()
    
    @State var done = false
    @State var logOut = false
    
    var body: some View {
        List {
            Section(header: Text("New password. Leave empty if you don't want to change")) {
                SecureField("New password", text: self.$newPassword)
                    .autocapitalization(.none)
                SecureField("Confirm password", text: self.$newPasswordConfirm)
                    .autocapitalization(.none)
                TextField("Password hint", text: self.$newPasswordHint)
            }
            
            Section(header: Text("Email")) {
                TextField("Email", text: self.$email)
                    .autocapitalization(.none)
            }
            
            Section(header: Text("Confirm action")) {
                SecureField("Current password", text: self.$password)
                    .autocapitalization(.none)
                ButtonWithSpinningWheel(text: "Update credentials", task: self.updateCredentials)
            }
            
            Section {
                Button("Log out", role: .destructive) {
                    self.logOut = true
                }
            }
        }
        
        .alert("Are you sure you want to log out?", isPresented: self.$logOut) {
            Button("Yes", role: .destructive) {
                self.lClient.logOut()
                self.locallyLoggedIn = false
                self.loggedIn = false
            }
            Button("No", role: .cancel) {}
        }
        
        .alert("Operation is finished. You'll be logged out. If you've changed email address, check your mailbox and verify email address", isPresented: self.$done) {
            Button("OK") {
                self.locallyLoggedIn = false
                self.loggedIn = false
            }
        }
        
        .onAppear {
            self.email = self.lClient.credentialsDatabase!.email
        }
    }
    
    func updateCredentials() throws {
        let (oldPrivateData, oldPublicData, oldSharedData) = try self.lClient.getKeys(email: self.lClient.credentialsDatabase!.email, password: self.password, argon2options: self.lClient.credentialsDatabase!.argon2idParams)
        
        if dataToHexString(data: oldPublicData) != self.lClient.credentialsDatabase!.publicKey {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        if email != self.lClient.credentialsDatabase!.email && !self.newPassword.isEmpty {
            throw LibrePassApiErrors.WithMessage(message: "Both settings (email and password) cannot be changed at the same time.")
        }
        
        _ = try? self.lClient.syncVault()
        
        if self.newPassword != "" {
            if self.newPassword != self.newPasswordConfirm {
                throw LibrePassApiErrors.WithMessage(message: "Passwords doesn't match")
            }
            
            self.password = self.newPassword
        }
        
        try self.lClient.updateCredentials(email: self.email, password: self.password, passwordHint: self.newPasswordHint, oldSharedKey: dataToHexString(data: oldSharedData))
        
        self.done = true
    }
}
