//
//  LoginView.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var customServerURL = ""
    @State private var isShowingCustomURLSheet = false
    @State private var selectedServerType: ServerType = .official

    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: UIImage(named: AppIconProvider.appIcon())!)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Text("LibrePass")
                    .font(.title)
                
                VStack(spacing: 24) {
                    InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
                        .autocapitalization(.none)
                    
                    InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                    
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
                            }
                        }   
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            
            Button {
                Task {
                    try await authViewModel.signIn(withEmail: email, password: password)
                }
            } label: {
                HStack {
                    Text ("SIGN IN")
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
            .padding(.top, 24)
            
            
            if authViewModel.biometricType() != .none {
                Button {
                    authViewModel.requestBiometricUnlock {
                        (result: Result<Credentials, AuthViewModel.AuthenticationError>) in
                        switch result {
                        case .success(let credentials):
                            authViewModel.isLoggedIn = true
                        case .failure(let error):
                            authViewModel.error = error
                        }
                    }
                } label: {
                    Image(systemName: authViewModel.biometricType() == .face ? "faceid" : "touchid")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .padding()
                }
            }
            
            
            NavigationLink {
                SignupView()
            } label: {
                HStack(spacing: 2) {
                    Text("Don't have an account?")
                    Text("Sign up")
                        .fontWeight(.bold)
                }
                .font(.system(size: 16))
            }
            .padding()
        }
        .alert(item: $authViewModel.error) { error in
            if error == .credentialsNotSaved {
                return Alert(
                    title: Text("Credentials Not Saved"),
                    message: Text(error.localizedDescription),
                    primaryButton: .default(Text("OK"), action: {}),
                    secondaryButton: .cancel()
                )
            } else {
                return Alert(title: Text("Invalid Login"), message: Text(error.localizedDescription))
            }
        }
        .sheet(isPresented: $isShowingCustomURLSheet) {
            NavigationStack {
                ServerURLView(serverURL: $customServerURL, isPresented: $isShowingCustomURLSheet)
            }
        }
    }
}

extension LoginView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && password.count > 7
    }
}

enum AppIconProvider {
    static func appIcon(in bundle: Bundle = .main) -> String {
        guard let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconFileName = iconFiles.last else {
            fatalError("Could not find icons in bundle")
        }
        return iconFileName
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
