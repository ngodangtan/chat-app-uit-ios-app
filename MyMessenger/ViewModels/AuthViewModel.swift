//
//  AuthViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/9/25.
//
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    private let api = DefaultAPIService(config: .init())
    
    @MainActor
    func login(email: String, password: String) async {
        do {
            let resp = try await api.login(.init(emailOrUsername: email.lowercased(), password: password))
            // lưu token vào Keychain
            KeychainHelper.shared.save(resp.token, service: "com.myapp.auth", account: "accessToken")
            isLoggedIn = true
            // connect realtime
            RealtimeClient.shared.connect()
        } catch {
            print("Login failed:", error.localizedDescription)
        }
    }

    func logout() {
        KeychainHelper.shared.delete(service: "com.myapp.auth", account: "accessToken")
        isLoggedIn = false
        RealtimeClient.shared.disconnect()
    }
    
    func checkIsLoginorNot() {
        if KeychainHelper.shared.read(service: "com.myapp.auth", account: "accessToken") != nil {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }
}
