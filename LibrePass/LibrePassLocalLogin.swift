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
    @State private var errorString = " "

    var body: some View {
        List {
            Section(header: Text("Login")) {
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                ButtonWithSpinningWheel(text: "Unlock vault", task: self.login)
            }
            
            Section(header: Text("If you're encountering crashes after update, try clearing local saved Vault. WARNING! THIS WILL DELETE VAULT SAVED ON THE DISK")) {
                ButtonWithSpinningWheel(text: "Clear vault", task: self.clearVault, color: Color.red)
            }
        }
    }
    
    func clearVault() throws {
        self.errorString = " "
        
        let credentials = try LibrePassCredentialsDatabase.load()
        self.lClient = try LibrePassClient(credentials: credentials, password: self.password)
        
        try self.lClient.fetchCiphers()
        
        self.lClient.unAuth()
    }
    
    func login() throws {
        self.errorString = " "
        
        let credentials = try LibrePassCredentialsDatabase.load()
        self.lClient = try LibrePassClient(credentials: credentials, password: self.password)
        try self.lClient.syncVault()
            
        self.loggedIn = true
    }
}
