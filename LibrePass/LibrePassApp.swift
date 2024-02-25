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

struct MainWindow: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State var lClient: LibrePassClient = LibrePassClient(apiUrl: "")
    
    @State var localLogIn = false
    @State var loggedIn = false
    
    var body: some View {
        HStack {
            if self.loggedIn {
                LibrePassManagerWindow(lClient: $lClient, loggedIn: $loggedIn, locallyLoggedIn: $localLogIn)
            } else if self.localLogIn {
                LibrePassLocalLogin(lClient: $lClient, loggedIn: $loggedIn)
            } else {
                NavigationView {
                    List {
                        NavigationLink(destination: LibrePassLoginWindow(lClient: $lClient, loggedIn: $loggedIn)) {
                            Text("Log in")
                        }
                        NavigationLink(destination: LibrePassRegistrationWindow(lClient: $lClient)) {
                            Text("Register")
                        }
                    }
                    .navigationTitle("Log in to LibrePass")
                }
            }
        }
        
        .onAppear {
            self.localLogIn = LibrePassCredentialsDatabase.isLocallyLoggedIn()
        }
        
        .onChange(of: scenePhase) { (phase) in
            if phase == .background {
                lClient.unAuth()
                self.localLogIn = true
                self.loggedIn = false
            }
        }
    }
}


//#Preview {
//    MainWindow()
//}
