//
//  LibrePassManagerWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftUI

struct LibrePassManagerWindow: View {
    @EnvironmentObject var context: LibrePassContext
    
    @State private var errorString: String = " "
    @State private var showAlert = false
    @State private var new = false
    
    @State var refreshIndicator: Bool = false
    @State var deletionIndicator: Bool = false
    
    @State var toDelete: IndexSet = []
    
    @State var accountSettings: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(self.context.lClient!.vault.vault, id: \.self.id) { cipher in
                    let index = self.context.lClient!.vault.vault.firstIndex(where: { vaultCipher in vaultCipher.id == cipher.id })!
                    
                    NavigationLink(destination: CipherView(cipher: cipher, index: index)) {
                        HStack {
                            CipherButton(cipher: cipher)
                            
                            Spacer()
                        }
                    }
                }
                .onDelete { indexSet in
                    self.toDelete = indexSet
                    self.deletionIndicator = true
                }
            }
        
            .navigationTitle("Vault")
            .toolbar {
                HStack {
                    SpinningWheel(isPresented: self.$deletionIndicator, task: self.deleteCiphers)
                    SpinningWheel(isPresented: self.$refreshIndicator, task: self.syncVault)
                    
                    if !self.refreshIndicator && !self.deletionIndicator {
                        Button(action: {
                            self.refreshIndicator = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Menu {
                            Button(action: {
                                self.accountSettings = true
                            }) {
                                Image(systemName: "gearshape")
                                Text("Account settings")
                            }
                            
                            Button(action: {
                                self.context.unAuth()
                            }) {
                                Image(systemName: "lock")
                                Text("Lock vault")
                            }
                            
                            Button(action: {
                                self.new.toggle()
                            }) {
                                Image(systemName: "plus")
                                Text("New cipher")
                            }
                        } label: {
                            Image(systemName: ("ellipsis.circle"))
                        }
                    }
                }
            }
        }
        
        .alert(self.errorString, isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
                self.context.unAuth()
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
        
        .sheet(isPresented: self.$accountSettings) {
            LibrePassAccountSettings()
        }
    }
    
    func syncVault() throws {
        try self.context.lClient!.syncVault()
    }
    
    func deleteCiphers() throws {
        Task {
            for index in self.toDelete {
                try self.context.lClient!.delete(id: self.context.lClient!.vault.vault[index].id)
            }
        }
    }
    
    func newCipher(type: LibrePassCipher.CipherType) {
        Task {
            let cipher = LibrePassCipher(id: self.context.lClient!.generateId(), owner: self.context.lClient!.credentialsDatabase!.userId, type: type)
            
            do {
                try self.context.lClient!.put(cipher: cipher)
            } catch ApiClientErrors.StatusCodeNot200(let statusCode, let body){
                self.errorString = String(statusCode) + ": " + body.error
                self.showAlert = true
            } catch {
                self.errorString = error.localizedDescription
                self.showAlert = true
            }
        }
    }
}
