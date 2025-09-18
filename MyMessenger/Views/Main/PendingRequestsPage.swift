//
//  PendingRequestsPage.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 18/9/25.
//

import SwiftUI

struct PendingRequestsPage: View {
    @StateObject private var vm: PendingRequestsViewModel

    init(service: DefaultAPIService) {
        _vm = StateObject(wrappedValue: PendingRequestsViewModel(service: service))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView("Loading…")
            } else if vm.items.isEmpty {
                ContentUnavailableView("No pending requests",
                                       systemImage: "envelope.badge",
                                       description: Text("Chưa có lời mời kết bạn mới."))
            } else {
                List {
                    ForEach(vm.items, id: \.id) { req in
                        HStack(spacing: 12) {
                            // email người gửi
                            VStack(alignment: .leading, spacing: 2) {
                                Text(req.from.email)
                                    .font(.body).bold()
                                Text(req.from.username)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                vm.accept(requestId: req.id)
                            } label: {
                                if vm.accepting.contains(req.id) {
                                    ProgressView()
                                } else {
                                    Label("Accept", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.accepting.contains(req.id))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Requests")
        .task { await vm.load() }
        .refreshable { await vm.reload() }
        .alert("Error", isPresented: $vm.hasError, actions: {
            Button("OK", role: .cancel) { vm.hasError = false }
        }, message: {
            Text(vm.errorMessage ?? "Something went wrong.")
        })
    }
}

struct PendingRequestsPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PendingRequestsPage(service: .init(config: .init()))
        }
    }
}
