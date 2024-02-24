//
//  LibrePassManagerWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftUI

struct LibrePassManagerWindow: View {
    @State private var errorIndicator: String = " "
    @State private var showAlert = false
    @State private var new = false
    @State private var logOut = false
    
    @Binding var lClient: LibrePassClient
    
    @Binding var loggedIn: Bool
    @Binding var locallyLoggedIn: Bool
    var body: some View {
        NavigationView {
                List(lClient.vault.vault, id: \.id) { cipher in
                    let index = lClient.vault.vault.firstIndex(where: { vaultCipher in vaultCipher.id == cipher.id })!
                    
                    NavigationLink(destination: CipherView(lClient: $lClient, cipher: cipher, index: index)) {
                        HStack {
                            CipherButton(cipher: cipher)
                            
                            Spacer()
                        }
                    }
                }
            
                .navigationTitle("Vault")
                .toolbar {
                    HStack {
                        Button(action: {
                            self.logOut.toggle()
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundStyle(Color.red)
                            
                        }
                        Button(action: {
                            _ = try? self.lClient.syncVault()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            self.new.toggle()
                        }) {
                            Image(systemName: "plus")
                        }
                    }
            }
        }
        
        .alert(self.errorIndicator + ". Please report this bug on GitHub", isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
                lClient.unAuth()
                self.loggedIn = false
            }
        }
        
        .alert("Select cipher type", isPresented: self.$new) {
            Button("Login data") {
                self.newCipher(type: .Login)
            }
            
            Button("Secure note") {
                self.newCipher(type: .SecureNote)
            }
            
            Button("Card data") {
                self.newCipher(type: .Card)
            }
            
            Button("Cancel", role: .cancel) {}
        }
        
        .alert("Are you sure you to log out?", isPresented: self.$logOut) {
            Button("Yes", role: .destructive) {
                self.lClient.logOut()
                
                self.locallyLoggedIn = false
                self.loggedIn = false
            }
            
            Button("No", role: .cancel) {}
        }
    }
    
    func newCipher(type: LibrePassCipher.CipherType) {
        let cipher = LibrePassCipher(id: lClient.generateId(), owner: lClient.credentialsDatabase!.userId, type: type)
        
        do {
            try self.lClient.put(cipher: cipher)
        } catch ApiClientErrors.StatusCodeNot200(let statusCode){
            self.errorIndicator = String(statusCode)
            self.showAlert = true
        } catch {
            self.errorIndicator = error.localizedDescription
            self.showAlert = true
        }
    }
}
