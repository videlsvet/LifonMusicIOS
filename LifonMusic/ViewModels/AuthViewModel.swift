import Foundation
import SwiftUI

public enum AuthStep {
    case username
    case password
    case setPassword
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var step: AuthStep = .username
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    public func submitUsername() async {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else {
            errorMessage = "Введи имя пользователя"
            return
        }

        isLoading = true
        errorMessage = nil

        let result = await ApiClient.shared.checkUsername(clean)
        isLoading = false

        switch result {
        case .needsPassword:
            self.step = .setPassword
            self.password = ""
            self.confirmPassword = ""
        case .hasPassword:
            self.step = .password
            self.password = ""
        case .error(let msg):
            self.errorMessage = msg
        }
    }

    public func submitLogin(onSuccess: @escaping (String, String) -> Void) async {
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if step == .setPassword {
            guard password.count >= 8 else {
                errorMessage = "Пароль должен быть не менее 8 символов"
                return
            }
            guard password == confirmPassword else {
                errorMessage = "Пароли не совпадают"
                return
            }
        } else {
            guard !password.isEmpty else {
                errorMessage = "Введи пароль"
                return
            }
        }

        isLoading = true
        errorMessage = nil

        let result = await ApiClient.shared.login(username: cleanUser, password: password)
        isLoading = false

        switch result {
        case .success(let token):
            onSuccess(token, cleanUser)
        case .error(let msg):
            self.errorMessage = msg
        }
    }

    public func resetToUsername() {
        step = .username
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
}
