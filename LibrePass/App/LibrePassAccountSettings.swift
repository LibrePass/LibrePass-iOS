//
//  LibrePassAccountSettings.swift
//  LibrePass
//
//  Created by Zapomnij on 29/02/2024.
//

import SwiftUI
import CryptoKit

struct LibrePassAccountSettings: View {
    @EnvironmentObject var context: LibrePassContext
    
    @State var password = String()
    @State var email = String()
    @State var newPassword = String()
    @State var newPasswordConfirm = String()
    @State var newPasswordHint = String()
    
    @State var done = false
    
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
                ButtonWithSpinningWheel(text: "Update credentials", task: {
                    if newPassword != newPasswordConfirm {
                        throw LibrePassApiErrors.WithMessage(message: "Passwords doesn't match")
                    }
                    
                    try self.context.updateCredentials(oldPassword: self.password, newPassword: self.newPassword, newPasswordHint: self.newPasswordHint, newEmail: self.email)
                })
                ButtonWithSpinningWheel(text: "Delete account", task: self.deleteAccount, color: Color.red)
            }
            
            Section {
                Button("Log out", role: .destructive) {
                    self.context.logOut()
                }
            }
        }
        
        .alert("Operation is finished. You'll be logged out. If you've changed email address, check your mailbox and verify email address", isPresented: self.$done) {
            Button("OK") {
                self.context.logOut()
            }
        }
        
        .onAppear {
            self.email = self.context.lClient!.credentialsDatabase!.email
        }
    }
    
    func deleteAccount() throws {
        try self.context.lClient!.deleteAccount(password: self.password)
        self.context.logOut()
    }
}
