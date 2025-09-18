//
//  InviteFriendViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 18/9/25.
//

import SwiftUI

struct InviteFriendPage: View {
    @StateObject private var vm: InviteFriendViewModel

    init(service: DefaultAPIService) {
        _vm = StateObject(wrappedValue: InviteFriendViewModel(service: service))
    }

    var body: some View {
        Form {
            Section(header: Text("Email")) {
                TextField("nhập email bạn bè…", text: $vm.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await vm.send() }
                } label: {
                    if vm.isSending {
                        ProgressView()
                    } else {
                        Label("Gửi lời mời", systemImage: "paperplane.fill")
                    }
                }
                .disabled(vm.isSending || vm.email.isEmpty)
            }

            if let success = vm.successMessage {
                Section {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Kết bạn")
        .alert("Lỗi", isPresented: $vm.hasError, actions: {
            Button("OK", role: .cancel) { vm.hasError = false }
        }, message: {
            Text(vm.errorMessage ?? "Đã có lỗi xảy ra.")
        })
    }
}

struct InviteFriendPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            InviteFriendPage(service: .init(config: .init()))
        }
    }
}
