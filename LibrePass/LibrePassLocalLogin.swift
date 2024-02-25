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
            SecureField("Password", text: $password)
                .autocapitalization(.none)
            ButtonWithSpinningWheel(text: "Unlock vault", task: self.login)
        }
        
        .navigationTitle("Unlock vault")
    }
    
    func login() throws {
        self.errorString = " "
        
        let credentials = try LibrePassCredentialsDatabase.load()
        lClient = try LibrePassClient(credentials: credentials, password: self.password)
            
        self.loggedIn = true
    }
}
