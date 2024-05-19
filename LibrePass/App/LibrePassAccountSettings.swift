//
//  LibrePassAccountSettings.swift
//  LibrePass
//
//  Created by Zapomnij on 29/02/2024.
//

import SwiftUI
import SwiftData
import Crypto

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
                if self.credentialsDatabaseStorage.count > 0 && self.credentialsDatabaseStorage[0].biometric ?? false {
                    Button("Disable biometric authentication") {
                        if self.context.lClient!.validatePassword(email: self.credentialsDatabaseStorage[0].credentialsDatabase.email, password: self.password) {
                            Task { await self.clearKeyChain() }
                        }
                    }
                } else {
                    Button("Enable biometric authentication") {
                        Task {
                            if self.context.lClient!.validatePassword(email: self.credentialsDatabaseStorage[0].credentialsDatabase.email, password: self.password) {
                                self.credentialsDatabaseStorage[0].biometric = await setUpBiometricalAuthentication(password: self.password)
                            }
                        }
                    }
                }
                
                Button("Log out", role: .destructive) {
                    Task { await self.logOut() }
                }
            }
            
            .alert("Operation is finished. You'll be logged out. If you've changed email address, check your mailbox and verify email address",isPresented: self.$done) {
                Button("OK") {
                    Task { await self.logOut() }
                }
            }
            
            .onAppear {
                self.email = self.context.credentialsDatabase!.email
            }
        }
    }
    
    func logOut() async {
        await self.clearKeyChain()
            
        try? modelContext.delete(model: CredentialsDatabaseStorageItem.self)
        try? modelContext.delete(model: EncryptedCipherStorageItem.self)
        try? modelContext.delete(model: SyncQueueItem.self)
        try? modelContext.delete(model: LastSyncStorage.self)
        
        self.context.loggedIn = false
        self.context.locallyLoggedIn = false
        self.context.lClient = nil
    }
    
    func clearKeyChain() async {
        self.credentialsDatabaseStorage[0].biometric = !(await disableBiometricAuthentication())
    }
    
    func updateCredentials() throws {
        if newPassword != "" && newPassword != newPasswordConfirm {
            throw LibrePassApiError.other("Passwords doesn't match")
        }
        
        try self.context.lClient!.updateCredentials(credentialsDatabase: self.credentialsDatabaseStorage[0].credentialsDatabase, oldPassword: password, newEmail: email, newPassword: (newPassword == "") ? nil : newPassword, newPasswordHint: newPasswordHint, vault: self.vault.toEncryptedVault())
        
        self.done = true
    }
    
    func deleteAccount() {
        do {
            try self.context.lClient!.deleteAccount(credentialsDatabase: self.credentialsDatabaseStorage[0].credentialsDatabase, password: self.password)
            
            self.done = true
        } catch {
            
        }
    }
}
