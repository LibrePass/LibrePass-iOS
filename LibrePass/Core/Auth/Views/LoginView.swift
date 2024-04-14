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
