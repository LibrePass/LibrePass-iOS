//
//  PasswordGenerator.swift
//  LibrePass
//
//  Created by Zapomnij on 01/03/2024.
//

import Foundation

func generatePassword(length: Int) throws -> String {
    if length < 8 {
        throw LibrePassApiError.other("Password length must be longer or equal to 8")
    }
    
    let nOfNumbers = length / 4
    let nOfSpecial = length / 4
    let nOfLowercased = length / 4
    let nOfUppercased = length - nOfSpecial - nOfLowercased - nOfNumbers
    
    var password = [Character?](repeating: nil, count: length)
    
    func fill(from: Int, to: Int, times: Int) {
        var filled = 0
        while filled < times {
            let char = Character(UnicodeScalar(Int.random(in: from...to))!)
            
            if password.first(where: { ch in ch == char }) == nil {
                while true {
                    let index = Int.random(in: 0...length - 1)
                    if password[index] == nil {
                        password[index] = char
                        filled += 1
                        break
                    }
                }
            }
        }
    }
    
    for _ in stride(from: 0, to: nOfSpecial, by: 1) {
        switch Int.random(in: 0...3) {
        case 0:
            fill(from: 32, to: 47, times: 1)
            break
        case 1:
            fill(from: 58, to: 64, times: 1)
            break
        case 2:
            fill(from: 91, to: 96, times: 1)
            break
        case 3:
            fill(from: 123, to: 126, times: 1)
            break
        default:
            print("This won't ever happen")
        }
    }
    
    fill(from: 48, to: 57, times: nOfNumbers)
    fill(from: 97, to: 122, times: nOfLowercased)
    fill(from: 65, to: 90, times: nOfUppercased)
    
    var string = ""
    password.forEach {
        if let char = $0 {
            string += String(char)
        }
    }
    
    return string
}
