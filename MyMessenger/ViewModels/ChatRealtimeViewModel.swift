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

final class ChatRealtimeViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var typingNames: [String] = []

    // Loading/error cho history
    @Published var isLoadingHistory = false
    @Published var historyError: String?

    private var cancellables = Set<AnyCancellable>()
    private let conversationId: String
    private let participantsById: [String: Participant]
    private let service: DefaultAPIService

    init(conversationId: String,
         participants: [Participant],
         service: DefaultAPIService = .init(config: .init())) {
        self.conversationId = conversationId
        self.participantsById = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        self.service = service
        subscribe()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - History (REST)
    @MainActor
    func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let apiMessages = try await service.getMessages(conversationId: conversationId)
            let mapped = apiMessages.map { ChatMessage(api: $0, participantsById: participantsById) }
            self.messages = mapped
            // Đánh dấu đã xem sau khi nạp lịch sử
            self.markSeen()
        } catch {
            self.historyError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - In/Out (Realtime)

    func send(text: String, me: Participant) {
        // create local message with clientId = id (so we can match server echo)
        var local = ChatMessage(conversationId: conversationId, sender: me, content: text, createdAt: Date(), status: .sending)
        // ensure id is stable client id
        let clientId = local.id
        messages.append(local)

        // emit lên server kèm clientId
        RealtimeClient.shared.sendMessage(conversationId: conversationId, content: text, clientId: clientId)
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
            .sink { [weak self] noti in
                self?.handleNewMessage(noti)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .rtTyping)
            .sink { [weak self] noti in
                self?.handleTyping(noti)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .rtSeen)
            .sink { [weak self] noti in
                self?.handleSeen(noti)
            }
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
        let clientIdFromServer = dict["clientId"] as? String

        let sender = participantsById[senderId] ?? Participant(id: senderId, name: "Unknown")
        let msg = ChatMessage(id: id, conversationId: convId, sender: sender, content: content, createdAt: createdAt, status: .sent)

        DispatchQueue.main.async {
            // 1) If server returned clientId, prefer matching by clientId (reliable)
            if let clientId = clientIdFromServer {
                if let idx = self.messages.firstIndex(where: { $0.id == clientId }) {
                    // update local (replace id -> server id, timestamp, status)
                    self.messages[idx].id = id
                    self.messages[idx].createdAt = createdAt
                    self.messages[idx].status = .sent
                    return
                }
            }

            // 2) Fallback: if sender is current user, try to match a .sending local message by sender+content
            if sender.isCurrentUser {
                if let idx = self.messages.firstIndex(where: {
                    $0.sender.id == sender.id && $0.status == .sending && $0.content == content
                }) {
                    self.messages[idx].id = id
                    self.messages[idx].createdAt = createdAt
                    self.messages[idx].status = .sent
                    return
                }
            }

            // 3) Otherwise append as normal
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

