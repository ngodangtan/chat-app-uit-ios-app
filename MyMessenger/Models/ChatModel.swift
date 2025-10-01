//
//  ChatModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 1/10/25.
//

import Foundation

// MARK: - UI Models (adapted to API models)
enum ChatType { case oneToOne, group }

struct Participant: Identifiable, Hashable {
    let id: String                 // match API User.id
    let name: String
    let avatarURL: URL?
    let isCurrentUser: Bool
    init(id: String = UUID().uuidString,
         name: String,
         avatarURL: URL? = nil,
         isCurrentUser: Bool = false) {
        self.id = id; self.name = name; self.avatarURL = avatarURL; self.isCurrentUser = isCurrentUser
    }
}

struct Chat: Identifiable, Equatable, Hashable {
    let id: String                 // match Conversation.id
    let type: ChatType
    let title: String
    let participants: [Participant]
    var messages: [ChatMessage]
}

// So sánh & hash chỉ theo id để tránh tốn kém khi mảng lớn
extension Chat {
    static func == (lhs: Chat, rhs: Chat) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// UI view-model for API.Message
enum MessageStatus { case sending, sent, delivered, read }


public enum ConversationType: String, Codable {
    case single, group
}

public struct Conversation: Codable, Identifiable, Hashable {
    public let id: String
    public let type: ConversationType
    public let name: String?
    public let members: [User]
    public let lastMessageAt: Date?
}

public struct Message: Codable, Identifiable, Hashable {
    enum Status { case sending, sent, delivered, read }
    public let id: String
    public let conversationId: String
    public let senderId: String
    public let content: String
    public let createdAt: Date
}

struct ChatMessage: Identifiable, Hashable {
    var id: String                 // API.Message.id (mutable to be reconciled with server id)
    let conversationId: String
    let sender: Participant        // mapped from API senderId
    let content: String            // API.Message.content
    var createdAt: Date            // make mutable so we can replace with server timestamp
    var status: MessageStatus = .sent

    init(id: String = UUID().uuidString,
         conversationId: String,
         sender: Participant,
         content: String,
         createdAt: Date,
         status: MessageStatus = .sent) {
        self.id = id
        self.conversationId = conversationId
        self.sender = sender
        self.content = content
        self.createdAt = createdAt
        self.status = status
    }

    /// Convenient mapper from API `Message` -> `ChatMessage`
    init(api: Message, participantsById: [String: Participant], fallbackName: String = "Unknown") {
        let sender = participantsById[api.senderId]
            ?? Participant(id: api.senderId, name: fallbackName)
        self.init(id: api.id,
                  conversationId: api.conversationId,
                  sender: sender,
                  content: api.content,
                  createdAt: api.createdAt,
                  status: .sent)
    }
}
