//
//  LibrePassManagerWindow.swift
//  LibrePass
//
//  Created by Zapomnij on 18/02/2024.
//

import SwiftData
import SwiftUI

struct LibrePassManagerWindow: View {
    @EnvironmentObject var context: LibrePassContext
    
    @State private var errorString: String = " "
    @State private var showAlert = false
    @State private var new = false
    
    @State var refreshIndicator: Bool = true
    @State var deletionIndicator: Bool = false
    
    @State var toDelete: IndexSet = []
    
    @State var accountSettings: Bool = false
    
    @Environment(\.modelContext) var modelContext
    @Query var vault: [EncryptedCipherStorageItem]
    @Query var syncQueue: [SyncQueueItem]
    @Query var lastStorageItem: [LastSyncStorage]
    
    var body: some View {
        NavigationView {
            List {
                if self.context.lClient != nil {
                    ForEach(vault, id: \.self.id) { encCipher in
                        let cipher = try? LibrePassCipher(encCipher: encCipher.encryptedCipher, key: self.context.lClient!.sharedKey!)
                        
                        if let cipher = cipher {
                            NavigationLink(destination: CipherView(cipher: cipher, sync: self.syncVault)) {
                                HStack {
                                    CipherButton(cipher: cipher)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        self.toDelete = indexSet
                        self.deletionIndicator = true
                    }
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
                            
                            Button(action: {
                                if let _ = try? modelContext.delete(model: EncryptedCipherStorageItem.self) {
                                    self.lastStorageItem[0].lastSync = 0
                                    self.refreshIndicator = true
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refetch ciphers")
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
                try? self.newCipher(.Login)
            }
            
            Button("Secure note") {
                try? self.newCipher(.SecureNote)
            }
            
            Button("Card data") {
                try? self.newCipher(.Card)
            }
            
            Button("Cancel", role: .cancel) {}
        }
            
        .sheet(isPresented: self.$accountSettings) {
            LibrePassAccountSettings()
        }
    }
    
    func deleteCiphers() throws {
        for index in self.toDelete {
            modelContext.insert(SyncQueueItem(operation: .Delete(id: self.vault[index].encryptedCipher.id), id: self.vault[index].encryptedCipher.id))
            if !networkMonitor.isConnected {
                modelContext.delete(self.vault[index])
            }
        }
        
        self.refreshIndicator = true
    }
    
    func newCipher(_ type: LibrePassCipher.CipherType) throws {
        let cipher = try LibrePassEncryptedCipher(cipher: LibrePassCipher(id: self.context.lClient!.generateId(vault: self.vault.toEncryptedVault()), owner: self.context.credentialsDatabase!.userId, type: type), key: self.context.lClient!.sharedKey!)
        
        modelContext.insert(SyncQueueItem(operation: .Push(cipher: cipher), id: cipher.id))
        if !networkMonitor.isConnected {
            modelContext.insert(EncryptedCipherStorageItem(encryptedCipher: cipher))
        }
        
        self.refreshIndicator = true
    }
    
    func syncVault() throws {
        if networkMonitor.isConnected {
            if let synced = try self.context.sync(syncQueue: self.syncQueue, vault: self.vault, lastSync: self.lastStorageItem[0].lastSync) {
                for updatedCipher in synced.ciphers {
                    if let index = self.vault.firstIndex(where: { updatedCipher.id == $0.encryptedCipher.id }) {
                        if let last1 = self.vault[index].encryptedCipher.lastModified, let last2 = updatedCipher.lastModified, last1 > last2 {
                            continue
                        }
                        
                        self.vault[index].encryptedCipher = updatedCipher
                    } else {
                        modelContext.insert(EncryptedCipherStorageItem(encryptedCipher: updatedCipher))
                    }
                }
                
                for cipher in self.vault {
                    if synced.ids.first(where: { cipher.encryptedCipher.id == $0 }) == nil {
                        modelContext.delete(cipher)
                    }
                }
                
                for item in self.syncQueue {
                    modelContext.delete(item)
                }
                
                lastStorageItem[0].update()
            }
        }
    }
}
