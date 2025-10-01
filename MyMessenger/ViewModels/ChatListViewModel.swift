//
//  ChatListViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 18/9/25.
//

import SwiftUI
import Combine

@MainActor
final class ChatListViewModel: ObservableObject {
    struct Row: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let type: ChatType
        let participants: [Participant]
        let conversation: Conversation
    }

    @Published var rows: [Row] = []
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let service: DefaultAPIService
    private var currentUserId: String?
    @Published var deleting: Set<String> = []

    init(service: DefaultAPIService = .init(config: .init())) {
        self.service = service
    }
}

extension ChatListViewModel {
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // 1) Lấy user hiện tại để biết ai là "mình"
            let me = try await service.me()
            currentUserId = me.id

            // 2) Lấy danh sách hội thoại
            let convs = try await service.myConversations()

            // 3) Map sang Row cho UI
            rows = convs.map { conv in
                let type: ChatType = (conv.type == .single) ? .oneToOne : .group
                let participants: [Participant] = conv.members.map { u in
                    Participant(
                        id: u.id,
                        name: u.username,
                        avatarURL: u.avatar,
                        isCurrentUser: u.id == me.id
                    )
                }

                // Tiêu đề:
                let title: String
                switch type {
                case .oneToOne:
                    // tên người còn lại
                    let other = participants.first(where: { !$0.isCurrentUser })
                    title = other?.name ?? conv.name ?? "Chat"
                case .group:
                    title = conv.name ?? "Group (\(participants.count))"
                }

                // Tạm thời chưa có last-message content, dùng thời điểm cuối
                let subtitle: String?
                if let last = conv.lastMessageAt {
                    let df = DateFormatter()
                    df.dateStyle = .short
                    df.timeStyle = .short
                    subtitle = "Last activity: " + df.string(from: last)
                } else {
                    subtitle = nil
                }

                return Row(
                    id: conv.id,
                    title: title,
                    subtitle: subtitle,
                    type: type,
                    participants: participants,
                    conversation: conv
                )
            }
        } catch {
            hasError = true
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    func deleteConversation(_ row: Row) async {
        guard !deleting.contains(row.id) else { return }
        deleting.insert(row.id)

        let backup = rows
        rows.removeAll { $0.id == row.id }

        do {
            _ = try await service.deleteConversation(conversationId: row.id)
        } catch {
            rows = backup
            hasError = true
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        deleting.remove(row.id)
    }

    func reload() async { await load() }

    /// Tạo model `Chat` để mở `ChatView`
    func makeChat(for row: Row) -> Chat {
        Chat(
            id: row.id,
            type: row.type,
            title: row.title,
            participants: row.participants,
            messages: [] // sẽ nhận realtime +/hoặc load lịch sử sau
        )
    }
}
