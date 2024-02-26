//
//  NetworkMonitor.swift
//  LibrePass
//
//  Created by Zapomnij on 26/02/2024.
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let dispatchQueue = DispatchQueue(label: "Monitor")
    
    var isConnected = false
    
    init() {
        self.monitor.pathUpdateHandler = { path in
            self.isConnected = path.status != .unsatisfied
        }
        
        self.monitor.start(queue: self.dispatchQueue)
    }
}
