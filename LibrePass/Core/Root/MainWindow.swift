//
//  MainWindow.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import SwiftUI

struct MainWindow: View {
    @State var lClient: LibrePassClient = LibrePassClient(apiUrl: "")
    
    @State var localLogIn = false
    @State var loggedIn = false
        
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
                }
            }
        }
        
        .onAppear {
            self.localLogIn = LibrePassCredentialsDatabase.isLocallyLoggedIn()
        }
    }
}


//#Preview {
//    MainWindow()
//}
