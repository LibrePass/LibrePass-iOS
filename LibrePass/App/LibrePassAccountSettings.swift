//
//  LibrePassAccountSettings.swift
//  LibrePass
//
//  Created by Zapomnij on 29/02/2024.
//

import SwiftUI
import SwiftData
import CryptoKit

struct LibrePassAccountSettings: View {
    @EnvironmentObject var context: LibrePassContext
    
    @Environment(\.modelContext) var modelContext
    @Query var vault: [EncryptedCipherStorageItem]
    @Query var credentialsDatabaseStorage: [CredentialsDatabaseStorageItem]
    @Query var lastSyncStorage: [LastSyncStorage]
    @Query var syncQueue: [SyncQueueItem]
    
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
                ButtonWithSpinningWheel(text: "Update credentials", task: self.updateCredentials)
                Button("Delete account", role: .destructive) {
                    self.deleteAccount()
                }
            }
            
            Section {
                Button("Log out", role: .destructive) {
                    self.logOut()
                }
            }
            
            .alert("Operation is finished. You'll be logged out. If you've changed email address, check your mailbox and verify email address",isPresented: self.$done) {
                Button("OK") {
                    self.logOut()
                }
            }
            
            .onAppear {
                self.email = self.context.credentialsDatabase!.email
            }
        }
    }
    
    func logOut() {
        do {
            try modelContext.delete(model: CredentialsDatabaseStorageItem.self)
            try modelContext.delete(model: EncryptedCipherStorageItem.self)
            try modelContext.delete(model: SyncQueueItem.self)
            try modelContext.delete(model: LastSyncStorage.self)
            
            self.context.loggedIn = false
            self.context.locallyLoggedIn = false
            self.context.lClient = nil
        } catch {
            
        }
    }
    
    func updateCredentials() throws {
        if newPassword != "" && newPassword != newPasswordConfirm {
            throw LibrePassApiErrors.WithMessage(message: "Passwords doesn't match")
        }
        
        try self.context.lClient!.updateCredentials(credentialsDatabase: self.credentialsDatabaseStorage[0].credentialsDatabase, oldPassword: password, newEmail: email, newPassword: (newPassword == "") ? nil : newPassword, newPasswordHint: newPasswordHint, vault: self.vault.toEncryptedVault())
        
        self.done = true
    }
    
    func deleteAccount() {
        do {
            try self.context.lClient!.deleteAccount(password: self.password, credentialsDatabase: self.credentialsDatabaseStorage[0].credentialsDatabase)
            
            self.done = true
        } catch {
            
        }
    }
}
