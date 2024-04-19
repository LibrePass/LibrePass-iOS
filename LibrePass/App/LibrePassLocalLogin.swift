//
//  LibrePassLocalLogin.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftUI
import SwiftData

struct LibrePassLocalLogin: View {
    @EnvironmentObject var context: LibrePassContext
    
    @Environment(\.modelContext) var modelContext
    @Query var credentials: [CredentialsDatabaseStorageItem]
    @Query var vault: [EncryptedCipherStorageItem]
    @Query var lastSyncStorage: [LastSyncStorage]
    @Query var syncQueue: [SyncQueueItem]
    
    @State private var password = String()
    
    @State private var showAlert = false
    @State private var errorString = " "
    @State private var tokenExpired = false

    var body: some View {
        List {
            Section(header: Text("Login")) {
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                ButtonWithSpinningWheel(text: "Unlock vault", task: self.logIn)
            }
            
            if self.credentials.count > 0 && self.credentials[0].biometric ?? false {
                Section(header: Text("Biometry")) {
                    Button("Face ID/Touch ID") {
                        self.biometricalLogin()
                    }
                }
            }
        }
        
        .onAppear {
            if self.credentials[0].biometric ?? false && !self.context.wasLogged {
                self.biometricalLogin()
            }
        }
        
        .alert("Token has expired. You must relogin to use LibrePass", isPresented: self.$tokenExpired) {
            Button("OK", role: .cancel) {
                do {
                    try modelContext.delete(model: CredentialsDatabaseStorageItem.self)
                    try modelContext.delete(model: EncryptedCipherStorageItem.self)
                    try modelContext.delete(model: SyncQueueItem.self)
                    try modelContext.delete(model: LastSyncStorage.self)
                    
                    self.context.locallyLoggedIn = false
                    self.context.lClient = nil
                } catch {
                    
                }
            }
        }
    }
    
    func logIn() throws {
        try self.context.localLogIn(password: self.password, credentialsDatabase: credentials[0].credentialsDatabase)
        self.context.wasLogged = true
    }
    
    func biometricalLogin() {
        Task {
            guard let password = await accessKeychain() else { return }
            self.password = password
            try? self.logIn()
        }
    }
}
