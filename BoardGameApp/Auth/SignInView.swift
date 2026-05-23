import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var auth: AuthService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Board Game")
                    .font(.largeTitle.bold())
                Text("Sign in to save your records to your account.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task { @MainActor in await auth.completeSignIn(with: authorization) }
                    case .failure(let error):
                        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                            return
                        }
                        let message = error.localizedDescription
                        Task { @MainActor in auth.lastError = message }
                    }
                },
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 32)
            .disabled(auth.isAuthenticating)

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if auth.isAuthenticating {
                ProgressView()
            }

            Spacer()
        }
    }
}

#Preview {
    SignInView(auth: AuthService())
}
