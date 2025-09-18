//
//  ChatViewPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/9/25.
//

import SwiftUI


// MARK: - Chat View
struct ChatView: View {
    let chat: Chat

    @State private var draft: String = ""
    @State private var isAtBottom: Bool = true
    @State private var typingUsers: [Participant] = []
    @Namespace private var bottomID
    @StateObject private var rtVM: ChatRealtimeViewModel
    
    
    init(chat: Chat) {
        self.chat = chat
         _rtVM = StateObject(wrappedValue: {
             let vm = ChatRealtimeViewModel(
                 conversationId: chat.id,
                 participants: chat.participants
             )
             // Seed messages for previews / initial state
             vm.messages = chat.messages
             return vm
         }())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            inputBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rtVM.messages.count) { _ in
            scrollToBottom(animated: true)
        }
        .onAppear {
            rtVM.markSeen()
            scrollToBottom(animated: false)
        }
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 12) {
            if chat.type == .group {
                GroupAvatar(participants: Array(chat.participants.prefix(4)))
            } else {
                let other = chat.participants.first(where: { !$0.isCurrentUser })
                AvatarView(name: other?.name ?? "", url: other?.avatarURL, size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title).font(.headline)
                if chat.type == .group {
                    Text("\(chat.participants.count) members")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    Text("Online").foregroundColor(.green).font(.subheadline)
                }
            }
            Spacer()
            Button { /* search */ } label: { Image(systemName: "magnifyingglass") }
            Button { /* call */ } label: { Image(systemName: "phone") }
            Button { /* more */ } label: { Image(systemName: "ellipsis.circle") }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: Messages
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(groupedByDay(rtVM.messages), id: \.0) { day, items in
                        DateSeparator(date: day)
                        ForEach(items) { msg in
                            MessageRow(message: msg, isGroup: chat.type == .group)
                                .id(msg.id)
                        }
                    }
                    if !rtVM.typingNames.isEmpty {
                        TypingIndicator(names: rtVM.typingNames)
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onAppear { scrollToBottom(animated: false, proxy: proxy) }
            .onChange(of: rtVM.messages) { _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(bottomID, anchor: .bottom) }
            }
        }
    }

    // MARK: Input
    private var inputBar: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                Button { } label: { Image(systemName: "paperclip") }.padding(8)

                GrowingTextEditor(text: $draft, placeholder: "Message \(chat.type == .group ? "group" : "…")")
                    .frame(minHeight: 38, maxHeight: 120)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    .onChange(of: draft) { text in
                        rtVM.setTyping(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                Button {
                    let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !content.isEmpty else { return }
                    draft = ""
                    if let me = chat.participants.first(where: { $0.isCurrentUser }) {
                        rtVM.send(text: content, me: me)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                        .padding(10)
                        .background(Circle().fill(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.accentColor))
                        .foregroundColor(.white)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }

    // MARK: Helpers
    private func send() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""

        // TODO: call ViewModel -> API `sendMessage`
        // Tạm thời tạo tin nhắn local (status .sending)
        if let me = chat.participants.first(where: { $0.isCurrentUser }) {
            let local = ChatMessage(conversationId: chat.id, sender: me, content: content, createdAt: Date(), status: .sending)
            // append vào datasource ở ViewModel của bạn
            print("Local message placeholder:", local)
        }
    }

    private func scrollToBottom(animated: Bool, proxy: ScrollViewProxy? = nil) {
        let action = { proxy?.scrollTo(bottomID, anchor: .bottom) }
        if animated { withAnimation(.easeOut(duration: 0.25)) { action() } } else { action() }
    }

    private func groupedByDay(_ messages: [ChatMessage]) -> [(Date, [ChatMessage])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: messages) { msg in
            calendar.startOfDay(for: msg.createdAt)
        }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.createdAt < $1.createdAt }) }
    }
}

// MARK: - Row

struct MessageRow: View {
    let message: ChatMessage
    let isGroup: Bool

    var body: some View {
        let mine = message.sender.isCurrentUser

        HStack(alignment: .bottom, spacing: 8) {
            if !mine {
                AvatarView(name: message.sender.name, url: message.sender.avatarURL, size: 28)
            } else {
                Spacer(minLength: 24)
            }

            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if isGroup && !mine {
                    Text(message.sender.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(mine ? .trailing : .leading, 6)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    if mine { Spacer(minLength: 0) }

                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            BubbleShape(isMine: mine)
                                .fill(mine ? Color.accentColor : Color(.secondarySystemBackground))
                        )
                        .foregroundColor(mine ? .white : .primary)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: mine ? .trailing : .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(message.createdAt.formattedTime())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if mine { StatusTicks(status: message.status) }
                    }
                }
            }

            if mine {
                AvatarView(name: message.sender.name, url: message.sender.avatarURL, size: 0).hidden()
            } else {
                Spacer(minLength: 24)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Components (unchanged UI)

struct DateSeparator: View {
    let date: Date
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(Color(.tertiaryLabel))
            Text(date.formattedSeparator())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
            Rectangle().frame(height: 1).foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 6)
    }
}

struct TypingIndicator: View {
    let names: [String]
    var body: some View {
        HStack(spacing: 8) {
            Circle().frame(width: 6, height: 6).opacity(0.3)
                .overlay(Circle().frame(width: 6, height: 6).opacity(0.7))
            Text(text)
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private var text: String {
        if names.isEmpty { return "Typing…" }
        if names.count == 1 { return "\(names[0]) is typing…" }
        if names.count == 2 { return "\(names[0]) & \(names[1]) are typing…" }
        return "\(names[0]), \(names[1]) +\(names.count - 2) are typing…"
    }
}

struct StatusTicks: View {
    let status: MessageStatus
    var body: some View {
        switch status {
        case .sending:
            Image(systemName: "clock").font(.caption2).foregroundColor(.secondary)
        case .sent:
            Image(systemName: "checkmark").font(.caption2).foregroundColor(.secondary)
        case .delivered:
            HStack(spacing: -2) {
                Image(systemName: "checkmark").font(.caption2).foregroundColor(.secondary)
                Image(systemName: "checkmark").font(.caption2).foregroundColor(.secondary).offset(x: -4)
            }
        case .read:
            HStack(spacing: -2) {
                Image(systemName: "checkmark").font(.caption2).foregroundColor(.blue)
                Image(systemName: "checkmark").font(.caption2).foregroundColor(.blue).offset(x: -4)
            }
        }
    }
}

struct BubbleShape: Shape {
    let isMine: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var p = Path(roundedRect: rect, cornerRadius: r)
        let tailSize = CGSize(width: 8, height: 10)
        let tailX = isMine ? rect.maxX - 6 : rect.minX + 6
        let direction: CGFloat = isMine ? 1 : -1
        var tail = Path()
        tail.move(to: CGPoint(x: tailX, y: rect.maxY - 12))
        tail.addLine(to: CGPoint(x: tailX + tailSize.width * direction, y: rect.maxY - 8))
        tail.addLine(to: CGPoint(x: tailX, y: rect.maxY - 4))
        tail.closeSubpath()
        p.addPath(tail)
        return p
    }
}

struct AvatarView: View {
    let name: String
    let url: URL?
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            Circle().fill(Color(.secondarySystemBackground))
            Text(initials(from: name)).font(.caption).bold().foregroundColor(.secondary)
        }
        .frame(width: size, height: size)
    }
    private func initials(from name: String) -> String {
        let comps = name.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

struct GroupAvatar: View {
    let participants: [Participant]
    var body: some View {
        ZStack {
            ForEach(Array(participants.enumerated()), id: \.element.id) { idx, p in
                AvatarView(name: p.name, url: p.avatarURL, size: 22)
                    .offset(x: CGFloat(idx) * 14)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
        }
        .frame(width: 22 + CGFloat(max(0, participants.count - 1)) * 14 + 4, height: 24)
    }
}

struct GrowingTextEditor: View {
    @Binding var text: String
    let placeholder: String
    @State private var height: CGFloat = 38
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            TextEditor(text: $text)
                .padding(6)
                .background(GeometryReader { geo in
                    Color.clear.onChange(of: text) { _ in
                        height = max(38, min(120, geo.size.height))
                    }
                })
        }
    }
}

// MARK: - Utils

private struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

extension Date {
    func formattedTime() -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: self)
    }
    func formattedSeparator() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }
}

// MARK: - Preview / Demo

struct ChatView_Previews: PreviewProvider {
    static let me = Participant(id: "me", name: "You", isCurrentUser: true)
    static let alice = Participant(id: "alice", name: "Alice")
    static let bob = Participant(id: "bob", name: "Bob")
    static let carol = Participant(id: "carol", name: "Carol")

    static var oneToOne: Chat {
        let convId = "conv-1"
        let msgs: [ChatMessage] = [
            ChatMessage(conversationId: convId, sender: alice, content: "Hey! Long time no see 👋", createdAt: Date().addingTimeInterval(-3600), status: .delivered),
            ChatMessage(conversationId: convId, sender: me, content: "Hi Alice! How are you?", createdAt: Date().addingTimeInterval(-3500), status: .read),
            ChatMessage(conversationId: convId, sender: alice, content: "Doing great. Coffee later?", createdAt: Date().addingTimeInterval(-3400), status: .delivered),
            ChatMessage(conversationId: convId, sender: me, content: "Absolutely. 3pm?", createdAt: Date().addingTimeInterval(-3300), status: .read)
        ]
        return Chat(id: convId, type: .oneToOne, title: "Alice", participants: [me, alice], messages: msgs)
    }

    static var group: Chat {
        let convId = "conv-2"
        let msgs: [ChatMessage] = [
            ChatMessage(conversationId: convId, sender: bob, content: "Team, kickoff in 10 mins.", createdAt: Date().addingTimeInterval(-7200)),
            ChatMessage(conversationId: convId, sender: carol, content: "On my way!", createdAt: Date().addingTimeInterval(-7100)),
            ChatMessage(conversationId: convId, sender: me, content: "I'll share the deck.", createdAt: Date().addingTimeInterval(-7000), status: .sent),
            ChatMessage(conversationId: convId, sender: bob, content: "Thanks!", createdAt: Date().addingTimeInterval(-6900))
        ]
        return Chat(id: convId, type: .group, title: "iOS Squad", participants: [me, bob, carol, alice], messages: msgs)
    }

    static var previews: some View {
        Group {
            NavigationStack { ChatView(chat: oneToOne) }
                .previewDisplayName("1:1")
            NavigationStack { ChatView(chat: group) }
                .previewDisplayName("Group")
        }
    }
}

