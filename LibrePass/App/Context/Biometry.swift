//
//  Biometry.swift
//  LibrePass
//
//  Created by Zapomnij on 19/04/2024.
//

import Foundation
import LocalAuthentication

func setUpBiometricalAuthentication(password: String) async -> Bool {
    let context = LAContext()
    
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Save password in keychain")
            
            guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) else {
                return false
            }
            
            guard let passwordData = password.data(using: .utf8) else {
                return false
            }
            
            let query: [String: Any] =
                [kSecClass as String: kSecClassGenericPassword,
                 kSecAttrService as String: "LibrePass",
                 kSecAttrAccessControl as String: access,
                 kSecUseAuthenticationContext as String: context,
                 kSecValueData as String: passwordData as Data]
            SecItemDelete(query as CFDictionary)
            
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                return true
            }
        } catch {
            
        }
    }
    
    return false
}

func accessKeychain() async -> String? {
    let context = LAContext()
    
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Save password in keychain")
            
            let query: [String: Any] = 
                [kSecClass as String: kSecClassGenericPassword,
                 kSecAttrService as String: "LibrePass",
                 kSecMatchLimit as String: kSecMatchLimitOne,
                 kSecReturnAttributes as String: true,
                 kSecUseAuthenticationContext as String: context,
                 kSecReturnData as String: true]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            print(status)
            if status == errSecSuccess {
                if let decoded = item as? [String: Any], let passwordData = decoded[kSecValueData as String] as? Data, let password = String(data: passwordData, encoding: .utf8) {
                    return password
                }
            }
        } catch {
            
        }
    }
    
    return nil
}

func disableBiometricAuthentication() async -> Bool {
    let context = LAContext()
    
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Save password in keychain")
            
            let query: [String: Any] =
                [kSecClass as String: kSecClassGenericPassword,
                 kSecAttrService as String: "LibrePass",
                 kSecReturnAttributes as String: true,
                 kSecUseAuthenticationContext as String: context,
                 kSecReturnData as String: true]
            
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess {
                return true
            }
        } catch {
            
        }
    }
    
    return false
}
