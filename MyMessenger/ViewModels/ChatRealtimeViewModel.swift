// ChatRealtimeViewModel.swift
// MyMessenger

import Foundation
import Combine

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

struct Chat: Identifiable {
    let id: String                 // match Conversation.id
    let type: ChatType
    let title: String
    let participants: [Participant]
    var messages: [ChatMessage]
}

// UI view-model for API.Message
enum MessageStatus { case sending, sent, delivered, read }

struct ChatMessage: Identifiable, Hashable {
    let id: String                 // API.Message.id
    let conversationId: String
    let sender: Participant        // mapped from API senderId
    let content: String            // API.Message.content
    let createdAt: Date
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

final class ChatRealtimeViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var typingNames: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private let conversationId: String
    private let participantsById: [String: Participant]

    init(conversationId: String, participants: [Participant]) {
        self.conversationId = conversationId
        self.participantsById = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        subscribe()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - In/Out

    func send(text: String, me: Participant) {
        // append local (status .sending)
        let local = ChatMessage(conversationId: conversationId, sender: me, content: text, createdAt: Date(), status: .sending)
        messages.append(local)

        // emit lên server
        RealtimeClient.shared.sendMessage(conversationId: conversationId, content: text)
    }

    func setTyping(_ on: Bool) {
        RealtimeClient.shared.setTyping(conversationId: conversationId, isTyping: on)
    }

    func markSeen() {
        RealtimeClient.shared.markSeen(conversationId: conversationId)
    }

    // MARK: - Subscriptions

    private func subscribe() {
        NotificationCenter.default.publisher(for: .rtNewMessage)
            .sink { [weak self] noti in self?.handleNewMessage(noti) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .rtTyping)
            .sink { [weak self] noti in self?.handleTyping(noti) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .rtSeen)
            .sink { [weak self] noti in self?.handleSeen(noti) }
            .store(in: &cancellables)
    }

    private func handleNewMessage(_ noti: Notification) {
        guard
            let dict = noti.userInfo as? [String: Any],
            let convId = dict["conversationId"] as? String,
            convId == conversationId
        else { return }

        let id = (dict["_id"] as? String) ?? UUID().uuidString
        let senderId = dict["senderId"] as? String ?? "unknown"
        let content = dict["content"] as? String ?? ""
        let createdAtISO = dict["createdAt"] as? String
        let createdAt = ISO8601DateFormatter().date(from: createdAtISO ?? "") ?? Date()

        let sender = participantsById[senderId] ?? Participant(id: senderId, name: "Unknown")
        let msg = ChatMessage(id: id, conversationId: convId, sender: sender, content: content, createdAt: createdAt, status: .sent)

        DispatchQueue.main.async {
            self.messages.append(msg)
        }
    }

    private func handleTyping(_ noti: Notification) {
        guard
            let dict = noti.userInfo as? [String: Any],
            let convId = dict["conversationId"] as? String,
            convId == conversationId
        else { return }

        let uid = dict["userId"] as? String ?? ""
        let isTyping = dict["isTyping"] as? Bool ?? false
        let name = participantsById[uid]?.name ?? "Someone"

        DispatchQueue.main.async {
            if isTyping {
                if !self.typingNames.contains(name) { self.typingNames.append(name) }
            } else {
                self.typingNames.removeAll { $0 == name }
            }
        }
    }

    private func handleSeen(_ noti: Notification) {
        guard
            let dict = noti.userInfo as? [String: Any],
            let convId = dict["conversationId"] as? String,
            convId == conversationId
        else { return }

        // Tuỳ yêu cầu UI: đổi status các tin của mình thành .read
        DispatchQueue.main.async {
            for i in self.messages.indices {
                if self.messages[i].sender.isCurrentUser {
                    self.messages[i].status = .read
                }
            }
        }
    }
}
