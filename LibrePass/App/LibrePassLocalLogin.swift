//
//  LibrePassLocalLogin.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftUI

struct LibrePassLocalLogin: View {
    @EnvironmentObject var context: LibrePassContext
    
    @State private var password = String()
    
    @State private var showAlert = false
    @State private var errorString = " "
    @State private var tokenExpired = false

    var body: some View {
        List {
            Section(header: Text("Login")) {
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                ButtonWithSpinningWheel(text: "Unlock vault", task: { try self.context.localLogIn(password: self.password) })
            }
            
            Section(header: Text("WARNING! THIS WILL DELETE VAULT SAVED ON THE DISK, but can fix crashes")) {
                ButtonWithSpinningWheel(text: "Clear vault", task: { try self.context.clearVault(password: self.password )}, color: Color.red)
            }
        }
        
        .alert("Token has expired. You must relogin to use LibrePass", isPresented: self.$tokenExpired) {
            Button("OK", role: .cancel) {
                self.context.lClient!.logOut()
            }
        }
    }
}
