//
//  SpinningWheel.swift
//  LibrePass
//
//  Created by Zapomnij on 25/02/2024.
//

import SwiftUI

struct SpinningWheel: View {
    @Binding var isPresented: Bool
    var task: () throws -> ()
    
    @State var showAlert: Bool = false
    @State var errorString = String()
    
    var body: some View {
        if self.isPresented {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.secondary))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        do {
                            try self.task()
                            self.isPresented = false
                        } catch {
                            self.errorString = error.localizedDescription
                            self.showAlert = true
                        }
                    }
                }
                .alert(self.errorString, isPresented: self.$showAlert) {
                    Button("OK", role: .cancel) {
                        self.isPresented = false
                    }
                }
        }
    }
}

struct ButtonWithSpinningWheel: View {
    var text: String
    var task: () throws -> ()
    
    @State var isPresented = false
    
    var body: some View {
        HStack {
            Button(text) { self.isPresented = true }
            Spacer()
            SpinningWheel(isPresented: self.$isPresented, task: self.task)
        }
    }
}

struct TextFieldWithCopyButton: View {
    var text: String
    @Binding var textBind: String
    
    var body: some View {
        HStack {
            TextField(self.text, text: self.$textBind)
                .autocapitalization(.none)
            Spacer()
            Button(action: {
                UIPasteboard.general.string = self.textBind
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
    }
}

struct SecureFieldWithCopyAndShowButton: View {
    var text: String
    @Binding var textBind: String
    
    @State var showPassword = false
    
    var body: some View {
        HStack {
            if self.showPassword {
                TextField(self.text, text: self.$textBind)
                    .autocapitalization(.none)
            } else {
                SecureField(self.text, text: self.$textBind)
                    .autocapitalization(.none)
            }
            
            Spacer()
            
            Button(action: {
                self.showPassword.toggle()
            }) {
                if self.showPassword {
                    Image(systemName: "eye")
                } else {
                    Image(systemName: "eye.fill")
                }
            }
            .buttonStyle(.plain)
            
            Button(action: {
                UIPasteboard.general.string = self.textBind
            }) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }
    }
}
