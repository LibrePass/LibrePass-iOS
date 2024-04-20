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
    @State private var customServerURL = ""
    @State private var isShowingCustomURLSheet = false
    @State private var selectedServerType: ServerType = .official
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    
    var body: some View {
        VStack {
            Image("Icon")
                .resizable()
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
            
            
            VStack(spacing: 24) {
                InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
#if os(iOS)
                    .autocapitalization(.none)
#endif
                
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
                    
                    Picker("Server Type", selection: $selectedServerType) {
                        Text("Official").tag(ServerType.official)
                        Text("Self-Hosted").tag(ServerType.selfHosted)
                    }
                    .padding()
                    .onChange(of: selectedServerType) { oldValue, newValue in
                        if newValue == .selfHosted {
                            isShowingCustomURLSheet = true
                        } else {
                            isShowingCustomURLSheet = false
                            customServerURL = CustomEnvironment.rootURL
                        }
                    }
                }
                
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            
            Button {
                Task {
                    try await authViewModel.signUp(withEmail: email, password: password)
                }
            } label: {
                HStack {
                    Text ("SIGN UP")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(width: screenWidth() - 32, height: 48)
            }
            .background(Color(.systemBlue))
            .disabled(!formIsValid)
            .opacity(formIsValid ? 1.0 : 0.5 )
            .cornerRadius(10)
            .padding(.top, 24)
            
            Spacer()
            
            Button {
                dismiss()
                
            } label: {
                HStack(spacing: 2) {
                    Text("Already have an account?")
                    Text("Sign in")
                        .fontWeight(.bold)
                }
                .font(.system(size: 16))
                
            }
            .padding()
        }
        .navigationTitle("Register")
        .sheet(isPresented: $isShowingCustomURLSheet) {
            NavigationStack {
                ServerURLView(serverURL: $customServerURL, isPresented: $isShowingCustomURLSheet)
            }
        }
    }
    
    private func screenWidth() -> CGFloat {
#if os(iOS)
        return UIScreen.main.bounds.width
#elseif os(macOS)
        return NSScreen.main?.visibleFrame.width ?? 0
#endif
    }
}

extension SignupView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && confirmPassword == password
        && password.count > 7
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
                .background(Color.systemGray6)
            }
            .navigationTitle("Self-Hosted")
#if os(iOS)
            .navigationBarItems(trailing: doneButton)
#endif
        }
        .background(Color.systemGray6.ignoresSafeArea())
    }
    
#if os(iOS)
    private var doneButton: some View {
        Button("Done") {
            UserDefaults.standard.set(serverURL, forKey: "SelfHostedURL")
            isPresented = false
        }
    }
#endif
}


extension Color {
#if os(iOS)
    static var systemGray6: Color {
        return Color(UIColor.systemGray6)
    }
#elseif os(macOS)
    static var systemGray6: Color {
        return Color(NSColor(calibratedWhite: 0.6, alpha: 1.0))
    }
#endif
}

enum ServerType {
    case official
    case selfHosted
}

#Preview {
    SignupView()
}
