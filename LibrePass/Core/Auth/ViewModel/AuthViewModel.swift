//
//  AuthViewModel.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import Foundation
import Argon2Swift
import Alamofire
import CryptoKit

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let credentials = try await login(withEmail: email, password: password)
            
        } catch {
            print("Debug: Failed to signIn with error: \(error.localizedDescription)")
        }
    }
    
    private func preLogin(email: String) async throws -> PreLoginResponse {
        let endpoint = "/preLogin"
        let parameters: [String: Any] = [
            "email" : email
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(CustomEnvironment.rootURL + endpoint, parameters: parameters)
                .responseDecodable(of: PreLoginResponse.self) { response in
                    switch response.result {
                    case let .success(data):
                        continuation.resume(returning: data)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    private func login(withEmail email: String, password: String) async throws {
        let preLoginData = try await preLogin(email: email)
        
        let passwordHash = try Argon2Swift.hashPasswordBytes(
            password: password.data(using: .utf8)!,
            salt: Salt(bytes: email.data(using: .utf8)!),
            iterations: preLoginData.iterations,
            memory: preLoginData.memory,
            parallelism: preLoginData.parallelism,
            type: .id,
            version: .V13
        )
        
        let serverPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: preLoginData.serverPublicKey.data(using: .utf8)!)
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: passwordHash.hashData())
        let sharedSecretKey = try privateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)

    }
    
    
    
    
    //
    //    func createUser(withEmail email: String, password: String, fullname: String) async throws {
    //        do {
    //
    //
    //        } catch {
    //            print("DEBUG: Failed to create user with error: \(error.localizedDescription)")
    //        }
    //    }
}
