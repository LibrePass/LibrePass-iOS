//
//  LibrePassCipherView.swift
//  Librepass
//
//  Created by Zapomnij on 19/02/2024.
//

import SwiftUI

struct CipherView: View {
    @Binding var lClient: LibrePassClient
    var cipher: LibrePassCipher
    var index: Int
    
    func save(cipher: LibrePassCipher) {
        cipher.lastModified = Int64(Date().timeIntervalSince1970)
        _ = try? lClient.put(cipher: cipher)
        _ = try? lClient.syncVault()
    }
    
    var body: some View {
        switch self.cipher.type {
        case LibrePassCipher.CipherType.Login:
            CipherLoginDataView(cipher: self.cipher, index: index, save: save)
        case LibrePassCipher.CipherType.SecureNote:
            CipherSecureNoteView(cipher: self.cipher, index: index, save: save)
        case LibrePassCipher.CipherType.Card:
            CipherCardDataView(cipher: self.cipher, index: index, save: save)
        }
    }
}

struct CipherLoginDataView: View {
    var cipher: LibrePassCipher
    var index: Int
    var save: (_ save: LibrePassCipher) -> ()
    
    @State var showPassword: Bool = false
    @State var name = String()
    @State var username = String()
    @State var password = String()
    @State var uris: [String] = []
    @State var notes = String()
    
    var body: some View {
        List {
            Section(header: Text("Login data")) {
                TextField("Name", text: $name)
                TextFieldWithCopyButton(text: "Username", textBind: self.$username)
                SecureFieldWithCopyAndShowButton(text: "Password", textBind: self.$password)
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
            
            Section(header: Text("Notes")) {
                TextField("Notes", text: self.$notes)
            }
            
            Section {
                ButtonWithSpinningWheel(text: "Save", task: self.saveCipher)
            }
        }
        
        .onAppear {
            self.name = self.cipher.loginData!.name
            self.username = self.cipher.loginData!.username ?? ""
            self.password = self.cipher.loginData!.password ?? ""
            self.uris = self.cipher.loginData!.uris ?? []
            self.notes = self.cipher.loginData!.notes ?? ""
        }
    }
    
    func saveCipher() throws {
        self.cipher.loginData!.name = self.name
        self.cipher.loginData!.username = self.username
        self.cipher.loginData!.password = self.password
        self.cipher.loginData!.uris = self.uris
        self.cipher.loginData!.notes = self.notes
        
        self.save(self.cipher)
    }
}

struct CipherSecureNoteView: View {
    var cipher: LibrePassCipher
    var index: Int
    var save: (_ cipher: LibrePassCipher) -> ()
    @State var title: String = String()
    @State var note: String = String()
    
    var body: some View {
        List {
            TextFieldWithCopyButton(text: "Title", textBind: self.$title)
            TextFieldWithCopyButton(text: "Note", textBind: self.$note)
            
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
    var index: Int
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
                TextFieldWithCopyButton(text: "Notes", textBind: self.$notes)
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
        self.cipher.cardData!.code = self.code
        self.cipher.cardData!.notes = self.notes
        
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

struct CipherDeleteButton: View {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var lClient: LibrePassClient
    var id: String
    
    @State var areYouSure = false
    @State var errorString = String()
    @State var showAlert = false
    
    var body: some View {
        Button(action: {
            self.areYouSure = true
        }) {
            Image(systemName: "trash")
        }
        .foregroundColor(Color.red)
        
        .alert("Are you sure you want to delete this cipher?", isPresented: $areYouSure) {
            Button("Yes", role: .destructive) {
                _ = try? lClient.delete(id: id)
                
                self.presentationMode.wrappedValue.dismiss()
            }
            
            Button("No", role: .cancel) {}
        }
        
        .alert(self.errorString, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
