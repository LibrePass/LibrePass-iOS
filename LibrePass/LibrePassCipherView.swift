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
        ScrollView {
            switch self.cipher.type {
            case LibrePassCipher.CipherType.Login:
                CipherLoginDataView(cipher: self.cipher, index: index, save: save)
            case LibrePassCipher.CipherType.SecureNote:
                CipherSecureNoteView(cipher: self.cipher, index: index, save: save)
            case LibrePassCipher.CipherType.Card:
                CipherCardDataView(cipher: self.cipher, index: index, save: save)
            }
        }
        
        .toolbar {
            CipherDeleteButton(lClient: $lClient, id: cipher.id)
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
        VStack {
            HStack {
                Text("Name").foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Name", text: $name)
            }
        }
        .padding()
        
        HStack {
            VStack {
                HStack {
                    Text("Username").foregroundStyle(Color.secondary)
                    Spacer()
                }
                HStack {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                }
            }
            
            HStack {
                Button(action: {
                    UIPasteboard.general.string = username
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .font(.system(size: 25))
                .foregroundColor(Color.primary)
            }
        }
        .padding()
        
        HStack {
            VStack {
                HStack {
                    Text("Password").foregroundStyle(Color.secondary)
                    Spacer()
                }
                HStack {
                    if self.showPassword {
                        TextField("Password", text: $password)
                            .autocapitalization(.none)
                    } else {
                        SecureField("Password", text: $password)
                            .autocapitalization(.none)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(action: {
                    self.showPassword.toggle()
                }) {
                    if self.showPassword {
                        Image(systemName: "eye")
                    } else {
                        Image(systemName: "eye.fill")
                    }
                }
                .font(.system(size: 25))
                .foregroundStyle(Color.primary)
                
                Button(action: {
                    UIPasteboard.general.string = password
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .font(.system(size: 25))
                .foregroundColor(Color.primary)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("URIs")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            
            ForEach(self.uris.indices, id: \.self) { index in
                HStack {
                    TextField("URI " + String(index + 1), text: self.$uris[index])
                        .autocapitalization(.none)
                    Button(action: {
                        self.uris.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(Color.red)
                    }
                }
                .padding(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
            }
            
            Button("Add") {
                self.uris.append("")
            }
            
        }
        .padding()
        
        VStack {
            HStack {
                Text("Notes")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            TextField("Notes", text: self.$notes)
        }
        .padding()
        
        .onAppear {
            self.name = self.cipher.loginData!.name
            self.username = self.cipher.loginData!.username ?? ""
            self.password = self.cipher.loginData!.password ?? ""
            self.uris = self.cipher.loginData!.uris ?? []
            self.notes = self.cipher.loginData!.notes ?? ""
        }
        
        Button("Save") {
            self.cipher.loginData!.name = self.name
            self.cipher.loginData!.username = self.username
            self.cipher.loginData!.password = self.password
            self.cipher.loginData!.uris = self.uris
            self.cipher.loginData!.notes = self.notes
        
            self.save(self.cipher)
        }
    }
}

struct CipherSecureNoteView: View {
    var cipher: LibrePassCipher
    var index: Int
    var save: (_ cipher: LibrePassCipher) -> ()
    @State var secureNoteData: LibrePassCipher.CipherSecureNoteData
    
    init(cipher: LibrePassCipher, index: Int, save: @escaping (_ cipher: LibrePassCipher) -> ()) {
        self.cipher = cipher
        self.index = index
        self.secureNoteData = self.cipher.secureNoteData!
        self.save = save
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Title").foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Title", text: self.$secureNoteData.title)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Notes").foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Notes", text: self.$secureNoteData.note)
            }
        }
        .padding()
        
        Button("Save") {
            self.cipher.secureNoteData = self.secureNoteData
            self.save(self.cipher)
        }
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
        VStack {
            HStack {
                Text("Name")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Name", text: $name)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Cardholder name")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Cardholder name", text: $cardholderName)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Number")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Number", text: $number)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Expires in month")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Expires in month", text: $expMonth)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Expires in year")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Expires in year", text: $expYear)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Code")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Code", text: $code)
            }
        }
        .padding()
        
        VStack {
            HStack {
                Text("Notes")
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            HStack {
                TextField("Notes", text: $notes)
            }
        }
        .padding()
        
        Button("Save") {
            self.cipher.cardData!.name = self.name
            self.cipher.cardData!.cardholderName = self.cardholderName
            self.cipher.cardData!.number = self.number
            self.cipher.cardData!.expMonth = Int(self.expMonth) ?? nil
            self.cipher.cardData!.expYear = Int(self.expYear) ?? nil
            self.cipher.cardData!.code = self.code
            self.cipher.cardData!.notes = self.notes
            
            self.save(self.cipher)
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
    @State var errorIndicator = String()
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
        
        .alert(self.errorIndicator, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
