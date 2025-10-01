//
//  UserModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 1/10/25.
//

import Foundation

public struct User: Codable, Identifiable, Hashable {
    public let id: String
    public let username: String
    public let email: String
    public let avatar: URL?
}

public struct RegisterRequest: Encodable {
    public let username: String
    public let email: String
    public let password: String
}

public struct LoginRequest: Encodable {
    public let emailOrUsername: String
    public let password: String
}

public struct TokenResponse: Decodable {
    public let token: String
    public let user: User
}

public struct ForgotPasswordRequest: Encodable {
    public let email: String
}

public struct ResetPasswordRequest: Encodable {
    public let token: String
    public let newPassword: String
}
