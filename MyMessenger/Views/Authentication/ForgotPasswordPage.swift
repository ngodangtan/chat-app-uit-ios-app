//
//  ForgotPasswordPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 14/9/25.
//

import SwiftUI

struct ForgotPasswordPage: View {
    @State var email: String = ""
    var body: some View {
        VStack {
            InfoField(title: "Email", text: $email)
        }
    }
}
