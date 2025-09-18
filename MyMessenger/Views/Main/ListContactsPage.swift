//
//  ListContactsPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 15/9/25.
//

import SwiftUI

struct ListContactsPage: View {
    @StateObject private var vm = ContactsViewModel(service: .init(config: .init()))

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

                            Spacer()

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
        .task {
            await vm.load()
        }
        .alert("Error", isPresented: $vm.hasError, actions: {
            Button("OK", role: .cancel) { vm.hasError = false }
        }, message: {
            Text(vm.errorMessage ?? "Something went wrong.")
        })
        .refreshable {
            await vm.reload()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PendingRequestsPage(service: .init(config: .init()))
                } label: {
                    Label("Requests", systemImage: "envelope.badge")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    InviteFriendPage(service: .init(config: .init()))
                } label: {
                    Label("Add Friend", systemImage: "person.badge.plus")
                }
            }
        }

    }
}

struct ListContactsPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListContactsPage()
        }
        .environmentObject(
            ContactsViewModel_Preview()
        )
    }
}

/// Mock ViewModel cho Preview
@MainActor
final class ContactsViewModel_Preview: ContactsViewModel {
    init() {
        super.init(service: .init(config: .init()))
        self.friends = [
            User(id: "1", username: "Alice", email: "alice@example.com", avatar: nil),
            User(id: "2", username: "Bob", email: "bob@example.com", avatar: nil)
        ]
    }
}
