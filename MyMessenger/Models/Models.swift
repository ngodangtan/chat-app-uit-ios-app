//
//  Models.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/9/25.
//

// MARK: - DTOs (requests)

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

// Conversations
public struct CreateSingleConversationRequest: Encodable {
    public let userId: String            // target user id
}

public struct CreateGroupConversationRequest: Encodable {
    public let name: String
    public let memberIds: [String]       // include yourself or server adds you automatically
}

// Friends
public struct FriendRequestAccept: Encodable { public let fromUserId: String }

// Messages
public struct SendMessageRequest: Encodable {
    public let conversationId: String
    public let content: String
}
