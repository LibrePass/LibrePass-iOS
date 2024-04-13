//
//  Context.swift
//  LibrePass
//
//  Created by Zapomnij on 08/04/2024.
//

import Foundation
import SwiftData
import SwiftUI

class LibrePassContext: ObservableObject {
    @Published var lClient: LibrePassClient?
    @Published var loggedIn: Bool
    @Published var locallyLoggedIn: Bool
    @Published var credentialsDatabase: LibrePassCredentialsDatabase?
    
    init(lClient: LibrePassClient? = nil) {
        self.lClient = lClient
        self.loggedIn = false
        self.locallyLoggedIn = false
    }

    func localLogIn(password: String, credentialsDatabase: LibrePassCredentialsDatabase) throws {
        self.lClient = try LibrePassClient(credentials: credentialsDatabase, password: password)
        self.credentialsDatabase = credentialsDatabase
        
        self.loggedIn = true
    }
    
    func sync(syncQueue: [SyncQueueItem], vault: [EncryptedCipherStorageItem], lastSync: Int64 = 0) throws -> LibrePassClient.SyncResponse? {
        let (toPush, toDelete) = syncQueue.toSync()
        return try self.lClient!.syncVault(toPush: toPush, toDelete: toDelete, lastSync: lastSync)
    }
    
    func logIn(email: String, password: String, apiUrl: String) throws -> CredentialsDatabaseStorageItem {
        self.lClient = LibrePassClient(apiUrl: apiUrl)
        let credets = CredentialsDatabaseStorageItem(credentialsDatabase: try self.lClient!.login(email: email, password: password))
        self.credentialsDatabase = credets.credentialsDatabase
        self.locallyLoggedIn = true
        self.loggedIn = true
        
        return credets
    }
    
    func unAuth() {
        self.loggedIn = false
        self.lClient = nil
    }
}
