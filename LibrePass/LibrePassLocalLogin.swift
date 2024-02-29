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
    @Binding var localLogIn: Bool
    
    @State private var password = String()
    
    @State private var showAlert = false
    @State private var errorString = " "
    @State private var tokenExpired = false

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
        
        .alert("Token has expired. You must relogin to use LibrePass", isPresented: self.$tokenExpired) {
            Button("OK", role: .cancel) {
                self.localLogIn = false
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
        do {
            try self.lClient.syncVault()
        } catch ApiClientErrors.StatusCodeNot200(let statusCode, let body) {
            self.lClient.unAuth()
            if statusCode == 401 && body.error == "InvalidToken" {
                self.lClient.logOut()
                self.tokenExpired = true
                return
            } else {
                throw ApiClientErrors.StatusCodeNot200(statusCode: statusCode, body: body)
            }
        } catch {
            self.lClient.unAuth()
            throw error
        }
            
        self.loggedIn = true
    }
}
