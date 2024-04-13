//
//  LibrePassApp.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI
import SwiftData

@main
struct LibrePassApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        .modelContainer(for: [CredentialsDatabaseStorageItem.self, EncryptedCipherStorageItem.self, LastSyncStorage.self, SyncQueueItem.self])
    }
}

struct MainWindow: View {
    @Query var credentials: [CredentialsDatabaseStorageItem]
    
    @StateObject var context: LibrePassContext = LibrePassContext()
    @State var showAbout = false
    
    var body: some View {
        HStack {
            if self.context.lClient != nil && self.context.loggedIn {
                LibrePassManagerWindow()
            } else if self.context.locallyLoggedIn {
                LibrePassLocalLogin()
            } else {
                NavigationView {
                    List {
                        NavigationLink(destination: LibrePassLoginWindow()) {
                            Text("Log in")
                        }
                        NavigationLink(destination: LibrePassRegistrationWindow()) {
                            Text("Register")
                        }
                    }
                    
                    .navigationTitle("Welcome to LibrePass!")
                    .toolbar {
                        Button(action: { self.showAbout = true }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
        }
        .environmentObject(context)
        .onAppear {
            if credentials.count > 0 {
                self.context.locallyLoggedIn = true
            }
        }
        
        .sheet(isPresented: self.$showAbout) {
            VStack {
                Image("Icon")
                    .resizable()
                    .cornerRadius(5.0)
                    .frame(width: 100, height: 100)
                    .padding()
                
                Text("Copyright © 2024 LibrePass Team")
                Text("LibrePass server: Medzik (Oskar) and contributors")
                Text("LibrePass app for iOS: aeoliux (Jacek)")
                Text("App is licensed under GPL v3 license")
                
                Link("See on Github", destination: URL(string: "https://github.com/LibrePass")!)
                    .padding()
                
                Link("See website", destination: URL(string: "https://librepass.org")!)
                    .padding()
            }
            .padding()
        }
    }
}


//#Preview {
//    MainWindow()
//        .modelContainer(for: [EncryptedCipherStorageItem.self, CredentialsDatabaseStorageItem.self, LastSyncStorage.self, SyncQueueItem.self])
//}
