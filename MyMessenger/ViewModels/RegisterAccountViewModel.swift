//
//  RegisterAccountViewModel.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 13/7/25.
//

import Foundation

final class RegisterAccountViewModel: ObservableObject {
    let service: DefaultAPIService
    @Published var didRegister = false
    @Published var isLoading = false

    init(service: DefaultAPIService) {
        self.service = service
    }
    
    @MainActor
    func register(param: RegisterRequest) async throws {
        isLoading = true
        do {
           let result = try await service.register(param)
            print(result)
            isLoading = false
            didRegister = true
        } catch {
            isLoading = false
            print("Handle error")
        }
    }
}
