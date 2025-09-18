//
//  LoginPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/6/25.
//

import SwiftUI

struct LoginPage: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var path = [Int]()
    @EnvironmentObject var auth: AuthViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                VStack {
                    InfoField(title: "Email", text: $email)
                    InfoField(title: "Password", text: $password)
                }
                .padding(.bottom,20)
                .padding(.horizontal,20)
                
                
                Button("Login") {
                    Task {
                        await auth.login(email: email, password: password)
                    }
                }
                .padding(.bottom, 20)
                
                Button("Forgot Password") {
                    path.append(1)
                }
                .padding(.bottom, 20)
                
                Button("Create Account") {
                    path.append(2)
                }
            }   .padding(.bottom, 20)
            .navigationTitle("Login")
            .navigationDestination(for: Int.self) { selection in
                if selection == 1 {
                    ForgotPasswordPage()
                } else if selection == 2 {
                    RegisterAccountPage()
                }
            }
        }
    }
}

#Preview {
    LoginPage()
}
