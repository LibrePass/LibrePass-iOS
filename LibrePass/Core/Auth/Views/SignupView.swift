//
//  SignupView.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import SwiftUI

struct SignupView: View {
    
    @State private var email = ""
    @State private var fullname = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var server = CustomEnvironment.rootURL
    @State private var showSelfHostedView = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel
    
    
    var body: some View {
        VStack {
            Spacer()
            
            Image(uiImage: UIImage(named: AppIconProvider.appIcon())!)
                .resizable()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Spacer()
            
            VStack(spacing: 24) {
                
                InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
                    .autocapitalization(.none)
                
                InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                
                ZStack(alignment: .trailing) {
                    InputView(text: $confirmPassword, title: "Confirm Password", placeholder: "Confirm your password", isSecureField: true)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty {
                        if password == confirmPassword {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemGreen))
                            
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemRed))
                        }
                    }
                }
                
                HStack {
                    Text ("Server Address")
                        .font(.footnote)
                    
                    Spacer()
                    
                    Picker("Server Address", selection: $server) {
                        Text("Official").tag(CustomEnvironment.rootURL)
                        Text("Self-Hosted").tag("")
                    }
                    .onChange(of: server) { newState in
                        if newState == "" {
                            showSelfHostedView = true
                        }
                    }
                }
                
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            
            Button {
                Task {
                    
                }
            } label: {
                HStack {
                    Text ("SIGN UP")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(width: UIScreen.main.bounds.width - 32, height: 48)
            }
            .background(Color(.systemBlue))
            .disabled(!formIsValid)
            .opacity(formIsValid ? 1.0 : 0.5 )
            .cornerRadius(10)
            .padding()
        }
        .sheet(isPresented: $showSelfHostedView) {
            NavigationStack {
                ServerURLView(serverURL: $server, isPresented: $showSelfHostedView)
            }
        }
    }
}

extension SignupView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && confirmPassword == password
        && password.count > 7
        && !fullname.isEmpty
    }
}

struct InputView: View {
    @Binding var text: String
    let title: String
    let placeholder: String
    var isSecureField = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .foregroundColor(Color(.darkGray))
                .fontWeight(.semibold)
                .font(.footnote)
            
            if isSecureField {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
            }
            
            Divider()
            
        }
    }
}

struct ServerURLView: View {
    @Binding var serverURL: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    TextField("Enter Server URL", text: $serverURL)
                }
                .background(Color(.systemGray6))
            }
            .navigationTitle("Self-Hosted")
            .navigationBarItems(trailing: Button("Done") {
                isPresented.toggle()
            })
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }
}

#Preview {
    SignupView()
}
