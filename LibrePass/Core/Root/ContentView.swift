//
//  MainWindow.swift
//  LibrePass
//
//  Created by Nish on 2024-04-06.
//

import SwiftUI

struct ContentView: View {
    
    @State private var isRegisterButtonTapped = false
    @State private var isLoginButtonTapped = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: UIImage(named: AppIconProvider.appIcon())!)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Text("Welcome to LibrePass")
                    .padding(.top, 20)
                
                NavigationLink(destination: SignupView()) {
                    Text("Register")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 90)
                .padding(.top, 20)
                
                NavigationLink(destination: LoginView()) {
                    Text("Login")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .padding(.horizontal, 90)
                .padding(.top, 8)
            }
        }
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
    ContentView()
}
