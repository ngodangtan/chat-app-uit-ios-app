//
//  AppRoot.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/9/25.
//

import SwiftUI

struct AppRoot: View {
    @EnvironmentObject var auth: AuthViewModel
    
    var body: some View {
        Group {
            if auth.isLoggedIn {
                NavigationStack {
                    MainPage()
                }
            } else {
                LoginPage()
            }
        }
        .animation(.default, value: auth.isLoggedIn)
        .task {
            auth.checkIsLoginorNot()
        }
    }
}
