//
//  OATH.swift
//  LibrePass
//
//  Created by Zapomnij on 16/03/2024.
//

import Foundation
import SwiftOTP
import SwiftUI

extension String {
    func toOTPAlgorithm() -> SwiftOTP.OTPAlgorithm {
        switch self {
        case "SHA1":
            return .sha1
        case "SHA256":
            return .sha256
        case "SHA512":
            return .sha512
        default:
            return .sha1
        }
    }
}

extension SwiftOTP.OTPAlgorithm {
    func toString() -> String {
        switch self {
        case .sha1:
            return "SHA1"
        case .sha256:
            return "SHA256"
        case .sha512:
            return "SHA512"
        }
    }
}

var stop = false
var running = false
struct OATHParams {
    enum OATHType {
        case TOTP
        case HOTP
        
        func toString() -> String {
            switch self {
            case .TOTP:
                return "totp"
            case .HOTP:
                return "htop"
            }
        }
    }
    
    var uri: String
    
    var type: OATHType = .TOTP
    var algorithm: SwiftOTP.OTPAlgorithm = .sha1
    var secret: Data = Data()
    var digits: Int = 6
    var period: Int = 30
    var counter: Int = 0
    
    init(uri: String) throws {
        self.uri = uri
        
        if uri.starts(with: "otpauth://totp/") {
            self.type = .TOTP
        } else {
            self.type = .HOTP
        }
        
        let uriSplit = uri.components(separatedBy: "?")[1].components(separatedBy: "&")
        
        for keyVal in uriSplit {
            let split = keyVal.components(separatedBy: "=")
            let key = split[0], val = split[1]
            
            switch key {
            case "secret":
                guard let secret = base32Decode(val) else {
                    throw LibrePassApiErrors.WithMessage(message: "Bad 2FA secret")
                }
                self.secret = Data(secret)
                break
            case "algorithm":
                self.algorithm = val.toOTPAlgorithm()
                break
            case "digits":
                self.digits = Int(val) ?? 6
                break
            case "counter":
                self.counter = Int(val) ?? 0
                break
            case "period":
                self.period = Int(val) ?? 30
                break
            default:
                break
            }
        }
    }
    
    func runTOTPCounter(callback: (_ oneTimePassword: String, _ timeLeft: Int) -> ()) async {
        running = true
        if let totp = TOTP(secret: self.secret, digits: self.digits, timeInterval: self.period, algorithm: self.algorithm) {
            var counter = Int(Date().timeIntervalSince1970) % self.period
            var password = totp.generate(time: Date()) ?? ""
            while !stop {
                if counter == 0 {
                    if let newPassword = totp.generate(time: Date()) {
                        password = newPassword
                    }
                }
                
                callback(password, self.period - counter)
                try? await Task.sleep(nanoseconds: UInt64(0.5 * 1000000000))
                counter = Int(Date().timeIntervalSince1970) % self.period
            }
            
            stop = false
            running = false
        }
    }
}
