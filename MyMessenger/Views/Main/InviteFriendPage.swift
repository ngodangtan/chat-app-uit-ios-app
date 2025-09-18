//
//  InviteFriendPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 18/9/25.
//

import Foundation
import Combine

@MainActor
final class InviteFriendViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var isSending: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service: DefaultAPIService

    init(service: DefaultAPIService) {
        self.service = service
    }

    func send() async {
        guard validateEmail(email) else {
            showError("Email không hợp lệ.")
            return
        }
        guard !isSending else { return }

        isSending = true
        defer { isSending = false }

        do {
            _ = try await service.sendFriendRequest(.init(email: email))
            successMessage = "Đã gửi lời mời kết bạn tới \(email)."
            email = ""
        } catch {
            showError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        hasError = true
        errorMessage = message
    }

    private func validateEmail(_ text: String) -> Bool {
        // Validator đơn giản: có @ và dấu chấm sau @
        guard let at = text.firstIndex(of: "@") else { return false }
        let domain = text[text.index(after: at)...]
        return domain.contains(".")
    }
}
