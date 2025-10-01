//
//  APIService.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 16/9/25.
//

import Foundation

// MARK: - Configuration

public struct APIConfig {
    public var baseURL: URL
    public var jsonDecoder: JSONDecoder
    public var jsonEncoder: JSONEncoder
    public var tokenProvider: () -> String?          // return Bearer token if logged in

    public init(baseURL: URL = URL(string: "http://localhost:3000")!,
                tokenProvider: (() -> String?)? = nil) {
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = decoder
        self.jsonEncoder = encoder
        
        // Nếu không truyền thì mặc định đọc từ KeychainHelper
         if let provider = tokenProvider {
             self.tokenProvider = provider
         } else {
             self.tokenProvider = {
                 KeychainHelper.shared.readString(
                     service: "com.myapp.auth",
                     account: "accessToken"
                 )
             }
         }
    }
}

// MARK: - Errors

public enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case http(Int, String?)
    case noData
    case decodingFailed(Error)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .encodingFailed: return "Failed to encode request body"
        case .http(let code, let msg): return "HTTP \(code): \(msg ?? "No message")"
        case .noData: return "Empty response"
        case .decodingFailed(let err): return "Decoding error: \(err.localizedDescription)"
        case .unknown(let err): return "Unknown error: \(err.localizedDescription)"
        }
    }
}

// MARK: - API Service Protocol

public protocol APIService {
    // Auth
    func register(_ req: RegisterRequest) async throws -> TokenResponse
    func login(_ req: LoginRequest) async throws -> TokenResponse
    func forgotPassword(_ req: ForgotPasswordRequest) async throws -> VoidResponse
    func resetPassword(_ req: ResetPasswordRequest) async throws -> VoidResponse

    // Users
    func me() async throws -> User
    func searchUsers(q: String) async throws -> [User]
    func removeCurrentUser() async throws -> VoidResponse

    // Conversations
    func createSingleConversation(_ req: CreateSingleConversationRequest) async throws -> Conversation
    func createGroupConversation(_ req: CreateGroupConversationRequest) async throws -> Conversation
    func myConversations() async throws -> [Conversation]
    func deleteConversation(conversationId: String) async throws -> VoidResponse

    // Friends
    func sendFriendRequest(_ req: FriendRequestCreate) async throws -> FriendRequest
    func acceptFriendRequest(_ req: FriendRequestAccept) async throws -> VoidResponse
    func listFriends() async throws -> [User]
    func pendingFriendRequests() async throws -> [FriendRequest]

    // Messages
    func sendMessage(_ req: SendMessageRequest) async throws -> Message
    func getMessages(conversationId: String) async throws -> [Message]
    func unfriend(userId: String) async throws -> VoidResponse
}

public struct VoidResponse: Decodable {} // convenience for endpoints returning 200/204 + no JSON

// MARK: - Default Implementation

public final class DefaultAPIService: APIService {
    private let config: APIConfig
    private let session: URLSession

    public init(config: APIConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }
    
    private func logRequest(_ req: URLRequest, body: Data?) {
        var log = "\n========= 📤 REQUEST =========\n"
        log += "\(req.httpMethod ?? "GET") \(req.url?.absoluteString ?? "")\n"
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty {
            log += "Headers:\n"
            headers.forEach { k, v in log += "  \(k): \(v)\n" }
        }
        if let body = body, !body.isEmpty {
            let bodyStr = String(data: body, encoding: .utf8) ?? "<non-utf8 body>"
            log += "Body:\n\(bodyStr)\n"
        }
        log += "==============================\n"
        print(log)
    }

    private func logResponse(url: URL?, status: Int, data: Data?) {
        var log = "\n========= 📥 RESPONSE ========\n"
        log += "URL: \(url?.absoluteString ?? "")\n"
        log += "Status: \(status)\n"
        if let data = data, !data.isEmpty {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
            log += "Raw JSON:\n\(raw)\n"
        } else {
            log += "Raw JSON: <empty>\n"
        }
        log += "==============================\n"
        print(log)
    }

    // Generic request performer
    @discardableResult
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        authorized: Bool = true,
        expectsNoContent: Bool = false
    ) async throws -> T {

        guard var components = URLComponents(url: config.baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if let query = query, !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        var encodedBody: Data?
        
        if let body = body {
            do {
                encodedBody = try config.jsonEncoder.encode(AnyEncodable(body))
                req.httpBody = try config.jsonEncoder.encode(AnyEncodable(body))
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw APIError.encodingFailed
            }
        }

        if authorized, let token = config.tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // LOG: request
        logRequest(req, body: encodedBody)
        
        let (data, response): (Data?, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.unknown(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        // LOG: response (raw)
        logResponse(url: url, status: http.statusCode, data: data)
        
        // 204 No Content or explicitly expected no content
        if (http.statusCode == 204 || expectsNoContent), (T.self == VoidResponse.self) {
            return VoidResponse() as! T
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = data.flatMap { String(data: $0, encoding: .utf8) }
            throw APIError.http(http.statusCode, message)
        }

        guard let data = data, !data.isEmpty else {
            if T.self == VoidResponse.self { return VoidResponse() as! T }
            throw APIError.noData
        }

        do {
            return try config.jsonDecoder.decode(T.self, from: data)
        } catch {
            let sample = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
            print("Decoding failed for \(T.self). Raw JSON sample:\n\(sample)")
            throw APIError.decodingFailed(error)
        }
    }

    // MARK: - Endpoints mapping

    // Auth
    public func register(_ req: RegisterRequest) async throws -> TokenResponse {
        try await request("/auth/register", method: "POST", body: req, authorized: false)
    }

    public func login(_ req: LoginRequest) async throws -> TokenResponse {
        try await request("/auth/login", method: "POST", body: req, authorized: false)
    }

    public func forgotPassword(_ req: ForgotPasswordRequest) async throws -> VoidResponse {
        try await request("/auth/forgot-password", method: "POST", body: req, authorized: false)
    }

    public func resetPassword(_ req: ResetPasswordRequest) async throws -> VoidResponse {
        try await request("/auth/reset-password", method: "POST", body: req, authorized: false)
    }

    // Users
    public func me() async throws -> User {
        try await request("/users/me")
    }

    public func searchUsers(q: String) async throws -> [User] {
        try await request("/users/search", query: [URLQueryItem(name: "q", value: q)])
    }

    public func removeCurrentUser() async throws -> VoidResponse {
        try await request("/users/remove", method: "DELETE")
    }

    // Conversations
    public func createSingleConversation(_ req: CreateSingleConversationRequest) async throws -> Conversation {
        try await request("/conversations/single", method: "POST", body: req)
    }

    public func createGroupConversation(_ req: CreateGroupConversationRequest) async throws -> Conversation {
        try await request("/conversations/group", method: "POST", body: req)
    }

    public func myConversations() async throws -> [Conversation] {
        try await request("/conversations/my")
    }
    
    public func deleteConversation(conversationId: String) async throws -> VoidResponse {
        try await request("/conversations/\(conversationId)",
                          method: "DELETE",
                          expectsNoContent: true)
    }

    // Friends
    public func sendFriendRequest(_ req: FriendRequestCreate) async throws -> FriendRequest {
        try await request("/friends/request", method: "POST", body: req)
    }

    public func acceptFriendRequest(_ req: FriendRequestAccept) async throws -> VoidResponse {
        try await request("/friends/accept", method: "POST", body: req)
    }

    public func listFriends() async throws -> [User] {
        try await request("/friends/list")
    }

    public func pendingFriendRequests() async throws -> [FriendRequest] {
        try await request("/friends/pending")
    }

    // Messages
    public func sendMessage(_ req: SendMessageRequest) async throws -> Message {
        try await request("/messages/send", method: "POST", body: req)
    }

    public func getMessages(conversationId: String) async throws -> [Message] {
        try await request("/messages/\(conversationId)")
    }
    
    public func unfriend(userId: String) async throws -> VoidResponse {
        try await request("/friends/\(userId)", method: "DELETE")
    }
}

// MARK: - Utilities

/// Erases concrete Encodable type – helpful for generic request bodies
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

// MARK: - Quick usage example

/*
 let service = DefaultAPIService(
     config: APIConfig(
         baseURL: URL(string: "http://localhost:3000")!,
         tokenProvider: { KeychainHelper.shared.accessToken } // Or other storage
     )
 )

 // Login:
 let session = try await service.login(.init(email: "a@b.com", password: "secret"))
 KeychainHelper.shared.accessToken = session.token

 // Search users:
 let users = try await service.searchUsers(q: "john")

 // Create 1-1 conversation then send message:
 let conv = try await service.createSingleConversation(.init(userId: users[0].id))
 let msg  = try await service.sendMessage(.init(conversationId: conv.id, content: "Hello!"))
*/
