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
            
            Section(header: Text("WARNING! THIS WILL DELETE VAULT SAVED ON THE DISK, but can fix crashes")) {
                ButtonWithSpinningWheel(text: "Clear vault", task: self.clearVault, color: Color.red)
            }
        }
    }
    
    func clearVault() throws {
        if networkMonitor.isConnected {
            let credentials = try LibrePassCredentialsDatabase.load()
            self.lClient = try LibrePassClient(credentials: credentials, password: self.password)
            
            try self.lClient.fetchCiphers()
            
            self.lClient.unAuth()
        } else {
            throw LibrePassApiErrors.WithMessage(message: "Offline clearing vault can't be done")
        }
    }
    
    func login() throws {
        let credentials = try LibrePassCredentialsDatabase.load()
        self.lClient = try LibrePassClient(credentials: credentials, password: self.password)
        try self.lClient.syncVault()
            
        self.loggedIn = true
    }
}
