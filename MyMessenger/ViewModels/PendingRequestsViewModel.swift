//
//  PendingRequestsViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 18/9/25.
//

import Foundation
import Combine

@MainActor
final class PendingRequestsViewModel: ObservableObject {
    @Published var items: [FriendRequest] = []
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var accepting: Set<String> = []   // requestId đang accept

    private let service: DefaultAPIService

    init(service: DefaultAPIService) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await fetch()
    }

    func reload() async { await fetch() }

    private func fetch() async {
        do {
            let rs = try await service.pendingFriendRequests()
            items = rs
        } catch {
            show(error)
        }
    }

    func accept(requestId: String) {
        guard !accepting.contains(requestId) else { return }
        accepting.insert(requestId)

        // Optimistic update
        let backup = items
        items.removeAll { $0.id == requestId }

        Task { @MainActor in
            do {
                _ = try await service.acceptFriendRequest(.init(fromUserId: requestId))
                accepting.remove(requestId)
            } catch {
                // Rollback
                items = backup
                accepting.remove(requestId)
                show(error)
            }
        }
    }

    private func show(_ error: Error) {
        hasError = true
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

