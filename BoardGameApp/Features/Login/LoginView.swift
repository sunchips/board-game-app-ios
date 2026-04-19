import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                Text("Board Game")
                    .font(.largeTitle).bold()
                Text("Track your game sessions and save your regular players.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handle(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 32)
            .disabled(auth.isAuthenticating)

            if auth.isAuthenticating {
                ProgressView()
            }

            if let message = auth.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 12)
        }
    }

    private func handle(_ result: Result<ASAuthorization, any Error>) async {
        switch result {
        case .success(let authorization):
            await auth.handleAppleAuthorization(authorization)
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            print("Apple sign-in failed: \(error)")
        }
    }
}

#Preview {
    LoginView().environment(AuthStore())
}
