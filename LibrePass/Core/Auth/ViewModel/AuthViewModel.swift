//
//  AuthViewModel.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import Foundation
import CryptoKit
import Argon2Swift
import Alamofire
import KeychainSwift
import LocalAuthentication

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isValidated = false
    @Published var error: AuthenticationError?
    
    let endpoint = "/api/auth"
    
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            _ = try await login(withEmail: email, password: password)
            
        } catch {
            print("Debug: Failed to signIn with error: \(error.localizedDescription)")
        }
    }
    
    func signUp(withEmail email: String, password: String) async throws {
        do {
            let preLoginData = try await preLogin(email: "")
            
            let passwordHash = try Argon2Swift.hashPasswordBytes(
                password: password.data(using: .utf8)!,
                salt: Salt(bytes: email.data(using: .utf8)!),
                iterations: preLoginData.iterations,
                memory: preLoginData.memory,
                parallelism: preLoginData.parallelism,
                type: .id,
                version: .V13
            )
            
            let serverPublicKeyHex = Data(preLoginData.serverPublicKey.hexToBytes()!)
            let serverPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKeyHex)
            KeychainManager.shared.set(serverPublicKey.rawRepresentation, forKey: "serverPublicKey")
            
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: passwordHash.hashData())
            KeychainManager.shared.set(privateKey.rawRepresentation, forKey: "userPrivateKey")
            
            let sharedSecretKey = try privateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)
            let sharedSecretKeyHex = sharedSecretKey.withUnsafeBytes { bytes in
                return Data(bytes).map { String(format: "%02hhx", $0) }.joined()
            }
            
            let body = try JSONEncoder().encode(RegisterRequest(
                email: email,
                passwordHint: "",
                sharedKey: sharedSecretKeyHex,
                parallelism: preLoginData.parallelism,
                memory: preLoginData.memory,
                iterations: preLoginData.iterations,
                publicKey: privateKey.publicKey.rawRepresentation.map { String(format: "%02hhx", $0) }.joined()
            ))
            
            let url = URL(string: CustomEnvironment.rootURL + endpoint + "/register")!
            var urlRequest = URLRequest(url: url)
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let response =  response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(response.statusCode) else {
                throw NetworkError.statusCode(response.statusCode)
            }
            
            do {
                let resp = try JSONDecoder().decode(UserCredentialResponse.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
            
            
            
            
            
        } catch {
            print("Debug: Failed to sigup with error: \(error.localizedDescription)")
        }
    }
    
    private func preLogin(email: String) async throws -> PreLoginResponse {
        let parameters: [String: Any] = [
            "email" : email
        ]
        
        let headers: HTTPHeaders = [
            "Accept": "application/json"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(CustomEnvironment.rootURL + endpoint + "/preLogin", method: .get, parameters: parameters, headers: headers)
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
        
        let serverPublicKeyHex = Data(preLoginData.serverPublicKey.hexToBytes()!)
        let serverPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKeyHex)
        //check if there's an existing key in keychain
        KeychainManager.shared.set(serverPublicKey.rawRepresentation, forKey: "serverPublicKey")
        
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: passwordHash.hashData())
        KeychainManager.shared.set(privateKey.rawRepresentation, forKey: "userPrivateKey")
        
        let sharedSecretKey = try privateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)
        let sharedSecretKeyHex = sharedSecretKey.withUnsafeBytes { bytes in
            return Data(bytes).map { String(format: "%02hhx", $0) }.joined()
        }
        
        let body = try JSONEncoder().encode(LoginRequest(email: email, sharedKey: sharedSecretKeyHex))
        
        let url = URL(string: CustomEnvironment.rootURL + endpoint + "/oauth?grantType=login")!
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let response =  response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(response.statusCode) else {
            throw NetworkError.statusCode(response.statusCode)
        }
        
        do {
            let resp = try JSONDecoder().decode(UserCredentialResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
        
        self.isLoggedIn = true
        
        //        let aesKey = try privateKey.sharedSecretFromKeyAgreement(with: privateKey.publicKey)
        
        
    }
    
    func biometricType() -> BiometricType {
        let authContext = LAContext()
        let _ = authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch authContext.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touch
        case .faceID:
            return .face
        case .opticID:
            return .optic
        @unknown default:
            return .none
        }
    }

    enum BiometricType {
        case none
        case face
        case touch
        case optic
    }
    
    func requestBiometricUnlock(completion: @escaping (Result<Credentials, AuthenticationError>) -> Void) {
        let credentials: Credentials? = nil
//        let credentials: Credentials? = Credentials(
//            userId: UUID(),
//            email: "test",
//            apiKey: "apikey",
//            publicKey: "publickey",
//            memory: 64950,
//            iterations: 3,
//            parallelism: 3
//        )

        guard let credentials = credentials else {
            completion(.failure(.credentialsNotSaved))
            return
        }
        
        let context = LAContext()
        var error: NSError?
        let canEvalute = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error = error {
            switch error.code {
            case -6:
                completion(.failure(.deniedAccess))
            case -7:
                if context.biometryType == .faceID {
                    completion(.failure(.noFaceIdEnrolled))
                } else {
                    completion(.failure(.noFingerprintEnrolled))
                }
            default:
                completion(.failure(.biometricError))
            }
            return
        }
        
        if canEvalute {
            if context.biometryType != .none {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Need access to credentials.") {
                    success, error in
                    DispatchQueue.main.async {
                        if error != nil {
                            completion(.failure(.biometricError))
                        } else {
                            completion(.success(credentials))
                        }
                    }
                }
            }
        }
    }
    
    enum NetworkError: Error {
        case invalidResponse
        case statusCode(Int)
        case decodingError(Error)
        
        var id: String {
            self.localizedDescription
        }
        
        //    var errorDescription: String? {
        //
        //    }
    }

    enum AuthenticationError: Error, LocalizedError, Identifiable {
        case invalidCredentials
        case deniedAccess
        case noFaceIdEnrolled
        case noFingerprintEnrolled
        case biometricError
        case credentialsNotSaved
        
        var id: String {
            self.localizedDescription
        }
        
        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return NSLocalizedString("Either your email or password are incorrect. Please try again.", comment: "")
            case .deniedAccess:
                return NSLocalizedString("You have denied access. Please go to settings app and located this application and turn on Face ID.", comment: "")
            case .noFaceIdEnrolled:
                return NSLocalizedString("You have not registered any Face ID yet.", comment: "")
            case .noFingerprintEnrolled:
                return NSLocalizedString("You have not registered any fingerprint yet.", comment: "")
            case .biometricError:
                return NSLocalizedString("Your face or fingerprint were not recognized.", comment: "")
            case .credentialsNotSaved:
                return NSLocalizedString("You credentials have not been saved. Do you want to save them after the next successful login?", comment: "")
            }
        }
    }
    
    func updateValidation(success: Bool) {
        isValidated = success
    }
}

extension String {
    func hexToBytes() -> [UInt8]? {
        var startIndex = self.startIndex
        return (0..<self.count/2).compactMap { _ in
            guard let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) else {
                return nil
            }
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}
