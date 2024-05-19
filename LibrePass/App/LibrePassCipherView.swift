//
//  LibrePassCipherView.swift
//  Librepass
//
//  Created by Zapomnij on 19/02/2024.
//

import SwiftUI
import SwiftOTP
import SwiftData
import CodeScanner

struct CipherView: View {
    @EnvironmentObject var context: LibrePassContext
    
    @Query var vault: [EncryptedCipherStorageItem]
    @Query var queue: [SyncQueueItem]
    @Environment(\.modelContext) var modelContext
    var cipher: LibrePassCipher
    var sync: () throws -> ()
    
    func save(cipher: LibrePassCipher) {
        do {
            cipher.lastModified = Int64(Date().timeIntervalSince1970)
            let encrypted = EncryptedCipherStorageItem(encryptedCipher: try LibrePassEncryptedCipher(cipher: cipher, key: self.context.lClient!.keys.sharedKey))
            
            modelContext.insert(SyncQueueItem(operation: .Push(cipher: encrypted.encryptedCipher), id: cipher.id))
            for (index, item) in self.vault.enumerated() {
                if item.encryptedCipher.id == encrypted.encryptedCipher.id {
                    self.vault[index].encryptedCipher = encrypted.encryptedCipher
                }
            }
            
            try self.sync()
        } catch {
            
        }
    }
    
    var body: some View {
        switch self.cipher.type {
        case LibrePassCipher.CipherType.Login:
            CipherLoginDataView(cipher: self.cipher, save: save)
        case LibrePassCipher.CipherType.SecureNote:
            CipherSecureNoteView(cipher: self.cipher, save: save)
        case LibrePassCipher.CipherType.Card:
            CipherCardDataView(cipher: self.cipher, save: save)
        }
    }
}

struct CipherLoginDataView: View {
    var cipher: LibrePassCipher
    var save: (_ save: LibrePassCipher) -> ()
    
    @State var showPassword: Bool = false
    @State var name = String()
    @State var username = String()
    @State var password = String()
    @State var uris: [String] = []
    @State var notes = String()
    @State var twoFactorUri: String?
    
    @State var passwordLength = 0
    @State var generatePasswordAlert = false
    
    @State var oneTimePassword = ""
    @State var timeLeft = 0
    @State var editTwoFactor = false
    @State var twoFactorScanQR = true
    
    var body: some View {
        List {
            Section(header: Text("Login data")) {
                TextField("Name", text: $name)
                TextFieldWithCopyButton(text: "Username", textBind: self.$username)
                SecureFieldWithCopyAndShowButton(text: "Password", textBind: self.$password)
                Button("Generate random password") { self.generatePasswordAlert = true }
            }
            
            Section(header: Text("URIs")) {
                ForEach(self.uris.indices, id: \.self) { index in
                    HStack {
                        TextFieldWithCopyButton(text: "URI " + String(index + 1), textBind: self.$uris[index])
                    }
                }
                .onDelete { index in
                    self.uris.remove(atOffsets: index)
                }
                
                Button("Add") {
                    self.uris.append("")
                }
            }
            
            Section(header: Text("Two factor")) {
                if let _ = self.twoFactorUri {
                    HStack {
                        Button(action: {
                            UIPasteboard.general.string = self.oneTimePassword
                        }, label: {
                            Image(systemName: "doc.on.doc")
                        })
                        .buttonStyle(.plain)
                        Text(self.oneTimePassword)
                        Spacer()
                        Text(String(self.timeLeft))
                    }
                    .onAppear {
                        runAuthenticatorJob()
                    }
                    .onDisappear {
                        stop = running
                    }
                    
                    Button("Edit 2FA") {
                        stop = running
                        self.editTwoFactor = true
                    }
                    
                    Button("Delete 2FA") {
                        stop = running
                        self.twoFactorUri = nil
                    }
                    
                    .alert("Incorrect 2FA configuration", isPresented: self.$twoFactorError) {
                        Button("OK", role: .cancel) {
                            self.twoFactorUri = nil
                        }
                    }
                } else {
                    Button("Set up 2FA") {
                        self.editTwoFactor = true
                    }
                }
            }
            
            Section(header: Text("Notes")) {
                TextField("Notes", text: self.$notes, axis: .vertical)
            }
            
            Section {
                ButtonWithSpinningWheel(text: "Save", task: self.saveCipher)
            }
        }
        
        .alert("Length of password (must be longer or equal to 8)", isPresented: self.$generatePasswordAlert) {
            TextField("Length", value: self.$passwordLength, formatter: NumberFormatter())
            Button("Generate") {
                if let password = try? generatePassword(length: self.passwordLength) {
                    self.password = password
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        
        .onAppear {
            self.name = self.cipher.loginData!.name
            self.username = self.cipher.loginData!.username ?? ""
            self.password = self.cipher.loginData!.password ?? ""
            self.uris = self.cipher.loginData!.uris ?? []
            self.notes = self.cipher.loginData!.notes ?? ""
            self.twoFactorUri = self.cipher.loginData!.twoFactor
        }
        
        .sheet(isPresented: self.$editTwoFactor, onDismiss: {
            runAuthenticatorJob()
        }) {
            if self.twoFactorScanQR {
                CodeScannerView(codeTypes: [.qr]) { response in
                    switch response {
                    case .success(let result):
                        self.twoFactorUri = result.string
                        if (try? self.parseTwoFactor()) == nil {
                            self.twoFactorError = true
                        } else {
                            self.twoFactorScanQR = false
                        }
                        break
                    case .failure:
                        break
                    }
                }
                .padding()
                
                List {
                    Section() {
                        Button("Set up manually") { self.twoFactorScanQR = false }
                    }
                }
            } else {
                List {
                    Section(header: Text("Manual configuration")) {
                        TextField("Secret", text: self.$twoFactorSecret)
                        Picker("Type", selection: self.$twoFactorType) {
                            Text("TOTP").tag(OATHParams.OATHType.TOTP)
                        }
                        TextField("Digits", value: self.$twoFactorDigits, formatter: NumberFormatter())
                        if self.twoFactorType == .TOTP {
                            TextField("Period", value: self.$twoFactorPeriod, formatter: NumberFormatter())
                        } else {
                            TextField("Counter", value: self.$twoFactorCounter, formatter: NumberFormatter())
                        }
                        
                        Button("Apply") {
                            let split = self.twoFactorSecret.components(separatedBy: " ")
                            if split.count > 0 {
                                self.twoFactorSecret = ""
                                split.forEach {
                                    if $0 != "" {
                                        self.twoFactorSecret += $0
                                    }
                                }
                            }
                            
                            var str = "otpauth://" + self.twoFactorType.toString()
                            str += "/randomlabel?secret=" + self.twoFactorSecret
                            str += "&algorithm=" + self.twoFactorAlgorithm.toString()
                            str += "&digits=" + String(self.twoFactorDigits)
                            
                            if self.twoFactorType == .TOTP {
                                str += "&period=" + String(self.twoFactorPeriod)
                            } else {
                                str += "&counter=" + String(self.twoFactorCounter)
                            }
                            
                            self.twoFactorUri = str
                            
                            self.editTwoFactor = false
                        }
                    }
                    
                    Section() {
                        Button("Scan QR code") { self.twoFactorScanQR = true }
                    }
                }
                .onAppear {
                    do {
                        try self.parseTwoFactor()
                    } catch {
                        self.twoFactorError = true
                    }
                }
            }
        }
    }
    
    @State var twoFactorType: OATHParams.OATHType = .TOTP
    @State var twoFactorAlgorithm: SwiftOTP.OTPAlgorithm = .sha1
    @State var twoFactorSecret = String()
    @State var twoFactorDigits = 6
    @State var twoFactorPeriod = 30
    @State var twoFactorCounter = 0
    @State var twoFactorError = false
    
    func parseTwoFactor() throws {
        if let twoFactorUri = self.twoFactorUri {
            let params = try OATHParams(uri: twoFactorUri)
            self.twoFactorType = params.type
            self.twoFactorAlgorithm = params.algorithm
            self.twoFactorSecret = base32Encode(params.secret)
            self.twoFactorDigits = params.digits
            self.twoFactorPeriod = params.period
            self.twoFactorCounter = params.counter
        }
    }
    
    func runAuthenticatorJob() {
        Task {
            do {
                if let twoFactorUri = self.twoFactorUri {
                    let engine = try OATHParams(uri: twoFactorUri)
                    switch engine.type {
                    case .TOTP:
                        await engine.runTOTPCounter { oneTimePassword, timeLeft in
                            self.oneTimePassword = oneTimePassword
                            self.timeLeft = timeLeft
                        }
                        break
                    case .HOTP:
                        break
                    }
                }
            } catch {
                self.twoFactorError = true
            }
        }
    }
    
    func saveCipher() throws {
        self.cipher.loginData!.name = self.name
        self.cipher.loginData!.username = self.username.emptyStringToNil()
        self.cipher.loginData!.password = self.password.emptyStringToNil()
        self.cipher.loginData!.uris = self.uris
        self.cipher.loginData!.notes = self.notes.emptyStringToNil()
        self.cipher.loginData!.twoFactor = self.twoFactorUri
        
        self.save(self.cipher)
    }
}

struct CipherSecureNoteView: View {
    var cipher: LibrePassCipher
    var save: (_ cipher: LibrePassCipher) -> ()
    @State var title: String = String()
    @State var note: String = String()
    
    var body: some View {
        List {
            TextField("Title", text: self.$title)
            TextField("Note", text: self.$note, axis: .vertical)
            
            ButtonWithSpinningWheel(text: "Save", task: self.saveCipher)
        }
        
        .onAppear {
            self.title = self.cipher.secureNoteData!.title
            self.note = self.cipher.secureNoteData!.note
        }
    }
    
    func saveCipher() throws {
        self.cipher.secureNoteData!.title = title
        self.cipher.secureNoteData!.note = note
        self.save(self.cipher)
    }
}

struct CipherCardDataView: View {
    var cipher: LibrePassCipher
    var save: (_ cipher: LibrePassCipher) -> ()
    
    @State var name = String()
    @State var cardholderName = String()
    @State var number = String()
    @State var expMonth = String()
    @State var expYear = String()
    @State var code = String()
    @State var notes = String()
    
    var body: some View {
        List {
            Section(header: Text("Card data")) {
                TextField("Name", text: self.$name)
                TextFieldWithCopyButton(text: "Cardholder name", textBind: self.$cardholderName)
                SecureFieldWithCopyAndShowButton(text: "Card number", textBind: self.$number)
                TextFieldWithCopyButton(text: "Expires in month", textBind: self.$expMonth)
                TextFieldWithCopyButton(text: "Expires in year", textBind: self.$expYear)
                SecureFieldWithCopyAndShowButton(text: "Security code", textBind: self.$code)
            }
            
            Section(header: Text("Notes")) {
                TextField("Note", text: self.$notes, axis: .vertical)
            }
            
            Section {
                ButtonWithSpinningWheel(text: "Save", task: self.saveCipher)
            }
        }
        
        .onAppear {
            self.name = self.cipher.cardData!.name
            self.cardholderName = self.cipher.cardData!.cardholderName
            self.number = self.cipher.cardData!.number
            
            if self.cipher.cardData!.expMonth == nil {
                self.expMonth = ""
            } else {
                self.expMonth = String(self.cipher.cardData!.expMonth!)
            }
            
            if self.cipher.cardData!.expYear == nil {
                self.expYear = ""
            } else {
                self.expYear = String(self.cipher.cardData!.expYear!)
            }
            
            self.code = self.cipher.cardData!.code ?? ""
            self.notes = self.cipher.cardData!.notes ?? ""
        }
    }
    
    func saveCipher() throws {
        self.cipher.cardData!.name = self.name
        self.cipher.cardData!.cardholderName = self.cardholderName
        self.cipher.cardData!.number = self.number
        self.cipher.cardData!.expMonth = Int(self.expMonth) ?? nil
        self.cipher.cardData!.expYear = Int(self.expYear) ?? nil
        self.cipher.cardData!.code = self.code.emptyStringToNil()
        self.cipher.cardData!.notes = self.notes.emptyStringToNil()
        
        self.save(self.cipher)
    }
}

struct CipherButton: View {
    var cipher: LibrePassCipher
    
    var body: some View {
        switch self.cipher.type {
        case .Login:
            HStack {
                Image(systemName: "person.crop.circle.fill")
                VStack {
                    HStack{
                        Text(self.cipher.loginData!.name)
                        Spacer()
                    }
                    if let username = self.cipher.loginData!.username {
                        HStack {
                            Text(username)
                            Spacer()
                        }
                    }
                }
            }
        case .SecureNote:
            HStack {
                Image(systemName: "note.text")
                Text(self.cipher.secureNoteData!.title)
                Spacer()
            }
        case .Card:
            HStack {
                Image(systemName: "creditcard")
                Text(self.cipher.cardData!.name)
                Spacer()
            }
        }
    }
}
