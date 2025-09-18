//
//  MyMessengerApp.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/6/25.
//

import SwiftUI

@main
struct MyMessengerApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(auth) // 2. Inject environment object
        }
    }
}
