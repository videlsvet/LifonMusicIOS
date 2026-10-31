import SwiftUI

public struct AuthView: View {
    @StateObject private var authVm = AuthViewModel()
    @ObservedObject var appVm = AppViewModel.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 24) {
                // Top Dismiss
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Card Content based on step
                VStack(spacing: 12) {
                    Text(titleForStep)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)

                    Text(subtitleForStep)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0).opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 14) {
                    switch authVm.step {
                    case .username:
                        inputField(placeholder: "Имя пользователя", text: $authVm.username, isSecure: false)

                    case .password:
                        inputField(placeholder: "Пароль", text: $authVm.password, isSecure: true)

                    case .setPassword:
                        inputField(placeholder: "Новый пароль (мин. 8 символов)", text: $authVm.password, isSecure: true)
                        inputField(placeholder: "Повтори пароль", text: $authVm.confirmPassword, isSecure: true)
                    }

                    // Error text
                    if let err = authVm.errorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.54))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Primary Action Button
                    Button(action: handleAction) {
                        HStack {
                            if authVm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Text(buttonTextForStep)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(authVm.isLoading)

                    if authVm.step != .username {
                        Button(action: { authVm.resetToUsername() }) {
                            Text("← Другой аккаунт")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 6)
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
    }

    private var titleForStep: String {
        switch authVm.step {
        case .username: return "Войти"
        case .password: return "Добро пожаловать"
        case .setPassword: return "Придумай пароль"
        }
    }

    private var subtitleForStep: String {
        switch authVm.step {
        case .username: return "Введи свой никнейм для входа в LifonMUSIC"
        case .password: return "Вход для пользователя @\(authVm.username)"
        case .setPassword: return "Привет, \(authVm.username)! Создай надёжный пароль для входа."
        }
    }

    private var buttonTextForStep: String {
        switch authVm.step {
        case .username: return "Продолжить"
        case .password: return "Войти"
        case .setPassword: return "Создать пароль и войти"
        }
    }

    private func inputField(placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func handleAction() {
        Task {
            if authVm.step == .username {
                await authVm.submitUsername()
            } else {
                await authVm.submitLogin { token, user in
                    appVm.setAuthToken(token: token, username: user)
                    dismiss()
                }
            }
        }
    }
}
