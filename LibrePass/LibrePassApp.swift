//
//  LibrePassApp.swift
//  LibrePass
//
//  Created by Zapomnij on 17/02/2024.
//

import SwiftUI

@main
struct LibrePassApp: App {
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
    }
}

var networkMonitor = NetworkMonitor()

struct MainWindow: View {
    @State var lClient: LibrePassClient = LibrePassClient(apiUrl: "")
    
    @State var localLogIn = false
    @State var loggedIn = false
    
    @State var showAbout = false
    
    var body: some View {
        HStack {
            if self.loggedIn {
                LibrePassManagerWindow(lClient: $lClient, loggedIn: $loggedIn, locallyLoggedIn: $localLogIn)
            } else if self.localLogIn {
                LibrePassLocalLogin(lClient: $lClient, loggedIn: $loggedIn, localLogIn: $localLogIn)
            } else {
                NavigationView {
                    List {
                        NavigationLink(destination: LibrePassLoginWindow(lClient: $lClient, loggedIn: $loggedIn, localLogIn: $localLogIn)) {
                            Text("Log in")
                        }
                        NavigationLink(destination: LibrePassRegistrationWindow(lClient: $lClient)) {
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
        
        .onAppear {
            self.localLogIn = LibrePassCredentialsDatabase.isLocallyLoggedIn()
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
                Text("LibrePass app for iOS: Zapomnij (Jacek)")
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
//}
