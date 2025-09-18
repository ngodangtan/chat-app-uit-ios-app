// RealtimeClient.swift
// MyMessenger

import Foundation
import SocketIO

/// Sự kiện & payload backend (theo file socket.js):
/// - handshake.auth.token (JWT)
/// - emit: "chat:send" { conversationId, content }
/// - emit: "chat:typing" { conversationId, isTyping }
/// - emit: "chat:seen" { conversationId }
/// - on:   "chat:new" { _id, conversationId, senderId, content, createdAt }
/// - on:   "chat:typing" { userId, isTyping, conversationId }
/// - on:   "chat:seen" { userId, conversationId }

public final class RealtimeClient {
    public static let shared = RealtimeClient()

    private var manager: SocketManager?
    private(set) var socket: SocketIOClient?

    /// Base URL của Socket.IO server (trùng host API HTTP của bạn)
    private let socketURL = URL(string: "http://localhost:3000")!

    /// Lấy JWT từ Keychain (đồng bộ với APIService)
    private func currentToken() -> String? {
        KeychainHelper.shared.readString(service: "com.myapp.auth", account: "accessToken")
    }

    private init() {}

    // MARK: - Public API

    /// Gọi sau khi login xong (đã có JWT trong Keychain)
    public func connect() {
        guard let token = currentToken(), !token.isEmpty else {
            print("[Realtime] Missing token, skip connect")
            return
        }

        // Tạo manager, KHÔNG đính token vào query
        let manager = SocketManager(
            socketURL: URL(string: "http://localhost:3000")!,
            config: [
                .log(true),
                .compress,
                .forceWebsockets(true),
                .reconnects(true),
                .reconnectAttempts(-1),
                .reconnectWait(2)
            ]
        )

        let socket = manager.defaultSocket

        // >> Quan trọng: gửi JWT qua payload của connect (để server đọc ở handshake.auth)
        socket.connect(withPayload: ["token": token])

        // Listeners
        bindCoreEvents(socket)
        bindBusinessEvents(socket)

        self.manager = manager
        self.socket = socket
    }

    public func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
    }

    /// Gửi tin nhắn
    public func sendMessage(conversationId: String, content: String) {
        socket?.emit("chat:send", ["conversationId": conversationId, "content": content])
    }

    /// Đánh dấu đang gõ
    public func setTyping(conversationId: String, isTyping: Bool) {
        socket?.emit("chat:typing", ["conversationId": conversationId, "isTyping": isTyping])
    }

    /// Đánh dấu đã xem
    public func markSeen(conversationId: String) {
        socket?.emit("chat:seen", ["conversationId": conversationId])
    }

    // MARK: - Events

    private func bindCoreEvents(_ socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { _, _ in
            print("[Realtime] connected")
        }
        socket.on(clientEvent: .error) { data, _ in
            print("[Realtime] error:", data)
        }
        socket.on(clientEvent: .disconnect) { _, _ in
            print("[Realtime] disconnected")
        }
        socket.on(clientEvent: .reconnect) { _, _ in
            print("[Realtime] reconnecting…")
        }
    }

    private func bindBusinessEvents(_ socket: SocketIOClient) {
        // Nhận tin nhắn mới
        socket.on("chat:new") { data, _ in
            guard let raw = data.first as? [String: Any] else { return }
            NotificationCenter.default.post(
                name: .rtNewMessage,
                object: nil,
                userInfo: raw
            )
        }

        // Trạng thái typing từ người khác
        socket.on("chat:typing") { data, _ in
            guard let raw = data.first as? [String: Any] else { return }
            NotificationCenter.default.post(
                name: .rtTyping,
                object: nil,
                userInfo: raw
            )
        }

        // Đã xem
        socket.on("chat:seen") { data, _ in
            guard let raw = data.first as? [String: Any] else { return }
            NotificationCenter.default.post(
                name: .rtSeen,
                object: nil,
                userInfo: raw
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let rtNewMessage = Notification.Name("rt.newMessage")
    static let rtTyping     = Notification.Name("rt.typing")
    static let rtSeen       = Notification.Name("rt.seen")
}
