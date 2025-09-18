//
//  ChatListView.swift
//  MyMessenger
//

import SwiftUI

struct ChatListView: View {
    @StateObject private var vm = ChatListViewModel()
    @State private var rowToDelete: ChatListViewModel.Row? = nil
    
    var body: some View {
        Group {
            if vm.isLoading && vm.rows.isEmpty {
                ProgressView("Loading conversations…")
            } else if vm.rows.isEmpty {
                ContentUnavailableView(
                    "No conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new chat from Contacts.")
                )
            } else {
                List {
                    ForEach(vm.rows) { row in
                        NavigationLink {
                            ChatView(chat: vm.makeChat(for: row))
                                .navigationTitle(row.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 12) {
                                // Avatar nhóm/đơn
                                if row.type == .group {
                                    GroupAvatar(participants: Array(row.participants.prefix(4)))
                                } else {
                                    let other = row.participants.first(where: { !$0.isCurrentUser })
                                    AvatarView(name: other?.name ?? row.title,
                                               url: other?.avatarURL,
                                               size: 36)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title)
                                        .font(.headline)
                                        .lineLimit(1)

                                    if let sub = row.subtitle, !sub.isEmpty {
                                        Text(sub)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                if vm.deleting.contains(row.id) {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                rowToDelete = row
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(vm.deleting.contains(row.id))
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.reload() }
            }
        }
        .navigationTitle("Chats")
        .task { await vm.load() }
        .alert("Error", isPresented: $vm.hasError) {
            Button("OK", role: .cancel) { vm.hasError = false }
        } message: {
            Text(vm.errorMessage ?? "Something went wrong.")
        }
        .alert("Delete this conversation?",
               isPresented: Binding(
                get: { rowToDelete != nil },
                set: { if !$0 { rowToDelete = nil } }
               ),
               actions: {
            Button("Delete", role: .destructive) {
                if let row = rowToDelete {
                    Task { await vm.deleteConversation(row) }
                }
                rowToDelete = nil
            }
            Button("Cancel", role: .cancel) { rowToDelete = nil }
        },
               message: {
            Text("This will remove it from your list. For group chats, you will leave the group.")
        }
        )
    }
}

#Preview {
    NavigationStack { ChatListView() }
}

