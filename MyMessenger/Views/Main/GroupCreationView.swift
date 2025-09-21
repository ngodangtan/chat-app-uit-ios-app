//
//  GroupCreationView.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 21/9/25.
//

import SwiftUI

struct GroupCreationView: View {
    @Environment(\.dismiss) private var dismiss
    private let service = DefaultAPIService(config: .init())

    // UI state
    @State private var emailQuery: String = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var results: [User] = []

    @State private var selected: [User] = []
    @State private var creating = false
    @State private var createError: String?
    @State private var navigateToChat = false
    @State private var createdChat: Chat?

    // (Optional) nhập tên nhóm
    @State private var groupName: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // NHẬP EMAIL + NÚT TÌM
            HStack(spacing: 8) {
                TextField("Nhập email để tìm…", text: $emailQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await doSearch() }
                } label: {
                    if isSearching { ProgressView().scaleEffect(0.8) }
                    else { Image(systemName: "magnifyingglass") }
                }
                .disabled(emailQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }
            .padding(.horizontal)

            if let err = searchError {
                Text(err).foregroundStyle(.orange).font(.caption)
            }

            // KẾT QUẢ TÌM KIẾM
            List {
                if !results.isEmpty {
                    Section("Kết quả") {
                        ForEach(results, id: \.id) { u in
                            HStack {
                                AvatarView(name: u.username, url: u.avatar, size: 28)
                                VStack(alignment: .leading) {
                                    Text(u.username).font(.subheadline)
                                    Text(u.email).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    addUser(u)
                                } label: {
                                    Label(selected.contains(where: { $0.id == u.id }) ? "Đã thêm" : "Thêm",
                                          systemImage: selected.contains(where: { $0.id == u.id }) ? "checkmark" : "plus")
                                }
                                .buttonStyle(.bordered)
                                .disabled(selected.contains(where: { $0.id == u.id }))
                            }
                        }
                    }
                }

                // DANH SÁCH ĐÃ CHỌN
                if !selected.isEmpty {
                    Section("Đã chọn (\(selected.count))") {
                        ForEach(selected, id: \.id) { u in
                            HStack {
                                AvatarView(name: u.username, url: u.avatar, size: 24)
                                Text(u.username)
                                Spacer()
                                Button(role: .destructive) {
                                    selected.removeAll { $0.id == u.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // TÊN NHÓM (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("Tên nhóm (tuỳ chọn)").font(.caption).foregroundStyle(.secondary)
                TextField("Ví dụ: iOS Squad", text: $groupName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            // NÚT TẠO NHÓM
            Button {
                Task { await createGroup() }
            } label: {
                HStack {
                    if creating { ProgressView().scaleEffect(0.9) }
                    Text("Tạo nhóm")
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(creating || selected.count < 2) // tối thiểu bạn + 2 người nữa => tổng >= 3
            .padding(.horizontal)

            if let err = createError {
                Text(err).foregroundStyle(.orange).font(.caption)
            }

            NavigationLink(isActive: $navigateToChat) {
                if let chat = createdChat {
                    ChatView(chat: chat)
                        .navigationTitle(chat.title)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    EmptyView()
                }
            } label: { EmptyView() }
        }
        .navigationTitle("Tạo nhóm")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions
    private func addUser(_ u: User) {
        if !selected.contains(where: { $0.id == u.id }) {
            selected.append(u)
        }
    }

    private func doSearch() async {
        guard !emailQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true; searchError = nil
        defer { isSearching = false }
        do {
            // backend cho phép tìm theo email/username qua q
            results = try await service.searchUsers(q: emailQuery)
            if results.isEmpty { searchError = "Không tìm thấy user phù hợp." }
        } catch {
            searchError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func createGroup() async {
        guard selected.count >= 2 else { return } // bạn + >=2 => tổng >=3
        creating = true; createError = nil
        defer { creating = false }

        do {
            // Lấy profile hiện tại để đánh dấu isCurrentUser
            let me = try await service.me()

            // memberIds không cần bao gồm mình — server sẽ tự thêm, nhưng thêm cũng không sao
            let memberIds = selected.map(\.id)

            let conv = try await service.createGroupConversation(
                .init(name: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nilNameSuggestion() : groupName,
                      memberIds: memberIds)
            )

            // Map Conversation -> Chat để mở ChatView
            let participants: [Participant] = conv.members.map {
                Participant(id: $0.id, name: $0.username, avatarURL: $0.avatar, isCurrentUser: $0.id == me.id)
            }

            let chat = Chat(
                id: conv.id,
                type: .group,
                title: conv.name ?? defaultGroupTitle(from: participants),
                participants: participants,
                messages: []
            )
            createdChat = chat
            navigateToChat = true
        } catch {
            createError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func nilNameSuggestion() -> String {
        // nếu không nhập tên nhóm -> gợi ý tên từ 3 thành viên đầu
        let names = selected.prefix(3).map(\.username)
        return names.isEmpty ? "Group" : names.joined(separator: ", ")
    }

    private func defaultGroupTitle(from ps: [Participant]) -> String {
        let others = ps.filter { !$0.isCurrentUser }.map(\.name)
        if others.isEmpty { return "Group" }
        return others.prefix(3).joined(separator: ", ")
    }
}
