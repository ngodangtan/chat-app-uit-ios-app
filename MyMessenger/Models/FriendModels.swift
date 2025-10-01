//
//  Models.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/9/25.
//

import Foundation

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

public struct FriendRequestCreate: Encodable, Hashable {
    public let email: String
}

public enum FriendRequestStatus: String, Codable {
    case pending, accepted, rejected
}

public struct FriendRequest: Codable, Identifiable, Hashable {
    public let id: String
    public let from: User
    public let to: User
    public let status: FriendRequestStatus
}
