//
//  RegisterAccountPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/6/25.
//

import SwiftUI

struct RegisterAccountPage: View {
    @Environment(\.dismiss) private var dismiss
    @State private var userName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var repassword: String = ""
    @StateObject private var vm: RegisterAccountViewModel = RegisterAccountViewModel(service: .init(config: .init()))
    
    var body: some View {
        ZStack {
            VStack {
                InfoField(title: "UserName", text: $userName)
                InfoField(title: "Email", text: $email)
                InfoField(title: "Password", text: $password)
                InfoField(title: "Repeat-Password", text: $repassword)
                
                Button {
                    Task {
                        if password != repassword {
                            return
                        }
                        try? await vm.register(param: .init(username: userName, email: email.lowercased(), password: password))
                    }
                } label: {
                    Text("Save")
                }
            }
            .padding(.bottom,20)
            .padding(.horizontal,20)
            
 
            
            // Loading overlay
             if vm.isLoading {
                 Color.black.opacity(0.3).ignoresSafeArea()
                 ProgressView("Creating account…")
                     .padding()
                     .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
             }
        }
        .onChange(of: vm.didRegister) { value in
            if value {
                // handle back
                dismiss()
            }
        }

    }
}

#Preview {
    RegisterAccountPage()
}
