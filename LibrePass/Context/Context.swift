//
//  Context.swift
//  LibrePass
//
//  Created by Zapomnij on 08/04/2024.
//

import Foundation

class LibrePassContext: ObservableObject {
    @Published var lClient: LibrePassClient?
    @Published var loggedIn: Bool
    @Published var locallyLoggedIn: Bool
    
    init(lClient: LibrePassClient? = nil, loggedIn: Bool, locallyLoggedIn: Bool) {
        self.lClient = lClient
        self.loggedIn = loggedIn
        self.locallyLoggedIn = locallyLoggedIn
    }
    
    func clearVault(password: String) throws {
        if networkMonitor.isConnected {
            let credentials = try LibrePassCredentialsDatabase.load()
            self.lClient = try LibrePassClient(credentials: credentials, password: password)
            
            try self.lClient!.fetchCiphers()
            
            self.lClient!.unAuth()
        } else {
            throw LibrePassApiErrors.WithMessage(message: "Offline clearing vault can't be done")
        }
    }
    
    func localLogIn(password: String) throws {
        let credentials = try LibrePassCredentialsDatabase.load()
        self.lClient = try LibrePassClient(credentials: credentials, password: password)
        try self.lClient!.syncVault()
            
        self.loggedIn = true
    }
    
    func logIn(email: String, password: String, apiUrl: String) throws {
        self.lClient = LibrePassClient(apiUrl: apiUrl)
        try self.lClient!.login(email: email, password: password)
        try self.lClient!.fetchCiphers()
        
        self.locallyLoggedIn = true
        self.loggedIn = true
    }
    
    func unAuth() {
        self.lClient!.unAuth()
        self.loggedIn = false
    }
    
    func logOut() {
        self.lClient!.logOut()
        self.locallyLoggedIn = false
        self.loggedIn = false
    }
    
    func updateCredentials(oldPassword: String, newPassword: String, newPasswordHint: String, newEmail: String) throws {
        let (_, oldPublicData, oldSharedData) = try self.lClient!.getKeys(email: self.lClient!.credentialsDatabase!.email, password: oldPassword, argon2options: self.lClient!.credentialsDatabase!.argon2idParams)
        
        if dataToHexString(data: oldPublicData) != self.lClient!.credentialsDatabase!.publicKey {
            throw LibrePassApiErrors.WithMessage(message: "Invalid credentials")
        }
        
        if newEmail != self.lClient!.credentialsDatabase!.email && !newPassword.isEmpty {
            throw LibrePassApiErrors.WithMessage(message: "Both settings (email and password) cannot be changed at the same time.")
        }
        
        _ = try? self.lClient!.syncVault()
        
        try self.lClient!.updateCredentials(email: newEmail, password: newPassword, passwordHint: newPasswordHint, oldSharedKey: dataToHexString(data: oldSharedData))
    }
}
