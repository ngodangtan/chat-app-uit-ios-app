//
//  SplashPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/6/25.
//

import SwiftUI 

struct SplashPage: View {
    @ObservedObject private var viewModel = SlashPageViewModel()
    var body: some View {
        Text("Go to Login")
        VStack {
            Text("Hello, World!")
        }
    }
}
