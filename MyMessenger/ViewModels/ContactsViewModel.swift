//
//  ContactsViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 17/9/25.
//

import SwiftUI
import Combine

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var unfriending: Set<String> = []

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

    func reload() async {
        await fetch()
    }

    private func fetch() async {
        do {
            let items = try await service.listFriends()
            friends = items
        } catch {
            //show(error)
        }
    }

    func unfriend(userId: String) {
        guard !unfriending.contains(userId) else { return }
        unfriending.insert(userId)

        let backup = friends
        friends.removeAll { $0.id == userId }

        Task { @MainActor in
            do {
                try await service.unfriend(userId: userId)
                unfriending.remove(userId)
            } catch {
                friends = backup
                unfriending.remove(userId)
                show(error)
            }
        }
    }

    private func show(_ error: Error) {
        hasError = true
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
