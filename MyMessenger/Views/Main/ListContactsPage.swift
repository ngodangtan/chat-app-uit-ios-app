//
//  ListContactsPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/9/25.
//

import SwiftUI

struct ListContactsPage: View {
    @StateObject private var vm = ContactsViewModel(service: .init(config: .init()))
    // service riêng để tạo/get conversation + lấy "me"
    private let service = DefaultAPIService(config: .init())

    // Điều hướng sang ChatView sau khi tạo/get conversation
    @State private var openingChat: Chat? = nil
    @State private var isCreatingChat: Set<String> = [] // friendId đang mở chat

    var body: some View {
        Group {
            if vm.isLoading && vm.friends.isEmpty {
                ProgressView("Loading contacts…")
            } else if vm.friends.isEmpty {
                ContentUnavailableView("No contacts",
                                       systemImage: "person.2",
                                       description: Text("You have no friends yet."))
            } else {
                List {
                    ForEach(vm.friends, id: \.id) { user in
                        HStack {
                            Text(user.username)
                                .font(.body)

                            Spacer(minLength: 12)

                            // Nút Chat (single)
                            Button {
                                Task { await openSingleChat(with: user) }
                            } label: {
                                if isCreatingChat.contains(user.id) {
                                    ProgressView()
                                } else {
                                    Label("Chat", systemImage: "bubble.right.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCreatingChat.contains(user.id))

                            // Nút Huỷ kết bạn
                            Button(role: .destructive) {
                                vm.unfriend(userId: user.id)
                            } label: {
                                if vm.unfriending.contains(user.id) {
                                    ProgressView()
                                } else {
                                    Text("Huỷ kết bạn")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(vm.unfriending.contains(user.id))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Contacts")
        .task { await vm.load() }
        .alert("Error", isPresented: $vm.hasError, actions: {
            Button("OK", role: .cancel) { vm.hasError = false }
        }, message: {
            Text(vm.errorMessage ?? "Something went wrong.")
        })
        .refreshable { await vm.reload() }

        // Điều hướng ChatView
        .navigationDestination(item: $openingChat) { chat in
            ChatView(chat: chat)
                .navigationTitle(chat.title)
                .navigationBarTitleDisplayMode(.inline)
        }
        // Toolbar giữ nguyên (Requests + Add Friend) nếu bạn đã có
    }

    // MARK: - Actions

    /// Tạo/get single conversation với friend và mở ChatView
    private func openSingleChat(with friend: User) async {
        guard !isCreatingChat.contains(friend.id) else { return }
        isCreatingChat.insert(friend.id)
        defer { isCreatingChat.remove(friend.id) }

        do {
            // Lấy "me" để gắn participants
            let me = try await service.me()

            // Tạo/get conversation 1-1
            // Client hiện dùng CreateSingleConversationRequest(userId:),
            // backend đang mong otherUserId. Xem ghi chú ở cuối.
            let conv = try await service.createSingleConversation(
                .init(userId: friend.id)
            )

            // Build participants & Chat model
            let meP = Participant(id: me.id, name: me.username, avatarURL: me.avatar, isCurrentUser: true)
            let friendP = Participant(id: friend.id, name: friend.username, avatarURL: friend.avatar, isCurrentUser: false)

            let title = friend.username
            let chat = Chat(
                id: conv.id,
                type: .oneToOne,
                title: title,
                participants: [meP, friendP],
                messages: [] // có thể load lịch sử tại ChatView nếu muốn
            )

            openingChat = chat
        } catch {
            // Có thể hiển thị alert riêng tại đây nếu bạn muốn
            print("Open chat failed:", error.localizedDescription)
        }
    }
}

