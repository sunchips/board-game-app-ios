import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var currentUser: AuthUser?
    private(set) var isAuthenticating: Bool = false
    var lastError: String?

    private static let tokenKey = "session_token"
    private static let userKey = "session_user"

    var isSignedIn: Bool { currentUser != nil }

    /// Returns the cached session token (if any) for the APIClient to attach as a
    /// `Authorization: Bearer` header. Returning nil is fine — the server treats
    /// unauthenticated calls as anonymous and creates unowned records.
    func sessionToken() -> String? {
        KeychainStore.get(Self.tokenKey)
    }

    init() {
        if let token = KeychainStore.get(Self.tokenKey), !token.isEmpty,
           let userJSON = UserDefaults.standard.data(forKey: Self.userKey),
           let user = try? JSONDecoder.iso8601().decode(AuthUser.self, from: userJSON) {
            self.currentUser = user
        }
    }

    func completeSignIn(with authorization: ASAuthorization) async {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            lastError = "Unexpected credential type from Apple."
            return
        }
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8), !identityToken.isEmpty else {
            lastError = "Apple did not return an identity token."
            return
        }
        // Apple only sends the user's chosen display name on the first sign-in; capture it
        // when present and pass it through so the server can persist it.
        let displayName: String? = credential.fullName.flatMap { components in
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
            return formatted.isEmpty ? nil : formatted
        }

        do {
            let session = try await APIClient.shared.signInWithApple(
                AppleSignInRequest(
                    identityToken: identityToken,
                    email: credential.email,
                    name: displayName,
                ),
            )
            persist(session: session)
            currentUser = session.user
        } catch let apiError as APIError {
            lastError = apiError.errorDescription ?? "Sign in failed"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        KeychainStore.delete(Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.userKey)
        currentUser = nil
    }

    private func persist(session: AuthSession) {
        KeychainStore.set(session.sessionToken, for: Self.tokenKey)
        if let data = try? JSONEncoder.iso8601().encode(session.user) {
            UserDefaults.standard.set(data, forKey: Self.userKey)
        }
    }
}

extension JSONEncoder {
    static func iso8601() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static func iso8601() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
